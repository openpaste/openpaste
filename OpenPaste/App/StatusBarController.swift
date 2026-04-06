//
//  StatusBarController.swift
//  OpenPaste
//

import AppKit
import Foundation

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    let statusItem: NSStatusItem
    let menu: NSMenu

    // Dependencies
    let monitoringState: MonitoringState
    let clipboardService: ClipboardServiceProtocol
    let storageService: StorageServiceProtocol
    let syncService: SyncServiceProtocol
    let updaterService: UpdaterServiceProtocol

    // Callbacks
    var onTogglePanel: (() -> Void)?
    var onShowNewTextItem: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    // Cached data for synchronous menu building
    var cachedRecentItems: [ClipboardItem] = []
    var cachedItemCount: Int = 0
    var timedResumeTask: Task<Void, Never>?

    // Cached static menu items (avoids didChangeImage warnings)
    private(set) lazy var settingsMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        item.keyEquivalentModifierMask = .command
        item.target = self
        return item
    }()
    private(set) lazy var updateMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "")
        item.target = self
        return item
    }()
    private(set) lazy var quitMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "Quit OpenPaste", action: #selector(quit), keyEquivalent: "q")
        item.keyEquivalentModifierMask = .command
        item.target = self
        return item
    }()

    init(
        monitoringState: MonitoringState,
        clipboardService: ClipboardServiceProtocol,
        storageService: StorageServiceProtocol,
        syncService: SyncServiceProtocol,
        updaterService: UpdaterServiceProtocol
    ) {
        self.monitoringState = monitoringState
        self.clipboardService = clipboardService
        self.storageService = storageService
        self.syncService = syncService
        self.updaterService = updaterService
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.menu = NSMenu()
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
        statusItem.button?.toolTip = "OpenPaste"

        Task { await refreshCaches() }
    }

    // MARK: - Dynamic Icon

    func updateIcon() {
        let imageName = monitoringState.isPaused ? "clipboard.badge.clock" : "clipboard"
        statusItem.button?.image = NSImage(
            systemSymbolName: imageName,
            accessibilityDescription: "OpenPaste"
        )
        statusItem.button?.image?.size = NSSize(width: 18, height: 18)

        if monitoringState.isPaused, let appName = monitoringState.pausedAppName {
            statusItem.button?.toolTip = "OpenPaste — Paused (\(appName))"
        } else if monitoringState.isPaused {
            statusItem.button?.toolTip = "OpenPaste — Paused"
        } else {
            statusItem.button?.toolTip = "OpenPaste"
        }
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        // Build menu synchronously so AppKit sees items before displaying.
        // menuWillOpen is always called on the main thread by AppKit.
        MainActor.assumeIsolated {
            self.rebuildMenu()
        }
        // Refresh caches in background, then rebuild with fresh data
        Task { @MainActor in
            await self.refreshCaches()
            self.rebuildMenu()
        }
    }

    // MARK: - Data

    func refreshCaches() async {
        let count = max(UserDefaults.standard.integer(forKey: Constants.recentItemsCountKey), 5)
        cachedRecentItems = (try? await storageService.fetch(limit: count, offset: 0)) ?? []
        cachedItemCount = (try? await storageService.itemCount()) ?? 0
    }

    // MARK: - Smart Pause

    func handleSensitiveAppActivated(appName: String) {
        guard UserDefaults.standard.bool(forKey: Constants.smartAutoPauseEnabledKey) else { return }
        Task { @MainActor in
            await clipboardService.pauseMonitoring()
            monitoringState.pause(reason: .smartDetect(appName: appName))
            updateIcon()
        }
    }

    func handleSensitiveAppDeactivated() {
        guard monitoringState.isPaused,
            case .smartDetect = monitoringState.pauseReason
        else { return }
        Task { @MainActor in
            await clipboardService.resumeMonitoring()
            monitoringState.resume()
            updateIcon()
        }
    }
}
