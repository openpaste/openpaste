@preconcurrency import CloudKit
import Foundation
import GRDB
import Network
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
    private var stagedAssetURLs: [String: URL] = [:]  // recordName -> fileURL

    private let statusLock = NSLock()
    private var status: SyncStatus = .disabled
    private var lastSyncDate: Date?

    private let lifecycleLock = NSLock()
    private var lifecycleGeneration: UInt64 = 0

    private var stopTask: Task<Void, Never>?
    private var stopToken: UUID?
    private var isStopping: Bool = false
    private var isResetting: Bool = false

    private var startTask: Task<Void, Never>?
    private var startToken: UUID?

    private var manualSyncTask: Task<Void, Never>?
    private var manualSyncToken: UUID?

    private var retryTask: Task<Void, Never>?

    // B3: Progress tracking
    private var syncTotalPending: Int = 0
    private var syncCompletedCount: Int = 0

    // Network reachability
    private var networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "dev.tuanle.OpenPaste.NetworkMonitor")
    private var isNetworkAvailable: Bool = true
    private var isNetworkMonitorStarted: Bool = false
    private let networkLock = NSLock()

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

        // Always start the network monitor so we can auto-recover when connectivity returns
        startNetworkMonitor()

        guard getNetworkAvailable() else {
            syncLog.warning(
                "SyncService.start() deferred: network unavailable — monitor will auto-start when online"
            )
            setStatus(.error("No network connection"))
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

        // A3: Validate iCloud account status before creating engine
        let container = CKContainer(identifier: CloudKitMapper.containerIdentifier)
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                break
            case .noAccount:
                syncLog.warning("iCloud account not found")
                setStatus(.error("Sign in to iCloud to enable sync"))
                return
            case .restricted:
                syncLog.warning("iCloud account restricted")
                setStatus(.error("iCloud access is restricted"))
                return
            case .temporarilyUnavailable:
                syncLog.warning("iCloud temporarily unavailable")
                setStatus(.error("iCloud temporarily unavailable"))
                return
            case .couldNotDetermine:
                syncLog.warning("Could not determine iCloud account status")
                setStatus(.error("Could not determine iCloud status"))
                return
            @unknown default:
                syncLog.warning("Unknown iCloud account status")
                setStatus(.error("Unknown iCloud status"))
                return
            }
        } catch {
            syncLog.error("Failed to check iCloud account status: \(error.localizedDescription)")
            setStatus(.error("Cannot verify iCloud account"))
            return
        }

        await recoverInFlightOutbox()

        do {
            let stateSerialization = try await loadEngineStateSerialization()

            var configuration = CKSyncEngine.Configuration(
                database: container.privateCloudDatabase,
                stateSerialization: stateSerialization,
                delegate: self
            )
            configuration.subscriptionID = Config.subscriptionID
            configuration.automaticallySync = true

            let newEngine = CKSyncEngine(configuration)

            lifecycleLock.lock()
            let canInstallEngine =
                (lifecycleGeneration == expectedGeneration && startToken == token && engine == nil)
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
                syncLog.info(
                    "Outbox callback: scheduled \(recordNames.count) new records with engine")
                _ = self  // prevent unused capture warning
            }

            loadLastSyncDate()
            setStatus(.idle)
            startNetworkMonitor()
            startRetryLoop()

            syncLog.info("SyncService engine created, ensuring zone exists…")
            try await ensureZoneExists(container: container)
            syncLog.info("Zone ensured. Seeding existing records if needed…")
            await enqueueExistingRecordsIfNeeded()
            syncLog.info("Scheduling pending outbox with engine…")
            await schedulePendingOutboxWithEngine(newEngine)

            // B5/B6: Run cleanup tasks on start (non-blocking)
            await cleanupTombstones()
            await pruneSyncMetadata()

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
            guard isStartStillValid(expectedGeneration: expectedGeneration, token: token) else {
                return
            }
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
        let retryToCancel: Task<Void, Never>?
        let engineToCancel: CKSyncEngine?

        lifecycleLock.lock()
        lifecycleGeneration += 1

        startToCancel = startTask
        startTask = nil
        startToken = nil

        manualToCancel = manualSyncTask
        manualSyncTask = nil
        manualSyncToken = nil

        retryToCancel = retryTask
        retryTask = nil

        isStopping = true
        engineToCancel = engine
        lifecycleLock.unlock()

        startToCancel?.cancel()
        manualToCancel?.cancel()
        retryToCancel?.cancel()

        stopNetworkMonitor()
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
        lifecycleLock.lock()
        task = stopTask
        lifecycleLock.unlock()
        if let task { await task.value }
    }

    private func isStoppingSnapshot() -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isStopping
    }

    func currentEngineSnapshot() -> CKSyncEngine? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard !isStopping else { return nil }
        return engine
    }

    private func isStartStillValid(expectedGeneration: UInt64, token: UUID) -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return lifecycleGeneration == expectedGeneration && startToken == token
    }

    private func isCurrentEngine(_ candidate: CKSyncEngine) -> Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
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
        guard getNetworkAvailable() else {
            syncLog.warning("triggerManualSync deferred: network unavailable")
            setStatus(.error("No network connection"))
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
        lifecycleLock.lock()
        let alreadyResetting = isResetting
        isResetting = true
        lifecycleLock.unlock()
        guard !alreadyResetting else {
            syncLog.info("reset() skipped — already resetting")
            return
        }

        defer {
            lifecycleLock.lock()
            isResetting = false
            lifecycleLock.unlock()
        }

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
        statusLock.lock()
        defer { statusLock.unlock() }
        return status
    }

    func getLastSyncDate() async -> Date? {
        statusLock.lock()
        defer { statusLock.unlock() }
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

    func getErrorCount() async -> Int {
        (try? await dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = ?",
                arguments: [SyncOutboxStatus.error.rawValue]
            ) ?? 0
        }) ?? 0
    }

    func getLastErrorMessage() async -> String? {
        try? await dbQueue.read { db in
            try String.fetchOne(
                db,
                sql:
                    "SELECT lastError FROM sync_metadata WHERE syncStatus = ? AND lastError IS NOT NULL ORDER BY updatedAt DESC LIMIT 1",
                arguments: [SyncOutboxStatus.error.rawValue]
            )
        }
    }

    func getDeviceName() async -> String {
        DeviceID.current
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
                // B3: Capture total pending count at start of send session
                let pending =
                    (try? await dbQueue.read { db in
                        try Int.fetchOne(
                            db,
                            sql:
                                "SELECT COUNT(*) FROM sync_metadata WHERE syncStatus IN ('pending', 'inFlight')"
                        )
                    }) ?? 0
                statusLock.lock()
                syncTotalPending = pending
                syncCompletedCount = 0
                statusLock.unlock()
                setStatus(.syncing(progress: 0))
                await eventBus.emit(.syncStarted)
            }
        case .fetchedRecordZoneChanges(let changes):
            syncLog.info(
                "CKSyncEngine: fetched \(changes.modifications.count) mods, \(changes.deletions.count) dels"
            )
            await applyRemote(modifications: changes.modifications, deletions: changes.deletions)
        case .sentRecordZoneChanges(let results):
            syncLog.info(
                "CKSyncEngine: sent \(results.savedRecords.count) saved, \(results.failedRecordSaves.count) failed"
            )
            await handleSent(saved: results.savedRecords, failed: results.failedRecordSaves)
            // B3: Update progress after each batch
            statusLock.lock()
            syncCompletedCount += results.savedRecords.count + results.failedRecordSaves.count
            let progress =
                syncTotalPending > 0
                ? min(Double(syncCompletedCount) / Double(syncTotalPending), 1.0)
                : nil
            statusLock.unlock()
            setStatus(.syncing(progress: progress))
        case .accountChange(let event):
            syncLog.info("CKSyncEngine: accountChange — \(String(describing: event.changeType))")
            await handleAccountChange(event)
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
            syncLog.info(
                "schedulePendingOutbox: scheduling \(pendingNames.count) records with engine")

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
        statusLock.lock()
        defer { statusLock.unlock() }
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
        assetLock.lock()
        defer { assetLock.unlock() }
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

    // MARK: - Network Reachability (A2)

    func getNetworkAvailable() -> Bool {
        networkLock.lock()
        defer { networkLock.unlock() }
        return isNetworkAvailable
    }

    private func setNetworkAvailable(_ available: Bool) {
        networkLock.lock()
        defer { networkLock.unlock() }
        isNetworkAvailable = available
    }

    private func startNetworkMonitor() {
        networkLock.lock()
        guard !isNetworkMonitorStarted else {
            networkLock.unlock()
            return
        }
        isNetworkMonitorStarted = true
        // Create a fresh monitor (NWPathMonitor can't be restarted after cancel)
        networkMonitor = NWPathMonitor()
        networkLock.unlock()

        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasAvailable = self.getNetworkAvailable()
            let nowAvailable = path.status == .satisfied
            self.setNetworkAvailable(nowAvailable)

            if !wasAvailable && nowAvailable {
                syncLog.info("Network restored — triggering sync")
                Task { [weak self] in
                    guard let self else { return }
                    guard self.currentEngineSnapshot() != nil else {
                        await self.start()
                        return
                    }
                    await self.triggerManualSync()
                }
            } else if wasAvailable && !nowAvailable {
                syncLog.info("Network lost")
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func stopNetworkMonitor() {
        networkMonitor.cancel()
        networkLock.lock()
        isNetworkMonitorStarted = false
        networkLock.unlock()
    }

    // MARK: - Retry Engine (A1)

    private func startRetryLoop() {
        retryTask?.cancel()
        retryTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.syncRetryCheckInterval))
                guard !Task.isCancelled else { break }
                await self?.retryFailedOutboxEntries()
            }
        }
    }

    private func retryFailedOutboxEntries() async {
        guard let engine = currentEngineSnapshot() else { return }
        guard getNetworkAvailable() else { return }

        // Don't retry while a manual sync is in-flight — avoid concurrent sendChanges
        lifecycleLock.lock()
        let manualActive = manualSyncTask != nil
        lifecycleLock.unlock()
        guard !manualActive else { return }

        do {
            let now = Date()
            let retried = try await dbQueue.write { db -> [String] in
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT recordName, retryCount, updatedAt
                        FROM sync_metadata
                        WHERE syncStatus = ?
                          AND retryCount < ?
                        ORDER BY updatedAt ASC
                        LIMIT 20
                        """,
                    arguments: [
                        SyncOutboxStatus.error.rawValue,
                        Constants.syncMaxRetries,
                    ]
                )

                var retriedNames: [String] = []
                for row in rows {
                    let recordName: String = row["recordName"]
                    let retryCount: Int = row["retryCount"]
                    let updatedAt: Date = row["updatedAt"]

                    // Exponential backoff: wait min(60 * 2^retryCount, 3600) seconds
                    let delay = min(
                        Constants.syncRetryBaseInterval * pow(2.0, Double(retryCount)),
                        Constants.syncRetryMaxInterval
                    )
                    guard now.timeIntervalSince(updatedAt) >= delay else { continue }

                    try db.execute(
                        sql: """
                            UPDATE sync_metadata
                            SET syncStatus = ?, lastError = NULL, updatedAt = ?
                            WHERE recordName = ?
                            """,
                        arguments: [SyncOutboxStatus.pending.rawValue, now, recordName]
                    )
                    retriedNames.append(recordName)
                }

                return retriedNames
            }

            if !retried.isEmpty {
                syncLog.info("Retry engine: reset \(retried.count) entries to pending")
                let changes = retried.map { name in
                    CKSyncEngine.PendingRecordZoneChange.saveRecord(
                        CKRecord.ID(recordName: name, zoneID: CloudKitMapper.zoneID)
                    )
                }
                engine.state.add(pendingRecordZoneChanges: changes)
            }

            // Remove records that exceeded max retries from engine's pending queue
            // to prevent infinite retry loops
            let stuckNames = try await dbQueue.read { db -> [String] in
                try String.fetchAll(
                    db,
                    sql: """
                        SELECT recordName FROM sync_metadata
                        WHERE syncStatus = ? AND retryCount >= ?
                        """,
                    arguments: [SyncOutboxStatus.error.rawValue, Constants.syncMaxRetries]
                )
            }
            if !stuckNames.isEmpty {
                syncLog.warning("Retry engine: \(stuckNames.count) records exceeded max retries")
                let stuckChanges = stuckNames.map { name in
                    CKSyncEngine.PendingRecordZoneChange.saveRecord(
                        CKRecord.ID(recordName: name, zoneID: CloudKitMapper.zoneID)
                    )
                }
                engine.state.remove(pendingRecordZoneChanges: stuckChanges)
            }
        } catch {
            syncLog.error("Retry engine failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Account Change Handling (A4)

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) async {
        switch event.changeType {
        case .signIn:
            lifecycleLock.lock()
            let alreadyResetting = isResetting
            lifecycleLock.unlock()
            guard !alreadyResetting else {
                syncLog.info("iCloud signIn event ignored — already resetting")
                return
            }
            syncLog.info("iCloud account signed in — resetting and restarting sync")
            await reset()
        case .signOut:
            syncLog.info("iCloud account signed out — stopping sync")
            await stop()
            setStatus(.error("Signed out of iCloud"))
        case .switchAccounts:
            syncLog.info("iCloud account switched — resetting sync data")
            await reset()
        @unknown default:
            syncLog.warning("Unknown account change type")
        }
    }
}
