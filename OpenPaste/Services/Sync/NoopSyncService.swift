import Foundation

struct NoopSyncService: SyncServiceProtocol {
    func start() async {}
    func stop() async {}
    func triggerManualSync() async {}
    func reset() async {}

    func getStatus() async -> SyncStatus { .disabled }
    func getLastSyncDate() async -> Date? { nil }
    func getPendingChangesCount() async -> Int { 0 }
}
