import Foundation
import GRDB

@Observable
final class DependencyContainer {
    let eventBus: EventBus
    let databaseManager: DatabaseManager
    let storageService: StorageServiceProtocol
    let searchService: SearchServiceProtocol
    let securityService: SecurityServiceProtocol
    let ocrService: OCRServiceProtocol
    let clipboardService: ClipboardServiceProtocol

    init() throws {
        eventBus = EventBus()
        databaseManager = try DatabaseManager()

        let dbQueue = databaseManager.dbQueue
        storageService = StorageService(dbQueue: dbQueue)
        searchService = SearchEngine(dbQueue: dbQueue)

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
