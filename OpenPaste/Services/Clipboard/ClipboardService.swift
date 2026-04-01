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

    func pasteItem(_ item: ClipboardItem) async {
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

        simulatePaste()
    }

    @MainActor
    private func handleClipboardChange(_ pasteboard: NSPasteboard) async {
        guard var item = normalizer.normalize(from: pasteboard) else { return }

        if securityService.isBlacklisted(bundleId: item.sourceApp.bundleId) { return }

        if let existing = try? await storageService.fetchByHash(item.contentHash) {
            try? await storageService.updateAccessCount(existing.id)
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
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
