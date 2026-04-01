import Foundation

@Observable
final class PasteStackViewModel {
    var items: [ClipboardItem] = []
    var currentIndex: Int = 0
    var isActive: Bool { !items.isEmpty }

    private var clipboardService: ClipboardServiceProtocol?
    var dismissAction: (() -> Void)?

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
        await clipboardService?.pasteItem(item)
        if currentIndex < items.count - 1 {
            currentIndex += 1
        } else {
            clear()
        }
        dismissAction?()
    }

    func clear() {
        items.removeAll()
        currentIndex = 0
    }

    var positionText: String {
        guard isActive else { return "" }
        return "\(currentIndex + 1)/\(items.count)"
    }
}
