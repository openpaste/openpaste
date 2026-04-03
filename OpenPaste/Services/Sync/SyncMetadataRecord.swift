import Foundation
@preconcurrency import GRDB

enum SyncOutboxOperation: String, Sendable {
    case upsert
    case delete
}

enum SyncOutboxStatus: String, Sendable {
    case pending
    case inFlight
    case synced
    case error
}

struct SyncMetadataRecord: Sendable, Hashable {
    var recordName: String
    var tableName: String
    var localId: String
    var operation: String
    var syncStatus: String
    var lastError: String?
    var retryCount: Int
    var updatedAt: Date
}

extension SyncMetadataRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "sync_metadata" }

    nonisolated init(row: Row) {
        recordName = row["recordName"]
        tableName = row["tableName"]
        localId = row["localId"]
        operation = row["operation"]
        syncStatus = row["syncStatus"]
        lastError = row["lastError"]
        retryCount = row["retryCount"]
        updatedAt = row["updatedAt"]
    }
}

extension SyncMetadataRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["recordName"] = recordName
        container["tableName"] = tableName
        container["localId"] = localId
        container["operation"] = operation
        container["syncStatus"] = syncStatus
        container["lastError"] = lastError
        container["retryCount"] = retryCount
        container["updatedAt"] = updatedAt
    }
}

extension SyncMetadataRecord {
    static func make(
        recordName: String,
        tableName: String,
        localId: String,
        operation: SyncOutboxOperation,
        status: SyncOutboxStatus = .pending,
        updatedAt: Date = Date()
    ) -> SyncMetadataRecord {
        SyncMetadataRecord(
            recordName: recordName,
            tableName: tableName,
            localId: localId,
            operation: operation.rawValue,
            syncStatus: status.rawValue,
            lastError: nil,
            retryCount: 0,
            updatedAt: updatedAt
        )
    }
}
