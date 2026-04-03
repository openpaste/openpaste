import Foundation
@preconcurrency import CloudKit
import GRDB

@available(macOS 14.0, *)
final class SyncService: NSObject, SyncServiceProtocol, CKSyncEngineDelegate, @unchecked Sendable {
    enum Config {
        static let maxBatchSize = 50
        static let subscriptionID = "OpenPasteSyncSubscription"
    }

    let dbQueue: DatabaseQueue
    let databaseManager: DatabaseManager
    let eventBus: EventBus
    let premiumService: PremiumServiceProtocol
    let encryption: SyncEncryptionServiceProtocol

    private let assetLock = NSLock()
    private var stagedAssetURLs: [String: URL] = [:] // recordName -> fileURL

    private let statusLock = NSLock()
    private var status: SyncStatus = .disabled
    private var lastSyncDate: Date?

    private var engine: CKSyncEngine?

    init(
        databaseManager: DatabaseManager,
        eventBus: EventBus,
        premiumService: PremiumServiceProtocol,
        encryption: SyncEncryptionServiceProtocol = SyncEncryptionService()
    ) {
        self.databaseManager = databaseManager
        self.dbQueue = databaseManager.dbQueue
        self.eventBus = eventBus
        self.premiumService = premiumService
        self.encryption = encryption
    }

    func start() async {
        guard premiumService.isPremium else {
            setStatus(.notPremium)
            return
        }
        guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else {
            setStatus(.disabled)
            return
        }
        if engine != nil { return }

        do {
            let stateSerialization = try await loadEngineStateSerialization()
            let container = CKContainer(identifier: CloudKitMapper.containerIdentifier)

            var configuration = CKSyncEngine.Configuration(
                database: container.privateCloudDatabase,
                stateSerialization: stateSerialization,
                delegate: self
            )
            configuration.subscriptionID = Config.subscriptionID
            configuration.automaticallySync = true

            engine = CKSyncEngine(configuration)
            setStatus(.idle)

            try await ensureZoneExists(container: container)
            try await engine?.fetchChanges()
            try await engine?.sendChanges()
        } catch {
            setStatus(.error(error.localizedDescription))
        }
    }

    func stop() async {
        await engine?.cancelOperations()
        engine = nil
        setStatus(.disabled)
    }

    func triggerManualSync() async {
        guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else {
            setStatus(.disabled)
            return
        }
        if engine == nil { await start() }

        do {
            setStatus(.syncing(progress: nil))
            try await engine?.fetchChanges()
            try await engine?.sendChanges()
            setStatus(.idle)
            await eventBus.emit(.syncCompleted)
        } catch {
            setStatus(.error(error.localizedDescription))
            await eventBus.emit(.syncFailed(error.localizedDescription))
        }
    }

    func reset() async {
        await stop()
        do {
            try await dbQueue.write { db in
                try db.execute(sql: "DELETE FROM sync_metadata")
                try db.execute(sql: "DELETE FROM sync_engine_state")
                try db.execute(sql: "UPDATE clipboardItems SET ckSystemFields = NULL")
                try db.execute(sql: "UPDATE collections SET ckSystemFields = NULL")
            }
        } catch {
            setStatus(.error(error.localizedDescription))
        }
    }

    func getStatus() async -> SyncStatus {
        statusLock.lock(); defer { statusLock.unlock() }
        return status
    }

    func getLastSyncDate() async -> Date? {
        statusLock.lock(); defer { statusLock.unlock() }
        return lastSyncDate
    }

    func getPendingChangesCount() async -> Int {
        (try? await dbQueue.read { db in
            try SyncMetadataRecord
                .filter(Column("syncStatus") == SyncOutboxStatus.pending.rawValue)
                .fetchCount(db)
        }) ?? 0
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            await persist(state: update.stateSerialization)

        case .willFetchChanges, .willSendChanges:
            await eventBus.emit(.syncStarted)

        case .fetchedRecordZoneChanges(let changes):
            await applyRemote(modifications: changes.modifications, deletions: changes.deletions)

        case .sentRecordZoneChanges(let results):
            await handleSent(saved: results.savedRecords, failed: results.failedRecordSaves)

        case .didFetchChanges, .didSendChanges, .accountChange, .fetchedDatabaseChanges, .sentDatabaseChanges,
             .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard premiumService.isPremium else { return nil }

        do {
            let outbox = try await claimPendingOutbox(limit: Config.maxBatchSize)
            if outbox.isEmpty { return nil }

            let records = await buildRecordsToSave(outbox: outbox)
            return records.isEmpty ? nil : CKSyncEngine.RecordZoneChangeBatch(recordsToSave: records)
        } catch {
            return nil
        }
    }

    // MARK: - Internal state helpers

    func setStatus(_ new: SyncStatus) {
        statusLock.lock(); defer { statusLock.unlock() }
        status = new
    }

    func touchLastSyncDate() {
        statusLock.lock(); defer { statusLock.unlock() }
        lastSyncDate = Date()
    }

    func stageAsset(url: URL, recordName: String) {
        assetLock.lock(); defer { assetLock.unlock() }
        stagedAssetURLs[recordName] = url
    }

    func cleanupStagedAsset(recordName: String) {
        assetLock.lock()
        let url = stagedAssetURLs.removeValue(forKey: recordName)
        assetLock.unlock()
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
