import Foundation
@preconcurrency import GRDB

struct CollectionRecord: Sendable, Identifiable {
    var id: String
    var name: String
    var createdAt: Date
}

extension CollectionRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "collections" }

    nonisolated init(row: Row) {
        id = row["id"]
        name = row["name"]
        createdAt = row["createdAt"]
    }
}

extension CollectionRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["createdAt"] = createdAt
    }
}

extension CollectionRecord {
    init(from collection: Collection) {
        id = collection.id.uuidString
        name = collection.name
        createdAt = collection.createdAt
    }

    func toCollection() -> Collection {
        Collection(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            createdAt: createdAt
        )
    }
}
