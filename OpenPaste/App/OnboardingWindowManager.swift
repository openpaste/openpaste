import AppKit
import SwiftUI

final class OnboardingWindowManager {
    private var window: NSWindow?

    @MainActor
    func show(onComplete: @escaping () -> Void) {
        guard window == nil else { return }

        let onboardingView = OnboardingView(onComplete: { [weak self] in
            self?.close()
            onComplete()
        })

        let hostingView = NSHostingView(rootView: onboardingView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 500)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = .controlBackgroundColor
        win.isMovableByWindowBackground = true
        win.center()
        win.contentView = hostingView
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.title = "Welcome to OpenPaste"

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = win

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            // If user closes window via X button, mark as completed
            UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
            onComplete()
        }
    }

    func close() {
        window?.close()
        window = nil
    }
}
