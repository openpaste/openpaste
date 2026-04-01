import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct SearchEngineTagFilterTests {

    func makeEngine() throws -> (SearchEngine, StorageService) {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return (SearchEngine(dbQueue: dbQueue), StorageService(dbQueue: dbQueue))
    }

    // MARK: - Tag Filters

    @Test func searchWithSingleTagFilter() async throws {
        let (engine, storage) = try makeEngine()

        // Item with "work" tag
        let taggedItem = TestHelpers.makeTextItem(text: "project notes", tags: ["work"])
        try await storage.save(taggedItem)

        // Item without tags
        let untaggedItem = TestHelpers.makeTextItem(text: "random text")
        try await storage.save(untaggedItem)

        var filters = SearchFilters.empty
        filters.tags = ["work"]
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "project notes")
    }

    @Test func searchWithMultipleTagsANDLogic() async throws {
        let (engine, storage) = try makeEngine()

        // Item with both tags
        let bothTags = TestHelpers.makeTextItem(text: "work urgent task", tags: ["work", "urgent"])
        try await storage.save(bothTags)

        // Item with only "work" tag
        let oneTag = TestHelpers.makeTextItem(text: "casual work notes", tags: ["work"])
        try await storage.save(oneTag)

        // Item with only "urgent" tag
        let otherTag = TestHelpers.makeTextItem(text: "urgent personal", tags: ["urgent"])
        try await storage.save(otherTag)

        var filters = SearchFilters.empty
        filters.tags = ["work", "urgent"]
        let results = try await engine.search(query: "", filters: filters)

        // AND logic: only item with both tags should match
        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "work urgent task")
    }

    @Test func searchWithTagAndTextQuery() async throws {
        let (engine, storage) = try makeEngine()

        let item1 = TestHelpers.makeTextItem(text: "hello world from work", tags: ["work"])
        try await storage.save(item1)

        let item2 = TestHelpers.makeTextItem(text: "hello world from home", tags: ["personal"])
        try await storage.save(item2)

        var filters = SearchFilters.empty
        filters.tags = ["work"]
        let results = try await engine.search(query: "hello", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "hello world from work")
    }

    @Test func searchWithNonExistentTag() async throws {
        let (engine, storage) = try makeEngine()

        let item = TestHelpers.makeTextItem(text: "some text", tags: ["existing"])
        try await storage.save(item)

        var filters = SearchFilters.empty
        filters.tags = ["nonexistent"]
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.isEmpty)
    }

    @Test func searchWithEmptyTagsNoFilter() async throws {
        let (engine, storage) = try makeEngine()

        let item = TestHelpers.makeTextItem(text: "test item", tags: ["tag1"])
        try await storage.save(item)

        // Empty tags array = no tag filtering, but need at least one non-empty filter
        var filters = SearchFilters.empty
        filters.tags = []
        filters.pinnedOnly = false
        // With truly empty filters, search returns empty
        let results = try await engine.search(query: "test", filters: filters)
        #expect(results.count == 1) // Found by text query, no tag filter applied
    }

    // MARK: - Collection ID Filter

    @Test func searchWithCollectionIdFilter() async throws {
        let (engine, storage) = try makeEngine()

        let collectionId = UUID()
        let inCollection = TestHelpers.makeTextItem(text: "in collection", collectionId: collectionId)
        try await storage.save(inCollection)

        let notInCollection = TestHelpers.makeTextItem(text: "no collection")
        try await storage.save(notInCollection)

        var filters = SearchFilters.empty
        filters.collectionId = collectionId
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "in collection")
        #expect(results.first?.collectionId == collectionId)
    }

    @Test func searchWithCollectionIdAndTextQuery() async throws {
        let (engine, storage) = try makeEngine()

        let collectionId = UUID()
        let item1 = TestHelpers.makeTextItem(text: "apple in collection", collectionId: collectionId)
        try await storage.save(item1)

        let item2 = TestHelpers.makeTextItem(text: "apple outside", collectionId: nil)
        try await storage.save(item2)

        var filters = SearchFilters.empty
        filters.collectionId = collectionId
        let results = try await engine.search(query: "apple", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.collectionId == collectionId)
    }

    @Test func searchWithNonExistentCollectionId() async throws {
        let (engine, storage) = try makeEngine()

        let item = TestHelpers.makeTextItem(text: "some text", collectionId: UUID())
        try await storage.save(item)

        var filters = SearchFilters.empty
        filters.collectionId = UUID() // different UUID
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.isEmpty)
    }

    // MARK: - Combined Filters

    @Test func searchCombinedTagAndContentType() async throws {
        let (engine, storage) = try makeEngine()

        // Text item with tag
        let textWithTag = TestHelpers.makeTextItem(text: "tagged text", tags: ["important"])
        try await storage.save(textWithTag)

        // Code item with tag
        var codeItem = TestHelpers.makeCodeItem(text: "let x = tagged()")
        codeItem.tags = ["important"]
        try await storage.save(codeItem)

        // Text item without tag
        let textNoTag = TestHelpers.makeTextItem(text: "untagged text")
        try await storage.save(textNoTag)

        var filters = SearchFilters.empty
        filters.tags = ["important"]
        filters.contentType = .text
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.type == .text)
        #expect(results.first?.plainTextContent == "tagged text")
    }

    @Test func searchCombinedTagAndPinned() async throws {
        let (engine, storage) = try makeEngine()

        let pinnedTagged = TestHelpers.makeTextItem(text: "pinned tagged", tags: ["work"], pinned: true)
        try await storage.save(pinnedTagged)

        let unpinnedTagged = TestHelpers.makeTextItem(text: "unpinned tagged", tags: ["work"])
        try await storage.save(unpinnedTagged)

        var filters = SearchFilters.empty
        filters.tags = ["work"]
        filters.pinnedOnly = true
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.pinned == true)
    }

    @Test func searchCombinedCollectionAndTag() async throws {
        let (engine, storage) = try makeEngine()

        let collectionId = UUID()
        let matchingItem = TestHelpers.makeTextItem(
            text: "matching item",
            tags: ["urgent"],
            collectionId: collectionId
        )
        try await storage.save(matchingItem)

        let wrongCollection = TestHelpers.makeTextItem(text: "wrong collection", tags: ["urgent"])
        try await storage.save(wrongCollection)

        let wrongTag = TestHelpers.makeTextItem(text: "wrong tag", tags: ["casual"], collectionId: collectionId)
        try await storage.save(wrongTag)

        var filters = SearchFilters.empty
        filters.collectionId = collectionId
        filters.tags = ["urgent"]
        let results = try await engine.search(query: "", filters: filters)

        #expect(results.count == 1)
        #expect(results.first?.plainTextContent == "matching item")
    }
}
