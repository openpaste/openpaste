import Foundation
@preconcurrency import CloudKit
import GRDB

@available(macOS 14.0, *)
extension SyncService {
    func applyRemote(
        modifications: [CKDatabase.RecordZoneChange.Modification],
        deletions: [CKDatabase.RecordZoneChange.Deletion]
    ) async {
        await databaseManager.withSyncTrackingSuspended {
            do {
                for mod in modifications {
                    let record = mod.record
                    let system = try CloudKitSystemFields.encode(from: record)

                    if record.recordType == CloudKitMapper.RecordType.clipboardItem {
                        var remote = try CloudKitMapper.decodeClipboardItem(from: record, encryption: encryption)
                        remote.ckSystemFields = system

                        if let existing = try await fetchClipboardItem(id: remote.id) {
                            remote.accessedAt = existing.accessedAt
                            remote.accessCount = existing.accessCount
                            let merged = ConflictResolver.resolve(local: existing, remote: remote)
                            try await upsertClipboardItem(merged)
                        } else {
                            try await upsertClipboardItem(remote)
                        }
                    } else if record.recordType == CloudKitMapper.RecordType.collection {
                        var remote = try CloudKitMapper.decodeCollection(from: record, encryption: encryption)
                        remote.ckSystemFields = system

                        if let existing = try await fetchCollection(id: remote.id) {
                            let merged = ConflictResolver.resolve(local: existing, remote: remote)
                            try await upsertCollection(merged)
                        } else {
                            try await upsertCollection(remote)
                        }
                    }
                }

                for deletion in deletions {
                    let recordName = deletion.recordID.recordName
                    if recordName.hasPrefix("item_") {
                        let id = String(recordName.dropFirst("item_".count))
                        try await softDeleteClipboardItem(id: id)
                    } else if recordName.hasPrefix("collection_") {
                        let id = String(recordName.dropFirst("collection_".count))
                        try await softDeleteCollection(id: id)
                    }
                }

                touchLastSyncDate()
            } catch {
                setStatus(.error(error.localizedDescription))
            }
        }
    }

    func fetchClipboardItem(id: String) async throws -> ClipboardItemRecord? {
        try await dbQueue.read { db in
            try ClipboardItemRecord.fetchOne(db, key: id)
        }
    }

    func fetchCollection(id: String) async throws -> CollectionRecord? {
        try await dbQueue.read { db in
            try CollectionRecord.fetchOne(db, key: id)
        }
    }

    func upsertClipboardItem(_ record: ClipboardItemRecord) async throws {
        try await dbQueue.write { db in
            do { try record.insert(db) } catch { try record.update(db) }
        }
    }

    func upsertCollection(_ record: CollectionRecord) async throws {
        try await dbQueue.write { db in
            do { try record.insert(db) } catch { try record.update(db) }
        }
    }

    func softDeleteClipboardItem(id: String) async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboardItems SET isDeleted = 1, modifiedAt = ?, deviceId = ?, syncVersion = syncVersion + 1 WHERE id = ?",
                arguments: [now, DeviceID.current, id]
            )
        }
    }

    func softDeleteCollection(id: String) async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE collections SET isDeleted = 1, modifiedAt = ?, deviceId = ? WHERE id = ?",
                arguments: [now, DeviceID.current, id]
            )
        }
    }
}
