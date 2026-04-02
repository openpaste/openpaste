import Foundation

@Observable
final class PasteStackViewModel {
    var items: [ClipboardItem] = []
    var currentIndex: Int = 0
    var isActive: Bool { !items.isEmpty }

    private var clipboardService: ClipboardServiceProtocol?
    var dismissAction: (() -> Void)?
    var reactivatePreviousApp: (() -> Void)?

    func configure(clipboardService: ClipboardServiceProtocol) {
        self.clipboardService = clipboardService
    }

    func addToStack(_ item: ClipboardItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
    }

    func removeFromStack(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if currentIndex >= items.count {
            currentIndex = max(0, items.count - 1)
        }
    }

    var currentItem: ClipboardItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    func pasteNext() async {
        guard let item = currentItem else { return }
        await clipboardService?.copyToClipboard(item)
        if currentIndex < items.count - 1 {
            currentIndex += 1
        } else {
            clear()
        }
        dismissAction?()
        reactivatePreviousApp?()
        await clipboardService?.simulatePasteToFrontApp()
    }

    func clear() {
        items.removeAll()
        currentIndex = 0
    }

    /// Move an item within the stack (for drag-and-drop reorder)
    func moveItems(from source: IndexSet, to destination: Int) {
        // Manual move implementation (Array.move is SwiftUI-specific)
        var reordered = items
        let movedItems = source.map { reordered[$0] }
        // Remove from highest index first to preserve lower indices
        for index in source.sorted().reversed() {
            reordered.remove(at: index)
        }
        let insertAt = min(destination, reordered.count)
        reordered.insert(contentsOf: movedItems, at: insertAt)
        
        // Adjust currentIndex if it was affected by the move
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
