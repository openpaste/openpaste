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

    init() throws {
        eventBus = EventBus()
        databaseManager = try DatabaseManager()
        feedbackRouter = FeedbackRouter()

        let dbQueue = databaseManager.dbQueue
        storageService = StorageService(dbQueue: dbQueue)
        searchService = SearchEngine(dbQueue: dbQueue)

        premiumService = PremiumService()
        if #available(macOS 14.0, *) {
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
}
