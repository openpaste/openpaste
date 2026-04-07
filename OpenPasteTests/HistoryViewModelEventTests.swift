import Foundation
import Testing

@testable import OpenPaste

private actor EventTestStorageService: StorageServiceProtocol {
    func save(_ item: ClipboardItem) async throws {}
    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem] { [] }
    func delete(_ id: UUID) async throws {}
    func deleteAll() async throws {}
    func fetchByHash(_ hash: String) async throws -> ClipboardItem? { nil }
    func updateAccessCount(_ id: UUID) async throws {}
    func deleteExpired() async throws {}
    func itemCount() async throws -> Int { 0 }
    func update(_ item: ClipboardItem) async throws {}
    func fetchCollections() async throws -> [Collection] { [] }
    func saveCollection(_ collection: Collection) async throws {}
    func deleteCollection(_ id: UUID) async throws {}
    func fetchItems(inCollection collectionId: UUID) async throws -> [ClipboardItem] { [] }
    func assignItemToCollection(itemId: UUID, collectionId: UUID?) async throws {}
    func fetchSummaries(limit: Int, offset: Int) async throws -> [ClipboardItemSummary] { [] }
    func fetchSummaries(inCollection collectionId: UUID) async throws -> [ClipboardItemSummary] { [] }
    func fetchContent(for id: UUID) async throws -> Data? { nil }
    func fetchFull(by id: UUID) async throws -> ClipboardItem? { nil }
    func fetchAllTags() async throws -> [String] { [] }
}

private struct EventTestClipboardService: ClipboardServiceProtocol {
    func startMonitoring() async {}
    func stopMonitoring() async {}
    func pauseMonitoring() async {}
    func resumeMonitoring() async {}
    func pasteItem(_ item: ClipboardItem) async {}
    func copyToClipboard(_ item: ClipboardItem) async {}
    func simulatePasteToFrontApp(targetBundleId: String?) async {}
}

struct HistoryViewModelEventTests {
    @Test @MainActor func itemStoredUpsertsExistingRowWithoutDuplicatingIDs() async {
        let viewModel = makeViewModel()
        let id = UUID()
        var original = TestHelpers.makeTextItem(text: "Old")
        original.id = id
        original.createdAt = Date(timeIntervalSince1970: 10)
        original.modifiedAt = original.createdAt

        var updated = TestHelpers.makeTextItem(text: "New")
        updated.id = id
        updated.createdAt = Date(timeIntervalSince1970: 20)
        updated.modifiedAt = updated.createdAt

        viewModel.items = [original.toSummary()]

        await viewModel.handleEvent(.itemStored(updated))

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.id == id)
        #expect(viewModel.items.first?.plainTextContent == "New")
    }

    @Test @MainActor func itemStoredSortsNewestUnpinnedBelowPinnedItems() async {
        let viewModel = makeViewModel()
        var pinned = TestHelpers.makeTextItem(text: "Pinned", pinned: true)
        pinned.createdAt = Date(timeIntervalSince1970: 10)
        pinned.modifiedAt = pinned.createdAt

        var older = TestHelpers.makeTextItem(text: "Older")
        older.createdAt = Date(timeIntervalSince1970: 20)
        older.modifiedAt = older.createdAt

        var newest = TestHelpers.makeTextItem(text: "Newest")
        newest.createdAt = Date(timeIntervalSince1970: 30)
        newest.modifiedAt = newest.createdAt

        viewModel.items = [pinned.toSummary(), older.toSummary()]

        await viewModel.handleEvent(.itemStored(newest))

        #expect(viewModel.items.map(\.plainTextContent) == ["Pinned", "Newest", "Older"])
    }

    @Test @MainActor func duplicateCopiedRemainsIdempotentAndMovesUpdatedItemToFront() async {
        let viewModel = makeViewModel()
        let id = UUID()

        var updated = TestHelpers.makeTextItem(text: "Updated")
        updated.id = id
        updated.createdAt = Date(timeIntervalSince1970: 40)
        updated.modifiedAt = updated.createdAt

        var older = TestHelpers.makeTextItem(text: "Older")
        older.createdAt = Date(timeIntervalSince1970: 10)
        older.modifiedAt = older.createdAt

        var stale = TestHelpers.makeTextItem(text: "Stale")
        stale.id = id
        stale.createdAt = Date(timeIntervalSince1970: 5)
        stale.modifiedAt = stale.createdAt

        viewModel.items = [older.toSummary(), stale.toSummary()]

        await viewModel.handleEvent(.duplicateCopied(updated))

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.first?.id == id)
        #expect(viewModel.items.first?.plainTextContent == "Updated")
    }

    private func makeViewModel() -> HistoryViewModel {
        HistoryViewModel(
            storageService: EventTestStorageService(),
            clipboardService: EventTestClipboardService(),
            eventBus: EventBus()
        )
    }
}
