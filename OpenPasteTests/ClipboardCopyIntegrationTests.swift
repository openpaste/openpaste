import AppKit
import Foundation
import Testing

@testable import OpenPaste

@Suite(.serialized)
struct ClipboardCopyIntegrationTests {
    private struct NoopOCRService: OCRServiceProtocol {
        func extractText(from imageData: Data) async throws -> String? { nil }
    }

    private enum PasteboardLock {
        static let value = NSLock()
    }

    @Test @MainActor func copyToClipboard_writesRichTextFallbacksAndUpdatesAccessCount()
        async throws
    {
        PasteboardLock.value.lock()
        defer { PasteboardLock.value.unlock() }

        let (service, storageService) = try makeClipboardService()
        let html = "<b>Hello Clipboard</b>"
        let item = ClipboardItem(
            type: .richText,
            content: Data(html.utf8),
            plainTextContent: "Hello Clipboard",
            contentHash: ContentHasher().hash(Data(html.utf8))
        )

        try await storageService.save(item)
        await service.copyToClipboard(item)

        let pasteboard = NSPasteboard.general
        #expect(pasteboard.data(forType: .rtf) != nil)
        #expect(pasteboard.string(forType: .string) == "Hello Clipboard")

        let fetched = try await storageService.fetch(limit: 1, offset: 0)
        #expect(fetched.first?.accessCount == 1)
    }

    @Test @MainActor func copyToClipboard_convertsPNGImageToTIFF() async throws {
        PasteboardLock.value.lock()
        defer { PasteboardLock.value.unlock() }

        let (service, storageService) = try makeClipboardService()
        let pngData = try #require(makePNGData())
        let item = ClipboardItem(
            type: .image,
            content: pngData,
            contentHash: ContentHasher().hash(pngData)
        )

        try await storageService.save(item)
        await service.copyToClipboard(item)

        let pasteboard = NSPasteboard.general
        let tiffData = try #require(pasteboard.data(forType: .tiff))
        #expect(NSImage(data: tiffData) != nil)
    }

    private func makeClipboardService() throws -> (ClipboardService, StorageService) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("OpenPasteTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let databaseManager = try DatabaseManager(
            databaseDirectoryOverride: tempDir,
            passphraseProvider: { "openpaste-test-passphrase" }
        )
        let storageService = StorageService(dbQueue: databaseManager.dbQueue)
        let service = ClipboardService(
            securityService: SensitiveContentDetector(),
            storageService: storageService,
            ocrService: NoopOCRService(),
            eventBus: EventBus()
        )
        return (service, storageService)
    }

    private func makePNGData() -> Data? {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return rep.representation(using: .png, properties: [:])
    }
}
