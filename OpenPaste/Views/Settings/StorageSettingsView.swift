import SwiftUI

struct StorageSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showOptimizeConfirm = false

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
                HStack {
                    Button("Optimize Storage…") {
                        showOptimizeConfirm = true
                    }
                    .disabled(viewModel.isOptimizing)
                    .help(
                        "Permanently removes deleted items and compacts the database to reclaim disk space."
                    )

                    if viewModel.isOptimizing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(
                    "Removes expired and soft-deleted items, then compacts the database file to free disk space."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let result = viewModel.optimizeResult {
                    optimizeResultView(result)
                }
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.loadStorageInfo() }
        .alert("Optimize Storage?", isPresented: $showOptimizeConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Optimize") {
                Task { await viewModel.optimizeStorage() }
            }
        } message: {
            Text(
                "This will permanently remove deleted items and compact the database. It may take a few seconds."
            )
        }
    }

    @ViewBuilder
    private func optimizeResultView(_ result: SettingsViewModel.OptimizeResult) -> some View {
        switch result {
        case .success(let savedBytes):
            let formatter = ByteCountFormatter()
            let saved = formatter.string(fromByteCount: savedBytes)
            Label("Freed \(saved)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}
