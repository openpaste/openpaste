import Foundation
import SwiftUI

@Observable
final class SearchViewModel {
    var query: String = ""
    var filters = SearchFilters.empty
    var results: [ClipboardItemSummary] = []
    var isSearching = false
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?
    var previousAppBundleId: (() -> String?)?
    var availableTags: [String] = []

    private let searchService: SearchServiceProtocol
    private let storageService: StorageServiceProtocol
    private let clipboardService: ClipboardServiceProtocol
    private var searchTask: Task<Void, Never>?

    init(searchService: SearchServiceProtocol, storageService: StorageServiceProtocol, clipboardService: ClipboardServiceProtocol) {
        self.searchService = searchService
        self.storageService = storageService
        self.clipboardService = clipboardService
        Task { await loadAvailableTags() }
    }

    func searchDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        let currentQuery = query
        guard !currentQuery.isEmpty || filters != .empty else {
            results = []
            return
        }
        isSearching = true
        do {
            results = try await searchService.searchSummaries(query: currentQuery, filters: filters)
        } catch {
            results = []
        }
        isSearching = false
    }

    func setTypeFilter(_ type: ContentType?) {
        filters.contentType = type
        searchDebounced()
    }

    func setTagFilter(_ tags: [String]) {
        filters.tags = tags
        searchDebounced()
    }

    func clearFilters() {
        filters = .empty
        searchDebounced()
    }

    func applySmartFilters() {
        searchDebounced()
    }

    func loadAvailableTags() async {
        do {
            availableTags = try await storageService.fetchAllTags()
        } catch {
            availableTags = []
        }
    }

    // MARK: - Item Actions

    func paste(_ item: ClipboardItemSummary) async {
        guard let fullItem = try? await storageService.fetchFull(by: item.id) else { return }
        await clipboardService.copyToClipboard(fullItem)

        let shouldPasteDirectly = UserDefaults.standard.object(forKey: Constants.pasteDirectlyKey) as? Bool ?? true
        guard shouldPasteDirectly else {
            dismissAction?()
            return
        }

        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        dismissAction?()
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func pasteAsPlainText(_ item: ClipboardItemSummary) async {
        guard let text = item.plainTextContent else {
            await paste(item)
            return
        }
        let plainItem = ClipboardItem(
            id: item.id,
            type: .text,
            content: Data(text.utf8),
            plainTextContent: text,
            sourceApp: item.sourceApp,
            contentHash: item.contentHash
        )
        await clipboardService.copyToClipboard(plainItem)

        let shouldPasteDirectly = UserDefaults.standard.object(forKey: Constants.pasteDirectlyKey) as? Bool ?? true
        guard shouldPasteDirectly else {
            dismissAction?()
            return
        }

        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        dismissAction?()
        await clipboardService.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func pasteByIndex(_ index: Int) async {
        guard index >= 0, index < results.count else { return }
        await paste(results[index])
    }

    func delete(_ item: ClipboardItemSummary) async {
        try? await storageService.delete(item.id)
        results.removeAll { $0.id == item.id }
    }

    func togglePin(_ item: ClipboardItemSummary) async {
        guard let index = results.firstIndex(where: { $0.id == item.id }) else { return }
        results[index].pinned.toggle()
        if var fullItem = try? await storageService.fetchFull(by: item.id) {
            fullItem.pinned = results[index].pinned
            try? await storageService.update(fullItem)
        }
        withAnimation(DS.Animation.springSnappy) {
            results.sort { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    func toggleStar(_ item: ClipboardItemSummary) async {
        guard let index = results.firstIndex(where: { $0.id == item.id }) else { return }
        results[index].starred.toggle()
        if var fullItem = try? await storageService.fetchFull(by: item.id) {
            fullItem.starred = results[index].starred
            try? await storageService.update(fullItem)
        }
    }
}

extension SearchFilters: Equatable {
    nonisolated static func == (lhs: SearchFilters, rhs: SearchFilters) -> Bool {
        lhs.contentType == rhs.contentType &&
        lhs.sourceAppBundleId == rhs.sourceAppBundleId &&
        lhs.dateFrom == rhs.dateFrom &&
        lhs.dateTo == rhs.dateTo &&
        lhs.pinnedOnly == rhs.pinnedOnly &&
        lhs.starredOnly == rhs.starredOnly &&
        lhs.tags == rhs.tags &&
        lhs.collectionId == rhs.collectionId &&
        lhs.timeRange == rhs.timeRange
    }
}
