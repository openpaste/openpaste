import Foundation
import GRDB
import SwiftUI

@Observable
final class HistoryViewModel {
    var items: [ClipboardItemSummary] = []
    var isLoading = false
    var hasMore = true
    var showPasteConfirmation = false
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?
    var previousAppBundleId: (() -> String?)?

    // Scroll restoration state
    var scrollAnchorId: UUID?
    private(set) var panelClosedAt: Date?
    private var hadNewItemSinceClose = false
    var isRestoringScroll = false
    private let scrollRestorationThreshold: TimeInterval = 30

    private var offset = 0
    private let pageSize = Constants.defaultHistoryPageSize
    private let maxItemsInMemory = 150

    private let storageService: StorageServiceProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let eventBus: EventBus

    init(
        storageService: StorageServiceProtocol, clipboardService: ClipboardServiceProtocol,
        eventBus: EventBus
    ) {
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
            items = try await storageService.fetchSummaries(limit: pageSize, offset: 0)
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
            let newItems = try await storageService.fetchSummaries(limit: pageSize, offset: offset)
            mergePage(newItems)
            offset += newItems.count
            hasMore = newItems.count == pageSize
        } catch {}
        isLoading = false
    }

    func paste(_ item: ClipboardItemSummary) async {
        guard let fullItem = try? await storageService.fetchFull(by: item.id) else { return }
        print("[Paste] Starting paste for item: \(fullItem.type)")
        await clipboardService.copyToClipboard(fullItem)
        showPasteConfirmation = true

        let shouldPasteDirectly =
            UserDefaults.standard.object(forKey: Constants.pasteDirectlyKey) as? Bool ?? true
        print("[Paste] shouldPasteDirectly = \(shouldPasteDirectly)")
        guard shouldPasteDirectly else {
            dismissAction?()
            return
        }

        // Capture target BEFORE dismissing — dismiss clears window state
        let targetBundleId = previousAppBundleId?()
        print("[Paste] targetBundleId = \(targetBundleId ?? "nil")")
        print(
            "[Paste] Current frontmost = \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")"
        )
        print("[Paste] OpenPaste bundleId = \(Bundle.main.bundleIdentifier ?? "nil")")

        // Reactivate target app FIRST while panel is still around
        reactivatePreviousApp?()
        print("[Paste] Called reactivatePreviousApp, waiting 100ms...")

        // Give macOS time to process app activation
        try? await Task.sleep(for: .milliseconds(100))

        print(
            "[Paste] After wait, frontmost = \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")"
        )

        // Then dismiss the panel
        dismissAction?()
        print("[Paste] Called dismissAction")

        // Finally simulate ⌘V into the (now active) target app
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
        print("[Paste] simulatePasteToFrontApp completed")
    }

    func pasteAsPlainText(_ item: ClipboardItemSummary) async {
        guard let text = item.plainTextContent else {
            await paste(item)
            return
        }
        var plainItem = ClipboardItem(
            id: item.id,
            type: .text,
            content: Data(text.utf8),
            plainTextContent: text,
            sourceApp: item.sourceApp,
            contentHash: item.contentHash
        )
        plainItem.plainTextContent = text
        await clipboardService.copyToClipboard(plainItem)

        let shouldPasteDirectly =
            UserDefaults.standard.object(forKey: Constants.pasteDirectlyKey) as? Bool ?? true
        guard shouldPasteDirectly else {
            dismissAction?()
            return
        }

        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        try? await Task.sleep(for: .milliseconds(100))
        dismissAction?()
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func pasteByIndex(_ index: Int) async {
        guard index >= 0, index < items.count else { return }
        await paste(items[index])
    }

    func delete(_ item: ClipboardItemSummary) async {
        try? await storageService.delete(item.id)
        items.removeAll { $0.id == item.id }
    }

    /// Move an item before another item in the displayed list (in-memory reorder).
    func moveItem(_ sourceId: UUID, before targetId: UUID) {
        guard let sourceIdx = items.firstIndex(where: { $0.id == sourceId }),
            let targetIdx = items.firstIndex(where: { $0.id == targetId }),
            sourceIdx != targetIdx
        else { return }
        let item = items.remove(at: sourceIdx)
        let insertIdx = sourceIdx < targetIdx ? targetIdx - 1 : targetIdx
        items.insert(item, at: insertIdx)
    }

    func togglePin(_ item: ClipboardItemSummary) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        // Fetch full item to update in DB
        if var fullItem = try? await storageService.fetchFull(by: item.id) {
            fullItem.pinned = items[index].pinned
            try? await storageService.update(fullItem)
        }
        withAnimation(DS.Animation.springSnappy) {
            items.sort { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    func toggleStar(_ item: ClipboardItemSummary) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].starred.toggle()
        if var fullItem = try? await storageService.fetchFull(by: item.id) {
            fullItem.starred = items[index].starred
            try? await storageService.update(fullItem)
        }
    }

    func quickEditAndPaste(_ item: ClipboardItemSummary, newText: String) async {
        guard let fullItem = try? await storageService.fetchFull(by: item.id) else { return }
        var modified = fullItem
        modified.content = Data(newText.utf8)
        modified.plainTextContent = newText
        await clipboardService.copyToClipboard(modified)

        #if DEBUG
            if ProcessInfo.processInfo.environment["OPENPASTE_UI_TEST_MODE"] == "1" {
                dismissAction?()
                return
            }
        #endif

        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        dismissAction?()
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func quickEditAndPasteImage(_ item: ClipboardItemSummary, imageData: Data) async {
        guard let fullItem = try? await storageService.fetchFull(by: item.id) else { return }
        var modified = fullItem
        modified.content = imageData
        await clipboardService.copyToClipboard(modified)

        #if DEBUG
            if ProcessInfo.processInfo.environment["OPENPASTE_UI_TEST_MODE"] == "1" {
                dismissAction?()
                return
            }
        #endif

        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        dismissAction?()
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func assignToCollection(_ item: ClipboardItemSummary, collectionId: UUID) async {
        try? await storageService.assignItemToCollection(
            itemId: item.id, collectionId: collectionId)
    }

    /// Prefetch content for visible items (for drag & drop readiness).
    func prefetchContent(for ids: [UUID]) {
        for id in ids {
            Task {
                _ = try? await storageService.fetchContent(for: id)
            }
        }
    }

    // MARK: - Scroll Restoration

    var shouldRestoreScroll: Bool {
        guard let closedAt = panelClosedAt,
            scrollAnchorId != nil,
            !hadNewItemSinceClose
        else { return false }
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
            await handleEvent(event)
        }
    }

    func handleEvent(_ event: AppEvent) async {
        switch event {
        case .itemStored(let storedItem), .duplicateCopied(let storedItem):
            await MainActor.run {
                hadNewItemSinceClose = true
                let summary = storedItem.toSummary()
                withAnimation(DS.Animation.springSnappy) {
                    upsertVisibleItem(summary)
                }
            }
        default:
            break
        }
    }

    private func mergePage(_ page: [ClipboardItemSummary]) {
        let existingIDs = Set(items.map(\.id))
        items.append(contentsOf: page.filter { !existingIDs.contains($0.id) })

        // Sliding window: evict unpinned tail items when exceeding limit
        if items.count > maxItemsInMemory {
            let pinnedCount = items.filter(\.pinned).count
            let targetUnpinned = maxItemsInMemory - pinnedCount
            var unpinnedSeen = 0
            items = items.filter { item in
                if item.pinned { return true }
                unpinnedSeen += 1
                return unpinnedSeen <= targetUnpinned
            }
            hasMore = true
        }
    }

    private func upsertVisibleItem(_ item: ClipboardItemSummary) {
        items.removeAll { $0.id == item.id }
        items.append(item)
        sortVisibleItems()
    }

    private func sortVisibleItems() {
        items.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
