import Foundation
import AppKit

final class HotkeyManager: @unchecked Sendable {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onToggle: @Sendable () -> Void

    init(onToggle: @escaping @Sendable () -> Void) {
        self.onToggle = onToggle
    }

    @MainActor
    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    @MainActor
    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let (modifiers, keyCode) = Self.loadCustomHotkey()
        let eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard eventMods == modifiers, event.keyCode == keyCode else { return }
        onToggle()
    }

    static func loadCustomHotkey() -> (NSEvent.ModifierFlags, UInt16) {
        let savedMods = UserDefaults.standard.integer(forKey: Constants.customHotkeyModifiersKey)
        let savedKey = UserDefaults.standard.integer(forKey: Constants.customHotkeyKeyCodeKey)
        if savedMods != 0 && savedKey != 0 {
            return (NSEvent.ModifierFlags(rawValue: UInt(savedMods)), UInt16(savedKey))
        }
        // Default: ⇧⌘V
        return ([.shift, .command], 0x09)
    }

    static func currentHotkeyDisplayString() -> String {
        let (modifiers, keyCode) = loadCustomHotkey()
        return displayString(modifiers: modifiers, keyCode: keyCode)
    }

    static func displayString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        let keyNames: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0A: "§", 0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E",
            0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2",
            0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0",
            0x1E: "]", 0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I",
            0x23: "P", 0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'",
            0x28: "K", 0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/",
            0x2D: "N", 0x2E: "M", 0x2F: ".",
            0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋",
        ]
        return keyNames[keyCode] ?? "Key\(keyCode)"
    }

    static func mapCharacterToKeyCode(_ chars: String) -> UInt16 {
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

    static func saveHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        UserDefaults.standard.set(Int(modifiers.rawValue), forKey: Constants.customHotkeyModifiersKey)
        UserDefaults.standard.set(Int(keyCode), forKey: Constants.customHotkeyKeyCodeKey)
    }
}
