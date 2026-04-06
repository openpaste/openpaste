//
//  StatusBarController+MenuBuilder.swift
//  OpenPaste
//

import AppKit

extension StatusBarController {

    func rebuildMenu() {
        menu.removeAllItems()

        addHistoryItem()
        addNewTextItem()
        menu.addItem(.separator())

        let showRecent =
            UserDefaults.standard.object(forKey: Constants.showRecentItemsInMenuKey) as? Bool
            ?? true
        if showRecent {
            addRecentItemsSubmenu()
            menu.addItem(.separator())
        }

        addSettingsItem()
        addUpdateItem()
        menu.addItem(.separator())

        addPauseSubmenu()
        addQuickActionsSubmenu()
        menu.addItem(.separator())

        addHelpSubmenu()
        menu.addItem(.separator())

        addQuitItem()
    }

    // MARK: - Top-Level Items

    private func addHistoryItem() {
        let item = NSMenuItem(
            title: "Show Clipboard History \(HotkeyManager.currentHotkeyDisplayString())",
            action: #selector(showHistory),
            keyEquivalent: "v"
        )
        item.keyEquivalentModifierMask = [.shift, .command]
        item.target = self
        menu.addItem(item)
    }

    private func addNewTextItem() {
        let item = NSMenuItem(
            title: "New Text Item", action: #selector(newTextItem), keyEquivalent: "n")
        item.keyEquivalentModifierMask = .command
        item.target = self
        menu.addItem(item)
    }

    private func addSettingsItem() {
        menu.addItem(settingsMenuItem)
    }

    private func addUpdateItem() {
        updateMenuItem.isEnabled = updaterService.canCheckForUpdates
        menu.addItem(updateMenuItem)
    }

    private func addQuitItem() {
        menu.addItem(quitMenuItem)
    }

    // MARK: - Submenus

    func addRecentItemsSubmenu() {
        let submenu = NSMenu()
        let maxItems = max(UserDefaults.standard.integer(forKey: Constants.recentItemsCountKey), 5)

        for (index, item) in cachedRecentItems.prefix(maxItems).enumerated() {
            let title = truncatedPreview(for: item)
            let menuItem = NSMenuItem(
                title: title, action: #selector(pasteRecentItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menuItem.image = iconForContentType(item.type)
            submenu.addItem(menuItem)
        }

        if !cachedRecentItems.isEmpty { submenu.addItem(.separator()) }

        let showAll = NSMenuItem(
            title: "Show All History", action: #selector(showHistory), keyEquivalent: "")
        showAll.target = self
        submenu.addItem(showAll)

        let parent = NSMenuItem(title: "Recent Copies", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    func addPauseSubmenu() {
        let submenu = NSMenu()

        let toggleTitle = monitoringState.isPaused ? "Resume Monitoring" : "Pause Monitoring"
        let toggle = NSMenuItem(
            title: toggleTitle, action: #selector(togglePause), keyEquivalent: "")
        toggle.target = self
        submenu.addItem(toggle)

        if monitoringState.isPaused, let remaining = monitoringState.remainingTimeString {
            let info = NSMenuItem(title: "Resumes in \(remaining)", action: nil, keyEquivalent: "")
            info.isEnabled = false
            submenu.addItem(info)
        }

        submenu.addItem(.separator())

        let durations: [(String, TimeInterval)] = [
            ("15 Minutes", 15 * 60), ("30 Minutes", 30 * 60),
            ("1 Hour", 3600), ("3 Hours", 10800), ("8 Hours", 28800),
        ]
        for (title, duration) in durations {
            let item = NSMenuItem(
                title: "Pause for \(title)", action: #selector(timedPause(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration as NSNumber
            submenu.addItem(item)
        }

        let parentTitle = monitoringState.isPaused ? "⏸ Monitoring Paused" : "Pause Monitoring"
        let parent = NSMenuItem(title: parentTitle, action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    func addQuickActionsSubmenu() {
        let submenu = NSMenu()

        let clear = NSMenuItem(
            title: "Clear All History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        submenu.addItem(clear)

        let sync = NSMenuItem(
            title: "Force Sync Now", action: #selector(forceSync), keyEquivalent: "")
        sync.target = self
        submenu.addItem(sync)

        submenu.addItem(.separator())

        let stats = NSMenuItem(
            title: "📊 Storage: \(cachedItemCount) items", action: nil, keyEquivalent: "")
        stats.isEnabled = false
        submenu.addItem(stats)

        let parent = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    func addHelpSubmenu() {
        let submenu = NSMenu()
        let baseURL = Constants.repositoryURLString

        let links: [(String, String?)] = [
            ("Getting Started", "\(baseURL)#readme"),
            ("Keyboard Shortcuts", nil),
            ("Documentation", "\(baseURL)/wiki"),
        ]
        for (title, url) in links {
            if let url {
                let item = NSMenuItem(
                    title: title, action: #selector(openURL(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                submenu.addItem(item)
            } else {
                let item = NSMenuItem(
                    title: title, action: #selector(openKeyboardShortcuts), keyEquivalent: "")
                item.target = self
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())

        for (title, path) in [
            ("Report Bug", "/issues/new?template=bug_report.md"),
            ("Feature Request", "/issues/new?template=feature_request.md"),
        ] {
            let item = NSMenuItem(title: title, action: #selector(openURL(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = "\(baseURL)\(path)"
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let star = NSMenuItem(
            title: "Star on GitHub", action: #selector(openURL(_:)), keyEquivalent: "")
        star.target = self
        star.representedObject = baseURL
        submenu.addItem(star)

        let parent = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }
}
