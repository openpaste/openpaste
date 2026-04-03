import Foundation

extension SettingsViewModel {
    func refreshSyncInfo() async {
        guard let syncService else {
            await MainActor.run {
                self.syncStatus = .disabled
                self.syncLastSyncDate = nil
                self.syncPendingChangesCount = 0
            }
            return
        }

        let status = await syncService.getStatus()
        let last = await syncService.getLastSyncDate()
        let pending = await syncService.getPendingChangesCount()

        await MainActor.run {
            self.syncStatus = status
            self.syncLastSyncDate = last
            self.syncPendingChangesCount = pending
        }
    }

    func syncNow() async {
        await syncService?.triggerManualSync()
        await refreshSyncInfo()
    }

    func resetSync() async {
        await syncService?.reset()
        await refreshSyncInfo()
    }
}
