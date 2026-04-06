import Foundation
import GRDB

@Observable
final class DependencyContainer {
    let eventBus: EventBus
    let databaseManager: DatabaseManager

    let premiumService: PremiumServiceProtocol
    let syncService: SyncServiceProtocol
    let feedbackRouter: FeedbackRouterProtocol

    let storageService: StorageServiceProtocol
    let searchService: SearchServiceProtocol
    let securityService: SecurityServiceProtocol
    let ocrService: OCRServiceProtocol
    let clipboardService: ClipboardServiceProtocol
    let smartListService: SmartListServiceProtocol

    init(uiTestMode: Bool = false) throws {
        eventBus = EventBus()

        let dbDirectory = uiTestMode ? Self.makeUITestDatabaseDirectory() : nil
        let passphraseProvider: (() throws -> String)? =
            uiTestMode ? { "openpaste-ui-test-passphrase" } : nil
        databaseManager = try DatabaseManager(
            databaseDirectoryOverride: dbDirectory,
            passphraseProvider: passphraseProvider
        )

        feedbackRouter = FeedbackRouter()

        let dbQueue = databaseManager.dbQueue
        storageService = StorageService(dbQueue: dbQueue)
        searchService = SearchEngine(dbQueue: dbQueue)
        smartListService = SmartListService(dbQueue: dbQueue)

        premiumService = PremiumService()
        if uiTestMode {
            syncService = NoopSyncService()
        } else if #available(macOS 14.0, *) {
            syncService = SyncService(
                databaseManager: databaseManager,
                eventBus: eventBus,
                premiumService: premiumService
            )
        } else {
            syncService = NoopSyncService()
        }

        let detector = SensitiveContentDetector()
        securityService = detector
        ocrService = OCRService()

        clipboardService = ClipboardService(
            securityService: detector,
            storageService: storageService,
            ocrService: ocrService,
            eventBus: eventBus
        )
    }

    private static func makeUITestDatabaseDirectory() -> URL {
        let env = ProcessInfo.processInfo.environment
        let base = FileManager.default.temporaryDirectory

        #if DEBUG
            if let overridePath = env["OPENPASTE_UI_TEST_DATABASE_DIR"], !overridePath.isEmpty {
                if overridePath.hasPrefix("/") {
                    return URL(fileURLWithPath: overridePath, isDirectory: true)
                        .standardizedFileURL
                }

                return URL(fileURLWithPath: overridePath, isDirectory: true, relativeTo: base)
                    .standardizedFileURL
            }
        #endif

        return
            base
            .appendingPathComponent("OpenPasteUITests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
