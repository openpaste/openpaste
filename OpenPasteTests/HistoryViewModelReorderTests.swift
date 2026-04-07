import Foundation
import Testing

@testable import OpenPaste

private actor NoopStorageService: StorageServiceProtocol {
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

private struct NoopClipboardService: ClipboardServiceProtocol {
    func startMonitoring() async {}
    func stopMonitoring() async {}
    func pauseMonitoring() async {}
    func resumeMonitoring() async {}
    func pasteItem(_ item: ClipboardItem) async {}
    func copyToClipboard(_ item: ClipboardItem) async {}
    func simulatePasteToFrontApp(targetBundleId: String?) async {}
}

struct HistoryViewModelReorderTests {
    @Test @MainActor func moveItem_forwardPlacesSourceBeforeTarget() {
        let viewModel = makeViewModel()
        let alpha = TestHelpers.makeTextItem(text: "Alpha").toSummary()
        let beta = TestHelpers.makeTextItem(text: "Beta").toSummary()
        let gamma = TestHelpers.makeTextItem(text: "Gamma").toSummary()
        viewModel.items = [alpha, beta, gamma]

        viewModel.moveItem(alpha.id, before: gamma.id)

        #expect(viewModel.items.map(\.plainTextContent) == ["Beta", "Alpha", "Gamma"])
    }

    @Test @MainActor func moveItem_backwardPlacesSourceBeforeTarget() {
        let viewModel = makeViewModel()
        let alpha = TestHelpers.makeTextItem(text: "Alpha").toSummary()
        let beta = TestHelpers.makeTextItem(text: "Beta").toSummary()
        let gamma = TestHelpers.makeTextItem(text: "Gamma").toSummary()
        viewModel.items = [alpha, beta, gamma]

        viewModel.moveItem(gamma.id, before: alpha.id)

        #expect(viewModel.items.map(\.plainTextContent) == ["Gamma", "Alpha", "Beta"])
    }

    @Test @MainActor func moveItem_sameSourceAndTargetIsNoOp() {
        let viewModel = makeViewModel()
        let alpha = TestHelpers.makeTextItem(text: "Alpha").toSummary()
        let beta = TestHelpers.makeTextItem(text: "Beta").toSummary()
        viewModel.items = [alpha, beta]

        viewModel.moveItem(alpha.id, before: alpha.id)

        #expect(viewModel.items.map(\.plainTextContent) == ["Alpha", "Beta"])
    }

    private func makeViewModel() -> HistoryViewModel {
        HistoryViewModel(
            storageService: NoopStorageService(),
            clipboardService: NoopClipboardService(),
            eventBus: EventBus()
        )
    }
}
