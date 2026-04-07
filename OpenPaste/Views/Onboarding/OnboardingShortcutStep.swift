import AppKit
import SwiftUI

struct OnboardingShortcutStep: View {
    let viewModel: OnboardingViewModel
    @State private var bounceKey = false
    @State private var recordingSuspensionToken = UUID()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "command.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

            Text("Set Your Shortcut")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Choose a global shortcut to open OpenPaste from anywhere.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Shortcut display / recorder
            shortcutRecorder

            // Hint
            Text("Must include ⌘ or ⌃ modifier")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var shortcutRecorder: some View {
        VStack(spacing: 12) {
            // Current shortcut display
            Button(action: {
                viewModel.isRecordingHotkey.toggle()
            }) {
                HStack(spacing: 8) {
                    if viewModel.isRecordingHotkey {
                        Image(systemName: "record.circle")
                            .foregroundColor(.red)
                            .symbolEffect(.pulse, isActive: true)
                        Text("Press your shortcut…")
                            .foregroundColor(.secondary)
                    } else {
                        shortcutKeyCaps
                    }
                }
                .frame(minWidth: 220, minHeight: 50)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            viewModel.isRecordingHotkey
                                ? Color.red.opacity(0.08)
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.isRecordingHotkey ? Color.red.opacity(0.3) : Color.clear,
                            lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .focusable()
            .onChange(of: viewModel.isRecordingHotkey, initial: true) { _, isRecording in
                HotkeyManager.setHotkeyRecordingSuspended(
                    isRecording, token: recordingSuspensionToken)
            }
            .onDisappear {
                HotkeyManager.setHotkeyRecordingSuspended(false, token: recordingSuspensionToken)
            }
            .onKeyPress(phases: .down) { keyPress in
                guard viewModel.isRecordingHotkey else { return .ignored }
                // Convert KeyPress to NSEvent-like data
                let mods = keyPress.modifiers
                var nsModifiers: NSEvent.ModifierFlags = []
                if mods.contains(.command) { nsModifiers.insert(.command) }
                if mods.contains(.shift) { nsModifiers.insert(.shift) }
                if mods.contains(.option) { nsModifiers.insert(.option) }
                if mods.contains(.control) { nsModifiers.insert(.control) }

                // Only accept if has command or control
                guard nsModifiers.contains(.command) || nsModifiers.contains(.control) else {
                    return .ignored
                }

                // Map character to key code
                let keyCode = HotkeyManager.mapCharacterToKeyCode(keyPress.characters)
                guard keyCode != 0xFF else { return .ignored }

                viewModel.hotkeyKeyCode = keyCode
                viewModel.hotkeyModifiers = nsModifiers
                viewModel.hotkeyDisplayString = HotkeyManager.displayString(
                    modifiers: nsModifiers, keyCode: keyCode)
                viewModel.isRecordingHotkey = false
                return .handled
            }

            // Reset to default button
            if viewModel.hotkeyDisplayString != "⇧⌘V" {
                Button("Reset to ⇧⌘V") {
                    viewModel.hotkeyKeyCode = 0x09
                    viewModel.hotkeyModifiers = [.shift, .command]
                    viewModel.hotkeyDisplayString = "⇧⌘V"
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
    }

    private var shortcutKeyCaps: some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.hotkeyDisplayString.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .frame(minWidth: 32, minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .tertiarySystemFill))
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    )
                    .scaleEffect(bounceKey ? 1.1 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.3)) {
                bounceKey = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    bounceKey = false
                }
            }
        }
    }
}

