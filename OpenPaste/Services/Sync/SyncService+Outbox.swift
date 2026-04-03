import Foundation
import GRDB
import os.log

private let syncLog = Logger(subsystem: "dev.tuanle.OpenPaste", category: "SyncOutbox")

@available(macOS 14.0, *)
extension SyncService {

    /// Seeds the outbox with local records not yet tracked in sync_metadata.
    /// Called during `start()` to handle data created before sync was enabled.
    func enqueueExistingRecordsIfNeeded() async {
        do {
            let includeSensitive = UserDefaults.standard.bool(forKey: Constants.iCloudSyncIncludeSensitiveKey)
            let now = Date()

            let enqueued = try await dbQueue.write { db -> Int in
                var total = 0

                // Enqueue clipboard items not yet in outbox
                let itemSQL = includeSensitive
                    ? """
                      SELECT id FROM clipboardItems
                      WHERE isDeleted = 0
                        AND ('item_' || id) NOT IN (SELECT recordName FROM sync_metadata)
                      """
                    : """
                      SELECT id FROM clipboardItems
                      WHERE isDeleted = 0 AND isSensitive = 0
                        AND ('item_' || id) NOT IN (SELECT recordName FROM sync_metadata)
                      """
                let itemIds = try String.fetchAll(db, sql: itemSQL)
                for id in itemIds {
                    let recordName = "item_" + id
                    try db.execute(
                        sql: """
                        INSERT OR IGNORE INTO sync_metadata
                            (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
                        VALUES (?, 'clipboardItems', ?, 'upsert', 'pending', 0, ?)
                        """,
                        arguments: [recordName, id, now]
                    )
                    total += 1
                }

                // Enqueue collections not yet in outbox
                let collectionIds = try String.fetchAll(
                    db,
                    sql: """
                    SELECT id FROM collections
                    WHERE isDeleted = 0
                      AND ('collection_' || id) NOT IN (SELECT recordName FROM sync_metadata)
                    """
                )
                for id in collectionIds {
                    let recordName = "collection_" + id
                    try db.execute(
                        sql: """
                        INSERT OR IGNORE INTO sync_metadata
                            (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
                        VALUES (?, 'collections', ?, 'upsert', 'pending', 0, ?)
                        """,
                        arguments: [recordName, id, now]
                    )
                    total += 1
                }

                return total
            }

            if enqueued > 0 {
                syncLog.info("enqueueExisting: seeded \(enqueued) untracked records into outbox")
            } else {
                syncLog.info("enqueueExisting: all local records already tracked")
            }
        } catch {
            syncLog.error("enqueueExisting failed: \(error.localizedDescription)")
        }
    }

    func claimPendingOutbox(limit: Int) async throws -> [SyncMetadataRecord] {
        try await dbQueue.write { db in
            let records = try SyncMetadataRecord
                .filter(Column("syncStatus") == SyncOutboxStatus.pending.rawValue)
                .order(Column("updatedAt").asc)
                .limit(limit)
                .fetchAll(db)

            for r in records {
                try db.execute(
                    sql: "UPDATE sync_metadata SET syncStatus = 'inFlight' WHERE recordName = ?",
                    arguments: [r.recordName]
                )
            }
            return records
        }
    }

    func recoverInFlightOutbox() async {
        try? await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE sync_metadata SET syncStatus = 'pending', lastError = NULL, updatedAt = ? WHERE syncStatus = 'inFlight'",
                arguments: [Date()]
            )
        }
    }

    func markOutboxSynced(recordName: String) async {
        try? await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE sync_metadata SET syncStatus = 'synced', lastError = NULL WHERE recordName = ?",
                arguments: [recordName]
            )
        }
    }

    func markOutboxError(recordName: String, message: String) async {
        try? await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE sync_metadata SET syncStatus = 'error', lastError = ?, retryCount = retryCount + 1 WHERE recordName = ?",
                arguments: [message, recordName]
            )
        }
    }
}
