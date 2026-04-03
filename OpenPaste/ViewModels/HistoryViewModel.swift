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

    // Scroll restoration state
    var scrollAnchorId: UUID?
    private(set) var panelClosedAt: Date?
    private var hadNewItemSinceClose = false
    var isRestoringScroll = false
    private let scrollRestorationThreshold: TimeInterval = 30

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
        // Skip reload if restoring scroll position — data is still fresh
        if isRestoringScroll { return }

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
        dismissAction?()

        let shouldPasteDirectly = UserDefaults.standard.object(forKey: Constants.pasteDirectlyKey) as? Bool ?? true
        guard shouldPasteDirectly else { return }

        reactivatePreviousApp?()
        await clipboardService.simulatePasteToFrontApp()
    }

    func pasteAsPlainText(_ item: ClipboardItem) async {
        guard let text = item.plainTextContent else {
            await paste(item)
            return
        }
        var plainItem = item
        plainItem.type = .text
        plainItem.content = Data(text.utf8)
        plainItem.plainTextContent = text
        await paste(plainItem)
    }

    func pasteByIndex(_ index: Int) async {
        guard index >= 0, index < items.count else { return }
        await paste(items[index])
    }

    func delete(_ item: ClipboardItem) async {
        try? await storageService.delete(item.id)
        items.removeAll { $0.id == item.id }
    }

    /// Move an item before another item in the displayed list (in-memory reorder).
    func moveItem(_ sourceId: UUID, before targetId: UUID) {
        guard let sourceIdx = items.firstIndex(where: { $0.id == sourceId }),
              let targetIdx = items.firstIndex(where: { $0.id == targetId }),
              sourceIdx != targetIdx else { return }
        let item = items.remove(at: sourceIdx)
        let insertIdx = sourceIdx < targetIdx ? targetIdx - 1 : targetIdx
        items.insert(item, at: insertIdx)
    }

    func togglePin(_ item: ClipboardItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        try? await storageService.update(items[index])
        withAnimation(DS.Animation.springSnappy) {
            items.sort { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned }
                return lhs.createdAt > rhs.createdAt
            }
        }
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

    // MARK: - Scroll Restoration

    var shouldRestoreScroll: Bool {
        guard let closedAt = panelClosedAt,
              scrollAnchorId != nil,
              !hadNewItemSinceClose else { return false }
        return Date().timeIntervalSince(closedAt) < scrollRestorationThreshold
    }

    func recordPanelClose(visibleItemId: UUID?) {
        scrollAnchorId = visibleItemId
        panelClosedAt = Date()
        hadNewItemSinceClose = false
    }

    func clearScrollState() {
        scrollAnchorId = nil
        panelClosedAt = nil
        hadNewItemSinceClose = false
    }

    func observeEvents() async {
        for await event in await eventBus.stream() {
            switch event {
            case .clipboardChanged(let newItem):
                await MainActor.run {
                    hadNewItemSinceClose = true
                    withAnimation(DS.Animation.springSnappy) {
                        let insertIndex = items.firstIndex(where: { !$0.pinned }) ?? items.count
                        items.insert(newItem, at: insertIndex)
                    }
                }
            case .duplicateCopied(let updatedItem):
                await MainActor.run {
                    hadNewItemSinceClose = true
                    withAnimation(DS.Animation.springSnappy) {
                        items.removeAll { $0.id == updatedItem.id }
                        if updatedItem.pinned {
                            items.insert(updatedItem, at: 0)
                        } else {
                            let insertIndex = items.firstIndex(where: { !$0.pinned }) ?? items.count
                            items.insert(updatedItem, at: insertIndex)
                        }
                    }
                }
            default:
                break
            }
        }
    }
}
