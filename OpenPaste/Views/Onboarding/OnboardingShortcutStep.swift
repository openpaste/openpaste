import SwiftUI
import AppKit

struct OnboardingShortcutStep: View {
    let viewModel: OnboardingViewModel
    @State private var bounceKey = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "command.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
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
                        .fill(viewModel.isRecordingHotkey
                              ? Color.red.opacity(0.08)
                              : Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.isRecordingHotkey ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .focusable()
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
                let keyCode = mapCharacterToKeyCode(keyPress.characters)
                guard keyCode != 0xFF else { return .ignored }

                viewModel.hotkeyKeyCode = keyCode
                viewModel.hotkeyModifiers = nsModifiers
                // Build display string
                var parts: [String] = []
                if nsModifiers.contains(.control) { parts.append("⌃") }
                if nsModifiers.contains(.option) { parts.append("⌥") }
                if nsModifiers.contains(.shift) { parts.append("⇧") }
                if nsModifiers.contains(.command) { parts.append("⌘") }
                parts.append(keyPress.characters.uppercased())
                viewModel.hotkeyDisplayString = parts.joined()
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

    private func mapCharacterToKeyCode(_ chars: String) -> UInt16 {
        let map: [String: UInt16] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
            "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
            "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
            "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19, "7": 0x1A,
            "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22,
            "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
            "m": 0x2E, " ": 0x31,
        ]
        return map[chars.lowercased()] ?? 0xFF
    }
}
