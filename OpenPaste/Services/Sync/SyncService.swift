import Foundation
@preconcurrency import CloudKit
import GRDB
import os.log

private let syncLog = Logger(subsystem: "dev.tuanle.OpenPaste", category: "Sync")

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

    private let lifecycleLock = NSLock()
    private var lifecycleGeneration: UInt64 = 0

    private var stopTask: Task<Void, Never>?
    private var stopToken: UUID?
    private var isStopping: Bool = false

    private var startTask: Task<Void, Never>?
    private var startToken: UUID?

    private var manualSyncTask: Task<Void, Never>?
    private var manualSyncToken: UUID?

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
        syncLog.info("SyncService.start() called")
        await waitForStopIfNeeded()

        guard premiumService.isPremium else {
            syncLog.warning("SyncService.start() aborted: not premium")
            setStatus(.notPremium)
            return
        }
        guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else {
            syncLog.warning("SyncService.start() aborted: iCloud sync disabled")
            setStatus(.disabled)
            return
        }

        let task: Task<Void, Never>
        lifecycleLock.lock()
        if engine != nil {
            lifecycleLock.unlock()
            return
        }
        if let existing = startTask {
            task = existing
            lifecycleLock.unlock()
            await task.value
            return
        }

        let generation = lifecycleGeneration
        let token = UUID()
        startToken = token
        let newTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.startImpl(expectedGeneration: generation, token: token)
        }
        startTask = newTask
        task = newTask
        lifecycleLock.unlock()

        await task.value
    }

    private func startImpl(expectedGeneration: UInt64, token: UUID) async {
        defer {
            lifecycleLock.lock()
            if startToken == token {
                startTask = nil
                startToken = nil
            }
            lifecycleLock.unlock()
        }

        lifecycleLock.lock()
        let isValidStart = (lifecycleGeneration == expectedGeneration && startToken == token)
        lifecycleLock.unlock()
        guard isValidStart else { return }

        guard premiumService.isPremium else {
            setStatus(.notPremium)
            return
        }
        guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else {
            setStatus(.disabled)
            return
        }

        await recoverInFlightOutbox()

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

            let newEngine = CKSyncEngine(configuration)

            lifecycleLock.lock()
            let canInstallEngine = (lifecycleGeneration == expectedGeneration && startToken == token && engine == nil)
            if canInstallEngine {
                engine = newEngine
            }
            lifecycleLock.unlock()
            guard canInstallEngine else { return }

            // Register callback so new local changes are automatically scheduled with the engine
            databaseManager.setSyncOutboxCallback { [weak self, weak newEngine] recordNames in
                guard let engine = newEngine else { return }
                let changes = recordNames.map { name in
                    CKSyncEngine.PendingRecordZoneChange.saveRecord(
                        CKRecord.ID(recordName: name, zoneID: CloudKitMapper.zoneID)
                    )
                }
                engine.state.add(pendingRecordZoneChanges: changes)
                syncLog.info("Outbox callback: scheduled \(recordNames.count) new records with engine")
                _ = self // prevent unused capture warning
            }

            loadLastSyncDate()
            setStatus(.idle)
            syncLog.info("SyncService engine created, ensuring zone exists…")
            try await ensureZoneExists(container: container)
            syncLog.info("Zone ensured. Seeding existing records if needed…")
            await enqueueExistingRecordsIfNeeded()
            syncLog.info("Scheduling pending outbox with engine…")
            await schedulePendingOutboxWithEngine(newEngine)
            syncLog.info("Fetching remote changes…")
            try await newEngine.fetchChanges()
            syncLog.info("Sending local changes…")
            try await newEngine.sendChanges()
            syncLog.info("SyncService start complete")
        } catch is CancellationError {
            syncLog.info("SyncService.start() cancelled")
            return
        } catch {
            syncLog.error("SyncService.start() failed: \(error.localizedDescription)")
            guard isStartStillValid(expectedGeneration: expectedGeneration, token: token) else { return }
            setStatus(.error(error.localizedDescription))
        }
    }

    func stop() async {
        let task: Task<Void, Never>

        lifecycleLock.lock()
        if let existing = stopTask {
            task = existing
            lifecycleLock.unlock()
            await task.value
            return
        }

        let token = UUID()
        stopToken = token
        let newTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.stopImpl(token: token)
        }
        stopTask = newTask
        task = newTask
        lifecycleLock.unlock()

        await task.value
    }

    private func stopImpl(token: UUID) async {
        defer {
            lifecycleLock.lock()
            if stopToken == token {
                stopTask = nil
                stopToken = nil
            }
            lifecycleLock.unlock()
        }

        let startToCancel: Task<Void, Never>?
        let manualToCancel: Task<Void, Never>?
        let engineToCancel: CKSyncEngine?

        lifecycleLock.lock()
        lifecycleGeneration += 1

        startToCancel = startTask
        startTask = nil
        startToken = nil

        manualToCancel = manualSyncTask
        manualSyncTask = nil
        manualSyncToken = nil

        isStopping = true
        engineToCancel = engine
        lifecycleLock.unlock()

        startToCancel?.cancel()
        manualToCancel?.cancel()

        setStatus(.disabled)
        databaseManager.setSyncOutboxCallback { _ in }

        if let engineToCancel {
            await engineToCancel.cancelOperations()
            lifecycleLock.lock()
            if engine === engineToCancel {
                engine = nil
            }
            lifecycleLock.unlock()
        }

        await recoverInFlightOutbox()

        lifecycleLock.lock()
        isStopping = false
        lifecycleLock.unlock()

        cleanupAllStagedAssets()
    }

    private func waitForStopIfNeeded() async {
        let task: Task<Void, Never>?
        lifecycleLock.lock(); task = stopTask; lifecycleLock.unlock()
        if let task { await task.value }
    }

    private func isStoppingSnapshot() -> Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        return isStopping
    }

    private func currentEngineSnapshot() -> CKSyncEngine? {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        guard !isStopping else { return nil }
        return engine
    }

    private func isStartStillValid(expectedGeneration: UInt64, token: UUID) -> Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        return lifecycleGeneration == expectedGeneration && startToken == token
    }

    private func isCurrentEngine(_ candidate: CKSyncEngine) -> Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        return engine === candidate
    }

    func triggerManualSync() async {
        let task: Task<Void, Never>
        lifecycleLock.lock()
        if let existing = manualSyncTask {
            task = existing
            lifecycleLock.unlock()
            await task.value
            return
        }

        let token = UUID()
        manualSyncToken = token
        let newTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.triggerManualSyncImpl(token: token)
        }
        manualSyncTask = newTask
        task = newTask
        lifecycleLock.unlock()

        await task.value
    }

    private func triggerManualSyncImpl(token: UUID) async {
        syncLog.info("triggerManualSync started")
        defer {
            lifecycleLock.lock()
            if manualSyncToken == token {
                manualSyncTask = nil
                manualSyncToken = nil
            }
            lifecycleLock.unlock()
        }

        guard premiumService.isPremium else {
            syncLog.warning("triggerManualSync aborted: not premium")
            setStatus(.notPremium)
            return
        }
        guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else {
            syncLog.warning("triggerManualSync aborted: iCloud sync disabled")
            setStatus(.disabled)
            return
        }

        if currentEngineSnapshot() == nil {
            syncLog.info("Engine not running, starting…")
            await start()
        }
        if Task.isCancelled { return }

        guard let engine = currentEngineSnapshot() else {
            if Task.isCancelled { return }
            let message = "Sync engine unavailable"
            syncLog.error("triggerManualSync: \(message)")
            setStatus(.error(message))
            await eventBus.emit(.syncFailed(message))
            return
        }

        do {
            setStatus(.syncing(progress: nil))
            await schedulePendingOutboxWithEngine(engine)
            syncLog.info("triggerManualSync: fetching changes…")
            try await engine.fetchChanges()
            syncLog.info("triggerManualSync: sending changes…")
            try await engine.sendChanges()

            guard isCurrentEngine(engine) else { return }
            syncLog.info("triggerManualSync completed successfully")
            setStatus(.idle)
            touchLastSyncDate()
            await eventBus.emit(.syncCompleted)
        } catch is CancellationError {
            syncLog.info("triggerManualSync cancelled")
            if Task.isCancelled { return }
            guard isCurrentEngine(engine) else { return }
            guard premiumService.isPremium else { return }
            guard UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) else { return }
            setStatus(.idle)
        } catch {
            syncLog.error("triggerManualSync failed: \(error.localizedDescription)")
            guard isCurrentEngine(engine) else { return }
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
            return
        }

        if UserDefaults.standard.bool(forKey: Constants.iCloudSyncEnabledKey) {
            await start()
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
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sync_metadata WHERE syncStatus IN (?, ?)",
                arguments: [SyncOutboxStatus.pending.rawValue, SyncOutboxStatus.inFlight.rawValue]
            ) ?? 0
        }) ?? 0
    }

    func getSyncedCount() async -> Int {
        (try? await dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = ?",
                arguments: [SyncOutboxStatus.synced.rawValue]
            ) ?? 0
        }) ?? 0
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine) else { return }

        switch event {
        case .stateUpdate(let update):
            syncLog.debug("CKSyncEngine: stateUpdate")
            await persist(state: update.stateSerialization)
        case .willFetchChanges:
            syncLog.info("CKSyncEngine: willFetchChanges")
            if !isStoppingSnapshot() {
                setStatus(.syncing(progress: nil))
                await eventBus.emit(.syncStarted)
            }
        case .willSendChanges:
            syncLog.info("CKSyncEngine: willSendChanges")
            if !isStoppingSnapshot() {
                setStatus(.syncing(progress: nil))
                await eventBus.emit(.syncStarted)
            }
        case .fetchedRecordZoneChanges(let changes):
            syncLog.info("CKSyncEngine: fetched \(changes.modifications.count) mods, \(changes.deletions.count) dels")
            await applyRemote(modifications: changes.modifications, deletions: changes.deletions)
        case .sentRecordZoneChanges(let results):
            syncLog.info("CKSyncEngine: sent \(results.savedRecords.count) saved, \(results.failedRecordSaves.count) failed")
            await handleSent(saved: results.savedRecords, failed: results.failedRecordSaves)
        case .accountChange:
            syncLog.info("CKSyncEngine: accountChange")
        case .didFetchChanges:
            syncLog.info("CKSyncEngine: didFetchChanges")
            setStatus(.idle)
        case .didSendChanges:
            syncLog.info("CKSyncEngine: didSendChanges")
            setStatus(.idle)
            await eventBus.emit(.syncCompleted)
        case .fetchedDatabaseChanges, .sentDatabaseChanges,
             .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        @unknown default:
            syncLog.debug("CKSyncEngine: unknown event")
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard isCurrentEngine(syncEngine) else { return nil }
        guard !isStoppingSnapshot() else { return nil }
        guard premiumService.isPremium else { return nil }

        do {
            let outbox = try await claimPendingOutbox(limit: Config.maxBatchSize)
            if outbox.isEmpty {
                syncLog.info("nextRecordZoneChangeBatch: outbox empty, nothing to send")
                return nil
            }
            syncLog.info("nextRecordZoneChangeBatch: building \(outbox.count) records")

            let records = await buildRecordsToSave(outbox: outbox)
            if records.isEmpty {
                syncLog.warning("nextRecordZoneChangeBatch: all records failed to build")
                return nil
            }
            return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: records)
        } catch {
            syncLog.error("nextRecordZoneChangeBatch error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Tell CKSyncEngine about all pending outbox records so it knows to call
    /// `nextRecordZoneChangeBatch()` during `sendChanges()`.
    func schedulePendingOutboxWithEngine(_ engine: CKSyncEngine) async {
        do {
            let pendingNames = try await dbQueue.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT recordName FROM sync_metadata WHERE syncStatus = ?",
                    arguments: [SyncOutboxStatus.pending.rawValue]
                )
            }
            guard !pendingNames.isEmpty else {
                syncLog.info("schedulePendingOutbox: no pending records")
                return
            }
            syncLog.info("schedulePendingOutbox: scheduling \(pendingNames.count) records with engine")

            let changes = pendingNames.map { name in
                CKSyncEngine.PendingRecordZoneChange.saveRecord(
                    CKRecord.ID(recordName: name, zoneID: CloudKitMapper.zoneID)
                )
            }
            engine.state.add(pendingRecordZoneChanges: changes)
        } catch {
            syncLog.error("schedulePendingOutbox error: \(error.localizedDescription)")
        }
    }

    func setStatus(_ new: SyncStatus) {
        statusLock.lock(); defer { statusLock.unlock() }
        status = new
    }

    func touchLastSyncDate() {
        let now = Date()
        statusLock.lock()
        lastSyncDate = now
        statusLock.unlock()

        try? dbQueue.writeWithoutTransaction { db in
            try db.execute(
                sql: "UPDATE sync_engine_state SET lastSyncDate = ? WHERE id = 1",
                arguments: [now]
            )
        }
    }

    func loadLastSyncDate() {
        let date = try? dbQueue.read { db in
            try Date.fetchOne(db, sql: "SELECT lastSyncDate FROM sync_engine_state WHERE id = 1")
        }
        statusLock.lock()
        lastSyncDate = date
        statusLock.unlock()
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

    private func cleanupAllStagedAssets() {
        assetLock.lock()
        let urls = Array(stagedAssetURLs.values)
        stagedAssetURLs.removeAll()
        assetLock.unlock()
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }
}
