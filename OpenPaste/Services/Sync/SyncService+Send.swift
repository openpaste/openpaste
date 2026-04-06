import Foundation
@preconcurrency import CloudKit
import GRDB
import os.log

private let syncLog = Logger(subsystem: "dev.tuanle.OpenPaste", category: "SyncSend")

@available(macOS 14.0, *)
extension SyncService {
    func buildRecordsToSave(outbox: [SyncMetadataRecord]) async -> [CKRecord] {
        let includeSensitive = UserDefaults.standard.bool(forKey: Constants.iCloudSyncIncludeSensitiveKey)
        let maxSizeBytes = UserDefaults.standard.integer(forKey: Constants.iCloudSyncMaxItemSizeBytesKey)

        var records: [CKRecord] = []
        for entry in outbox {
            do {
                if entry.tableName == "clipboardItems" {
                    guard let local = try await fetchClipboardItem(id: entry.localId) else {
                        await markOutboxError(recordName: entry.recordName, message: "Missing local record")
                        continue
                    }
                    if local.isSensitive && !includeSensitive {
                        await markOutboxSynced(recordName: entry.recordName)
                        continue
                    }
                    // A6: Skip items exceeding max sync size
                    if maxSizeBytes > 0 && local.content.count > maxSizeBytes {
                        syncLog.info("Skipping \(entry.recordName): content size \(local.content.count) exceeds limit \(maxSizeBytes)")
                        await markOutboxSynced(recordName: entry.recordName)
                        await removeFromEnginePendingQueue(recordName: entry.recordName)
                        continue
                    }

                    let keyVersion = try await currentKeyVersion()
                    let mapped = try CloudKitMapper.makeClipboardItemRecord(
                        recordName: entry.recordName,
                        local: local,
                        keyVersion: keyVersion,
                        encryption: encryption
                    )
                    stageAsset(url: mapped.stagedFileURL, recordName: entry.recordName)
                    records.append(mapped.record)
                } else if entry.tableName == "collections" {
                    guard let local = try await fetchCollection(id: entry.localId) else {
                        await markOutboxError(recordName: entry.recordName, message: "Missing local record")
                        continue
                    }

                    let keyVersion = try await currentKeyVersion()
                    let mapped = try CloudKitMapper.makeCollectionRecord(
                        recordName: entry.recordName,
                        local: local,
                        keyVersion: keyVersion,
                        encryption: encryption
                    )
                    stageAsset(url: mapped.stagedFileURL, recordName: entry.recordName)
                    records.append(mapped.record)
                } else if entry.tableName == "smartLists" {
                    guard let local = try await fetchSmartListRecord(id: entry.localId) else {
                        await markOutboxError(recordName: entry.recordName, message: "Missing local record")
                        continue
                    }

                    let keyVersion = try await currentKeyVersion()
                    let mapped = try CloudKitMapper.makeSmartListRecord(
                        recordName: entry.recordName,
                        local: local,
                        keyVersion: keyVersion,
                        encryption: encryption
                    )
                    stageAsset(url: mapped.stagedFileURL, recordName: entry.recordName)
                    records.append(mapped.record)
                }
            } catch {
                await markOutboxError(recordName: entry.recordName, message: error.localizedDescription)
            }
        }
        return records
    }

    func handleSent(
        saved: [CKRecord],
        failed: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]
    ) async {
        for record in saved {
            let recordName = record.recordID.recordName
            cleanupStagedAsset(recordName: recordName)

            do {
                let system = try CloudKitSystemFields.encode(from: record)
                let localId = record[CloudKitMapper.Field.localId] as? String ?? ""

                try await dbQueue.write { db in
                    if record.recordType == CloudKitMapper.RecordType.clipboardItem {
                        try db.execute(
                            sql: "UPDATE clipboardItems SET ckSystemFields = ? WHERE id = ?",
                            arguments: [system, localId]
                        )
                    } else if record.recordType == CloudKitMapper.RecordType.collection {
                        try db.execute(
                            sql: "UPDATE collections SET ckSystemFields = ? WHERE id = ?",
                            arguments: [system, localId]
                        )
                    } else if record.recordType == CloudKitMapper.RecordType.smartList {
                        try db.execute(
                            sql: "UPDATE smartLists SET ckSystemFields = ? WHERE id = ?",
                            arguments: [system, localId]
                        )
                    }

                    try db.execute(
                        sql: "UPDATE sync_metadata SET syncStatus = 'synced', lastError = NULL WHERE recordName = ?",
                        arguments: [recordName]
                    )
                }
            } catch {
                await markOutboxError(recordName: recordName, message: error.localizedDescription)
            }
        }

        var zoneNotFoundDetected = false
        for failure in failed {
            let recordName = failure.record.recordID.recordName
            cleanupStagedAsset(recordName: recordName)

            let ckError = failure.error as CKError
            if ckError.code == .zoneNotFound {
                zoneNotFoundDetected = true
                // Reset to pending so they're re-sent after zone recreation
                await markOutboxForRetry(recordName: recordName, retryAfter: 5)
            } else if isRetryableCloudKitError(ckError) {
                let retryAfter = ckError.retryAfterSeconds ?? Constants.syncRetryBaseInterval
                syncLog.info("Rate limited for \(recordName), CKSyncEngine will retry after ~\(retryAfter)s")
                await markOutboxForRetry(recordName: recordName, retryAfter: retryAfter)
            } else {
                await markOutboxError(recordName: recordName, message: failure.error.localizedDescription)
                await removeFromEnginePendingQueue(recordName: recordName)
            }
        }

        // B2: Zone-not-found recovery — recreate zone and re-enqueue
        if zoneNotFoundDetected {
            syncLog.warning("Zone not found — attempting to recreate")
            await recoverFromZoneNotFound()
        }

        touchLastSyncDate()
        // Note: syncCompleted is emitted by handleEvent(.didSendChanges), not here,
        // to avoid duplicate events when CKSyncEngine sends multiple batches.
    }

    /// Check if a CloudKit error is retryable (rate limit, zone busy, service unavailable)
    private func isRetryableCloudKitError(_ error: CKError) -> Bool {
        switch error.code {
        case .requestRateLimited, .zoneBusy, .serviceUnavailable:
            return true
        default:
            return false
        }
    }

    /// Mark an outbox entry for retry without incrementing retryCount.
    /// Sets updatedAt forward so the retry loop respects the cooldown.
    func markOutboxForRetry(recordName: String, retryAfter: TimeInterval) async {
        let futureDate = Date().addingTimeInterval(retryAfter)
        try? await dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE sync_metadata
                SET syncStatus = ?, lastError = 'Rate limited', updatedAt = ?
                WHERE recordName = ?
                """,
                arguments: [SyncOutboxStatus.pending.rawValue, futureDate, recordName]
            )
        }
    }

    /// Remove a record from CKSyncEngine's internal pending queue
    /// to prevent infinite loops for records that can never be built.
    private func removeFromEnginePendingQueue(recordName: String) async {
        guard let engine = currentEngineSnapshot() else { return }
        let change = CKSyncEngine.PendingRecordZoneChange.saveRecord(
            CKRecord.ID(recordName: recordName, zoneID: CloudKitMapper.zoneID)
        )
        engine.state.remove(pendingRecordZoneChanges: [change])
    }
}
