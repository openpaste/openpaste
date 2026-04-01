import SwiftUI
import AppKit

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

                    Button(action: {
                        viewModel.isRecordingHotkey.toggle()
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isRecordingHotkey {
                                Image(systemName: "record.circle")
                                    .foregroundColor(.red)
                                    .symbolEffect(.pulse, isActive: true)
                                Text("Press shortcut…")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Text(viewModel.hotkeyDisplayString)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(viewModel.isRecordingHotkey
                                      ? Color.red.opacity(0.08)
                                      : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.isRecordingHotkey
                                        ? Color.red.opacity(0.3)
                                        : Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .onKeyPress(phases: .down) { keyPress in
                        guard viewModel.isRecordingHotkey else { return .ignored }
                        var nsModifiers: NSEvent.ModifierFlags = []
                        if keyPress.modifiers.contains(.command) { nsModifiers.insert(.command) }
                        if keyPress.modifiers.contains(.shift) { nsModifiers.insert(.shift) }
                        if keyPress.modifiers.contains(.option) { nsModifiers.insert(.option) }
                        if keyPress.modifiers.contains(.control) { nsModifiers.insert(.control) }
                        guard nsModifiers.contains(.command) || nsModifiers.contains(.control) else {
                            return .ignored
                        }
                        viewModel.recordHotkey(modifiers: nsModifiers, characters: keyPress.characters)
                        return .handled
                    }
                }

                if viewModel.hotkeyDisplayString != "⇧⌘V" {
                    Button("Reset to ⇧⌘V") {
                        viewModel.resetHotkey()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }

                Text("Must include ⌘ or ⌃ modifier")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
