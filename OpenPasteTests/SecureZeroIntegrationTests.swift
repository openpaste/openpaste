import AppKit
import Foundation
import Testing
@testable import OpenPaste

struct SecureZeroIntegrationTests {
    private struct NoopOCRService: OCRServiceProtocol {
        func extractText(from imageData: Data) async throws -> String? { nil }
    }

    @Test @MainActor func clipboardService_zerosSensitiveContentAfterSave() async throws {
        UserDefaults.standard.register(defaults: [
            "sensitiveDetectionEnabled": true,
        ])

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("OpenPasteTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbManager = try DatabaseManager(
            databaseDirectoryOverride: tempDir,
            passphraseProvider: { "openpaste-test-passphrase" }
        )
        let storageService = StorageService(dbQueue: dbManager.dbQueue)

        let detector = SensitiveContentDetector()
        let eventBus = EventBus()
        let ocrService = NoopOCRService()
        let clipboardService = ClipboardService(
            securityService: detector,
            storageService: storageService,
            ocrService: ocrService,
            eventBus: eventBus
        )

        var secureZeroCallCount = 0
        #if DEBUG
        SecureBytesDebugHooks.onDataSecureZero = { _ in
            secureZeroCallCount += 1
        }
        defer { SecureBytesDebugHooks.onDataSecureZero = nil }
        #endif

        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("api_key=AAAAAAAAAAAAAAAAAAAA", forType: .string)

        await clipboardService.handleClipboardChange(pasteboard)

        #if DEBUG
        #expect(secureZeroCallCount >= 1)
        #endif
    }
}
