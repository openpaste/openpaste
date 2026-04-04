import SwiftUI

struct SyncSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("Optional premium beta feature path — still maturing. OpenPaste remains local-first by default.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)

                Toggle("Sync sensitive items", isOn: $viewModel.iCloudSyncIncludeSensitive)
                    .disabled(!viewModel.iCloudSyncEnabled)
            }

            Section("Status") {
                HStack {
                    Text("Status")
                    Spacer()
                    if viewModel.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
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
                    Text("Synced")
                    Spacer()
                    Text("\(viewModel.syncSyncedCount)")
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
                    .disabled(!viewModel.iCloudSyncEnabled || viewModel.isSyncing)

                    Button("Reset Sync Data") {
                        Task { await viewModel.resetSync() }
                    }
                    .disabled(!viewModel.iCloudSyncEnabled || viewModel.isSyncing)
                }
            }

            Section {
                Text("Current builds may still show Premium required while sync is being hardened for broader rollout.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            if viewModel.iCloudSyncEnabled {
                await viewModel.syncService?.start()
            }
            await viewModel.refreshSyncInfo()
        }
    }

    private var statusText: String {
        switch viewModel.syncStatus {
        case .disabled: "Disabled"
        case .idle: "Idle"
        case .syncing: "Syncing…"
        case .error(let message): "Error: \(message)"
        case .notPremium: "Premium required"
        }
    }
}
