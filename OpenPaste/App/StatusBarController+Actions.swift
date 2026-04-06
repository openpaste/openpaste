//
//  StatusBarController+Actions.swift
//  OpenPaste
//

import AppKit

extension StatusBarController {

    // MARK: - Menu Actions

    @objc func showHistory() {
        onTogglePanel?()
    }

    @objc func newTextItem() {
        onShowNewTextItem?()
    }

    @objc func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc func checkUpdates() {
        updaterService.checkForUpdates()
    }

    @objc func togglePause() {
        Task { @MainActor in
            if monitoringState.isPaused {
                await clipboardService.resumeMonitoring()
                monitoringState.resume()
            } else {
                await clipboardService.pauseMonitoring()
                monitoringState.pause(reason: .manual)
            }
            updateIcon()
        }
    }

    @objc func timedPause(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? NSNumber else { return }
        let interval = duration.doubleValue

        Task { @MainActor in
            timedResumeTask?.cancel()
            await clipboardService.pauseMonitoring()
            monitoringState.pause(reason: .timed(duration: interval))
            updateIcon()

            timedResumeTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await clipboardService.resumeMonitoring()
                monitoringState.resume()
                updateIcon()
            }
        }
    }

    @objc func pasteRecentItem(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < cachedRecentItems.count else { return }
        let item = cachedRecentItems[index]
        Task { @MainActor in
            await clipboardService.copyToClipboard(item)
        }
    }

    @objc func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will permanently delete all clipboard history items. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            Task { @MainActor in
                try? await storageService.deleteAll()
            }
        }
    }

    @objc func forceSync() {
        Task { @MainActor in
            await syncService.triggerManualSync()
        }
    }

    @objc func openKeyboardShortcuts() {
        openSettings()
    }

    @objc func openURL(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    func truncatedPreview(for item: ClipboardItem) -> String {
        switch item.type {
        case .image:
            return "[Image] from \(item.sourceApp.name ?? "Unknown")"
        case .file:
            return "[File] \(item.plainTextContent?.components(separatedBy: "\n").first ?? "Unknown")"
        default:
            let text = item.plainTextContent ?? ""
            let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            if cleaned.count > 60 { return String(cleaned.prefix(57)) + "…" }
            return cleaned.isEmpty ? "[Empty]" : cleaned
        }
    }

    func iconForContentType(_ type: ContentType) -> NSImage? {
        let symbolName: String
        switch type {
        case .text: symbolName = "doc.text"
        case .code: symbolName = "chevron.left.forwardslash.chevron.right"
        case .link: symbolName = "link"
        case .image: symbolName = "photo"
        case .file: symbolName = "doc"
        case .richText: symbolName = "doc.richtext"
        case .color: symbolName = "paintpalette"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: type.rawValue)
        image?.size = NSSize(width: 14, height: 14)
        return image
    }
}
