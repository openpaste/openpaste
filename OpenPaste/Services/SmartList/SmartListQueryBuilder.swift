import Foundation
import GRDB

enum SmartListQueryBuilder {
    /// Builds a SQL WHERE clause and arguments from Smart List rules.
    static func buildQuery(
        rules: [SmartListRule],
        matchMode: MatchMode,
        sortOrder: SmartListSortOrder,
        limit: Int = 500
    ) -> (sql: String, arguments: StatementArguments, hasRegex: Bool) {
        var conditions: [String] = []
        var args: [DatabaseValueConvertible?] = []
        var hasRegex = false

        // Always exclude deleted items
        conditions.append("isDeleted = 0")

        for rule in rules {
            if let (sql, ruleArgs) = buildCondition(rule: rule) {
                conditions.append(sql)
                args.append(contentsOf: ruleArgs)
            } else if rule.field == .textRegex {
                hasRegex = true
            }
        }

        let joiner = matchMode == .all ? " AND " : " OR "

        // If all conditions after the base isDeleted check come from rules,
        // wrap them properly with the joiner
        let baseCondition = "isDeleted = 0"
        let ruleConditions = Array(conditions.dropFirst())
        let whereClause: String
        if ruleConditions.isEmpty {
            whereClause = baseCondition
        } else if matchMode == .any {
            whereClause = "\(baseCondition) AND (\(ruleConditions.joined(separator: joiner)))"
        } else {
            whereClause = ([baseCondition] + ruleConditions).joined(separator: " AND ")
        }

        let orderBy = buildOrderBy(sortOrder)

        let sql = """
        SELECT * FROM clipboardItems
        WHERE \(whereClause)
        ORDER BY \(orderBy)
        LIMIT ?
        """
        args.append(limit)

        return (sql, StatementArguments(args), hasRegex)
    }

    /// Builds a COUNT query that reuses buildCondition() logic (no limit/order).
    static func buildCountQuery(
        rules: [SmartListRule],
        matchMode: MatchMode
    ) -> (sql: String, arguments: StatementArguments) {
        var conditions: [String] = []
        var args: [DatabaseValueConvertible?] = []

        conditions.append("isDeleted = 0")

        for rule in rules {
            if let (sql, ruleArgs) = buildCondition(rule: rule) {
                conditions.append(sql)
                args.append(contentsOf: ruleArgs)
            }
        }

        let baseCondition = "isDeleted = 0"
        let ruleConditions = Array(conditions.dropFirst())
        let whereClause: String
        if ruleConditions.isEmpty {
            whereClause = baseCondition
        } else if matchMode == .any {
            let joiner = " OR "
            whereClause = "\(baseCondition) AND (\(ruleConditions.joined(separator: joiner)))"
        } else {
            whereClause = ([baseCondition] + ruleConditions).joined(separator: " AND ")
        }

        let sql = "SELECT COUNT(*) FROM clipboardItems WHERE \(whereClause)"
        return (sql, StatementArguments(args))
    }

    // MARK: - Private

    private static func buildCondition(rule: SmartListRule) -> (String, [DatabaseValueConvertible?])? {
        switch rule.field {
        case .contentType:
            return buildStringCondition(column: "type", comparison: rule.comparison, value: rule.value)
        case .sourceApp:
            if rule.comparison == .equals {
                return ("sourceAppBundleId = ?", [rule.value])
            }
            return buildStringCondition(column: "sourceAppName", comparison: rule.comparison, value: rule.value)
        case .createdDate:
            return buildDateCondition(column: "createdAt", comparison: rule.comparison, value: rule.value)
        case .textContains:
            return buildStringCondition(column: "plainTextContent", comparison: rule.comparison, value: rule.value)
        case .textRegex:
            // Post-fetch filter — handled in SmartListService
            return nil
        case .contentLength:
            return buildNumericCondition(column: "length(plainTextContent)", comparison: rule.comparison, value: rule.value)
        case .tag:
            return buildTagCondition(comparison: rule.comparison, value: rule.value)
        case .pinned:
            return buildBoolCondition(column: "pinned", comparison: rule.comparison)
        case .starred:
            return buildBoolCondition(column: "starred", comparison: rule.comparison)
        case .isSensitive:
            return buildBoolCondition(column: "isSensitive", comparison: rule.comparison)
        case .ocrText:
            return buildStringCondition(column: "ocrText", comparison: rule.comparison, value: rule.value)
        }
    }

