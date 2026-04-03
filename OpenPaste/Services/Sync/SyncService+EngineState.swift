import Foundation
@preconcurrency import CloudKit
import GRDB

@available(macOS 14.0, *)
extension SyncService {
    func ensureZoneExists(container: CKContainer) async throws {
        let zone = CKRecordZone(zoneID: CloudKitMapper.zoneID)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
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
}
