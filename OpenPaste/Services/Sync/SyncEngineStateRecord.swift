import Foundation
@preconcurrency import GRDB

struct SyncEngineStateRecord: Sendable, Hashable {
    var id: Int
    var stateData: Data
    var lastSyncDate: Date?
    var deviceId: String
    var keyVersion: Int
}

extension SyncEngineStateRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "sync_engine_state" }

    nonisolated init(row: Row) {
        id = row["id"]
        stateData = row["stateData"]
        lastSyncDate = row["lastSyncDate"]
        deviceId = row["deviceId"]
        keyVersion = row["keyVersion"]
    }
}

extension SyncEngineStateRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["stateData"] = stateData
        container["lastSyncDate"] = lastSyncDate
        container["deviceId"] = deviceId
        container["keyVersion"] = keyVersion
    }
}
