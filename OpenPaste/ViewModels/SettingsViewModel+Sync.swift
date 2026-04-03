import Foundation

extension SettingsViewModel {
    func refreshSyncInfo() async {
        guard let syncService else {
            await MainActor.run {
                self.syncStatus = .disabled
                self.syncLastSyncDate = nil
                self.syncPendingChangesCount = 0
                self.syncSyncedCount = 0
            }
            return
        }

        let status = await syncService.getStatus()
        let last = await syncService.getLastSyncDate()
        let pending = await syncService.getPendingChangesCount()
        let synced = await syncService.getSyncedCount()

        await MainActor.run {
            self.syncStatus = status
            self.syncLastSyncDate = last
            self.syncPendingChangesCount = pending
            self.syncSyncedCount = synced
            self.isSyncing = {
                if case .syncing = status { return true }
                return false
            }()
        }
    }

    func syncNow() async {
        await MainActor.run {
            self.isSyncing = true
            self.syncStatus = .syncing(progress: nil)
        }
        await syncService?.triggerManualSync()
        await refreshSyncInfo()
        await MainActor.run {
            self.isSyncing = false
        }
    }

    func resetSync() async {
        await syncService?.reset()
        await refreshSyncInfo()
    }

    /// Observes EventBus sync events and live-refreshes the UI.
    func startSyncObserver() {
        syncObserverTask?.cancel()
        guard let eventBus else { return }
        syncObserverTask = Task { [weak self] in
            for await event in await eventBus.stream() {
                guard !Task.isCancelled else { break }
                switch event {
                case .syncStarted, .syncCompleted, .syncFailed:
                    await self?.refreshSyncInfo()
                default:
                    break
                }
            }
        }
    }

    func stopSyncObserver() {
        syncObserverTask?.cancel()
        syncObserverTask = nil
    }
}
