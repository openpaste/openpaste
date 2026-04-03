import SwiftUI

struct BottomShelfView: View {
    @Bindable var historyViewModel: HistoryViewModel
    @Bindable var searchViewModel: SearchViewModel
    var pasteStackViewModel: PasteStackViewModel?
    var collectionViewModel: CollectionViewModel?

    @State var selectedId: UUID?
    @State var selectedCollectionId: UUID?
    @State var showPreview = false
    @State private var showNewCollectionSheet = false
    @State private var newCollectionName = ""
    @FocusState var searchFocused: Bool

    @AppStorage(Constants.showShortcutHintsKey) private var showShortcutHints = true

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.5)
            mainContent

            if showShortcutHints {
                Divider().opacity(0.5)
                ShortcutHintBar()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // Background blur handled natively by NSVisualEffectView at panel level
        .overlay(alignment: .bottom) {
            if let pvm = pasteStackViewModel {
                PasteStackOverlay(viewModel: pvm)
                    .padding(.bottom, showShortcutHints ? DS.Shelf.hintBarHeight : 0)
            }
        }
        .focusable()
        .onKeyPress(phases: .down) { handleKeyPress($0) }
        .onKeyPress(.tab) {
            togglePreview()
            return .handled
        }
        .onKeyPress(.escape) {
            historyViewModel.dismissAction?()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard !searchFocused else { return .ignored }
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !searchFocused else { return .ignored }
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.delete) {
            guard !searchFocused else { return .ignored }
            deleteSelected()
            return .handled
        }
        .onKeyPress(.deleteForward) {
            guard !searchFocused else { return .ignored }
            deleteSelected()
            return .handled
        }
        .onAppear {
            selectedId = displayItems.first?.id
            selectedCollectionId = searchViewModel.filters.collectionId
        }
        .task { await historyViewModel.loadInitial() }
        .task { await historyViewModel.observeEvents() }
        .sheet(isPresented: $showNewCollectionSheet) {
            newCollectionSheet
        }
    }

    // MARK: - Top Bar (Paste-style: search left, tabs center, + right)

    private var topBar: some View {
        HStack(spacing: DS.Spacing.md) {
            // Search field (left)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search…", text: $searchViewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                    .onChange(of: searchViewModel.query) { _, _ in
                        searchViewModel.searchDebounced()
                    }
                if !searchViewModel.query.isEmpty {
                    Button {
                        searchViewModel.query = ""
                        searchViewModel.searchDebounced()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .separatorColor).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .frame(maxWidth: 240)

            // Tab bar (fills center)
            PinboardTabBar(
                collectionViewModel: collectionViewModel,
                selectedCollectionId: $selectedCollectionId,
                onAddCollection: {
                    newCollectionName = ""
                    showNewCollectionSheet = true
                }
            )

            Spacer()
        }
        .padding(.horizontal, DS.Shelf.horizontalPadding)
        .padding(.vertical, 8)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: selectedCollectionId) { _, newValue in
            applyCollectionFilter(newValue)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            if showPreview, let item = selectedItem {
                HSplitView {
                    cardGrid
                    BottomShelfPreviewPanel(item: item) {
                        withAnimation(DS.Animation.springDefault) {
                            showPreview = false
                        }
                    }
                }
            } else {
                cardGrid
            }
        }
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Card.spacing) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                        ClipboardCard(
                            item: item,
                            isSelected: selectedId == item.id,
                            index: idx,
                            onPaste: {
                                selectedId = item.id
                                Task { await activePaste(item) }
                            },
                            onSelect: {
                                selectedId = item.id
                            },
                            onDelete: {
                                selectedId = item.id
                                Task { await activeDelete(item) }
                            },
                            onTogglePin: {
                                selectedId = item.id
                                Task { await activeTogglePin(item) }
                            },
                            onToggleStar: {
                                selectedId = item.id
                                Task { await activeToggleStar(item) }
                            }
                        )
                        .id(item.id)
                    }

                    if shouldShowLoadingMore {
                        ProgressView()
                            .frame(width: DS.Card.width, height: DS.Card.height)
                            .task { await historyViewModel.loadMore() }
                    }
                }
                .padding(.horizontal, DS.Shelf.horizontalPadding)
                .padding(.vertical, DS.Spacing.lg)
            }
            .onChange(of: selectedId) { _, newId in
                guard let newId else { return }
                withAnimation(DS.Animation.springDefault) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    // MARK: - New Collection Sheet

    private var newCollectionSheet: some View {
        VStack(spacing: 16) {
            Text("New Pinboard")
                .font(.headline)

            TextField("Name", text: $newCollectionName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showNewCollectionSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    guard !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await collectionViewModel?.createCollection(name: newCollectionName)
                        showNewCollectionSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
