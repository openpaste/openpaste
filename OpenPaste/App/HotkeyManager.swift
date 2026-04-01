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
}
