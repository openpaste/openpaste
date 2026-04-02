import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    var pasteStackViewModel: PasteStackViewModel?
    @State private var selectedId: UUID?
    @State private var showQuickEdit = false
    @State private var editingItem: ClipboardItem?
    @State private var showPreview = false
    @State private var pendingG = false
    @State private var showShortcutOverlay = false

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
        .overlay {
            PasteConfirmationOverlay(isShowing: $viewModel.showPasteConfirmation)
        }
        .overlay {
            if showShortcutOverlay {
                KeyboardShortcutOverlay(isShowing: $showShortcutOverlay)
            }
        }
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
        ScrollViewReader { proxy in
            List(selection: $selectedId) {
                // Pinned section
                let pinned = viewModel.items.filter(\.pinned)
                if !pinned.isEmpty {
                    Section {
                        ForEach(pinned) { item in
                            itemRow(for: item)
                        }
                    } header: {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(DS.Typography.sectionHeader)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }

                // Recent section
                Section {
                    ForEach(viewModel.items.filter { !$0.pinned }) { item in
                        itemRow(for: item)
                    }
                } header: {
                    if !pinned.isEmpty {
                        Text("Recent")
                            .font(DS.Typography.sectionHeader)
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task { await viewModel.loadMore() }
                }
            }
            .listStyle(.plain)
            .animation(DS.Animation.springDefault, value: viewModel.items.map(\.id))
            .onAppear {
                if let anchorId = viewModel.scrollAnchorId,
                   viewModel.shouldRestoreScroll,
                   viewModel.items.contains(where: { $0.id == anchorId }) {
                    viewModel.isRestoringScroll = true
                    selectedId = anchorId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(anchorId, anchor: .center)
                        }
                        viewModel.isRestoringScroll = false
                    }
                }
                viewModel.clearScrollState()
            }
            .onDisappear {
                viewModel.recordPanelClose(visibleItemId: selectedId ?? viewModel.items.first?.id)
            }
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
                withAnimation(DS.Animation.springDefault) { showPreview.toggle() }
                return .handled
            }
            // ? = show shortcuts overlay
            .onKeyPress(characters: .init(charactersIn: "?"), phases: .down) { _ in
                withAnimation(DS.Animation.springDefault) { showShortcutOverlay.toggle() }
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
    }

    private func itemRow(for item: ClipboardItem) -> some View {
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
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DS.Colors.accent.opacity(0.6))
                .symbolEffect(.pulse.byLayer, options: .repeating)

            Text("No clipboard history")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Copy something to get started")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("Press")
                Text("⇧⌘V")
                    .font(.system(.callout, design: .monospaced).bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                Text("anytime to open")
            }
            .font(.callout)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                    withAnimation(DS.Animation.springDefault) { isRevealed = hovering }
                }
        } else {
            content
        }
    }
}