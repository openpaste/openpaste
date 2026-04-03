import SwiftUI

struct SyncSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)

                Toggle("Sync sensitive items", isOn: $viewModel.iCloudSyncIncludeSensitive)
                    .disabled(!viewModel.iCloudSyncEnabled)
            }

            Section("Status") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Pending")
                    Spacer()
                    Text("\(viewModel.syncPendingChangesCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Last sync")
                    Spacer()
                    Text(viewModel.syncLastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Sync Now") {
                        Task { await viewModel.syncNow() }
                    }
                    .disabled(!viewModel.iCloudSyncEnabled)

                    Button("Reset Sync Data") {
                        Task { await viewModel.resetSync() }
                    }
                    .disabled(!viewModel.iCloudSyncEnabled)
                }
            }

            Section {
                Text("Clipboard data is encrypted before leaving this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await viewModel.refreshSyncInfo()
        }
    }

    private var statusText: String {
        switch viewModel.syncStatus {
        case .disabled: "Disabled"
        case .idle: "Idle"
        case .syncing: "Syncing"
        case .error(let message): "Error: \(message)"
        case .notPremium: "Premium required"
        }
    }
}