    private static func buildStringCondition(column: String, comparison: RuleComparison, value: String) -> (String, [DatabaseValueConvertible?]) {
        switch comparison {
        case .equals: return ("\(column) = ?", [value])
        case .notEquals: return ("\(column) != ?", [value])
        case .contains: return ("\(column) LIKE ? ESCAPE '\\'", ["%\(escapeLikeValue(value))%"])
        case .notContains: return ("(\(column) IS NULL OR \(column) NOT LIKE ? ESCAPE '\\')", ["%\(escapeLikeValue(value))%"])
        default: return ("\(column) = ?", [value])
        }
    }

    private static func buildDateCondition(column: String, comparison: RuleComparison, value: String) -> (String, [DatabaseValueConvertible?])? {
        switch comparison {
        case .greaterThan:
            guard let date = parseRelativeDate(value) else { return nil }
            return ("\(column) >= ?", [date])
        case .lessThan:
            guard let date = parseRelativeDate(value) else { return nil }
            return ("\(column) < ?", [date])
        case .between:
            let parts = value.split(separator: "|")
            guard parts.count == 2,
                  let start = parseRelativeDate(String(parts[0])),
                  let end = parseRelativeDate(String(parts[1])) else { return nil }
            return ("\(column) BETWEEN ? AND ?", [start, end])
        default:
            return nil
        }
    }

    private static func buildNumericCondition(column: String, comparison: RuleComparison, value: String) -> (String, [DatabaseValueConvertible?])? {
        guard let num = Int(value) else { return nil }
        switch comparison {
        case .greaterThan: return ("\(column) > ?", [num])
        case .lessThan: return ("\(column) < ?", [num])
        default: return nil
        }
    }

    private static func buildBoolCondition(column: String, comparison: RuleComparison) -> (String, [DatabaseValueConvertible?]) {
        switch comparison {
        case .isTrue: return ("\(column) = 1", [])
        case .isFalse: return ("\(column) = 0", [])
        default: return ("\(column) = 1", [])
        }
    }

    private static func escapeLikeValue(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
             .replacingOccurrences(of: "%", with: "\\%")
             .replacingOccurrences(of: "_", with: "\\_")
    }

    private static func buildTagCondition(comparison: RuleComparison, value: String) -> (String, [DatabaseValueConvertible?]) {
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        let likeValue = "%\"\(escapeLikeValue(escaped))\"%"
        switch comparison {
        case .contains: return ("tags LIKE ? ESCAPE '\\'", [likeValue])
        case .notContains: return ("tags NOT LIKE ? ESCAPE '\\'", [likeValue])
        default: return ("tags LIKE ? ESCAPE '\\'", [likeValue])
        }
    }

    private static func buildOrderBy(_ sortOrder: SmartListSortOrder) -> String {
        switch sortOrder {
        case .newestFirst: "createdAt DESC"
        case .oldestFirst: "createdAt ASC"
        case .alphabetical: "plainTextContent ASC"
        case .mostUsed: "accessCount DESC"
        }
    }

    /// Parses relative date strings like "today", "-24h", "-7d", "-30d"
    /// or ISO 8601 dates.
    static func parseRelativeDate(_ value: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current

        switch value.lowercased() {
        case "today":
            return calendar.startOfDay(for: now)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        default:
            // Try relative formats: -24h, -7d, -30d
            if value.hasSuffix("h"), let hours = Int(value.dropLast()) {
                return calendar.date(byAdding: .hour, value: hours, to: now)
            }
            if value.hasSuffix("d"), let days = Int(value.dropLast()) {
                return calendar.date(byAdding: .day, value: days, to: now)
            }
            // Try ISO 8601
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: value)
        }
    }
}
