import AppKit
import SwiftUI

/// Monitors `flagsChanged` events to detect when the ⌘ (Command) key is pressed or released.
///
/// Used by `BottomShelfView` to reveal all `⌘1-9` quick-paste badges simultaneously,
/// giving the user a clear visual map of available shortcuts.
struct CommandKeyMonitor: NSViewRepresentable {
    @Binding var isCommandPressed: Bool

    func makeNSView(context: Context) -> NSView {
        context.coordinator.register()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.binding = $isCommandPressed
    }

    func makeCoordinator() -> Coordinator { Coordinator(binding: $isCommandPressed) }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.unregister()
    }

    // MARK: - Coordinator

    final class Coordinator {
        var binding: Binding<Bool>
        private var token: Any?

        init(binding: Binding<Bool>) {
            self.binding = binding
        }

        func register() {
            guard token == nil else { return }
            token = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                guard let self else { return event }
                let pressed = event.modifierFlags.contains(.command)
                if self.binding.wrappedValue != pressed {
                    self.binding.wrappedValue = pressed
                }
                return event  // pass through — don't swallow modifier events
            }
        }

        func unregister() {
            if let t = token {
                NSEvent.removeMonitor(t)
                token = nil
            }
            // Avoid mutating SwiftUI state during representable teardown.
            // The owning view is already being dismantled, and writing through the
            // binding here can trip Swift exclusivity checks while GraphHost
            // invalidates the view tree.
        }
    }
}
