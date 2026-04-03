import Foundation

enum SyncStatus: Sendable, Equatable {
    case disabled
    case idle
    case syncing(progress: Double?)
    case error(String)
    case notPremium
}

protocol SyncServiceProtocol: Sendable {
    func start() async
    func stop() async
    func triggerManualSync() async
    func reset() async

    func getStatus() async -> SyncStatus
    func getLastSyncDate() async -> Date?
    func getPendingChangesCount() async -> Int
    func getSyncedCount() async -> Int
}
