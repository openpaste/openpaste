import AppKit
import Foundation
import QuartzCore
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

final class BottomShelfPanel: NSPanel {
    static let dragSessionDidEndNotification = Notification.Name(
        "BottomShelfPanel.dragSessionDidEnd")

    override var canBecomeKey: Bool { true }

    var onRequestClose: (() -> Void)?
    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private(set) var isDragSessionActive = false

    init(contentView hostingView: NSView, frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow

        // Native AppKit blur — single GPU pass, much faster than SwiftUI .ultraThinMaterial
        let blurView = NSVisualEffectView()
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active

        // Use maskImage for reliable rounded corners on NSVisualEffectView.
        // layer?.cornerRadius does NOT clip the internal blur layers properly.
        blurView.maskImage = Self.roundedRectMask(radius: DS.Shelf.cornerRadius)

        blurView.translatesAutoresizingMaskIntoConstraints = false

        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = DS.Shelf.cornerRadius
        hostingView.layer?.masksToBounds = true
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        blurView.addSubview(hostingView)

        self.contentView = blurView

        // Pin hostingView within blurView
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: blurView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
        ])
    }

    /// Creates a stretchable mask image with rounded corners for NSVisualEffectView.
    private static func roundedRectMask(radius: CGFloat) -> NSImage {
        let diameter = radius * 2 + 1
        let size = NSSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: radius, left: radius, bottom: radius, right: radius
        )
        image.resizingMode = .stretch
        return image
    }

    override func resignKey() {
        super.resignKey()
        if isDragSessionActive {
            return
        }
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

    deinit {
        removeDragSessionMonitors()
    }

    func beginDragSession() {
        guard !isDragSessionActive else { return }
        isDragSessionActive = true
        installDragSessionMonitors()
    }

    func endDragSession(closeIfNeeded: Bool = true) {
        guard isDragSessionActive else { return }
        isDragSessionActive = false
        removeDragSessionMonitors()

        NotificationCenter.default.post(name: Self.dragSessionDidEndNotification, object: self)

        guard closeIfNeeded else { return }

        // Grace period: destination app needs time to read NSItemProvider data
        // after the drop lands. Closing immediately kills the provider callbacks.
        // Images/files need extra time for DB fetch + TIFF conversion.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            guard !self.isKeyWindow, NSApp.keyWindow !== self else { return }
            guard self.sheets.isEmpty else { return }
            if let keyWindow = NSApp.keyWindow,
                keyWindow.isSheet || keyWindow.sheetParent === self
            {
                return
            }
            self.onRequestClose?()
        }
    }

    private func installDragSessionMonitors() {
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) {
            [weak self] event in
            self?.endDragSession(closeIfNeeded: true)
            return event
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.endDragSession(closeIfNeeded: true)
            }
        }
    }

    private func removeDragSessionMonitors() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }

        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
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

        let mode =
            UserDefaults.standard.string(forKey: Constants.windowPositionModeKey)
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
        print(
            "[WindowManager] showBottomShelf: captured previousApp = \(previousApp?.bundleIdentifier ?? "nil"), isActive = \(previousApp?.isActive ?? false)"
        )

        guard let screen = screenForMouse() ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame  // Area above Dock

        let shelfHeight = DS.Shelf.defaultHeight
        let inset = DS.Shelf.edgeInset
        let targetFrame = NSRect(
            x: visibleFrame.minX + inset,
            y: visibleFrame.minY,
            width: visibleFrame.width - inset * 2,
            height: shelfHeight
        )

        let hostingView = NSHostingView(rootView: content().ignoresSafeArea())
        // Prevent SwiftUI from influencing window size
        hostingView.sizingOptions = []

        let newPanel = BottomShelfPanel(contentView: hostingView, frame: targetFrame)
        newPanel.onRequestClose = { [weak self] in
            self?.hide()
        }

        // Set start position BELOW screen BEFORE showing — prevents layout flash
        let startFrame = NSRect(
            x: visibleFrame.minX + inset,
            y: visibleFrame.minY - shelfHeight,
            width: visibleFrame.width - inset * 2,
            height: shelfHeight
        )
        newPanel.setFrame(startFrame, display: false)
        newPanel.makeKeyAndOrderFront(nil)

        // Animate slide-up to target position
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newPanel.animator().setFrame(targetFrame, display: true)
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
            let screen = shelfPanel.screen ?? NSScreen.main
        {
            shelfPanel.onRequestClose = nil
            let visibleFrame = screen.visibleFrame
            let currentFrame = shelfPanel.frame

            let hideFrame = NSRect(
                x: currentFrame.minX,
                y: visibleFrame.minY - currentFrame.height,
                width: currentFrame.width,
                height: currentFrame.height
            )

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                shelfPanel.animator().setFrame(hideFrame, display: true)
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
        print(
            "[WindowManager] reactivatePreviousApp: \(previousApp?.bundleIdentifier ?? "nil"), isActive = \(previousApp?.isActive ?? false)"
        )
        previousApp?.activate()
    }

    private func positionNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
        else {
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
            let screen = shelfPanel.screen ?? NSScreen.main
        else { return }
        let visibleFrame = screen.visibleFrame
        let height = shelfPanel.frame.height
        let inset = DS.Shelf.edgeInset
        shelfPanel.setFrame(
            NSRect(
                x: visibleFrame.minX + inset, y: visibleFrame.minY,
                width: visibleFrame.width - inset * 2, height: height),
            display: true
        )
    }
}
