import Foundation
@preconcurrency import CloudKit
import GRDB
import os.log

private let syncLog = Logger(subsystem: "dev.tuanle.OpenPaste", category: "SyncEngine")

@available(macOS 14.0, *)
extension SyncService {
    func ensureZoneExists(container: CKContainer) async throws {
        let zoneName = CloudKitMapper.zoneID.zoneName
        syncLog.info("Ensuring zone exists: \(zoneName)")
        let zone = CKRecordZone(zoneID: CloudKitMapper.zoneID)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
        syncLog.info("Zone verified/created successfully")
    }

    func loadEngineStateSerialization() async throws -> CKSyncEngine.State.Serialization? {
        try await dbQueue.write { db in
            if let existing = try SyncEngineStateRecord.fetchOne(db, key: 1) {
                return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: existing.stateData)
            }

            let record = SyncEngineStateRecord(
                id: 1,
                stateData: Data(),
                lastSyncDate: nil,
                deviceId: DeviceID.current,
                keyVersion: 1
            )
            try record.insert(db)
            return nil
        }
    }

    func currentKeyVersion() async throws -> Int {
        try await dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT keyVersion FROM sync_engine_state WHERE id = 1")
            return (row?["keyVersion"] as? Int) ?? 1
        }
    }

    func persist(state: CKSyncEngine.State.Serialization) async {
        do {
            let data = try JSONEncoder().encode(state)
            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE sync_engine_state SET stateData = ? WHERE id = 1",
                    arguments: [data]
                )
            }
        } catch {
            // ignore
        }
    }

    // MARK: - B2: Zone-Not-Found Recovery

    func recoverFromZoneNotFound() async {
        do {
            let container = CKContainer(identifier: CloudKitMapper.containerIdentifier)
            try await ensureZoneExists(container: container)
            syncLog.info("Zone recreated — re-enqueuing all local records")

            // Re-enqueue all synced records as pending so they're re-sent
            try await dbQueue.write { db in
                try db.execute(
                    sql: """
                    UPDATE sync_metadata
                    SET syncStatus = 'pending', lastError = NULL, retryCount = 0, updatedAt = ?
                    WHERE syncStatus IN ('synced', 'error')
                    """,
                    arguments: [Date()]
                )
            }
            if let engine = currentEngineSnapshot() {
                await schedulePendingOutboxWithEngine(engine)
            }
        } catch {
            syncLog.error("Zone recovery failed: \(error.localizedDescription)")
            setStatus(.error("Zone recovery failed"))
        }
    }
}
