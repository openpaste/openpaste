import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let showOnboardingNotification = Notification.Name("OpenPaste.showOnboarding")
    static let didReceiveRemoteNotification = Notification.Name("OpenPaste.didReceiveRemoteNotification")

    private static let pendingRemoteNotificationLock = NSLock()
    private static var hasPendingRemoteNotification = false

    static func consumePendingRemoteNotification() -> Bool {
        pendingRemoteNotificationLock.lock(); defer { pendingRemoteNotificationLock.unlock() }
        let value = hasPendingRemoteNotification
        hasPendingRemoteNotification = false
        return value
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)
        NSApp.registerForRemoteNotifications()

        // Trigger onboarding after menu bar is ready
        if OnboardingViewModel.shouldShowOnboarding {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                NotificationCenter.default.post(name: Self.showOnboardingNotification, object: nil)
            }
        }
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        Self.pendingRemoteNotificationLock.lock()
        Self.hasPendingRemoteNotification = true
        Self.pendingRemoteNotificationLock.unlock()

        NotificationCenter.default.post(
            name: Self.didReceiveRemoteNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("APNs registration failed: \(error)")
    }
}
