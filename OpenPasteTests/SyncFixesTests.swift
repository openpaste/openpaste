import Foundation
import GRDB
import Testing

@testable import OpenPaste

// MARK: - Stubs for SyncService instantiation

private struct StubPremiumService: PremiumServiceProtocol {
    var isPremium: Bool = true
}

private struct StubEncryptionService: SyncEncryptionServiceProtocol {
    func ensureKeyExists(version: Int) throws {}
    func encrypt(_ data: Data, keyVersion: Int) throws -> Data { data }
    func decrypt(_ combined: Data, keyVersion: Int) throws -> Data { combined }
}

// MARK: - Test helpers

private func makeSyncServiceWithDbQueue() throws -> (SyncService, DatabaseQueue) {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("OpenPasteTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let dbManager = try DatabaseManager(
        databaseDirectoryOverride: tempDir,
        passphraseProvider: { "test-passphrase" }
    )
    let service = SyncService(
        databaseManager: dbManager,
        eventBus: EventBus(),
        premiumService: StubPremiumService(),
        encryption: StubEncryptionService()
    )
    return (service, dbManager.dbQueue)
}

private func insertSyncMetadata(
    _ db: Database,
    recordName: String,
    tableName: String,
    localId: String,
    syncStatus: String = "synced"
) throws {
    try db.execute(
        sql: """
            INSERT INTO sync_metadata (recordName, tableName, localId, operation, syncStatus, retryCount, updatedAt)
            VALUES (?, ?, ?, 'upsert', ?, 0, ?)
            """,
        arguments: [recordName, tableName, localId, syncStatus, Date()]
    )
}

// MARK: - Test Suite for iCloud Sync Bug Fixes

@Suite("Sync Fixes")
struct SyncFixesTests {

    // MARK: - Fix #1: Collection sync_metadata orphan leak
    // Calls real SyncService.cleanupTombstones()

    @Suite("Tombstone Cleanup via SyncService")
    struct TombstoneCleanupTests {

        @Test("cleanupTombstones removes collection sync_metadata before physical delete")
        func collectionSyncMetadataCleaned() async throws {
            guard #available(macOS 14.0, *) else { return }
            let (syncService, dbQueue) = try makeSyncServiceWithDbQueue()
            let cutoff = Calendar.current.date(byAdding: .day, value: -31, to: Date())!

            // Insert data (DatabaseManager's own tracker will set status='pending')
            try await dbQueue.write { db in
                let col = CollectionRecord(
                    id: "col-1", name: "Old", color: "#FF0000",
                    createdAt: cutoff.addingTimeInterval(-100),
                    modifiedAt: cutoff, deviceId: "device-A",
                    isDeleted: true, ckSystemFields: nil
                )
                try col.insert(db)
            }
            // Simulate completed sync: mark all metadata as 'synced'
            try await dbQueue.write { db in
                try db.execute(sql: "UPDATE sync_metadata SET syncStatus = 'synced'")
            }

            await syncService.cleanupTombstones()

            try await dbQueue.read { db in
                let collCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collections") ?? -1
                let metaCount =
                    try Int.fetchOne(
                        db,
                        sql:
                            "SELECT COUNT(*) FROM sync_metadata WHERE recordName = 'collection_col-1'"
                    ) ?? -1
                #expect(collCount == 0, "Collection tombstone should be physically deleted")
                #expect(metaCount == 0, "sync_metadata should be cleaned — no orphan")
            }
        }

        @Test("cleanupTombstones preserves recent deleted collections")
        func recentCollectionsSurvive() async throws {
            guard #available(macOS 14.0, *) else { return }
            let (syncService, dbQueue) = try makeSyncServiceWithDbQueue()

            try await dbQueue.write { db in
                let col = CollectionRecord(
                    id: "col-recent", name: "Recent", color: "#00FF00",
                    createdAt: Date().addingTimeInterval(-100),
                    modifiedAt: Date().addingTimeInterval(-86400),
                    deviceId: "device-A", isDeleted: true, ckSystemFields: nil
                )
                try col.insert(db)
            }
            try await dbQueue.write { db in
                try db.execute(sql: "UPDATE sync_metadata SET syncStatus = 'synced'")
            }

            await syncService.cleanupTombstones()

            try await dbQueue.read { db in
                let collCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collections") ?? -1
                let metaCount =
                    try Int.fetchOne(
                        db,
                        sql:
                            "SELECT COUNT(*) FROM sync_metadata WHERE recordName = 'collection_col-recent'"
                    ) ?? -1
                #expect(collCount == 1, "Recent tombstone should survive")
                #expect(metaCount == 1, "sync_metadata should survive")
            }
        }

