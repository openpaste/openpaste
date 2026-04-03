import Foundation
@preconcurrency import GRDB

struct CollectionRecord: Sendable, Identifiable {
    var id: String
    var name: String
    var color: String
    var createdAt: Date
    var modifiedAt: Date
    var deviceId: String
    var isDeleted: Bool
    var ckSystemFields: Data?
}

extension CollectionRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "collections" }

    nonisolated init(row: Row) {
        id = row["id"]
        name = row["name"]
        color = row["color"]
        createdAt = row["createdAt"]
        let decodedModifiedAt: Date? = row["modifiedAt"]
        modifiedAt = decodedModifiedAt ?? createdAt
        deviceId = row["deviceId"]
        isDeleted = row["isDeleted"]
        ckSystemFields = row["ckSystemFields"]
    }
}

extension CollectionRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["color"] = color
        container["createdAt"] = createdAt
        container["modifiedAt"] = modifiedAt
        container["deviceId"] = deviceId
        container["isDeleted"] = isDeleted
        container["ckSystemFields"] = ckSystemFields
    }
}

extension CollectionRecord {
    init(from collection: Collection) {
        id = collection.id.uuidString
        name = collection.name
        color = collection.color
        createdAt = collection.createdAt
        modifiedAt = collection.modifiedAt
        deviceId = collection.deviceId
        isDeleted = collection.isDeleted
        ckSystemFields = nil
    }

    func toCollection() -> Collection {
        Collection(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            color: color,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deviceId: deviceId,
            isDeleted: isDeleted
        )
    }
}
