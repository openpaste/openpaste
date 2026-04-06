import Foundation

struct SmartList: Identifiable, Sendable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var rules: [SmartListRule]
    var matchMode: MatchMode
    var sortOrder: SmartListSortOrder
    var isBuiltIn: Bool
    var position: Int
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "list.bullet",
        color: String = "#007AFF",
        rules: [SmartListRule] = [],
        matchMode: MatchMode = .all,
        sortOrder: SmartListSortOrder = .newestFirst,
        isBuiltIn: Bool = false,
        position: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.rules = rules
        self.matchMode = matchMode
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.position = position
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct SmartListRule: Identifiable, Sendable, Codable, Hashable {
    var id: UUID
    var field: RuleField
    var comparison: RuleComparison
    var value: String

    init(
        id: UUID = UUID(),
        field: RuleField,
        comparison: RuleComparison,
        value: String
    ) {
        self.id = id
        self.field = field
        self.comparison = comparison
        self.value = value
    }
}

// MARK: - Enums

enum MatchMode: String, Codable, Sendable, CaseIterable {
    case all
    case any
}

enum SmartListSortOrder: String, Codable, Sendable, CaseIterable {
    case newestFirst
    case oldestFirst
    case alphabetical
    case mostUsed
}

enum RuleField: String, Codable, Sendable, CaseIterable {
    case contentType
    case sourceApp
    case createdDate
    case textContains
    case textRegex
    case contentLength
    case tag
    case pinned
    case starred
    case isSensitive
    case ocrText

    var displayName: String {
        switch self {
        case .contentType: "Content Type"
        case .sourceApp: "Source App"
        case .createdDate: "Created Date"
        case .textContains: "Text Contains"
        case .textRegex: "Text Matches Regex"
        case .contentLength: "Content Length"
        case .tag: "Tag"
        case .pinned: "Pinned"
        case .starred: "Starred"
        case .isSensitive: "Sensitive"
        case .ocrText: "OCR Text"
        }
    }

    var availableComparisons: [RuleComparison] {
        switch self {
        case .contentType: [.equals, .notEquals]
        case .sourceApp: [.equals, .contains, .notContains]
        case .createdDate: [.greaterThan, .lessThan, .between]
        case .textContains: [.contains, .notContains]
        case .textRegex: [.matches]
        case .contentLength: [.greaterThan, .lessThan]
        case .tag: [.contains, .notContains]
        case .pinned, .starred, .isSensitive: [.isTrue, .isFalse]
        case .ocrText: [.contains, .notContains]
        }
    }
}

enum RuleComparison: String, Codable, Sendable, CaseIterable {
    case equals
    case notEquals
    case contains
    case notContains
    case greaterThan
    case lessThan
    case between
    case matches
    case isTrue
    case isFalse

    var displayName: String {
        switch self {
        case .equals: "equals"
        case .notEquals: "does not equal"
        case .contains: "contains"
        case .notContains: "does not contain"
        case .greaterThan: "is greater than"
        case .lessThan: "is less than"
        case .between: "is between"
        case .matches: "matches regex"
        case .isTrue: "is true"
        case .isFalse: "is false"
        }
    }
}
