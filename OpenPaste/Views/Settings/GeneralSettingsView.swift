import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var updaterService: UpdaterServiceProtocol
    @State private var showClearConfirmation = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @AppStorage(Constants.historyRetentionDaysKey) private var retentionDays = 0
    @AppStorage(Constants.pasteDirectlyKey) private var pasteDirectly = true

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                            Text(
                                accessibilityGranted
                                    ? "Global shortcuts and paste are working."
                                    : "Required for global shortcuts and paste to other apps."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if !accessibilityGranted {
                                Text(
                                    "Find OpenPaste in the Accessibility list and toggle it ON."
                                )
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            }
                        }
                    } icon: {
                        Image(
                            systemName: accessibilityGranted
                                ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                    }

                    Spacer()

                    if !accessibilityGranted {
                        Button("Grant Access…") {
                            // Trigger system Accessibility dialog to auto-add app to list
                            Self.triggerAccessibilityPrompt()
                            if let url = URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            ) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                .task {
                    // Poll as fallback
                    while !Task.isCancelled {
                        accessibilityGranted = AXIsProcessTrusted()
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
                .onReceive(
                    DistributedNotificationCenter.default()
                        .publisher(for: Notification.Name("com.apple.accessibility.api"))
                ) { _ in
                    // Slight delay: TCC database may not be updated instantly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        accessibilityGranted = AXIsProcessTrusted()
                    }
                }
            }

            Section("Startup") {
                Toggle("Open at login", isOn: $viewModel.launchAtLogin)

                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updaterService.automaticallyChecksForUpdates },
                        set: { updaterService.automaticallyChecksForUpdates = $0 }
                    ))
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

            Section("Paste Behavior") {
                Toggle(isOn: $pasteDirectly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paste directly to active app")
                        Text(
                            "When enabled, selecting an item pastes it directly into the previously active app. When disabled, items are only copied to the clipboard."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("History") {
                Picker("Keep history for", selection: $retentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                    Text("Forever").tag(0)
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

    /// Posts a harmless CGEvent to trigger the system Accessibility dialog.
    private static func triggerAccessibilityPrompt() {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
