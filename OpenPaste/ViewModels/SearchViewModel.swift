import Foundation

@Observable
final class SearchViewModel {
    var query: String = ""
    var filters = SearchFilters.empty
    var results: [ClipboardItem] = []
    var isSearching = false

    private let searchService: SearchServiceProtocol
    private var searchTask: Task<Void, Never>?

    init(searchService: SearchServiceProtocol) {
        self.searchService = searchService
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

    func clearFilters() {
        filters = .empty
        searchDebounced()
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
        lhs.tags == rhs.tags
    }
}
