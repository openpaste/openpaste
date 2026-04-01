import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct SearchEngineTests {
    func makeEngine() throws -> (SearchEngine, StorageService) {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return (SearchEngine(dbQueue: dbQueue), StorageService(dbQueue: dbQueue))
    }

    @Test func searchByText() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "hello world"))
        try await storage.save(TestHelpers.makeTextItem(text: "goodbye world"))

        let results = try await engine.search(query: "hello", filters: .empty)
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "hello world")
    }

    @Test func searchPrefixMatch() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "programming language"))

        let results = try await engine.search(query: "prog", filters: .empty)
        #expect(results.count == 1)
    }

    @Test func searchMultipleTokens() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "hello beautiful world"))
        try await storage.save(TestHelpers.makeTextItem(text: "hello friend"))

        let results = try await engine.search(query: "hello world", filters: .empty)
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "hello beautiful world")
    }

    @Test func searchByContentType() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "text item"))
        try await storage.save(TestHelpers.makeCodeItem(text: "let x = 1"))

        let results = try await engine.search(
            query: "",
            filters: SearchFilters(contentType: .code)
        )
        #expect(results.allSatisfy { $0.type == .code })
    }

    @Test func searchEmptyQueryEmptyFilters() async throws {
        let (engine, _) = try makeEngine()
        let results = try await engine.search(query: "", filters: .empty)
        #expect(results.isEmpty)
    }

    @Test func searchPinnedOnly() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "unpinned"))
        try await storage.save(TestHelpers.makeTextItem(text: "pinned", pinned: true))

        var filters = SearchFilters.empty
        filters.pinnedOnly = true
        let results = try await engine.search(query: "", filters: filters)
        #expect(results.allSatisfy { $0.pinned })
    }

    @Test func searchStarredOnly() async throws {
        let (engine, storage) = try makeEngine()
        try await storage.save(TestHelpers.makeTextItem(text: "unstarred"))
        try await storage.save(TestHelpers.makeTextItem(text: "starred", starred: true))

        var filters = SearchFilters.empty
        filters.starredOnly = true
        let results = try await engine.search(query: "", filters: filters)
        #expect(results.allSatisfy { $0.starred })
    }

    @Test func searchBySourceApp() async throws {
        let (engine, storage) = try makeEngine()
        let safariApp = AppInfo(bundleId: "com.apple.Safari", name: "Safari", iconPath: nil)
        let terminalApp = AppInfo(bundleId: "com.apple.Terminal", name: "Terminal", iconPath: nil)
        try await storage.save(TestHelpers.makeTextItem(text: "from safari", sourceApp: safariApp))
        try await storage.save(TestHelpers.makeTextItem(text: "from terminal", sourceApp: terminalApp))

        var filters = SearchFilters.empty
        filters.sourceAppBundleId = "com.apple.Safari"
        let results = try await engine.search(query: "", filters: filters)
        #expect(results.count == 1)
        #expect(results.first?.sourceApp.bundleId == "com.apple.Safari")
    }

    @Test func searchLimitResults() async throws {
        let (engine, storage) = try makeEngine()
        for i in 0..<150 {
            try await storage.save(TestHelpers.makeTextItem(text: "item \(i)"))
        }

        let results = try await engine.search(query: "item", filters: .empty)
        #expect(results.count <= 100)
    }

    @Test func buildFTS5QuerySanitizesInput() {
        let query = SearchEngine.buildFTS5Query("hello world")
        #expect(query.contains("\"hello\"*"))
        #expect(query.contains("\"world\"*"))
    }

    @Test func buildFTS5QueryHandlesSpecialChars() {
        let query = SearchEngine.buildFTS5Query("test\"*()special")
        #expect(query.contains("testspecial"))
    }

    @Test func buildFTS5QueryHandlesReservedWords() {
        let query = SearchEngine.buildFTS5Query("NOT important")
        #expect(query.contains("\"NOT\"*"))
    }
}
