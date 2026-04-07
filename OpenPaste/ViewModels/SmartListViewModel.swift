import Foundation

@MainActor
@Observable
final class SmartListViewModel {
    var smartLists: [SmartList] = []
    var selectedSmartListId: UUID?
    var filteredItems: [ClipboardItemSummary] = []
    var matchCounts: [UUID: Int] = [:]
    var isLoading = false

    @ObservationIgnored
    private let smartListService: SmartListServiceProtocol
    @ObservationIgnored
    private let eventBus: EventBus?
    @ObservationIgnored
    private var countRefreshTask: Task<Void, Never>?

    init(smartListService: SmartListServiceProtocol, eventBus: EventBus? = nil) {
        self.smartListService = smartListService
        self.eventBus = eventBus
    }

    // MARK: - Load

    func loadSmartLists() async {
        do {
            smartLists = try await smartListService.fetchAll()
        } catch {
            print("SmartListVM: Failed to load smart lists: \(error)")
        }
    }

    func seedPresetsIfNeeded() async {
        do {
            try await smartListService.seedPresetsIfNeeded()
        } catch {
            print("SmartListVM: Failed to seed presets: \(error)")
        }
    }

    // MARK: - Event Observation (C1 + C4)

    func observeEvents() async {
        guard let eventBus else { return }
        for await event in await eventBus.stream() {
            switch event {
            case .clipboardChanged, .itemStored, .syncCompleted:
                scheduleCountRefresh()
            default:
                break
            }
        }
    }

    /// Debounced count refresh (500ms) to avoid hammering DB on rapid copies
    private func scheduleCountRefresh() {
        countRefreshTask?.cancel()
        countRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await refreshCounts()
            // If a smart list is selected, refresh its results too
            if let selectedId = selectedSmartListId {
                await selectSmartList(selectedId)
            }
        }
    }

    // MARK: - Selection

    func selectSmartList(_ id: UUID?) async {
        selectedSmartListId = id
        guard let id, let smartList = smartLists.first(where: { $0.id == id }) else {
            filteredItems = []
            return
        }
        isLoading = true
        do {
            filteredItems = try await smartListService.evaluateSummaries(smartList, limit: 500)
        } catch {
            print("SmartListVM: Failed to evaluate smart list: \(error)")
            filteredItems = []
        }
        isLoading = false
    }

    // MARK: - CRUD

    func createSmartList(_ smartList: SmartList) async {
        do {
            try await smartListService.save(smartList)
            await loadSmartLists()
        } catch {
            print("SmartListVM: Failed to create smart list: \(error)")
        }
    }

    func updateSmartList(_ smartList: SmartList) async {
        do {
            try await smartListService.save(smartList)
            await loadSmartLists()
            if selectedSmartListId == smartList.id {
                await selectSmartList(smartList.id)
            }
        } catch {
            print("SmartListVM: Failed to update smart list: \(error)")
        }
    }

    func deleteSmartList(_ id: UUID) async {
        do {
            try await smartListService.delete(id)
            if selectedSmartListId == id {
                selectedSmartListId = nil
                filteredItems = []
            }
            await loadSmartLists()
        } catch {
            print("SmartListVM: Failed to delete smart list: \(error)")
        }
    }

    // MARK: - Counts

    func refreshCounts() async {
        var counts: [UUID: Int] = [:]
        for smartList in smartLists {
            do {
                counts[smartList.id] = try await smartListService.countMatches(smartList)
            } catch {
                counts[smartList.id] = 0
            }
        }
        matchCounts = counts
    }
}
