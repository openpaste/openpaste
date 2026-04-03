import Foundation
import GRDB

final class SyncChangeTracker: TransactionObserver {
    private let lock = NSLock()
    private var suspensionCount: Int = 0
    private var pendingEvents: [DatabaseEvent] = []

    private let includeSensitiveProvider: @Sendable () -> Bool

    init(includeSensitiveProvider: @escaping @Sendable () -> Bool = {
        UserDefaults.standard.bool(forKey: Constants.iCloudSyncIncludeSensitiveKey)
    }) {
        self.includeSensitiveProvider = includeSensitiveProvider
    }

    func suspend() {
        lock.lock()
        suspensionCount += 1
        lock.unlock()
    }

    func resume() {
        lock.lock()
        suspensionCount = max(0, suspensionCount - 1)
        lock.unlock()
    }

    private func isSuspended() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return suspensionCount > 0
    }

    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        switch eventKind {
        case .insert(let tableName):
            return tableName == "clipboardItems" || tableName == "collections"

        case .update(let tableName, let columnNames):
            if tableName == "clipboardItems" {
                return columnNames.contains("syncVersion") || columnNames.contains("isDeleted") || columnNames.contains("isSensitive")
            }
            if tableName == "collections" {
                return columnNames.contains("modifiedAt") || columnNames.contains("isDeleted") || columnNames.contains("name") || columnNames.contains("color")
            }
            return false

        case .delete:
            // App uses soft-delete (tombstones), so physical deletes are not sync-relevant.
            return false
        }
    }

    func databaseDidChange(with event: DatabaseEvent) {
        guard !isSuspended() else { return }
        guard event.tableName == "clipboardItems" || event.tableName == "collections" else { return }

        lock.lock()
        pendingEvents.append(event.copy())
        lock.unlock()
    }

    func databaseDidCommit(_ db: Database) {
        let events: [DatabaseEvent] = {
            lock.lock()
            defer { lock.unlock() }
            defer { pendingEvents.removeAll(keepingCapacity: true) }
            return pendingEvents
        }()

        guard !events.isEmpty else { return }

        let now = Date()
        let includeSensitive = includeSensitiveProvider()

        let clipboardRowIDs = Set(events.filter { $0.tableName == "clipboardItems" }.map { $0.rowID })
        let collectionRowIDs = Set(events.filter { $0.tableName == "collections" }.map { $0.rowID })

        if !clipboardRowIDs.isEmpty {
            let ids = Array(clipboardRowIDs)
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let sql = "SELECT rowid, id, isDeleted, isSensitive FROM clipboardItems WHERE rowid IN (\(placeholders))"
            let rows = try? Row.fetchAll(db, sql: sql, arguments: StatementArguments(ids))
            rows?.forEach { row in
                let id: String = row["id"]
                let isDeleted: Bool = row["isDeleted"]
                let isSensitive: Bool = row["isSensitive"]

                guard includeSensitive || !isSensitive else { return }

                let recordName = "item_" + id
                let operation: SyncOutboxOperation = isDeleted ? .delete : .upsert
                Self.enqueueOutbox(db, recordName: recordName, tableName: "clipboardItems", localId: id, operation: operation, updatedAt: now)
            }
        }

        if !collectionRowIDs.isEmpty {
            let ids = Array(collectionRowIDs)
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let sql = "SELECT rowid, id, isDeleted FROM collections WHERE rowid IN (\(placeholders))"
            let rows = try? Row.fetchAll(db, sql: sql, arguments: StatementArguments(ids))
            rows?.forEach { row in
                let id: String = row["id"]
                let isDeleted: Bool = row["isDeleted"]

                let recordName = "collection_" + id
                let operation: SyncOutboxOperation = isDeleted ? .delete : .upsert
                Self.enqueueOutbox(db, recordName: recordName, tableName: "collections", localId: id, operation: operation, updatedAt: now)
            }
        }
    }

    func databaseDidRollback(_ db: Database) {
        lock.lock()
        pendingEvents.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    private static func enqueueOutbox(
        _ db: Database,
        recordName: String,
        tableName: String,
        localId: String,
        operation: SyncOutboxOperation,
        updatedAt: Date
    ) {
        try? db.execute(
            sql: """
            INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
            VALUES (?, ?, ?, ?, 'pending', 0, ?)
            ON CONFLICT(recordName) DO UPDATE SET
              tableName = excluded.tableName,
              localId = excluded.localId,
              operation = excluded.operation,
              syncStatus = 'pending',
              lastError = NULL,
              retryCount = 0,
              updatedAt = excluded.updatedAt;
            """,
            arguments: [recordName, tableName, localId, operation.rawValue, updatedAt]
        )
    }
}
