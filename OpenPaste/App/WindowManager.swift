import Foundation
import AppKit
import SwiftUI
import QuartzCore

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

final class BottomShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    var onRequestClose: (() -> Void)?

    init(contentView: NSView, frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow

        minSize = NSSize(width: 350, height: DS.Shelf.minHeight)
        maxSize = NSSize(width: frame.width, height: DS.Shelf.maxHeight)

        // Native AppKit blur — single GPU pass, much faster than SwiftUI .ultraThinMaterial
        let blurView = NSVisualEffectView()
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = DS.Radius.lg
        blurView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        blurView.layer?.masksToBounds = true
        blurView.autoresizingMask = [.width, .height]

        contentView.translatesAutoresizingMaskIntoConstraints = true
        contentView.autoresizingMask = [.width, .height]
        contentView.frame = blurView.bounds
        blurView.addSubview(contentView)

        self.contentView = blurView
    }

    override func resignKey() {
        super.resignKey()
        // Don't close when a child sheet/dialog takes key focus
        if let keyWindow = NSApp.keyWindow, keyWindow.isSheet || keyWindow.sheetParent === self {
            return
        }
        // Don't close if one of our own sheets is being presented
        if !sheets.isEmpty {
            return
        }
        onRequestClose?()
    }

    override func cancelOperation(_ sender: Any?) {
        onRequestClose?()
    }
}

@Observable
final class WindowManager {
    private var panel: NSPanel?
    private var closeObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    var isVisible: Bool = false
    /// App đang active trước khi panel hiện lên
    private(set) var previousApp: NSRunningApplication?

    func toggle<Content: View>(content: @escaping () -> Content) {
        if isVisible {
            hide()
            return
        }

        let mode = UserDefaults.standard.string(forKey: Constants.windowPositionModeKey)
            ?? Constants.windowPositionModeBottomShelf

        if mode == Constants.windowPositionModeBottomShelf {
            showBottomShelf(content: content)
        } else {
            showFloating(content: content)
        }
    }

    func showFloating<Content: View>(content: @escaping () -> Content) {
        if let obs = closeObserver {
            NotificationCenter.default.removeObserver(obs)
        }

        previousApp = NSWorkspace.shared.frontmostApplication

        let hostingView = NSHostingView(rootView: content())
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 600)

        let newPanel = FloatingPanel(contentView: hostingView)

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

    func showBottomShelf<Content: View>(content: @escaping () -> Content) {
        if let obs = closeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = screenObserver {
            NotificationCenter.default.removeObserver(obs)
        }

        previousApp = NSWorkspace.shared.frontmostApplication

        guard let screen = screenForMouse() ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let shelfHeight = DS.Shelf.defaultHeight
        let frame = NSRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: shelfHeight)

        let hostingView = NSHostingView(rootView: content())
        // Prevent Auto Layout conflicts — let the panel drive sizing
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)

        let newPanel = BottomShelfPanel(contentView: hostingView, frame: frame)
        newPanel.onRequestClose = { [weak self] in
            self?.hide()
        }

        // Start below screen → animate up
        newPanel.setFrameOrigin(NSPoint(x: visibleFrame.minX, y: visibleFrame.minY - shelfHeight))
        newPanel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newPanel.animator().setFrameOrigin(NSPoint(x: visibleFrame.minX, y: visibleFrame.minY))
        }

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

        // Re-position when Dock or screen config changes
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.repositionBottomShelf()
        }
    }

    func hide() {
        guard let currentPanel = panel else {
            isVisible = false
            return
        }

        if let obs = screenObserver {
            NotificationCenter.default.removeObserver(obs)
            screenObserver = nil
        }

        if let shelfPanel = currentPanel as? BottomShelfPanel,
           let screen = shelfPanel.screen ?? NSScreen.main {
            shelfPanel.onRequestClose = nil
            let visibleFrame = screen.visibleFrame
            let height = shelfPanel.frame.height

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                shelfPanel.animator().setFrameOrigin(NSPoint(x: visibleFrame.minX, y: visibleFrame.minY - height))
            } completionHandler: {
                shelfPanel.close()
            }
        } else {
            currentPanel.close()
        }

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

    private func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
    }

    private func repositionBottomShelf() {
        guard let shelfPanel = panel as? BottomShelfPanel,
              let screen = shelfPanel.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let height = shelfPanel.frame.height
        shelfPanel.setFrame(
            NSRect(x: visibleFrame.minX, y: visibleFrame.minY,
                   width: visibleFrame.width, height: height),
            display: true
        )
    }
}
