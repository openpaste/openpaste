import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showAppPicker = false
    @State private var showFilePicker = false
    @State private var selectedAppId: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { !viewModel.screenSharingAutoHide },
                        set: { viewModel.screenSharingAutoHide = !$0 }
                    )
                ) {
                    Text("Show during screen sharing")
                    Text("Allow OpenPaste to appear to others when you share your screen.")
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $viewModel.urlPreviewEnabled) {
                    Text("Generate link previews")
                    Text(
                        "Download web content for previews; may activate one-time or analytics-sensitive links."
                    )
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

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.blacklistedApps, id: \.bundleId) { app in
                                HStack(spacing: 10) {
                                    appIcon(for: app)
                                    Text(app.name)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    selectedAppId == app.bundleId
                                        ? Color.accentColor
                                        : Color.clear
                                )
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedAppId = app.bundleId
                                }
                            }
                        }
                        .padding(4)
                    }
                }
                .frame(height: 160)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onDeleteCommand {
                    removeSelected()
                }

                ControlGroup {
                    Menu {
                        Button("Running App…") { showAppPicker = true }
                        Button("Browse…") { showFilePicker = true }
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        removeSelected()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedAppId == nil)
                }
                .frame(width: 52)
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.application]
        ) { result in
            if case .success(let url) = result,
                let bundle = Bundle(path: url.path),
                let bundleId = bundle.bundleIdentifier
            {
                let name =
                    bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let app = AppInfo(bundleId: bundleId, name: name, iconPath: nil)
                viewModel.addBlacklistedApp(app)
            }
        }
    }

    private func removeSelected() {
        guard let id = selectedAppId,
            let app = viewModel.blacklistedApps.first(where: { $0.bundleId == id })
        else { return }
        viewModel.removeBlacklistedApp(app)
        selectedAppId = nil
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
