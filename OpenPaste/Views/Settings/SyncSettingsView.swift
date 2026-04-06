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

                Picker("Max item size to sync", selection: $viewModel.iCloudSyncMaxItemSizeBytes) {
                    Text("Unlimited").tag(0)
                    Text("1 MB").tag(1_048_576)
                    Text("5 MB").tag(5_242_880)
                    Text("10 MB").tag(10_485_760)
                }
                .disabled(!viewModel.iCloudSyncEnabled)
            }

            Section("Status") {
                // C1: First sync indicator
                if isFirstSync {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Initial sync in progress…")
                            .font(.headline)
                        if case .syncing(let progress) = viewModel.syncStatus, let progress {
                            ProgressView(value: progress)
                                .tint(.accentColor)
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
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

                    // B3: Progress bar during sync
                    if case .syncing(let progress) = viewModel.syncStatus, let progress {
                        ProgressView(value: progress)
                            .tint(.accentColor)
                    }
                }

                // C3: Health dashboard
                HStack {
                    Text("Synced")
                    Spacer()
                    Text("\(viewModel.syncSyncedCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Pending")
                    Spacer()
                    Text("\(viewModel.syncPendingChangesCount)")
                        .foregroundStyle(.secondary)
                }

                if viewModel.syncErrorCount > 0 {
                    HStack {
                        Text("Errors")
                        Spacer()
                        Text("\(viewModel.syncErrorCount)")
                            .foregroundStyle(.red)
                    }

                    if let lastErr = viewModel.syncLastError {
                        Text(lastErr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Text("Last sync")
                    Spacer()
                    Text(viewModel.syncLastSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                        .foregroundStyle(.secondary)
                }

                // C4: Device name display
                if !viewModel.syncDeviceName.isEmpty {
                    HStack {
                        Text("This device")
                        Spacer()
                        Text(viewModel.syncDeviceName)
                            .foregroundStyle(.secondary)
                    }
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

    private var isFirstSync: Bool {
        viewModel.iCloudSyncEnabled
            && viewModel.syncLastSyncDate == nil
            && viewModel.isSyncing
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
