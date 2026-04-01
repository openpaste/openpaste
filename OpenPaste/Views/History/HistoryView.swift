import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    var pasteStackViewModel: PasteStackViewModel?
    @State private var selectedId: UUID?
    @State private var showQuickEdit = false
    @State private var editingItem: ClipboardItem?
    @State private var showPreview = false
    @State private var pendingG = false

    var body: some View {
        Group {
            if viewModel.items.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                if showPreview, let item = selectedItem {
                    HSplitView {
                        itemsList
                        previewPanel(for: item)
                    }
                } else {
                    itemsList
                }
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

    private var selectedItem: ClipboardItem? {
        guard let id = selectedId else { return viewModel.items.first }
        return viewModel.items.first(where: { $0.id == id })
    }

    // MARK: - Preview Panel

    private func previewPanel(for item: ClipboardItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation { showPreview = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Full content preview (with sensitive content protection)
                    Group {
                        switch item.type {
                        case .text, .code, .richText:
                            if item.type == .code {
                                SyntaxHighlightedCode(code: item.plainTextContent ?? "", maxLines: 50)
                                    .padding(8)
                            } else {
                                Text(item.plainTextContent ?? "")
                                    .font(.system(.body, design: .default))
                                    .textSelection(.enabled)
                                    .padding(8)
                            }
                        case .image:
                            if let nsImage = NSImage(data: item.content) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding(8)
                            }
                        case .link:
                            LinkPreviewRow(urlString: item.plainTextContent ?? "", isSensitive: item.isSensitive)
                                .padding(8)
                        case .file, .color:
                            ContentPreviewView(item: item)
                                .padding(8)
                        }
                    }
                    .modifier(SensitiveBlurModifier(isSensitive: item.isSensitive))

                    // Metadata section
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        metadataRow("Type", value: item.type.rawValue.capitalized)
                        metadataRow("Source", value: item.sourceApp.name)
                        metadataRow("Created", value: item.createdAt.relativeFormatted)
                        metadataRow("Size", value: item.content.humanReadableSize)
                        if !item.tags.isEmpty {
                            metadataRow("Tags", value: item.tags.joined(separator: ", "))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(.ultraThinMaterial)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Items List with Vim Keys

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
        .focusable()
        // Enter to paste
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        // Escape to dismiss
        .onKeyPress(.escape) {
            viewModel.dismissAction?()
            return .handled
        }
        // Tab to toggle preview
        .onKeyPress(.tab) {
            withAnimation(.easeInOut(duration: 0.2)) { showPreview.toggle() }
            return .handled
        }
        // j = move down
        .onKeyPress(characters: .init(charactersIn: "j"), phases: .down) { _ in
            moveSelection(by: 1)
            return .handled
        }
        // k = move up
        .onKeyPress(characters: .init(charactersIn: "k"), phases: .down) { _ in
            moveSelection(by: -1)
            return .handled
        }
        // G (shift+g) = go to bottom
        .onKeyPress(characters: .init(charactersIn: "G"), phases: .down) { _ in
            selectedId = viewModel.items.last?.id
            return .handled
        }
        // g = first tap starts timer, second tap within 400ms goes to top
        .onKeyPress(characters: .init(charactersIn: "g"), phases: .down) { _ in
            if pendingG {
                selectedId = viewModel.items.first?.id
                pendingG = false
            } else {
                pendingG = true
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    pendingG = false
                }
            }
            return .handled
        }
    }

    // MARK: - Selection Helpers

    private func moveSelection(by offset: Int) {
        guard !viewModel.items.isEmpty else { return }
        guard let current = selectedId,
              let idx = viewModel.items.firstIndex(where: { $0.id == current }) else {
            selectedId = viewModel.items.first?.id
            return
        }
        let newIdx = min(max(idx + offset, 0), viewModel.items.count - 1)
        selectedId = viewModel.items[newIdx].id
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

/// Applies blur + hover-to-reveal for sensitive content in preview panel
private struct SensitiveBlurModifier: ViewModifier {
    let isSensitive: Bool
    @State private var isRevealed = false

    func body(content: Content) -> some View {
        if isSensitive && !isRevealed {
            content
                .blur(radius: 8)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                        Text("Sensitive — hover to reveal")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) { isRevealed = hovering }
                }
        } else {
            content
        }
    }
}