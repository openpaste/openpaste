import SwiftUI

struct ContentView: View {
    let historyViewModel: HistoryViewModel
    let searchViewModel: SearchViewModel
    var pasteStackViewModel: PasteStackViewModel?
    var collectionViewModel: CollectionViewModel?

    @State private var selectedTab: Tab = .history
    @State private var appeared = false

    enum Tab { case history, collections }

    var body: some View {
        VStack(spacing: 0) {
            SearchView(viewModel: searchViewModel)

            Divider()

            if searchViewModel.query.isEmpty && searchViewModel.filters == .empty {
                tabPicker
                Divider()

                switch selectedTab {
                case .history:
                    HistoryView(
                        viewModel: historyViewModel,
                        pasteStackViewModel: pasteStackViewModel
                    )
                case .collections:
                    if let cvm = collectionViewModel {
                        CollectionListView(viewModel: cvm)
                    }
                }
            }

            if let pvm = pasteStackViewModel {
                PasteStackOverlay(viewModel: pvm)
            }
        }
        .frame(minWidth: 350, idealWidth: 400, maxWidth: 700,
               minHeight: 400, idealHeight: 560, maxHeight: 900)
        .background(.ultraThinMaterial)
        .scaleEffect(appeared ? 1.0 : 0.96)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(DS.Animation.springDefault) {
                appeared = true
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("History").tag(Tab.history)
            Text("Collections").tag(Tab.collections)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
