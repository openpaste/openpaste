import SwiftUI
import AppKit

struct PrivacySettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showAppPicker = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { !viewModel.screenSharingAutoHide },
                    set: { viewModel.screenSharingAutoHide = !$0 }
                )) {
                    Text("Show during screen sharing")
                    Text("Allow OpenPaste to appear to others when you share your screen.")
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $viewModel.urlPreviewEnabled) {
                    Text("Generate link previews")
                    Text("Download web content for previews; may activate one-time or analytics-sensitive links.")
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $viewModel.sensitiveDetectionEnabled) {
                    Text("Ignore confidential content")
                    Text("Do not save passwords and sensitive data when detected.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Auto-expire sensitive items", selection: $viewModel.sensitiveAutoExpiry) {
                    Text("15 min").tag(900.0)
                    Text("30 min").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                    Text("4 hours").tag(14400.0)
                    Text("Never").tag(0.0)
                }
            }

            Section("Ignore Applications") {
                Text("Do not save content copied from the applications below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(viewModel.blacklistedApps, id: \.bundleId) { app in
                        HStack(spacing: 10) {
                            appIcon(for: app)
                            Text(app.name)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.removeBlacklistedApp(viewModel.blacklistedApps[index])
                        }
                    }
                }
                .frame(height: 80)

                HStack {
                    Button {
                        showAppPicker = true
                    } label: {
                        Label("Add App…", systemImage: "plus")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAppPicker) {
            RunningAppPickerView(
                onSelect: { app in
                    viewModel.addBlacklistedApp(app)
                    showAppPicker = false
                },
                onCancel: { showAppPicker = false }
            )
        }
    }

    private func appIcon(for app: AppInfo) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: app.bundleId
            ) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
    }
}
