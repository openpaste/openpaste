//
//  SmartPauseDetector.swift
//  OpenPaste
//

import AppKit
import Foundation

@MainActor
final class SmartPauseDetector {
    static let sensitiveAppBundleIds: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.dashlane.dashlanephonefinal",
        "com.keepersecurity.keeper",
    ]

    var onSensitiveAppActivated: ((String) -> Void)?
    var onSensitiveAppDeactivated: (() -> Void)?

    private var isTrackingSensitiveApp = false
    nonisolated(unsafe) private var activationObserver: NSObjectProtocol?
    nonisolated(unsafe) private var deactivationObserver: NSObjectProtocol?

    func startMonitoring() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppActivation(notification)
            }
        }

        deactivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleAppDeactivation(notification)
            }
        }
    }

    func stopMonitoring() {
        if let obs = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            activationObserver = nil
        }
        if let obs = deactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            deactivationObserver = nil
        }
        isTrackingSensitiveApp = false
    }

    deinit {
        if let obs = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let obs = deactivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              Self.sensitiveAppBundleIds.contains(bundleId)
        else { return }

        isTrackingSensitiveApp = true
        let appName = app.localizedName ?? bundleId
        onSensitiveAppActivated?(appName)
    }

    private func handleAppDeactivation(_ notification: Notification) {
        guard isTrackingSensitiveApp,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              Self.sensitiveAppBundleIds.contains(bundleId)
        else { return }

        isTrackingSensitiveApp = false
        onSensitiveAppDeactivated?()
    }
}
