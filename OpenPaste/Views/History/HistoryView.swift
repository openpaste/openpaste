import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    var pasteStackViewModel: PasteStackViewModel?
    @State private var selectedId: UUID?
    @State private var showQuickEdit = false
    @State private var editingItem: ClipboardItem?

    var body: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                itemsList
            }
        }
        .task { await viewModel.loadInitial() }
        .task { await viewModel.observeEvents() }
        .sheet(isPresented: $showQuickEdit) {
            if let item = editingItem {
                QuickEditView(
                    item: item,
                    onSave: { text in
                        Task { await viewModel.quickEditAndPaste(item, newText: text) }
                        showQuickEdit = false
                    },
                    onCancel: { showQuickEdit = false }
                )
            }
        }
    }

    private var itemsList: some View {
        List(selection: $selectedId) {
            ForEach(viewModel.items) { item in
                ClipboardItemRow(
                    item: item,
                    onPaste: { Task { await viewModel.paste(item) } },
                    onDelete: { Task { await viewModel.delete(item) } },
                    onTogglePin: { Task { await viewModel.togglePin(item) } },
                    onToggleStar: { Task { await viewModel.toggleStar(item) } },
                    onQuickEdit: {
                        editingItem = item
                        showQuickEdit = true
                    },
                    onAddToStack: pasteStackViewModel != nil ? {
                        pasteStackViewModel?.addToStack(item)
                    } : nil
                )
                .tag(item.id)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.visible)
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .task { await viewModel.loadMore() }
            }
        }
        .listStyle(.plain)
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.dismissAction?()
            return .handled
        }
    }

    private func pasteSelected() {
        guard let id = selectedId,
              let item = viewModel.items.first(where: { $0.id == id }) else { return }
        Task { await viewModel.paste(item) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No clipboard history")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
