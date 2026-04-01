import Foundation

actor EventBus {
    private var continuations: [UUID: AsyncStream<AppEvent>.Continuation] = [:]

    func emit(_ event: AppEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func stream() -> AsyncStream<AppEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.addContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<AppEvent>.Continuation) {
        continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
