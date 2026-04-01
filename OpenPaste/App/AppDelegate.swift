import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let showOnboardingNotification = Notification.Name("OpenPaste.showOnboarding")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Trigger onboarding after menu bar is ready
        if OnboardingViewModel.shouldShowOnboarding {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                NotificationCenter.default.post(name: Self.showOnboardingNotification, object: nil)
            }
        }
    }
}
