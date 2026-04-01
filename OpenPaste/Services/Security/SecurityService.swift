import Foundation

final class SecurityService: @unchecked Sendable {
    private let detector: SensitiveContentDetector
    private let storageService: StorageServiceProtocol
    private var cleanupTimer: Timer?

    init(detector: SensitiveContentDetector, storageService: StorageServiceProtocol) {
        self.detector = detector
        self.storageService = storageService
    }

    @MainActor
    func startCleanupTimer(interval: TimeInterval = 300) {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.storageService.deleteExpired()
            }
        }
    }

    @MainActor
    func stopCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}
