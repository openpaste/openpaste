//
//  MonitoringState.swift
//  OpenPaste
//

import Foundation

@MainActor
@Observable
final class MonitoringState {
    var isPaused: Bool = false
    var pauseReason: PauseReason?
    var pauseEndDate: Date?

    var pausedAppName: String? {
        guard case .smartDetect(let name) = pauseReason else { return nil }
        return name
    }

    var remainingTimeString: String? {
        guard let endDate = pauseEndDate else { return nil }
        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    func pause(reason: PauseReason) {
        isPaused = true
        pauseReason = reason
        switch reason {
        case .timed(let duration):
            pauseEndDate = Date().addingTimeInterval(duration)
        case .smartDetect:
            pauseEndDate = nil
        case .manual:
            pauseEndDate = nil
        }
    }

    func resume() {
        isPaused = false
        pauseReason = nil
        pauseEndDate = nil
    }
}
