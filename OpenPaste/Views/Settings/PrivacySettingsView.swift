import SwiftUI

struct PrivacySettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section("Sensitive Content") {
                Toggle("Auto-detect sensitive content", isOn: $viewModel.sensitiveDetectionEnabled)

                HStack {
                    Text("Auto-expire after")
                    Spacer()
                    Picker("", selection: $viewModel.sensitiveAutoExpiry) {
                        Text("15 min").tag(900.0)
                        Text("30 min").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                        Text("4 hours").tag(14400.0)
                        Text("Never").tag(0.0)
                    }
                    .frame(width: 120)
                }
            }

            Section("History") {
                Button("Clear All History", role: .destructive) {
                    showClearConfirmation = true
                }
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
        .formStyle(.grouped)
        .padding()
    }
}
