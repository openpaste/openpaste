import Foundation

@Observable
final class SearchViewModel {
    var query: String = ""
    var filters = SearchFilters.empty
    var results: [ClipboardItem] = []
    var isSearching = false
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?
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
            results = try await searchService.search(query: currentQuery, filters: filters)
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

    func loadAvailableTags() async {
        do {
            let items = try await storageService.fetch(limit: 500, offset: 0)
            var tagSet = Set<String>()
            for item in items {
                tagSet.formUnion(item.tags)
            }
            availableTags = tagSet.sorted()
        } catch {
            availableTags = []
        }
    }

    // MARK: - Item Actions

    func paste(_ item: ClipboardItem) async {
        await clipboardService.copyToClipboard(item)
        dismissAction?()
        reactivatePreviousApp?()
        await clipboardService.simulatePasteToFrontApp()
    }

    func delete(_ item: ClipboardItem) async {
        try? await storageService.delete(item.id)
        results.removeAll { $0.id == item.id }
    }

    func togglePin(_ item: ClipboardItem) async {
        guard let index = results.firstIndex(where: { $0.id == item.id }) else { return }
        results[index].pinned.toggle()
        try? await storageService.update(results[index])
    }

    func toggleStar(_ item: ClipboardItem) async {
        guard let index = results.firstIndex(where: { $0.id == item.id }) else { return }
        results[index].starred.toggle()
        try? await storageService.update(results[index])
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
        lhs.collectionId == rhs.collectionId
    }
}
