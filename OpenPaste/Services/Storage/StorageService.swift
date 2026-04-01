import Foundation
import GRDB

final class StorageService: StorageServiceProtocol, @unchecked Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func save(_ item: ClipboardItem) async throws {
        let record = ClipboardItemRecord(from: item)
        try await dbQueue.write { db in
            try record.insert(db)
        }
    }

    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem] {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .order(Column("pinned").desc, Column("createdAt").desc)
                .limit(limit, offset: offset)
                .fetchAll(db)
                .map { $0.toClipboardItem() }
        }
    }

    func delete(_ id: UUID) async throws {
        try await dbQueue.write { db in
            try ClipboardItemRecord
                .filter(Column("id") == id.uuidString)
                .deleteAll(db)
        }
    }

    func fetchByHash(_ hash: String) async throws -> ClipboardItem? {
        try await dbQueue.read { db in
            try ClipboardItemRecord
                .filter(Column("contentHash") == hash)
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
        try await dbQueue.write { db in
            try ClipboardItemRecord
                .filter(Column("expiresAt") != nil && Column("expiresAt") < Date())
                .deleteAll(db)
        }
    }

    func itemCount() async throws -> Int {
        try await dbQueue.read { db in
            try ClipboardItemRecord.fetchCount(db)
        }
    }

    func update(_ item: ClipboardItem) async throws {
        let record = ClipboardItemRecord(from: item)
        try await dbQueue.write { db in
            try record.update(db)
        }
    }
}
