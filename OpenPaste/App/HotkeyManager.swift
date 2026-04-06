import AppKit
import CoreGraphics
import Foundation

final class HotkeyManager: @unchecked Sendable {
    private static let accessibilityNotification = Notification.Name("com.apple.accessibility.api")
    private static var hotkeyRecordingSuspensionTokens = Set<UUID>()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityObserver: NSObjectProtocol?
    private let onToggle: @Sendable () -> Void

    init(onToggle: @escaping @Sendable () -> Void) {
        self.onToggle = onToggle
    }

    @MainActor
    func register() {
        observeAccessibilityChangesIfNeeded()
        installEventTapIfPossible()
    }

    @MainActor
    func unregister() {
        if let accessibilityObserver {
            DistributedNotificationCenter.default().removeObserver(accessibilityObserver)
            self.accessibilityObserver = nil
        }
        removeEventTap()
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let (modifiers, keyCode) = Self.loadCustomHotkey()
        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        guard
            Self.shouldInterceptHotkey(
                modifiers: modifiers,
                keyCode: keyCode,
                eventFlags: event.flags,
                eventKeyCode: eventKeyCode,
                isAutoRepeat: isAutoRepeat
            )
        else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async { [weak self] in
            self?.onToggle()
        }
        return nil
    }

    @MainActor
    private func observeAccessibilityChangesIfNeeded() {
        guard accessibilityObserver == nil else { return }

        accessibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.accessibilityNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAccessibilityStatusChange()
            }
        }
    }

    @MainActor
    private func handleAccessibilityStatusChange() {
        if AXIsProcessTrusted() {
            installEventTapIfPossible()
        } else {
            removeEventTap()
        }
    }

    @MainActor
    private func installEventTapIfPossible() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon else {
                        return Unmanaged.passUnretained(event)
                    }

                    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    return manager.handleEventTap(type: type, event: event)
                },
                userInfo: refcon
            )
        else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    @MainActor
    private func removeEventTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
    }

    static func loadCustomHotkey() -> (NSEvent.ModifierFlags, UInt16) {
        let defaults = UserDefaults.standard
        if let savedMods = defaults.object(forKey: Constants.customHotkeyModifiersKey) as? Int,
            let savedKey = defaults.object(forKey: Constants.customHotkeyKeyCodeKey) as? Int
        {
            return (
                normalizedModifierFlags(NSEvent.ModifierFlags(rawValue: UInt(savedMods))),
                UInt16(savedKey)
            )
        }
        // Default: ⇧⌘V
        return ([.shift, .command], 0x09)
    }

    static func hotkeyMatches(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        eventFlags: CGEventFlags,
        eventKeyCode: UInt16,
        isAutoRepeat: Bool = false
    ) -> Bool {
        guard !isAutoRepeat else { return false }
        return normalizedModifierFlags(modifiers) == modifierFlags(from: eventFlags)
            && eventKeyCode == keyCode
    }

    static func shouldInterceptHotkey(
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        eventFlags: CGEventFlags,
        eventKeyCode: UInt16,
        isAutoRepeat: Bool = false
    ) -> Bool {
        guard hotkeyRecordingSuspensionTokens.isEmpty else { return false }
        return hotkeyMatches(
            modifiers: modifiers,
            keyCode: keyCode,
            eventFlags: eventFlags,
            eventKeyCode: eventKeyCode,
            isAutoRepeat: isAutoRepeat
        )
    }

    static func setHotkeyRecordingSuspended(_ isSuspended: Bool, token: UUID) {
        if isSuspended {
            hotkeyRecordingSuspensionTokens.insert(token)
        } else {
            hotkeyRecordingSuspensionTokens.remove(token)
        }
    }

    static func currentHotkeyDisplayString() -> String {
        let (modifiers, keyCode) = loadCustomHotkey()
        return displayString(modifiers: modifiers, keyCode: keyCode)
    }

    static func displayString(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        let normalizedModifiers = normalizedModifierFlags(modifiers)
        var parts: [String] = []
        if normalizedModifiers.contains(.control) { parts.append("⌃") }
        if normalizedModifiers.contains(.option) { parts.append("⌥") }
        if normalizedModifiers.contains(.shift) { parts.append("⇧") }
        if normalizedModifiers.contains(.command) { parts.append("⌘") }
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
        let normalizedModifiers = normalizedModifierFlags(modifiers)
        UserDefaults.standard.set(
            Int(normalizedModifiers.rawValue), forKey: Constants.customHotkeyModifiersKey)
        UserDefaults.standard.set(Int(keyCode), forKey: Constants.customHotkeyKeyCodeKey)
    }

    private static func normalizedModifierFlags(_ modifiers: NSEvent.ModifierFlags)
        -> NSEvent.ModifierFlags
    {
        modifiers.intersection([.control, .option, .shift, .command])
    }

    private static func modifierFlags(from eventFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if eventFlags.contains(.maskControl) { flags.insert(.control) }
        if eventFlags.contains(.maskAlternate) { flags.insert(.option) }
        if eventFlags.contains(.maskShift) { flags.insert(.shift) }
        if eventFlags.contains(.maskCommand) { flags.insert(.command) }
        return flags
    }
}
