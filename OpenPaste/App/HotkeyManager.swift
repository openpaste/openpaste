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
        // ⇧⌘V (Shift+Command+V)
        guard event.modifierFlags.contains([.shift, .command]),
              event.keyCode == 0x09 else { return } // V key
        onToggle()
    }
}
