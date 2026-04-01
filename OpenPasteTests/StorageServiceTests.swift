import Foundation
import Testing
import GRDB
@testable import OpenPaste

struct StorageServiceTests {
    func makeService() throws -> StorageService {
        let dbQueue = try TestHelpers.makeInMemoryDatabaseQueue()
        return StorageService(dbQueue: dbQueue)
    }

    @Test func saveAndFetch() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem()
        try await service.save(item)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == item.id)
    }

    @Test func fetchPreservesContent() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem(text: "hello world")
        try await service.save(item)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.first?.plainTextContent == "hello world")
        #expect(fetched.first?.type == .text)
    }

    @Test func delete() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem()
        try await service.save(item)
        try await service.delete(item.id)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.isEmpty)
    }

    @Test func deleteAll() async throws {
        let service = try makeService()
        try await service.save(TestHelpers.makeTextItem(text: "item1"))
        try await service.save(TestHelpers.makeTextItem(text: "item2"))
        try await service.save(TestHelpers.makeTextItem(text: "item3"))
        try await service.deleteAll()

        let count = try await service.itemCount()
        #expect(count == 0)
    }

    @Test func fetchByHash() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem()
        try await service.save(item)

        let found = try await service.fetchByHash(item.contentHash)
        #expect(found?.id == item.id)
    }

    @Test func fetchByHashNotFound() async throws {
        let service = try makeService()
        let found = try await service.fetchByHash("nonexistent")
        #expect(found == nil)
    }

    @Test func updateAccessCount() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem()
        try await service.save(item)
        try await service.updateAccessCount(item.id)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.first?.accessCount == 1)
    }

    @Test func updateAccessCountMultiple() async throws {
        let service = try makeService()
        let item = TestHelpers.makeTextItem()
        try await service.save(item)
        try await service.updateAccessCount(item.id)
        try await service.updateAccessCount(item.id)
        try await service.updateAccessCount(item.id)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.first?.accessCount == 3)
    }

    @Test func deleteExpired() async throws {
        let service = try makeService()
        var expiredItem = TestHelpers.makeTextItem(text: "expired", isSensitive: true)
        expiredItem.expiresAt = Date().addingTimeInterval(-100)
        try await service.save(expiredItem)

        let validItem = TestHelpers.makeTextItem(text: "valid")
        try await service.save(validItem)

        try await service.deleteExpired()
        let count = try await service.itemCount()
        #expect(count == 1)
    }

    @Test func pinnedItemsAppearFirst() async throws {
        let service = try makeService()
        try await service.save(TestHelpers.makeTextItem(text: "unpinned"))
        try await service.save(TestHelpers.makeTextItem(text: "pinned", pinned: true))

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.first?.pinned == true)
        #expect(fetched.first?.plainTextContent == "pinned")
    }

    @Test func pagination() async throws {
        let service = try makeService()
        for i in 0..<5 {
            try await service.save(TestHelpers.makeTextItem(text: "item \(i)"))
        }

        let page1 = try await service.fetch(limit: 2, offset: 0)
        let page2 = try await service.fetch(limit: 2, offset: 2)
        #expect(page1.count == 2)
        #expect(page2.count == 2)
        #expect(page1.first?.id != page2.first?.id)
    }

    @Test func itemCount() async throws {
        let service = try makeService()
        #expect(try await service.itemCount() == 0)
        try await service.save(TestHelpers.makeTextItem(text: "a"))
        try await service.save(TestHelpers.makeTextItem(text: "b"))
        #expect(try await service.itemCount() == 2)
    }

    @Test func updateItem() async throws {
        let service = try makeService()
        var item = TestHelpers.makeTextItem(text: "original")
        try await service.save(item)

        item.pinned = true
        item.starred = true
        try await service.update(item)

        let fetched = try await service.fetch(limit: 10, offset: 0)
        #expect(fetched.first?.pinned == true)
        #expect(fetched.first?.starred == true)
    }
}