        @Test("cleanupTombstones preserves pending (unsynced) metadata")
        func pendingMetadataSurvives() async throws {
            guard #available(macOS 14.0, *) else { return }
            let (syncService, dbQueue) = try makeSyncServiceWithDbQueue()
            let cutoff = Calendar.current.date(byAdding: .day, value: -31, to: Date())!

            // Insert data — DatabaseManager's tracker creates 'pending' entry automatically
            try await dbQueue.write { db in
                let col = CollectionRecord(
                    id: "col-pending", name: "Pending", color: "#0000FF",
                    createdAt: cutoff.addingTimeInterval(-100),
                    modifiedAt: cutoff, deviceId: "device-A",
                    isDeleted: true, ckSystemFields: nil
                )
                try col.insert(db)
            }
            // Leave sync_metadata as 'pending' — don't mark as synced

            await syncService.cleanupTombstones()

            try await dbQueue.read { db in
                let collCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collections") ?? -1
                #expect(collCount == 0, "Old tombstone row should be physically deleted")

                let metaCount =
                    try Int.fetchOne(
                        db,
                        sql:
                            "SELECT COUNT(*) FROM sync_metadata WHERE recordName = 'collection_col-pending'"
                    ) ?? -1
                #expect(metaCount == 1, "Pending metadata should NOT be cleaned")
            }
        }

        @Test("cleanupTombstones covers all three entity types consistently")
        func allEntityTypesCleaned() async throws {
            guard #available(macOS 14.0, *) else { return }
            let (syncService, dbQueue) = try makeSyncServiceWithDbQueue()
            let cutoff = Calendar.current.date(byAdding: .day, value: -31, to: Date())!

            try await dbQueue.write { db in
                let item = ClipboardItemRecord(
                    id: "item-1", type: ContentType.text.rawValue,
                    content: Data("old".utf8), plainTextContent: "old",
                    ocrText: nil, sourceAppBundleId: "", sourceAppName: "Unknown",
                    sourceAppIconPath: nil, sourceURL: nil,
                    createdAt: cutoff.addingTimeInterval(-100), modifiedAt: cutoff,
                    deviceId: "device", isDeleted: true, syncVersion: 1, ckSystemFields: nil,
                    accessedAt: cutoff, accessCount: 0, tags: "[]",
                    pinned: false, starred: false, collectionId: nil,
                    contentHash: "hash", isSensitive: false, expiresAt: nil, metadata: "{}"
                )
                try item.insert(db)

                let col = CollectionRecord(
                    id: "col-1", name: "Old", color: "#000",
                    createdAt: cutoff.addingTimeInterval(-100),
                    modifiedAt: cutoff, deviceId: "device",
                    isDeleted: true, ckSystemFields: nil
                )
                try col.insert(db)

                let sl = SmartListRecord(
                    id: "sl-1", name: "Old", icon: "list.bullet", color: "#000",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: cutoff.addingTimeInterval(-100),
                    modifiedAt: cutoff, deviceId: "device",
                    isDeleted: true, ckSystemFields: nil
                )
                try sl.insert(db)
            }
            // Simulate completed sync
            try await dbQueue.write { db in
                try db.execute(sql: "UPDATE sync_metadata SET syncStatus = 'synced'")
            }

            await syncService.cleanupTombstones()

            try await dbQueue.read { db in
                let itemCount =
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clipboardItems") ?? -1
                let colCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM collections") ?? -1
                let slCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM smartLists") ?? -1
                let metaCount =
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_metadata") ?? -1
                #expect(itemCount == 0)
                #expect(colCount == 0)
                #expect(slCount == 0)
                #expect(metaCount == 0, "All sync_metadata should be cleaned — no orphans")
            }
        }
    }

    // MARK: - Fix #2: Pinned/Starred LWW
    // Calls real ConflictResolver.resolve()

    @Suite("Conflict Resolver LWW for Pinned/Starred")
    struct PinnedStarredLWWTests {

        private func makeItem(
            id: String = UUID().uuidString,
            modifiedAt: Date,
            pinned: Bool = false,
            starred: Bool = false
        ) -> ClipboardItemRecord {
            ClipboardItemRecord(
                id: id, type: ContentType.text.rawValue,
                content: Data("test".utf8), plainTextContent: "test",
                ocrText: nil, sourceAppBundleId: "", sourceAppName: "Unknown",
                sourceAppIconPath: nil, sourceURL: nil,
                createdAt: modifiedAt.addingTimeInterval(-10), modifiedAt: modifiedAt,
                deviceId: "device", isDeleted: false, syncVersion: 1, ckSystemFields: nil,
                accessedAt: modifiedAt, accessCount: 0, tags: "[]",
                pinned: pinned, starred: starred, collectionId: nil,
                contentHash: "hash", isSensitive: false, expiresAt: nil, metadata: "{}"
            )
        }

