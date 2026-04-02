import Foundation
import SwiftUI
import GRDB

@Observable
final class HistoryViewModel {
    var items: [ClipboardItem] = []
    var isLoading = false
    var hasMore = true
    var showPasteConfirmation = false
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?
    private var offset = 0
    private let pageSize = Constants.defaultHistoryPageSize

    private let storageService: StorageServiceProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let eventBus: EventBus

    init(storageService: StorageServiceProtocol, clipboardService: ClipboardServiceProtocol, eventBus: EventBus) {
        self.storageService = storageService
        self.clipboardService = clipboardService
        self.eventBus = eventBus
    }

    func loadInitial() async {
        isLoading = true
        offset = 0
        do {
            items = try await storageService.fetch(limit: pageSize, offset: 0)
            offset = items.count
            hasMore = items.count == pageSize
        } catch {
            items = []
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let newItems = try await storageService.fetch(limit: pageSize, offset: offset)
            items.append(contentsOf: newItems)
            offset += newItems.count
            hasMore = newItems.count == pageSize
        } catch {}
        isLoading = false
    }

    func paste(_ item: ClipboardItem) async {
        await clipboardService.copyToClipboard(item)
        showPasteConfirmation = true
        try? await Task.sleep(for: .milliseconds(600))
        dismissAction?()
        reactivatePreviousApp?()
        await clipboardService.simulatePasteToFrontApp()
    }

    func delete(_ item: ClipboardItem) async {
        try? await storageService.delete(item.id)
        items.removeAll { $0.id == item.id }
    }

    func togglePin(_ item: ClipboardItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        try? await storageService.update(items[index])
    }

    func toggleStar(_ item: ClipboardItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].starred.toggle()
        try? await storageService.update(items[index])
    }

    func quickEditAndPaste(_ item: ClipboardItem, newText: String) async {
        var modified = item
        modified.content = Data(newText.utf8)
        modified.plainTextContent = newText
        await clipboardService.copyToClipboard(modified)
        dismissAction?()
        reactivatePreviousApp?()
        await clipboardService.simulatePasteToFrontApp()
    }

    func assignToCollection(_ item: ClipboardItem, collectionId: UUID) async {
        try? await storageService.assignItemToCollection(itemId: item.id, collectionId: collectionId)
    }

    func observeEvents() async {
        for await event in await eventBus.stream() {
            switch event {
            case .clipboardChanged(let newItem):
                await MainActor.run {
                    withAnimation(DS.Animation.springSnappy) {
                        items.insert(newItem, at: 0)
                    }
                }
            default:
                break
            }
        }
    }
}
