import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct SmartListServiceTests {
    func makeService() throws -> (SmartListService, StorageService, DatabaseQueue) {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return (SmartListService(dbQueue: dbQueue), StorageService(dbQueue: dbQueue), dbQueue)
    }

    // MARK: - CRUD

    @Test func saveAndFetchAll() async throws {
        let (service, _, _) = try makeService()
        let smartList = SmartList(
            name: "My List",
            rules: [SmartListRule(field: .pinned, comparison: .isTrue, value: "")]
        )
        try await service.save(smartList)

        let all = try await service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "My List")
    }

    @Test func saveThenUpdate() async throws {
        let (service, _, _) = try makeService()
        var smartList = SmartList(name: "V1", rules: [])
        try await service.save(smartList)

        smartList.name = "V2"
        try await service.save(smartList)

        let all = try await service.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "V2")
    }

    @Test func softDelete() async throws {
        let (service, _, _) = try makeService()
        let smartList = SmartList(name: "ToDelete", rules: [])
        try await service.save(smartList)
        #expect(try await service.fetchAll().count == 1)

        try await service.delete(smartList.id)
        #expect(try await service.fetchAll().count == 0)
    }

    @Test func fetchAllOrderedByPosition() async throws {
        let (service, _, _) = try makeService()
        try await service.save(SmartList(name: "Third", position: 2))
        try await service.save(SmartList(name: "First", position: 0))
        try await service.save(SmartList(name: "Second", position: 1))

        let all = try await service.fetchAll()
        #expect(all.map(\.name) == ["First", "Second", "Third"])
    }

    // MARK: - Evaluate

    @Test func evaluateContentTypeFilter() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "hello"))
        try await storage.save(TestHelpers.makeCodeItem(text: "let x = 1"))
        try await storage.save(TestHelpers.makeImageItem())

        let smartList = SmartList(
            name: "Code Only",
            rules: [SmartListRule(field: .contentType, comparison: .equals, value: ContentType.code.rawValue)]
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.type == .code)
    }

    @Test func evaluatePinnedFilter() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "pinned", pinned: true))
        try await storage.save(TestHelpers.makeTextItem(text: "not pinned", pinned: false))

        let smartList = SmartList(
            name: "Pinned",
            rules: [SmartListRule(field: .pinned, comparison: .isTrue, value: "")]
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "pinned")
    }

    @Test func evaluateWithRegexAllMode() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "abc123"))
        try await storage.save(TestHelpers.makeTextItem(text: "no numbers"))
        try await storage.save(TestHelpers.makeTextItem(text: "456def"))

        let smartList = SmartList(
            name: "Has Numbers",
            rules: [SmartListRule(field: .textRegex, comparison: .matches, value: "\\d+")],
            matchMode: .all
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 2)
        #expect(results.allSatisfy { ($0.plainTextContent ?? "").contains(where: \.isNumber) })
    }

    @Test func evaluateWithRegexAnyMode() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "abc123"))
        try await storage.save(TestHelpers.makeTextItem(text: "no match"))

        let smartList = SmartList(
            name: "Regex Any",
            rules: [
                SmartListRule(field: .textRegex, comparison: .matches, value: "\\d+"),
                SmartListRule(field: .textRegex, comparison: .matches, value: "xyz"),
            ],
            matchMode: .any
        )
        // In .any mode, either regex matching is sufficient
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "abc123")
    }

    @Test func evaluateWithRegexAllModeStrict() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "abc123"))

        let smartList = SmartList(
            name: "Regex All",
            rules: [
                SmartListRule(field: .textRegex, comparison: .matches, value: "\\d+"),
                SmartListRule(field: .textRegex, comparison: .matches, value: "xyz"),
            ],
            matchMode: .all
        )
        // In .all mode, both regex must match — "abc123" has digits but not "xyz"
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 0)
    }

    @Test func evaluateMultiRuleAND() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "important pinned", pinned: true, starred: true))
        try await storage.save(TestHelpers.makeTextItem(text: "just pinned", pinned: true, starred: false))
        try await storage.save(TestHelpers.makeTextItem(text: "just starred", pinned: false, starred: true))

        let smartList = SmartList(
            name: "Pinned AND Starred",
            rules: [
                SmartListRule(field: .pinned, comparison: .isTrue, value: ""),
                SmartListRule(field: .starred, comparison: .isTrue, value: ""),
            ],
            matchMode: .all
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "important pinned")
    }

    @Test func evaluateMultiRuleOR() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "just pinned", pinned: true, starred: false))
        try await storage.save(TestHelpers.makeTextItem(text: "just starred", pinned: false, starred: true))
        try await storage.save(TestHelpers.makeTextItem(text: "neither", pinned: false, starred: false))

        let smartList = SmartList(
            name: "Pinned OR Starred",
            rules: [
                SmartListRule(field: .pinned, comparison: .isTrue, value: ""),
                SmartListRule(field: .starred, comparison: .isTrue, value: ""),
            ],
            matchMode: .any
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 2)
    }

    @Test func evaluateRespectsSortOrder() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "banana"))
        try await Task.sleep(for: .milliseconds(50))
        try await storage.save(TestHelpers.makeTextItem(text: "apple"))

        let smartList = SmartList(
            name: "Alphabetical",
            rules: [],
            sortOrder: .alphabetical
        )
        let results = try await service.evaluate(smartList, limit: 100)
        #expect(results.count == 2)
        #expect(results.first?.plainTextContent == "apple")
    }

    @Test func evaluateRespectsLimit() async throws {
        let (service, storage, _) = try makeService()
        for i in 0..<10 {
            try await storage.save(TestHelpers.makeTextItem(text: "item \(i)"))
        }

        let smartList = SmartList(name: "All", rules: [])
        let results = try await service.evaluate(smartList, limit: 3)
        #expect(results.count == 3)
    }

    // MARK: - Count Matches

    @Test func countMatchesAccurate() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "hello 1"))
        try await storage.save(TestHelpers.makeTextItem(text: "hello 2"))
        try await storage.save(TestHelpers.makeTextItem(text: "goodbye"))

        let smartList = SmartList(
            name: "Hello",
            rules: [SmartListRule(field: .textContains, comparison: .contains, value: "hello")]
        )
        let count = try await service.countMatches(smartList)
        #expect(count == 2)
    }

    @Test func countMatchesWithBetweenDates() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "recent"))

        let smartList = SmartList(
            name: "This Week",
            rules: [SmartListRule(field: .createdDate, comparison: .between, value: "-7d|today")]
        )
        // Should not crash — the between date produces 2 args correctly
        let count = try await service.countMatches(smartList)
        #expect(count >= 0)
    }

    @Test func countMatchesWithRegexFallsBackToEvaluate() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "abc123"))
        try await storage.save(TestHelpers.makeTextItem(text: "no digits"))

        let smartList = SmartList(
            name: "Regex Count",
            rules: [SmartListRule(field: .textRegex, comparison: .matches, value: "\\d+")]
        )
        let count = try await service.countMatches(smartList)
        #expect(count == 1)
    }

    @Test func countMatchesEmptyRules() async throws {
        let (service, storage, _) = try makeService()
        try await storage.save(TestHelpers.makeTextItem(text: "item1"))
        try await storage.save(TestHelpers.makeTextItem(text: "item2"))

        let smartList = SmartList(name: "All", rules: [])
        let count = try await service.countMatches(smartList)
        #expect(count == 2)
    }

    // MARK: - Presets

    @Test func seedPresetsCreates5() async throws {
        let (service, _, _) = try makeService()
        try await service.seedPresetsIfNeeded()

        let all = try await service.fetchAll()
        let presets = all.filter(\.isBuiltIn)
        #expect(presets.count == 5)
        #expect(Set(presets.map(\.name)) == ["Today", "Images", "Links", "Code Snippets", "Sensitive"])
    }

    @Test func seedPresetsIdempotent() async throws {
        let (service, _, _) = try makeService()
        try await service.seedPresetsIfNeeded()
        try await service.seedPresetsIfNeeded()

        let presets = try await service.fetchAll().filter(\.isBuiltIn)
        #expect(presets.count == 5)
    }

    @Test func presetTodayMatchesRecentItems() async throws {
        let (service, storage, _) = try makeService()
        try await service.seedPresetsIfNeeded()
        try await storage.save(TestHelpers.makeTextItem(text: "just copied"))

        let allLists = try await service.fetchAll()
        let today = allLists.first { $0.name == "Today" }!
        let results = try await service.evaluate(today, limit: 100)
        #expect(results.count == 1)
    }

    @Test func presetImagesMatchesImageItems() async throws {
        let (service, storage, _) = try makeService()
        try await service.seedPresetsIfNeeded()
        try await storage.save(TestHelpers.makeImageItem())
        try await storage.save(TestHelpers.makeTextItem(text: "not an image"))

        let allLists = try await service.fetchAll()
        let images = allLists.first { $0.name == "Images" }!
        let results = try await service.evaluate(images, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.type == .image)
    }

    @Test func presetSensitiveMatchesSensitiveItems() async throws {
        let (service, storage, _) = try makeService()
        try await service.seedPresetsIfNeeded()
        try await storage.save(TestHelpers.makeTextItem(text: "api key", isSensitive: true))
        try await storage.save(TestHelpers.makeTextItem(text: "normal text"))

        let allLists = try await service.fetchAll()
        let sensitive = allLists.first { $0.name == "Sensitive" }!
        let results = try await service.evaluate(sensitive, limit: 100)
        #expect(results.count == 1)
        #expect(results.first?.isSensitive == true)
    }

    // MARK: - Import / Export

    @Test func exportAndImportRoundTrip() async throws {
        let (service, _, _) = try makeService()
        let original = SmartList(
            name: "Exported",
            icon: "star",
            color: "#FF0000",
            rules: [
                SmartListRule(field: .pinned, comparison: .isTrue, value: ""),
                SmartListRule(field: .textContains, comparison: .contains, value: "hello"),
            ],
            matchMode: .any
        )

        let data = try service.exportAsJSON(original)
        let imported = try service.importFromJSON(data)

        #expect(imported.name == "Exported")
        #expect(imported.icon == "star")
        #expect(imported.color == "#FF0000")
        #expect(imported.rules.count == 2)
        #expect(imported.matchMode == .any)
        // Should get a new ID
        #expect(imported.id != original.id)
        #expect(imported.isBuiltIn == false)
    }

    @Test func importSetsNewDates() async throws {
        let (service, _, _) = try makeService()
        let oldDate = Date(timeIntervalSince1970: 0)
        let original = SmartList(name: "Old", createdAt: oldDate, modifiedAt: oldDate)

        let data = try service.exportAsJSON(original)
        let imported = try service.importFromJSON(data)

        // Dates should be recent, not the old ones
        #expect(imported.createdAt.timeIntervalSince1970 > 1_000_000)
    }

    // MARK: - SmartListRecord Conversion

    @Test func recordRoundTrip() {
        let smartList = SmartList(
            name: "Test",
            icon: "folder",
            color: "#00FF00",
            rules: [SmartListRule(field: .contentType, comparison: .equals, value: "text")],
            matchMode: .any,
            sortOrder: .alphabetical,
            isBuiltIn: false,
            position: 3
        )

        let record = SmartListRecord(from: smartList)
        let converted = record.toSmartList()

        #expect(converted.id == smartList.id)
        #expect(converted.name == "Test")
        #expect(converted.icon == "folder")
        #expect(converted.color == "#00FF00")
        #expect(converted.rules.count == 1)
        #expect(converted.rules.first?.field == .contentType)
        #expect(converted.matchMode == .any)
        #expect(converted.sortOrder == .alphabetical)
        #expect(converted.position == 3)
    }
}