        @Test("unpin on newer device propagates via LWW")
        func unpinPropagates() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(id: id, modifiedAt: base, pinned: true)
            let remote = makeItem(id: id, modifiedAt: base.addingTimeInterval(5), pinned: false)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.pinned == false)
        }

        @Test("unstar on newer device propagates via LWW")
        func unstarPropagates() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(id: id, modifiedAt: base, starred: true)
            let remote = makeItem(id: id, modifiedAt: base.addingTimeInterval(5), starred: false)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.starred == false)
        }

        @Test("pin on newer device propagates")
        func pinPropagates() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(id: id, modifiedAt: base, pinned: false)
            let remote = makeItem(id: id, modifiedAt: base.addingTimeInterval(5), pinned: true)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.pinned == true)
        }

        @Test("local wins when newer")
        func localWins() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(
                id: id, modifiedAt: base.addingTimeInterval(5), pinned: true, starred: true)
            let remote = makeItem(id: id, modifiedAt: base, pinned: false, starred: false)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.pinned == true)
            #expect(merged.starred == true)
        }

        @Test("cross-field conflict resolves by LWW winner")
        func crossField() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(id: id, modifiedAt: base, pinned: true, starred: false)
            let remote = makeItem(
                id: id, modifiedAt: base.addingTimeInterval(1), pinned: false, starred: true)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.pinned == false)
            #expect(merged.starred == true)
        }

        @Test("equal timestamps prefer remote (>= semantics)")
        func equalTimestamps() {
            let base = Date()
            let id = UUID().uuidString
            let local = makeItem(id: id, modifiedAt: base, pinned: true, starred: false)
            let remote = makeItem(id: id, modifiedAt: base, pinned: false, starred: true)
            let merged = ConflictResolver.resolve(local: local, remote: remote)
            #expect(merged.pinned == false)
            #expect(merged.starred == true)
        }

        @Test("roundtrip pin/unpin across 3 sync cycles")
        func pinUnpinRoundtrip() {
            let base = Date()
            let id = UUID().uuidString

            let t0Local = makeItem(id: id, modifiedAt: base, pinned: true)

            var t1Remote = t0Local
            t1Remote.modifiedAt = base.addingTimeInterval(10)
            t1Remote.pinned = false
            let merge1 = ConflictResolver.resolve(local: t0Local, remote: t1Remote)
            #expect(merge1.pinned == false, "Step 1: unpin propagates")

            var t2Local = merge1
            t2Local.modifiedAt = base.addingTimeInterval(20)
            t2Local.pinned = true
            let merge2 = ConflictResolver.resolve(local: t2Local, remote: t1Remote)
            #expect(merge2.pinned == true, "Step 2: re-pin wins")

            var t3Remote = merge2
            t3Remote.modifiedAt = base.addingTimeInterval(30)
            t3Remote.pinned = false
            let merge3 = ConflictResolver.resolve(local: t2Local, remote: t3Remote)
            #expect(merge3.pinned == false, "Step 3: second unpin wins")
        }
    }

    // MARK: - Fix #3 & #4: SmartList save/delete sets deviceId
    // Calls real SmartListService.save() and .delete()

    @Suite("SmartList DeviceId via SmartListService")
    struct SmartListDeviceIdTests {

        @Test("save() sets deviceId to current device")
        func saveSetsDeviceId() async throws {
            let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
            let service = SmartListService(dbQueue: dbQueue)

            let smartList = SmartList(name: "Test List", rules: [])
            try await service.save(smartList)

            let record = try await dbQueue.read { db in
                try SmartListRecord.fetchOne(db, key: smartList.id.uuidString)
            }
            #expect(record != nil)
            #expect(record?.deviceId == DeviceID.current)
            #expect(record?.deviceId.isEmpty == false)
        }

        @Test("save() overwrites remote deviceId on local update")
        func updateOverwritesDeviceId() async throws {
            let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
            let service = SmartListService(dbQueue: dbQueue)

            var smartList = SmartList(name: "V1", rules: [])
            try await service.save(smartList)

            // Simulate record arrived from remote device
            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE smartLists SET deviceId = 'remote-device' WHERE id = ?",
                    arguments: [smartList.id.uuidString]
                )
            }

            smartList.name = "V2"
            try await service.save(smartList)

            let record = try await dbQueue.read { db in
                try SmartListRecord.fetchOne(db, key: smartList.id.uuidString)
            }
            #expect(record?.name == "V2")
            #expect(record?.deviceId == DeviceID.current)
        }

        @Test("delete() sets deviceId to current device")
        func deleteSetsDeviceId() async throws {
            let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
            let service = SmartListService(dbQueue: dbQueue)

            let smartList = SmartList(name: "To Delete", rules: [])
            try await service.save(smartList)

            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE smartLists SET deviceId = 'remote-device' WHERE id = ?",
                    arguments: [smartList.id.uuidString]
                )
            }

            try await service.delete(smartList.id)

            let record = try await dbQueue.read { db in
                try Row.fetchOne(
                    db,
                    sql: "SELECT deviceId, isDeleted FROM smartLists WHERE id = ?",
                    arguments: [smartList.id.uuidString]
                )
            }
            #expect(record != nil)
            let isDeleted: Bool = record!["isDeleted"]
            let deviceId: String = record!["deviceId"]
            #expect(isDeleted == true)
            #expect(deviceId == DeviceID.current)
        }

        @Test("full lifecycle: create → update → delete preserves deviceId")
        func fullLifecycle() async throws {
            let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
            let service = SmartListService(dbQueue: dbQueue)

            var smartList = SmartList(name: "My List", rules: [], position: 0)
            try await service.save(smartList)

            var record = try await dbQueue.read { db in
                try SmartListRecord.fetchOne(db, key: smartList.id.uuidString)!
            }
            #expect(record.deviceId == DeviceID.current)
            let firstModifiedAt = record.modifiedAt

            try await Task.sleep(for: .milliseconds(50))

            smartList.name = "Updated"
            smartList.position = 5
            try await service.save(smartList)

            record = try await dbQueue.read { db in
                try SmartListRecord.fetchOne(db, key: smartList.id.uuidString)!
            }
            #expect(record.name == "Updated")
            #expect(record.position == 5)
            #expect(record.deviceId == DeviceID.current)
            #expect(record.modifiedAt > firstModifiedAt)

            try await service.delete(smartList.id)

            let deletedRow = try await dbQueue.read { db in
                try Row.fetchOne(
                    db,
                    sql: "SELECT isDeleted, deviceId FROM smartLists WHERE id = ?",
                    arguments: [smartList.id.uuidString]
                )!
            }
            let isDeleted: Bool = deletedRow["isDeleted"]
            let deviceId: String = deletedRow["deviceId"]
            #expect(isDeleted == true)
            #expect(deviceId == DeviceID.current)
        }
    }

    // MARK: - Fix #5: SyncChangeTracker observes all SmartList columns
    // Uses real SyncChangeTracker registered as TransactionObserver on a live DB

    @Suite("SyncChangeTracker End-to-End")
    struct SyncChangeTrackerTests {

        private func makeTrackedDb() throws -> (DatabaseQueue, SyncChangeTracker) {
            let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
            let tracker = SyncChangeTracker(includeSensitiveProvider: { true })
            dbQueue.add(transactionObserver: tracker)
            return (dbQueue, tracker)
        }

        // -- Column observation unit tests --

        @Test("observes new SmartList columns: icon, color, matchMode, sortOrder, position")
        func observesNewColumns() {
            let tracker = SyncChangeTracker()
            for col in ["icon", "color", "matchMode", "sortOrder", "position"] {
                #expect(
                    tracker.observes(
                        eventsOfKind: .update(tableName: "smartLists", columnNames: [col])) == true,
                    "Should observe SmartList.\(col)"
                )
            }
        }

        @Test("observes original SmartList columns: name, rules, modifiedAt, isDeleted")
        func observesOriginalColumns() {
            let tracker = SyncChangeTracker()
            for col in ["name", "rules", "modifiedAt", "isDeleted"] {
                #expect(
                    tracker.observes(
                        eventsOfKind: .update(tableName: "smartLists", columnNames: [col])) == true
                )
            }
        }

        @Test("ignores irrelevant columns: ckSystemFields, isBuiltIn")
        func ignoresIrrelevant() {
            let tracker = SyncChangeTracker()
            for col in ["ckSystemFields", "isBuiltIn"] {
                #expect(
                    tracker.observes(
                        eventsOfKind: .update(tableName: "smartLists", columnNames: [col])) == false
                )
            }
        }

        @Test("observes inserts for synced tables only")
        func observesInserts() {
            let tracker = SyncChangeTracker()
            #expect(tracker.observes(eventsOfKind: .insert(tableName: "clipboardItems")) == true)
            #expect(tracker.observes(eventsOfKind: .insert(tableName: "collections")) == true)
            #expect(tracker.observes(eventsOfKind: .insert(tableName: "smartLists")) == true)
            #expect(tracker.observes(eventsOfKind: .insert(tableName: "sync_metadata")) == false)
        }

        // -- End-to-end DB observer tests --

        @Test("SmartList insert triggers outbox entry via real observer")
        func insertCreatesOutboxEntry() async throws {
            let (dbQueue, _tracker) = try makeTrackedDb()

            let slId = UUID().uuidString
            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId, name: "New", icon: "star", color: "#FF0000",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId)"]
                    ) ?? 0
                #expect(count == 1, "Insert should create outbox entry")
            }
            withExtendedLifetime(_tracker) {}
        }

        @Test("SmartList icon update triggers outbox via real observer")
        func iconUpdateCreatesOutbox() async throws {
            let (dbQueue, _tracker) = try makeTrackedDb()
            let slId = UUID().uuidString

            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId, name: "List", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }
            try await dbQueue.write { db in try db.execute(sql: "DELETE FROM sync_metadata") }

            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE smartLists SET icon = 'star.fill', modifiedAt = ? WHERE id = ?",
                    arguments: [Date(), slId]
                )
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId)"]
                    ) ?? 0
                #expect(count == 1, "Icon update should create outbox entry")
            }
            withExtendedLifetime(_tracker) {}
        }

        @Test("SmartList color update triggers outbox via real observer")
        func colorUpdateCreatesOutbox() async throws {
            let (dbQueue, _tracker) = try makeTrackedDb()
            let slId = UUID().uuidString

            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId, name: "List", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }
            try await dbQueue.write { db in try db.execute(sql: "DELETE FROM sync_metadata") }

            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE smartLists SET color = '#FF0000', modifiedAt = ? WHERE id = ?",
                    arguments: [Date(), slId]
                )
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId)"]
                    ) ?? 0
                #expect(count == 1, "Color update should create outbox entry")
            }
            withExtendedLifetime(_tracker) {}
        }

        @Test("SmartList position update triggers outbox via real observer")
        func positionUpdateCreatesOutbox() async throws {
            let (dbQueue, _tracker) = try makeTrackedDb()
            let slId = UUID().uuidString

            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId, name: "List", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }
            try await dbQueue.write { db in try db.execute(sql: "DELETE FROM sync_metadata") }

            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE smartLists SET position = 3, modifiedAt = ? WHERE id = ?",
                    arguments: [Date(), slId]
                )
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId)"]
                    ) ?? 0
                #expect(count == 1, "Position update should create outbox entry")
            }
            withExtendedLifetime(_tracker) {}
        }

        @Test("built-in SmartList changes are NOT enqueued")
        func builtInSkipped() async throws {
            let (dbQueue, _tracker) = try makeTrackedDb()
            let slId = UUID().uuidString

            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId, name: "Built-in", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: true, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId)"]
                    ) ?? 0
                #expect(count == 0, "Built-in SmartList should NOT create outbox entry")
            }
            withExtendedLifetime(_tracker) {}
        }

        @Test("suspended tracker does NOT enqueue, resumes normally")
        func suspendResume() async throws {
            let (dbQueue, tracker) = try makeTrackedDb()
            tracker.suspend()

            let slId1 = UUID().uuidString
            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId1, name: "During Suspend", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId1)"]
                    ) ?? 0
                #expect(count == 0, "Suspended tracker should NOT enqueue")
            }

            tracker.resume()

            let slId2 = UUID().uuidString
            try await dbQueue.write { db in
                let sl = SmartListRecord(
                    id: slId2, name: "After Resume", icon: "list.bullet", color: "#007AFF",
                    rules: "[]", matchMode: "all", sortOrder: "newestFirst",
                    isBuiltIn: false, position: 0,
                    createdAt: Date(), modifiedAt: Date(),
                    deviceId: DeviceID.current,
                    isDeleted: false, ckSystemFields: nil
                )
                try sl.insert(db)
            }

            try await dbQueue.read { db in
                let count =
                    try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM sync_metadata WHERE recordName = ?",
                        arguments: ["smartlist_\(slId2)"]
                    ) ?? 0
                #expect(count == 1, "After resume, tracker should enqueue normally")
            }
        }
    }
}
