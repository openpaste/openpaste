import AppKit
import SwiftUI

/// Intercepts keyboard events at the AppKit layer before they reach the first responder.
///
/// # Why this is needed
/// `BottomShelfPanel` uses `[.borderless, .nonactivatingPanel]`. Clicking a card does NOT
/// trigger `makeFirstResponder()` in AppKit — the search TextField stays as first responder
/// indefinitely. SwiftUI's `@FocusState` + `.focusable()` attempts to transfer focus via
/// `makeFirstResponder()`, but this call is unreliable (often silently ignored) in a
/// non-activating panel that was never "activated" by the OS.
///
/// `NSEvent.addLocalMonitorForEvents` fires **before** `sendEvent:` dispatches to the
/// first responder, giving us a chance to intercept Delete / Arrow keys before the
/// TextField consumes them.
struct ShelfKeyboardSink: NSViewRepresentable {
    /// Mirrors SwiftUI's `searchFocused` state — true when user is actively editing search.
    var searchFocused: Bool
    /// True when at least one item is selected (so Delete has a target).
    var hasSelection: Bool

    var onDelete: () -> Void
    var onMoveLeft: () -> Void
    var onMoveRight: () -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.register()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let c = context.coordinator
        c.searchFocused = searchFocused
        c.hasSelection = hasSelection
        c.onDelete = onDelete
        c.onMoveLeft = onMoveLeft
        c.onMoveRight = onMoveRight
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.unregister()
    }

    // MARK: - Coordinator

    final class Coordinator {
        var searchFocused = false
        var hasSelection = false
        var onDelete: (() -> Void)?
        var onMoveLeft: (() -> Void)?
        var onMoveRight: (() -> Void)?

        private var token: Any?

        func register() {
            guard token == nil else { return }
            token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, !self.searchFocused, self.hasSelection else { return event }
                switch event.keyCode {
                case 51, 117:   // Delete / Forward Delete
                    self.onDelete?()
                    return nil  // consumed — TextField never sees it
                case 123:       // Left Arrow
                    self.onMoveLeft?()
                    return nil
                case 124:       // Right Arrow
                    self.onMoveRight?()
                    return nil
                default:
                    return event
                }
            }
        }

        func unregister() {
            if let t = token {
                NSEvent.removeMonitor(t)
                token = nil
            }
        }
    }
}
