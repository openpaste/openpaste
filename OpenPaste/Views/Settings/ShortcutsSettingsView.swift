import SwiftUI
import AppKit

struct ShortcutsSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Activate OpenPaste")
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

                    Button(action: {
                        viewModel.isRecordingHotkey = false
                        viewModel.resetHotkey()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.isRecordingHotkey {
                Section {
                    Text("Press a key combination with ⌘ or ⌃ modifier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Reset shortcuts to default…") {
                    viewModel.resetHotkey()
                }
            }
        }
        .formStyle(.grouped)
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
}
