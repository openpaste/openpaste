import Foundation
import AppKit

final class ClipboardMonitor: Sendable {
    private let interval: TimeInterval
    private let onChange: @Sendable (NSPasteboard) -> Void
    nonisolated(unsafe) private var lastChangeCount: Int = 0
    nonisolated(unsafe) private var timer: Timer?
    nonisolated(unsafe) var isPaused: Bool = false

    init(interval: TimeInterval = 0.5, onChange: @escaping @Sendable (NSPasteboard) -> Void) {
        self.interval = interval
        self.onChange = onChange
    }

    @MainActor
    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    @MainActor
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        onChange(pasteboard)
    }
}
