import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct SmartListQueryBuilderTests {
    func makeDB() throws -> (DatabaseQueue, StorageService) {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return (dbQueue, StorageService(dbQueue: dbQueue))
    }

    // MARK: - Content Type Rules

    @Test func contentTypeEquals() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hello"))
        try await storage.save(TestHelpers.makeCodeItem(text: "let x = 1"))
        try await storage.save(TestHelpers.makeImageItem())

        let rules = [SmartListRule(field: .contentType, comparison: .equals, value: ContentType.code.rawValue)]
        let (sql, args, hasRegex) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        #expect(!hasRegex)

        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.type == ContentType.code.rawValue)
    }

    @Test func contentTypeNotEquals() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hello"))
        try await storage.save(TestHelpers.makeCodeItem(text: "let x = 1"))

        let rules = [SmartListRule(field: .contentType, comparison: .notEquals, value: ContentType.code.rawValue)]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.type == ContentType.text.rawValue)
    }

    // MARK: - Text Contains Rules

    @Test func textContains() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hello world"))
        try await storage.save(TestHelpers.makeTextItem(text: "goodbye"))

        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "hello")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "hello world")
    }

    @Test func textNotContains() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hello world"))
        try await storage.save(TestHelpers.makeTextItem(text: "goodbye"))

        let rules = [SmartListRule(field: .textContains, comparison: .notContains, value: "hello")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "goodbye")
    }

    @Test func textContainsWithSQLWildcards() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "100% complete"))
        try await storage.save(TestHelpers.makeTextItem(text: "100 items"))
        try await storage.save(TestHelpers.makeTextItem(text: "file_name.txt"))

        // Search for literal "100%" — should NOT match "100 items"
        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "100%")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "100% complete")
    }

    @Test func textContainsWithUnderscore() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "file_name.txt"))
        try await storage.save(TestHelpers.makeTextItem(text: "filename.txt"))

        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "file_name")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "file_name.txt")
    }

    // MARK: - Boolean Rules

    @Test func pinnedIsTrue() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "pinned", pinned: true))
        try await storage.save(TestHelpers.makeTextItem(text: "not pinned", pinned: false))

        let rules = [SmartListRule(field: .pinned, comparison: .isTrue, value: "")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "pinned")
    }

    @Test func starredIsFalse() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "starred", starred: true))
        try await storage.save(TestHelpers.makeTextItem(text: "not starred", starred: false))

        let rules = [SmartListRule(field: .starred, comparison: .isFalse, value: "")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "not starred")
    }

    @Test func sensitiveIsTrue() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "secret", isSensitive: true))
        try await storage.save(TestHelpers.makeTextItem(text: "normal"))

        let rules = [SmartListRule(field: .isSensitive, comparison: .isTrue, value: "")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "secret")
    }

    // MARK: - Content Length Rules

    @Test func contentLengthGreaterThan() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "short"))
        try await storage.save(TestHelpers.makeTextItem(text: String(repeating: "a", count: 200)))

        let rules = [SmartListRule(field: .contentLength, comparison: .greaterThan, value: "100")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect((results.first?.plainTextContent?.count ?? 0) > 100)
    }

    @Test func contentLengthLessThan() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hi"))
        try await storage.save(TestHelpers.makeTextItem(text: String(repeating: "b", count: 200)))

        let rules = [SmartListRule(field: .contentLength, comparison: .lessThan, value: "10")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "hi")
    }

    // MARK: - Tag Rules

    @Test func tagContains() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "tagged", tags: ["work", "important"]))
        try await storage.save(TestHelpers.makeTextItem(text: "untagged", tags: []))

        let rules = [SmartListRule(field: .tag, comparison: .contains, value: "work")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "tagged")
    }

    // MARK: - Date Rules

    @Test func createdDateRelativeToday() async throws {
        let date = SmartListQueryBuilder.parseRelativeDate("today")
        #expect(date != nil)
        let calendar = Calendar.current
        #expect(calendar.isDateInToday(date!))
    }

    @Test func createdDateRelativeHours() async throws {
        let date = SmartListQueryBuilder.parseRelativeDate("-24h")
        #expect(date != nil)
        let diff = Date().timeIntervalSince(date!)
        // Should be approximately 24 hours ago (within 5 seconds)
        #expect(abs(diff - 86400) < 5)
    }

    @Test func createdDateRelativeDays() async throws {
        let date = SmartListQueryBuilder.parseRelativeDate("-7d")
        #expect(date != nil)
        let diff = Date().timeIntervalSince(date!)
        #expect(abs(diff - 604800) < 5)
    }

    @Test func createdDateBetween() async throws {
        let (dbQueue, _) = try makeDB()

        let rules = [SmartListRule(field: .createdDate, comparison: .between, value: "-7d|today")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        // Should produce 2 placeholders for BETWEEN, not crash
        let count = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: sql.replacingOccurrences(of: "SELECT *", with: "SELECT COUNT(*)"), arguments: args)
        }
        #expect(count != nil)
    }

    // MARK: - Match Modes (AND / OR)

    @Test func matchModeAll() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "pinned starred", pinned: true, starred: true))
        try await storage.save(TestHelpers.makeTextItem(text: "pinned only", pinned: true, starred: false))
        try await storage.save(TestHelpers.makeTextItem(text: "starred only", pinned: false, starred: true))

        let rules = [
            SmartListRule(field: .pinned, comparison: .isTrue, value: ""),
            SmartListRule(field: .starred, comparison: .isTrue, value: ""),
        ]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "pinned starred")
    }

    @Test func matchModeAny() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "pinned only", pinned: true, starred: false))
        try await storage.save(TestHelpers.makeTextItem(text: "starred only", pinned: false, starred: true))
        try await storage.save(TestHelpers.makeTextItem(text: "neither", pinned: false, starred: false))

        let rules = [
            SmartListRule(field: .pinned, comparison: .isTrue, value: ""),
            SmartListRule(field: .starred, comparison: .isTrue, value: ""),
        ]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .any, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 2)
    }

    // MARK: - Regex Detection

    @Test func regexRuleDetected() {
        let rules = [SmartListRule(field: .textRegex, comparison: .matches, value: "\\d+")]
        let (_, _, hasRegex) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        #expect(hasRegex)
    }

    @Test func nonRegexRuleNoRegex() {
        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "hello")]
        let (_, _, hasRegex) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        #expect(!hasRegex)
    }

    // MARK: - Sort Orders

    @Test func sortNewestFirst() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "first"))
        try await Task.sleep(for: .milliseconds(50))
        try await storage.save(TestHelpers.makeTextItem(text: "second"))

        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "")]
        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: rules, matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 2)
        // Newest first = "second" should be first
        #expect(results.first?.plainTextContent == "second")
    }

    // MARK: - Count Query

    @Test func countQueryMatchesEvaluate() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "hello world"))
        try await storage.save(TestHelpers.makeTextItem(text: "hello there"))
        try await storage.save(TestHelpers.makeTextItem(text: "goodbye"))

        let rules = [SmartListRule(field: .textContains, comparison: .contains, value: "hello")]
        let (countSql, countArgs) = SmartListQueryBuilder.buildCountQuery(
            rules: rules, matchMode: .all
        )
        let count = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: countSql, arguments: countArgs)
        }
        #expect(count == 2)
    }

    @Test func countQueryBetweenDates() async throws {
        let (dbQueue, _) = try makeDB()

        let rules = [SmartListRule(field: .createdDate, comparison: .between, value: "-7d|today")]
        let (countSql, countArgs) = SmartListQueryBuilder.buildCountQuery(
            rules: rules, matchMode: .all
        )
        // Should not crash — argument count matches placeholder count
        let count = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: countSql, arguments: countArgs)
        }
        #expect(count != nil)
    }

    // MARK: - Empty Rules

    @Test func emptyRulesReturnsAll() async throws {
        let (dbQueue, storage) = try makeDB()
        try await storage.save(TestHelpers.makeTextItem(text: "item1"))
        try await storage.save(TestHelpers.makeTextItem(text: "item2"))

        let (sql, args, _) = SmartListQueryBuilder.buildQuery(
            rules: [], matchMode: .all, sortOrder: .newestFirst
        )
        let results = try await dbQueue.read { db in
            try ClipboardItemRecord.fetchAll(db, sql: sql, arguments: args)
        }
        #expect(results.count == 2)
    }
}
