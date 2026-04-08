import SwiftUI
import UniformTypeIdentifiers

extension BottomShelfView {
    var displayItems: [ClipboardItemSummary] {
        if searchActive {
            return searchViewModel.results
        }
        if selectedSmartListId != nil, let slvm = smartListViewModel {
            return slvm.filteredItems
        }
        return historyViewModel.items
    }

    var shouldShowLoadingMore: Bool {
        !searchActive && selectedSmartListId == nil && historyViewModel.hasMore
    }

    var searchActive: Bool {
        !searchViewModel.query.isEmpty || searchViewModel.filters != .empty
    }

    var selectedItem: ClipboardItemSummary? {
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

        // Cmd+F → focus search field
        if keyPress.modifiers.contains(.command), keyPress.characters == "f" {
            searchFocused = true
            return .handled
        }

        if keyPress.modifiers.contains(.command),
            let n = Int(keyPress.characters),
            n >= 1, n <= 9
        {
            pasteByIndex(n - 1)
            return .handled
        }

        guard !searchFocused else { return .ignored }

        // Type-to-search: printable characters (no modifiers) focus search
        if keyPress.modifiers.isEmpty || keyPress.modifiers == .shift,
            let scalar = keyPress.characters.unicodeScalars.first,
            CharacterSet.alphanumerics.union(.punctuationCharacters).union(.symbols).contains(
                scalar)
        {
            searchFocused = true
            // Append the typed character since focus switch eats the keystroke
            searchViewModel.query.append(keyPress.characters)
            searchViewModel.searchDebounced()
            return .handled
        }

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
            let idx = displayItems.firstIndex(where: { $0.id == current })
        else {
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
        guard index >= 0, index < displayItems.count else { return }
        let item = displayItems[index]
        Task { await activePaste(item) }
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

    func activePaste(_ item: ClipboardItemSummary) async {
        if searchActive {
            await searchViewModel.paste(item)
        } else {
            await historyViewModel.paste(item)
        }
    }

    func activeDelete(_ item: ClipboardItemSummary) async {
        if searchActive {
            await searchViewModel.delete(item)
        } else {
            await historyViewModel.delete(item)
        }
    }

    func activeTogglePin(_ item: ClipboardItemSummary) async {
        if searchActive {
            await searchViewModel.togglePin(item)
        } else {
            await historyViewModel.togglePin(item)
        }
    }

    func activeToggleStar(_ item: ClipboardItemSummary) async {
        if searchActive {
            await searchViewModel.toggleStar(item)
        } else {
            await historyViewModel.toggleStar(item)
        }
    }

    func activePasteAsPlainText(_ item: ClipboardItemSummary) async {
        if searchActive {
            await searchViewModel.pasteAsPlainText(item)
        } else {
            await historyViewModel.pasteAsPlainText(item)
        }
    }
}

// MARK: - Drag & Drop Delegate for horizontal card reordering

struct CardDropDelegate: DropDelegate {
    let targetId: UUID
    @Binding var draggedItemId: UUID?
    let historyViewModel: HistoryViewModel

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedItemId = nil }
        guard let draggedId = draggedItemId, draggedId != targetId else { return false }
        historyViewModel.moveItem(draggedId, before: targetId)
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedItemId, draggedId != targetId else { return }
        withAnimation(DS.Animation.springSnappy) {
            historyViewModel.moveItem(draggedId, before: targetId)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Reset if drag leaves all targets (cancelled/dropped outside)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedItemId != nil && info.hasItemsConforming(to: [UTType.openPasteReorderItem])
    }
}
