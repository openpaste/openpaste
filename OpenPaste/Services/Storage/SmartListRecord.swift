import Foundation
@preconcurrency import GRDB

struct SmartListRecord: Sendable, Identifiable {
    var id: String
    var name: String
    var icon: String
    var color: String
    var rules: String // JSON-encoded [SmartListRule]
    var matchMode: String
    var sortOrder: String
    var isBuiltIn: Bool
    var position: Int
    var createdAt: Date
    var modifiedAt: Date
    var deviceId: String
    var isDeleted: Bool
    var ckSystemFields: Data?
}

extension SmartListRecord: FetchableRecord {
    nonisolated static var databaseTableName: String { "smartLists" }

    nonisolated init(row: Row) {
        id = row["id"]
        name = row["name"]
        icon = row["icon"]
        color = row["color"]
        rules = row["rules"]
        matchMode = row["matchMode"]
        sortOrder = row["sortOrder"]
        isBuiltIn = row["isBuiltIn"]
        position = row["position"]
        createdAt = row["createdAt"]
        modifiedAt = row["modifiedAt"] ?? row["createdAt"]
        deviceId = row["deviceId"]
        isDeleted = row["isDeleted"]
        ckSystemFields = row["ckSystemFields"]
    }
}

extension SmartListRecord: PersistableRecord {
    nonisolated func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["icon"] = icon
        container["color"] = color
        container["rules"] = rules
        container["matchMode"] = matchMode
        container["sortOrder"] = sortOrder
        container["isBuiltIn"] = isBuiltIn
        container["position"] = position
        container["createdAt"] = createdAt
        container["modifiedAt"] = modifiedAt
        container["deviceId"] = deviceId
        container["isDeleted"] = isDeleted
        container["ckSystemFields"] = ckSystemFields
    }
}

extension SmartListRecord {
    init(from smartList: SmartList) {
        id = smartList.id.uuidString
        name = smartList.name
        icon = smartList.icon
        color = smartList.color
        rules = Self.encodeRules(smartList.rules)
        matchMode = smartList.matchMode.rawValue
        sortOrder = smartList.sortOrder.rawValue
        isBuiltIn = smartList.isBuiltIn
        position = smartList.position
        createdAt = smartList.createdAt
        modifiedAt = smartList.modifiedAt
        deviceId = DeviceID.current
        isDeleted = false
        ckSystemFields = nil
    }

    func toSmartList() -> SmartList {
        SmartList(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            icon: icon,
            color: color,
            rules: Self.decodeRules(rules),
            matchMode: MatchMode(rawValue: matchMode) ?? .all,
            sortOrder: SmartListSortOrder(rawValue: sortOrder) ?? .newestFirst,
            isBuiltIn: isBuiltIn,
            position: position,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    private static func encodeRules(_ rules: [SmartListRule]) -> String {
        let data = (try? JSONEncoder().encode(rules)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decodeRules(_ json: String) -> [SmartListRule] {
        (try? JSONDecoder().decode([SmartListRule].self, from: Data(json.utf8))) ?? []
    }
}
