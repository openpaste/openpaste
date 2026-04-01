import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchField
            filterBar
            if !viewModel.query.isEmpty || viewModel.filters != .empty {
                resultsList
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history…", text: $viewModel.query)
                .textFieldStyle(.plain)
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.searchDebounced()
                }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.clearFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ContentType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue.capitalized,
                        isActive: viewModel.filters.contentType == type
                    ) {
                        if viewModel.filters.contentType == type {
                            viewModel.setTypeFilter(nil)
                        } else {
                            viewModel.setTypeFilter(type)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var resultsList: some View {
        Group {
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty {
                Text("No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.results) { item in
                            ClipboardItemRow(
                                item: item,
                                onPaste: { Task { await viewModel.paste(item) } },
                                onDelete: { Task { await viewModel.delete(item) } },
                                onTogglePin: { Task { await viewModel.togglePin(item) } },
                                onToggleStar: { Task { await viewModel.toggleStar(item) } },
                                highlightQuery: viewModel.query
                            )
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
