import Foundation
import GRDB

@available(macOS 14.0, *)
extension SyncService {
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
