import SwiftUI

struct BottomShelfView: View {
    @Bindable var historyViewModel: HistoryViewModel
    @Bindable var searchViewModel: SearchViewModel
    var pasteStackViewModel: PasteStackViewModel?
    var collectionViewModel: CollectionViewModel?

    @State var selectedId: UUID?
    @State var selectedCollectionId: UUID?
    @State var showPreview = false
    @FocusState var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            mainContent
            Divider()
            ShortcutHintBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background blur handled natively by NSVisualEffectView at panel level
        .overlay(alignment: .bottom) {
            if let pvm = pasteStackViewModel {
                PasteStackOverlay(viewModel: pvm)
                    .padding(.bottom, DS.Shelf.hintBarHeight)
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
        .onAppear {
            selectedId = displayItems.first?.id
            selectedCollectionId = searchViewModel.filters.collectionId
        }
        .task { await historyViewModel.loadInitial() }
        .task { await historyViewModel.observeEvents() }
    }

    private var topBar: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search…", text: $searchViewModel.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onChange(of: searchViewModel.query) { _, _ in
                        searchViewModel.searchDebounced()
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .frame(maxWidth: 260)

            PinboardTabBar(
                collectionViewModel: collectionViewModel,
                selectedCollectionId: $selectedCollectionId
            )
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, DS.Shelf.horizontalPadding)
        .padding(.vertical, 6)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: selectedCollectionId) { _, newValue in
            applyCollectionFilter(newValue)
        }
    }

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

}
