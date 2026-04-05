import Foundation
import Sparkle

@MainActor
final class DisabledUpdaterService: UpdaterServiceProtocol {
    var canCheckForUpdates = false
    var automaticallyChecksForUpdates = false

    func checkForUpdates() {}
}

/// Wraps Sparkle's SPUStandardUpdaterController for SwiftUI integration.
/// Uses KVO to bridge `canCheckForUpdates` into Swift Observation.
@MainActor @Observable
final class UpdaterService: UpdaterServiceProtocol {
    var canCheckForUpdates = false

    @ObservationIgnored
    private let updaterController: SPUStandardUpdaterController

    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    init() {
        // Don't start updater in DEBUG builds to avoid EdDSA key validation errors
        #if DEBUG
        let shouldStart = false
        #else
        let shouldStart = true
        #endif

        updaterController = SPUStandardUpdaterController(
            startingUpdater: shouldStart,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        observation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, _ in
            Task { @MainActor in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
