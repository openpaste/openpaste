import Foundation
import GRDB

protocol SmartListServiceProtocol: Sendable {
    func fetchAll() async throws -> [SmartList]
    func save(_ smartList: SmartList) async throws
    func delete(_ id: UUID) async throws
    func evaluate(_ smartList: SmartList, limit: Int) async throws -> [ClipboardItem]
    func evaluateSummaries(_ smartList: SmartList, limit: Int) async throws
        -> [ClipboardItemSummary]
    func countMatches(_ smartList: SmartList) async throws -> Int
    func seedPresetsIfNeeded() async throws
    func exportAsJSON(_ smartList: SmartList) throws -> Data
    func importFromJSON(_ data: Data) throws -> SmartList
}

final class SmartListService: SmartListServiceProtocol, Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func fetchAll() async throws -> [SmartList] {
        try await dbQueue.read { db in
            try SmartListRecord
                .filter(Column("isDeleted") == false)
                .order(Column("position").asc, Column("createdAt").asc)
                .fetchAll(db)
        }.map { $0.toSmartList() }
    }

    func save(_ smartList: SmartList) async throws {
        var record = SmartListRecord(from: smartList)
        record.modifiedAt = Date()
        record.deviceId = DeviceID.current
        try await dbQueue.write { db in
            try record.save(db)
        }
    }

    func delete(_ id: UUID) async throws {
        let now = Date()
        try await dbQueue.write { db in
            try db.execute(
                sql:
                    "UPDATE smartLists SET isDeleted = 1, modifiedAt = ?, deviceId = ? WHERE id = ?",
                arguments: [now, DeviceID.current, id.uuidString]
            )
        }
    }

    func evaluate(_ smartList: SmartList, limit: Int = 500) async throws -> [ClipboardItem] {
        let containsRegex = smartList.rules.contains { $0.field == .textRegex }
        let fetchLimit = containsRegex ? 500 : limit

        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: smartList.rules,
            matchMode: smartList.matchMode,
            sortOrder: smartList.sortOrder,
            limit: fetchLimit
        )

        let records = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }

        var items = records.map { $0.toClipboardItem() }

        // Post-fetch regex filter
        if containsRegex {
            let regexRules = smartList.rules.filter { $0.field == .textRegex }
            let useAll = smartList.matchMode == .all
            items = items.filter { item in
                guard let text = item.plainTextContent else { return false }
                let matcher: (SmartListRule) -> Bool = { rule in
                    guard let regex = try? NSRegularExpression(pattern: rule.value) else {
                        return false
                    }
                    let range = NSRange(text.startIndex..., in: text)
                    return regex.firstMatch(in: text, range: range) != nil
                }
                return useAll ? regexRules.allSatisfy(matcher) : regexRules.contains(where: matcher)
            }
        }

        return Array(items.prefix(limit))
    }

    func evaluateSummaries(_ smartList: SmartList, limit: Int = 500) async throws
        -> [ClipboardItemSummary]
    {
        let containsRegex = smartList.rules.contains { $0.field == .textRegex }
        let fetchLimit = containsRegex ? 500 : limit

        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: smartList.rules,
            matchMode: smartList.matchMode,
            sortOrder: smartList.sortOrder,
            limit: fetchLimit
        )

        let records = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }

        var summaries = records.map { $0.toSummary() }

        if containsRegex {
            let regexRules = smartList.rules.filter { $0.field == .textRegex }
            let useAll = smartList.matchMode == .all
            summaries = summaries.filter { summary in
                guard let text = summary.plainTextContent else { return false }
                let matcher: (SmartListRule) -> Bool = { rule in
                    guard let regex = try? NSRegularExpression(pattern: rule.value) else {
                        return false
                    }
                    let range = NSRange(text.startIndex..., in: text)
                    return regex.firstMatch(in: text, range: range) != nil
                }
                return useAll ? regexRules.allSatisfy(matcher) : regexRules.contains(where: matcher)
            }
        }

        return Array(summaries.prefix(limit))
    }

    func countMatches(_ smartList: SmartList) async throws -> Int {
        let hasRegex = smartList.rules.contains { $0.field == .textRegex }
        if hasRegex {
            return try await evaluate(smartList, limit: 500).count
        }

        let (sql, args) = SmartListQueryBuilder.buildCountQuery(
            rules: smartList.rules,
            matchMode: smartList.matchMode
        )

        return try await dbQueue.read { db in
            try Int.fetchOne(db, sql: sql, arguments: args) ?? 0
        }
    }

    // MARK: - Presets

    func seedPresetsIfNeeded() async throws {
        let existing = try await dbQueue.read { db in
            try SmartListRecord
                .filter(Column("isBuiltIn") == true)
                .fetchCount(db)
        }
        guard existing == 0 else { return }

        let presets = Self.builtInPresets
        try await dbQueue.write { db in
            for preset in presets {
                let record = SmartListRecord(from: preset)
                try record.insert(db)
            }
        }
    }

    static let builtInPresets: [SmartList] = [
        SmartList(
            name: "Today",
            icon: "calendar",
            color: "#007AFF",
            rules: [SmartListRule(field: .createdDate, comparison: .greaterThan, value: "today")],
            isBuiltIn: true,
            position: 0
        ),
        SmartList(
            name: "Images",
            icon: "photo",
            color: "#FF9500",
            rules: [
                SmartListRule(
                    field: .contentType, comparison: .equals, value: ContentType.image.rawValue)
            ],
            isBuiltIn: true,
            position: 1
        ),
        SmartList(
            name: "Links",
            icon: "link",
            color: "#34C759",
            rules: [
                SmartListRule(
                    field: .contentType, comparison: .equals, value: ContentType.link.rawValue)
            ],
            isBuiltIn: true,
            position: 2
        ),
        SmartList(
            name: "Code Snippets",
            icon: "chevron.left.forwardslash.chevron.right",
            color: "#AF52DE",
            rules: [
                SmartListRule(
                    field: .contentType, comparison: .equals, value: ContentType.code.rawValue)
            ],
            isBuiltIn: true,
            position: 3
        ),
        SmartList(
            name: "Sensitive",
            icon: "lock.shield",
            color: "#FF3B30",
            rules: [SmartListRule(field: .isSensitive, comparison: .isTrue, value: "")],
            isBuiltIn: true,
            position: 4
        ),
    ]

    // MARK: - Import/Export

    func exportAsJSON(_ smartList: SmartList) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(smartList)
    }

    func importFromJSON(_ data: Data) throws -> SmartList {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var imported = try decoder.decode(SmartList.self, from: data)
        // Give it a new ID to avoid conflicts
        imported.id = UUID()
        imported.isBuiltIn = false
        imported.createdAt = Date()
        imported.modifiedAt = Date()
        return imported
    }
}
