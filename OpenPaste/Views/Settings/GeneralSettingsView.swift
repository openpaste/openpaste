import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Clipboard Monitoring") {
                HStack {
                    Text("Polling interval")
                    Spacer()
                    Picker("", selection: $viewModel.pollingInterval) {
                        Text("250ms").tag(0.25)
                        Text("500ms").tag(0.5)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                    }
                    .frame(width: 120)
                }

                HStack {
                    Text("Max item size")
                    Spacer()
                    Picker("", selection: $viewModel.maxItemSizeMB) {
                        Text("5 MB").tag(5)
                        Text("10 MB").tag(10)
                        Text("25 MB").tag(25)
                        Text("50 MB").tag(50)
                    }
                    .frame(width: 120)
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
            }

            Section("Keyboard Shortcut") {
                HStack {
                    Text("Open clipboard")
                    Spacer()
                    Text("⇧⌘V")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
