import SwiftUI

struct BlacklistView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard capture is disabled for these apps:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List {
                ForEach(viewModel.blacklistedApps, id: \.bundleId) { app in
                    HStack {
                        Image(systemName: "app")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(app.name)
                                .font(.body)
                            Text(app.bundleId)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            viewModel.removeBlacklistedApp(app)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("Add Running App…") {
                    showAppPicker = true
                }
                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $showAppPicker) {
            RunningAppPickerView(onSelect: { app in
                viewModel.addBlacklistedApp(app)
                showAppPicker = false
            }, onCancel: {
                showAppPicker = false
            })
        }
    }
}

struct RunningAppPickerView: View {
    let onSelect: (AppInfo) -> Void
    let onCancel: () -> Void

    @State private var runningApps: [AppInfo] = []

    var body: some View {
        VStack {
            Text("Select App to Blacklist")
                .font(.headline)
                .padding(.top)

            List(runningApps, id: \.bundleId) { app in
                Button {
                    onSelect(app)
                } label: {
                    HStack {
                        Image(systemName: "app")
                        Text(app.name)
                        Spacer()
                        Text(app.bundleId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 400, height: 300)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
            }
            .padding()
        }
        .onAppear { loadRunningApps() }
    }

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        runningApps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier else { return nil }
                return AppInfo(
                    bundleId: bundleId,
                    name: app.localizedName ?? bundleId,
                    iconPath: nil
                )
            }
            .sorted { $0.name < $1.name }
    }
}
