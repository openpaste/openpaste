import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: $viewModel.launchAtLogin)
            }

            Section("Clipboard Monitoring") {
                Picker("Polling interval", selection: $viewModel.pollingInterval) {
                    Text("250ms").tag(0.25)
                    Text("500ms").tag(0.5)
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                }

                Picker("Max item size", selection: $viewModel.maxItemSizeMB) {
                    Text("5 MB").tag(5)
                    Text("10 MB").tag(10)
                    Text("25 MB").tag(25)
                    Text("50 MB").tag(50)
                }
            }

            Section {
                Button("Erase History…", role: .destructive) {
                    showClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.onClearAllHistory?() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
