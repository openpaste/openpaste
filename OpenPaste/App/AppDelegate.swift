import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let showOnboardingNotification = Notification.Name("OpenPaste.showOnboarding")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Trigger onboarding after menu bar is ready
        if OnboardingViewModel.shouldShowOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NotificationCenter.default.post(name: Self.showOnboardingNotification, object: nil)
            }
        }
    }
}
