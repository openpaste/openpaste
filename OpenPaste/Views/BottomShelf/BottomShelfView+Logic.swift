import SwiftUI

extension BottomShelfView {
    var displayItems: [ClipboardItem] {
        if searchActive {
            return searchViewModel.results
        }
        return historyViewModel.items
    }

    var shouldShowLoadingMore: Bool {
        !searchActive && historyViewModel.hasMore
    }

    var searchActive: Bool {
        !searchViewModel.query.isEmpty || searchViewModel.filters != .empty
    }

    var selectedItem: ClipboardItem? {
        if let selectedId {
            return displayItems.first(where: { $0.id == selectedId })
        }
        return displayItems.first
    }

    func applyCollectionFilter(_ collectionId: UUID?) {
        searchViewModel.filters.collectionId = collectionId
        searchViewModel.searchDebounced()
    }

    func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.characters == "\r" || keyPress.characters == "\n" {
            if keyPress.modifiers.contains(.shift) {
                pasteSelectedAsPlainText()
            } else {
                pasteSelected()
            }
            return .handled
        }

        if keyPress.modifiers.contains(.command),
           let n = Int(keyPress.characters),
           n >= 1, n <= 9 {
            pasteByIndex(n - 1)
            return .handled
        }

        guard !searchFocused else { return .ignored }

        if keyPress.characters == " " {
            togglePreview()
            return .handled
        }

        if keyPress.characters == "d" {
            deleteSelected()
            return .handled
        }
        if keyPress.characters == "p" {
            togglePinSelected()
            return .handled
        }
        if keyPress.characters == "s" {
            toggleStarSelected()
            return .handled
        }

        return .ignored
    }

    func togglePreview() {
        withAnimation(DS.Animation.springDefault) {
            showPreview.toggle()
        }
        searchFocused = false
    }

    func moveSelection(by offset: Int) {
        guard !displayItems.isEmpty else { return }
        guard let current = selectedId,
              let idx = displayItems.firstIndex(where: { $0.id == current }) else {
            selectedId = displayItems.first?.id
            return
        }
        let newIdx = min(max(idx + offset, 0), displayItems.count - 1)
        selectedId = displayItems[newIdx].id
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        Task { await activePaste(item) }
    }

    func pasteSelectedAsPlainText() {
        guard let item = selectedItem else { return }
        Task { await activePasteAsPlainText(item) }
    }

    func pasteByIndex(_ index: Int) {
        if searchActive {
            Task { await searchViewModel.pasteByIndex(index) }
        } else {
            Task { await historyViewModel.pasteByIndex(index) }
        }
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        Task { await activeDelete(item) }
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        Task { await activeTogglePin(item) }
    }

    func toggleStarSelected() {
        guard let item = selectedItem else { return }
        Task { await activeToggleStar(item) }
    }

    func activePaste(_ item: ClipboardItem) async {
        if searchActive {
            await searchViewModel.paste(item)
        } else {
            await historyViewModel.paste(item)
        }
    }

    func activeDelete(_ item: ClipboardItem) async {
        if searchActive {
            await searchViewModel.delete(item)
        } else {
            await historyViewModel.delete(item)
        }
    }

    func activeTogglePin(_ item: ClipboardItem) async {
        if searchActive {
            await searchViewModel.togglePin(item)
        } else {
            await historyViewModel.togglePin(item)
        }
    }

    func activeToggleStar(_ item: ClipboardItem) async {
        if searchActive {
            await searchViewModel.toggleStar(item)
        } else {
            await historyViewModel.toggleStar(item)
        }
    }

    func activePasteAsPlainText(_ item: ClipboardItem) async {
        if searchActive {
            await searchViewModel.pasteAsPlainText(item)
        } else {
            await historyViewModel.pasteAsPlainText(item)
        }
    }
}
