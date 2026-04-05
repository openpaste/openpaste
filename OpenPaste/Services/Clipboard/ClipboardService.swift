import Foundation
import AppKit

final class ClipboardService: ClipboardServiceProtocol, @unchecked Sendable {
    private let normalizer = ContentNormalizer()
    private let securityService: SecurityServiceProtocol
    private let storageService: StorageServiceProtocol
    private let ocrService: OCRServiceProtocol
    private let eventBus: EventBus
    private var monitor: ClipboardMonitor?

    init(
        securityService: SecurityServiceProtocol,
        storageService: StorageServiceProtocol,
        ocrService: OCRServiceProtocol,
        eventBus: EventBus
    ) {
        self.securityService = securityService
        self.storageService = storageService
        self.ocrService = ocrService
        self.eventBus = eventBus
    }

    func startMonitoring() async {
        let settingsInterval = UserDefaults.standard.double(forKey: "pollingInterval")
        let interval = settingsInterval > 0 ? settingsInterval : Constants.defaultPollingInterval
        let monitor = ClipboardMonitor(interval: interval) { [weak self] pasteboard in
            guard let self else { return }
            Task { await self.handleClipboardChange(pasteboard) }
        }
        self.monitor = monitor
        await monitor.start()
    }

    func stopMonitoring() async {
        await monitor?.stop()
        monitor = nil
    }

    /// Legacy method used by PasteInterceptor — copies and immediately simulates paste.
    func pasteItem(_ item: ClipboardItem) async {
        await copyToClipboard(item)
        simulatePaste()
    }

    /// Copy item content to the system clipboard without simulating paste.
    func copyToClipboard(_ item: ClipboardItem) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .code, .link, .color:
            if let text = item.plainTextContent {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            pasteboard.setData(item.content, forType: .rtf)
            if let text = item.plainTextContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            pasteboard.setData(item.content, forType: .tiff)
        case .file:
            if let text = item.plainTextContent {
                let urls = text.components(separatedBy: "\n").compactMap { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSPasteboardWriting])
            }
        }

        try? await storageService.updateAccessCount(item.id)
        await eventBus.emit(.itemPasted(item))
    }

    /// Simulate ⌘V to paste into the frontmost application.
    /// Waits for the target app to become active, checks Accessibility permission,
    /// and shows an alert if not granted.
    /// - Parameter targetBundleId: If provided, waits for this specific app to become active.
    func simulatePasteToFrontApp(targetBundleId: String? = nil) async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["OPENPASTE_UI_TEST_MODE"] == "1" {
            return
        }
        #endif

        print("[SimulatePaste] Starting, targetBundleId = \(targetBundleId ?? "nil")")
        // Chờ app đích active (timeout 500ms)
        let deadline = Date().addingTimeInterval(0.5)
        var found = false
        while Date() < deadline {
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.isActive,
               frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                // Nếu có target cụ thể, chờ ĐÚNG app đó
                if let target = targetBundleId {
                    if frontApp.bundleIdentifier == target {
                        print("[SimulatePaste] Target app matched: \(target)")
                        found = true
                        break
                    } else {
                        print("[SimulatePaste] Polling... front=\(frontApp.bundleIdentifier ?? "?"), waiting for \(target)")
                    }
                } else {
                    print("[SimulatePaste] Non-OpenPaste app active: \(frontApp.bundleIdentifier ?? "?")")
                    found = true
                    break
                }
            } else {
                let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
                let active = NSWorkspace.shared.frontmostApplication?.isActive ?? false
                print("[SimulatePaste] Polling... front=\(bid), isActive=\(active)")
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        if !found {
            print("[SimulatePaste] ⚠️ Timeout! Target app never became active")
        }

        // Kiểm tra Accessibility permission
        guard AXIsProcessTrusted() else {
            print("[SimulatePaste] ❌ AXIsProcessTrusted = false")
            await showAccessibilityAlert()
            return
        }

        print("[SimulatePaste] ✅ Dispatching CGEvent ⌘V")
        simulatePaste()
    }

    // MARK: - Private

    @MainActor
    func handleClipboardChange(_ pasteboard: NSPasteboard) async {
        guard var item = normalizer.normalize(from: pasteboard) else { return }

        if securityService.isBlacklisted(bundleId: item.sourceApp.bundleId) { return }

        if let existing = try? await storageService.fetchByHash(item.contentHash) {
            var updated = existing
            updated.createdAt = Date()
            try? await storageService.update(updated)
            try? await storageService.updateAccessCount(existing.id)
            await eventBus.emit(.duplicateCopied(updated))
            return
        }

        if let text = item.plainTextContent {
            item.isSensitive = securityService.detectSensitive(text)
            if item.isSensitive {
                item.expiresAt = securityService.suggestedExpiry(for: item)
                await eventBus.emit(.sensitiveDetected(item))
            }
        }

        try? await storageService.save(item)
        await eventBus.emit(.clipboardChanged(item))

        if item.isSensitive {
            item.content.secureZero()
        }

        if item.type == .image {
            Task {
                if let ocrText = try? await ocrService.extractText(from: item.content) {
                    var updatedItem = item
                    updatedItem.ocrText = ocrText
                    updatedItem.plainTextContent = updatedItem.plainTextContent ?? ocrText
                    try? await storageService.update(updatedItem)
                    await eventBus.emit(.ocrCompleted(item: updatedItem, extractedText: ocrText))
                }
            }
        }
    }

    private nonisolated func simulatePaste() {
        // Proven approach used by Maccy (popular macOS clipboard manager):
        // - .combinedSessionState captures current session keyboard state
        // - setLocalEventsFilterDuringSuppressionState suppresses local keyboard
        //   events from our own app during paste, preventing interference
        // - .cgAnnotatedSessionEventTap posts at the session level where events
        //   are annotated for delivery to the correct target application
        let source = CGEventSource(stateID: .combinedSessionState)

        // Suppress local keyboard events during the paste operation
        // to prevent our own key handling from interfering
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            print("[SimulatePaste] ❌ Failed to create CGEvent")
            return
        }

        // Explicitly set ONLY Command flag
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post to annotated session tap (not HID tap) — this ensures
        // the event is routed to the correct application at session level
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        usleep(20_000) // 20ms delay for target app to process keyDown
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    @MainActor
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Cần cấp quyền Accessibility"
        alert.informativeText = "OpenPaste cần quyền Accessibility để paste trực tiếp vào ứng dụng khác.\n\nVào System Settings → Privacy & Security → Accessibility → Bật OpenPaste."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Mở System Settings")
        alert.addButton(withTitle: "Để sau")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
