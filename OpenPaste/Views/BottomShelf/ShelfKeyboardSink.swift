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
    /// Suspends global key interception while a child sheet/dialog owns keyboard input.
    var isSuspended: Bool
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
        c.isSuspended = isSuspended
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
        var isSuspended = false
        var hasSelection = false
        var onDelete: (() -> Void)?
        var onMoveLeft: (() -> Void)?
        var onMoveRight: (() -> Void)?

        private var token: Any?

        func register() {
            guard token == nil else { return }
            token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.shouldInterceptKeyEvent else { return event }
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

        private var shouldInterceptKeyEvent: Bool {
            guard !isSuspended, !searchFocused, hasSelection else { return false }

            guard let keyWindow = NSApp.keyWindow else { return false }
            if keyWindow.isSheet || keyWindow.sheetParent != nil || keyWindow.attachedSheet != nil {
                return false
            }

            if let textResponder = keyWindow.firstResponder as? NSTextView,
               textResponder.isEditable || textResponder.isSelectable {
                return false
            }

            return true
        }

        func unregister() {
            if let t = token {
                NSEvent.removeMonitor(t)
                token = nil
            }
        }
    }
}
