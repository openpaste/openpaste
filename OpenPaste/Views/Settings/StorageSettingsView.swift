import SwiftUI

struct StorageSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Database size", value: viewModel.databaseSize)
                LabeledContent("Total items", value: "\(viewModel.totalItemCount)")
            }

            Section("Breakdown") {
                ForEach(ContentType.allCases, id: \.self) { type in
                    let count = viewModel.itemCountByType[type] ?? 0
                    LabeledContent(type.rawValue.capitalized, value: "\(count)")
                }
            }

            Section {
                Button("Optimize Storage…") {
                    Task { await viewModel.optimizeStorage() }
                }
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.loadStorageInfo() }
    }
}
