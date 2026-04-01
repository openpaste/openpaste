import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct CollectionStorageTests {
    func makeService() throws -> StorageService {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return StorageService(dbQueue: dbQueue)
    }

    @Test func createAndFetchCollections() async throws {
        let service = try makeService()
        let collection = Collection(name: "Test Collection")
        try await service.saveCollection(collection)

        let fetched = try await service.fetchCollections()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Collection")
    }

    @Test func fetchCollectionsOrderedByName() async throws {
        let service = try makeService()
        try await service.saveCollection(Collection(name: "Zeta"))
        try await service.saveCollection(Collection(name: "Alpha"))
        try await service.saveCollection(Collection(name: "Middle"))

        let fetched = try await service.fetchCollections()
        #expect(fetched.map(\.name) == ["Alpha", "Middle", "Zeta"])
    }

    @Test func deleteCollection() async throws {
        let service = try makeService()
        let collection = Collection(name: "To Delete")
        try await service.saveCollection(collection)
        try await service.deleteCollection(collection.id)

        let fetched = try await service.fetchCollections()
        #expect(fetched.isEmpty)
    }

    @Test func deleteCollectionUnassignsItems() async throws {
        let service = try makeService()
        let collection = Collection(name: "My Collection")
        try await service.saveCollection(collection)

        let item = TestHelpers.makeTextItem(collectionId: collection.id)
        try await service.save(item)
        try await service.assignItemToCollection(itemId: item.id, collectionId: collection.id)

        try await service.deleteCollection(collection.id)

        let items = try await service.fetch(limit: 10, offset: 0)
        #expect(items.first?.collectionId == nil)
    }

    @Test func assignItemToCollection() async throws {
        let service = try makeService()
        let collection = Collection(name: "Work")
        try await service.saveCollection(collection)

        let item = TestHelpers.makeTextItem()
        try await service.save(item)
        try await service.assignItemToCollection(itemId: item.id, collectionId: collection.id)

        let items = try await service.fetchItems(inCollection: collection.id)
        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
    }

    @Test func removeItemFromCollection() async throws {
        let service = try makeService()
        let collection = Collection(name: "Temp")
        try await service.saveCollection(collection)

        let item = TestHelpers.makeTextItem()
        try await service.save(item)
        try await service.assignItemToCollection(itemId: item.id, collectionId: collection.id)
        try await service.assignItemToCollection(itemId: item.id, collectionId: nil)

        let items = try await service.fetchItems(inCollection: collection.id)
        #expect(items.isEmpty)
    }

    @Test func fetchItemsInEmptyCollection() async throws {
        let service = try makeService()
        let collection = Collection(name: "Empty")
        try await service.saveCollection(collection)

        let items = try await service.fetchItems(inCollection: collection.id)
        #expect(items.isEmpty)
    }

    @Test func multipleItemsInCollection() async throws {
        let service = try makeService()
        let collection = Collection(name: "Project")
        try await service.saveCollection(collection)

        for i in 0..<3 {
            let item = TestHelpers.makeTextItem(text: "item \(i)")
            try await service.save(item)
            try await service.assignItemToCollection(itemId: item.id, collectionId: collection.id)
        }

        let items = try await service.fetchItems(inCollection: collection.id)
        #expect(items.count == 3)
    }
}
