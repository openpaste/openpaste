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
            let includeSensitive = UserDefaults.standard.bool(
                forKey: Constants.iCloudSyncIncludeSensitiveKey)
            let now = Date()

            let enqueued = try await dbQueue.write { db -> Int in
                var total = 0

                // Enqueue clipboard items not yet in outbox
                let itemSQL =
                    includeSensitive
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

                // Enqueue smart lists not yet in outbox (skip built-in)
                let smartListIds = try String.fetchAll(
                    db,
                    sql: """
                        SELECT id FROM smartLists
                        WHERE isDeleted = 0 AND isBuiltIn = 0
                          AND ('smartlist_' || id) NOT IN (SELECT recordName FROM sync_metadata)
                        """
                )
                for id in smartListIds {
                    let recordName = "smartlist_" + id
                    try db.execute(
                        sql: """
                            INSERT OR IGNORE INTO sync_metadata
                                (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
                            VALUES (?, 'smartLists', ?, 'upsert', 'pending', 0, ?)
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
            let records =
                try SyncMetadataRecord
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
                sql:
                    "UPDATE sync_metadata SET syncStatus = 'pending', lastError = NULL, updatedAt = ? WHERE syncStatus = 'inFlight'",
                arguments: [Date()]
            )
        }
    }

    /// One-time recovery: reset records stuck in 'error' due to ServerRecordChanged
    /// ("record to insert already exists") so they can retry with the new fix.
    func recoverServerRecordChangedErrors() async {
        let count = try? await dbQueue.write { db -> Int in
            try db.execute(
                sql: """
                    UPDATE sync_metadata
                    SET syncStatus = 'pending', retryCount = 0, lastError = NULL, updatedAt = ?
                    WHERE syncStatus = 'error'
                      AND lastError LIKE '%record to insert already exists%'
                    """,
                arguments: [Date()]
            )
            return db.changesCount
        }
        if let count, count > 0 {
            syncLog.info("Recovered \(count) records stuck with ServerRecordChanged errors")
        }
    }

    func markOutboxSynced(recordName: String) async {
        try? await dbQueue.write { db in
            try db.execute(
                sql:
                    "UPDATE sync_metadata SET syncStatus = 'synced', lastError = NULL WHERE recordName = ?",
                arguments: [recordName]
            )
        }
    }

    func markOutboxError(recordName: String, message: String) async {
        try? await dbQueue.write { db in
            try db.execute(
                sql:
                    "UPDATE sync_metadata SET syncStatus = 'error', lastError = ?, retryCount = retryCount + 1, updatedAt = ? WHERE recordName = ?",
                arguments: [message, Date(), recordName]
            )
        }
    }

    // MARK: - B5: Tombstone Cleanup

    /// Deletes old tombstones: items soft-deleted > 30 days ago that are synced.
    /// Should be called periodically (e.g., daily or on app launch).
    func cleanupTombstones() async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        do {
            let deleted = try await dbQueue.write { db -> Int in
                var total = 0

                try db.execute(
                    sql: """
                        DELETE FROM sync_metadata
                        WHERE syncStatus = 'synced'
                          AND localId IN (
                            SELECT id FROM clipboardItems WHERE isDeleted = 1 AND modifiedAt < ?
                          )
                        """,
                    arguments: [cutoff]
                )
                total += db.changesCount

                try db.execute(
                    sql: "DELETE FROM clipboardItems WHERE isDeleted = 1 AND modifiedAt < ?",
                    arguments: [cutoff]
                )
                total += db.changesCount

                // Collection tombstones
                try db.execute(
                    sql: """
                        DELETE FROM sync_metadata
                        WHERE syncStatus = 'synced'
                          AND localId IN (
                            SELECT id FROM collections WHERE isDeleted = 1 AND modifiedAt < ?
                          )
                        """,
                    arguments: [cutoff]
                )
                total += db.changesCount

                try db.execute(
                    sql: "DELETE FROM collections WHERE isDeleted = 1 AND modifiedAt < ?",
                    arguments: [cutoff]
                )
                total += db.changesCount

                // Smart list tombstones
                try db.execute(
                    sql: """
                        DELETE FROM sync_metadata
                        WHERE syncStatus = 'synced'
                          AND localId IN (
                            SELECT id FROM smartLists WHERE isDeleted = 1 AND modifiedAt < ?
                          )
                        """,
                    arguments: [cutoff]
                )
                total += db.changesCount

                try db.execute(
                    sql: "DELETE FROM smartLists WHERE isDeleted = 1 AND modifiedAt < ?",
                    arguments: [cutoff]
                )
                total += db.changesCount

                return total
            }
            if deleted > 0 {
                syncLog.info("Tombstone cleanup: removed \(deleted) rows")
            }
        } catch {
            syncLog.error("Tombstone cleanup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - B6: sync_metadata Pruning

    /// Prunes old synced metadata entries to prevent unbounded table growth.
    func pruneSyncMetadata(keepCount: Int = 10_000) async {
        do {
            let pruned = try await dbQueue.write { db -> Int in
                let total =
                    try Int.fetchOne(
                        db,
                        sql: "SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = 'synced'"
                    ) ?? 0
                guard total > keepCount else { return 0 }

                let deleteCount = total - keepCount
                try db.execute(
                    sql: """
                        DELETE FROM sync_metadata
                        WHERE rowid IN (
                            SELECT rowid FROM sync_metadata
                            WHERE syncStatus = 'synced'
                            ORDER BY updatedAt ASC
                            LIMIT ?
                        )
                        """,
                    arguments: [deleteCount]
                )
                return db.changesCount
            }
            if pruned > 0 {
                syncLog.info("Metadata pruning: removed \(pruned) old synced entries")
            }
        } catch {
            syncLog.error("Metadata pruning failed: \(error.localizedDescription)")
        }
    }
}
