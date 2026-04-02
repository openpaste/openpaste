import Foundation
import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow
        minSize = NSSize(width: 350, height: 400)
        maxSize = NSSize(width: 700, height: 900)
        self.contentView = contentView
    }

    override func resignKey() {
        super.resignKey()
        // Don't close when a child sheet/dialog (e.g. "New Collection") takes key focus
        if let keyWindow = NSApp.keyWindow, keyWindow.isSheet || keyWindow.sheetParent === self {
            return
        }
        // Don't close if one of our own sheets is being presented
        if !sheets.isEmpty {
            return
        }
        close()
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@Observable
final class WindowManager {
    private var panel: FloatingPanel?
    private var closeObserver: NSObjectProtocol?
    var isVisible: Bool = false
    /// App đang active trước khi panel hiện lên
    private(set) var previousApp: NSRunningApplication?

    func toggle<Content: View>(content: @escaping () -> Content) {
        if isVisible {
            hide()
        } else {
            show(content: content)
        }
    }

    func show<Content: View>(content: @escaping () -> Content) {
        if let obs = closeObserver {
            NotificationCenter.default.removeObserver(obs)
        }

        previousApp = NSWorkspace.shared.frontmostApplication

        let hostingView = NSHostingView(rootView: content())
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)

        let newPanel = FloatingPanel(contentView: hostingView)

        // Position based on user preference
        let mode = UserDefaults.standard.string(forKey: Constants.windowPositionModeKey) ?? "center"
        if mode == "cursor" {
            positionNearCursor(newPanel)
        } else {
            newPanel.center()
        }

        newPanel.makeKeyAndOrderFront(nil)

        panel = newPanel
        isVisible = true

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            self?.isVisible = false
            self?.panel = nil
        }
    }

    func hide() {
        panel?.close()
        panel = nil
        isVisible = false
    }

    /// Trả focus về app trước đó
    func reactivatePreviousApp() {
        previousApp?.activate()
    }

    private func positionNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            panel.center()
            return
        }
        var origin = mouseLocation
        origin.x -= panel.frame.width / 2
        origin.y -= panel.frame.height / 2

        let screenFrame = screen.visibleFrame
        origin.x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - panel.frame.width))
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - panel.frame.height))

        panel.setFrameOrigin(origin)
    }
}
