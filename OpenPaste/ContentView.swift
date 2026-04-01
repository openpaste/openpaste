import SwiftUI

struct ContentView: View {
    let historyViewModel: HistoryViewModel
    let searchViewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchView(viewModel: searchViewModel)

            Divider()

            if searchViewModel.query.isEmpty && searchViewModel.filters == .empty {
                HistoryView(viewModel: historyViewModel)
            }
        }
        .frame(width: 400, height: 560)
    }
}
