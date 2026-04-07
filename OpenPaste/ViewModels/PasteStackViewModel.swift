import Foundation

@Observable
final class PasteStackViewModel {
    var items: [ClipboardItemSummary] = []
    var currentIndex: Int = 0
    var isActive: Bool { !items.isEmpty }

    private var clipboardService: ClipboardServiceProtocol?
    private var storageService: StorageServiceProtocol?
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?
    var previousAppBundleId: (() -> String?)?

    func configure(clipboardService: ClipboardServiceProtocol, storageService: StorageServiceProtocol) {
        self.clipboardService = clipboardService
        self.storageService = storageService
    }

    func addToStack(_ item: ClipboardItemSummary) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
    }

    func removeFromStack(_ item: ClipboardItemSummary) {
        items.removeAll { $0.id == item.id }
        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
    }

    var currentItem: ClipboardItemSummary? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    func pasteNext() async {
        guard let summary = currentItem else { return }
        guard let fullItem = try? await storageService?.fetchFull(by: summary.id) else { return }
        await clipboardService?.copyToClipboard(fullItem)
        if currentIndex < items.count - 1 {
            currentIndex += 1
        } else {
            clear()
        }
        let targetBundleId = previousAppBundleId?()
        reactivatePreviousApp?()
        dismissAction?()
        await clipboardService?.simulatePasteToFrontApp(targetBundleId: targetBundleId)
    }

    func clear() {
        items.removeAll()
        currentIndex = 0
    }

    /// Move an item within the stack (for drag-and-drop reorder)
    func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = items
        let movedItems = source.map { reordered[$0] }
        for index in source.sorted().reversed() {
            reordered.remove(at: index)
        }
        let insertAt = min(destination, reordered.count)
        reordered.insert(contentsOf: movedItems, at: insertAt)

        if let sourceIdx = source.first {
            if sourceIdx == currentIndex {
                currentIndex = destination > sourceIdx ? destination - 1 : destination
            } else if sourceIdx < currentIndex && destination > currentIndex {
                currentIndex -= 1
            } else if sourceIdx > currentIndex && destination <= currentIndex {
                currentIndex += 1
            }
        }
        items = reordered
    }

    var positionText: String {
        guard isActive else { return "" }
        return "\(currentIndex + 1)/\(items.count)"
    }
}
