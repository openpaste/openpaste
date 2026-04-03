import Foundation
import GRDB

final class StorageService: StorageServiceProtocol, @unchecked Sendable {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func save(_ item: ClipboardItem) async throws {
        var record = ClipboardItemRecord(from: item)
        record.modifiedAt = Date()
        record.deviceId = DeviceID.current
        record.isDeleted = false
        try await dbQueue.write { db in
            try record.insert(db)
        }
    }

    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem] {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("isDeleted") == false)
                .order(Column("pinned").desc, Column("createdAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
                .map { $0.toClipboardItem() }
        }
    }

    func delete(_ id: UUID) async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboardItems SET isDeleted = 1, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE id = ?",
                arguments: [now, DeviceID.current, id.uuidString]
            )
        }
    }

    func deleteAll() async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboardItems SET isDeleted = 1, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE isDeleted = 0",
                arguments: [now, DeviceID.current]
            )
        }
    }

    func fetchByHash(_ hash: String) async throws -> ClipboardItem? {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("contentHash") == hash)
                .filter(Column("isDeleted") == false)
                .fetchOne(db)?
                .toClipboardItem()
        }
    }

    func updateAccessCount(_ id: UUID) async throws {
        try await dbQueue.write { db in
            if var record = try ClipboardItemRecord.fetchOne(db, key: id.uuidString) {
                record.accessCount += 1
                record.accessedAt = Date()
                try record.update(db)
            }
        }
    }

    func deleteExpired() async throws {
        let now = Date()
        let cutoff = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboardItems SET isDeleted = 1, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE isDeleted = 0 AND expiresAt IS NOT NULL AND expiresAt < ?",
                arguments: [now, DeviceID.current, cutoff]
            )
        }
    }

    func itemCount() async throws -> Int {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("isDeleted") == false)
                .fetchCount(db)
        }
    }

    func update(_ item: ClipboardItem) async throws {
        var record = ClipboardItemRecord(from: item)
        record.modifiedAt = Date()
        record.deviceId = DeviceID.current
        record.syncVersion += 1
        try await dbQueue.write { db in
            try record.update(db)
        }
    }

    // MARK: - Collections

    func fetchCollections() async throws -> [Collection] {
        try await dbQueue.read { db in
            try CollectionRecord
                .filter(Column("isDeleted") == false)
                .order(Column("name").asc)
                .fetchAll(db)
                .map { $0.toCollection() }
        }
    }

    func saveCollection(_ collection: Collection) async throws {
        var record = CollectionRecord(from: collection)
        record.modifiedAt = Date()
        record.deviceId = DeviceID.current
        record.isDeleted = false
        try await dbQueue.write { db in
            try record.insert(db)
        }
    }

    func deleteCollection(_ id: UUID) async throws {
        let now = Date()
        try await dbQueue.write { db in
            // Unassign items first (this is a sync-relevant mutation)
            try db.execute(
                sql: "UPDATE clipboardItems SET collectionId = NULL, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE isDeleted = 0 AND collectionId = ?",
                arguments: [now, DeviceID.current, id.uuidString]
            )

            // Soft-delete the collection
            try db.execute(
                sql: "UPDATE collections SET isDeleted = 1, modifiedAt = ?, deviceId = ? WHERE id = ?",
                arguments: [now, DeviceID.current, id.uuidString]
            )
        }
    }

    func fetchItems(inCollection collectionId: UUID) async throws -> [ClipboardItem] {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("collectionId") == collectionId.uuidString)
                .filter(Column("isDeleted") == false)
                .order(Column("createdAt").desc)
                .fetchAll(db)
                .map { $0.toClipboardItem() }
        }
    }

    func assignItemToCollection(itemId: UUID, collectionId: UUID?) async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboardItems SET collectionId = ?, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE isDeleted = 0 AND id = ?",
                arguments: [collectionId?.uuidString, now, DeviceID.current, itemId.uuidString]
            )
        }
    }
}
