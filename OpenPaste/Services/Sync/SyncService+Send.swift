import Foundation
@preconcurrency import CloudKit
import GRDB

@available(macOS 14.0, *)
extension SyncService {
    func buildRecordsToSave(outbox: [SyncMetadataRecord]) async -> [CKRecord] {
        let includeSensitive = UserDefaults.standard.bool(forKey: Constants.iCloudSyncIncludeSensitiveKey)

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

        for failure in failed {
            let recordName = failure.record.recordID.recordName
            cleanupStagedAsset(recordName: recordName)
            await markOutboxError(recordName: recordName, message: failure.error.localizedDescription)
        }

        touchLastSyncDate()
    }
}
