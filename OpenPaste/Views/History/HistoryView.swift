import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel

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
    }

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.items) { item in
                    ClipboardItemRow(
                        item: item,
                        onPaste: { Task { await viewModel.paste(item) } },
                        onDelete: { Task { await viewModel.delete(item) } },
                        onTogglePin: { Task { await viewModel.togglePin(item) } },
                        onToggleStar: { Task { await viewModel.toggleStar(item) } }
                    )
                    Divider().padding(.leading, 46)
                }

                if viewModel.hasMore {
                    ProgressView()
                        .padding()
                        .task { await viewModel.loadMore() }
                }
            }
        }
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
