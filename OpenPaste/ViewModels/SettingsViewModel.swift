import Foundation
import AppKit
import ServiceManagement

@Observable
final class SettingsViewModel {
    var pollingInterval: TimeInterval {
        didSet { UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval") }
    }
    var maxItemSizeMB: Int {
        didSet { UserDefaults.standard.set(maxItemSizeMB, forKey: "maxItemSizeMB") }
    }
    var sensitiveAutoExpiry: TimeInterval {
        didSet { UserDefaults.standard.set(sensitiveAutoExpiry, forKey: "sensitiveAutoExpiry") }
    }
    var sensitiveDetectionEnabled: Bool {
        didSet { UserDefaults.standard.set(sensitiveDetectionEnabled, forKey: "sensitiveDetectionEnabled") }
    }
    var blacklistedApps: [AppInfo] = []
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    var onClearAllHistory: (() async -> Void)?

    init() {
        let defaults = UserDefaults.standard
        pollingInterval = defaults.double(forKey: "pollingInterval").nonZero ?? Constants.defaultPollingInterval
        maxItemSizeMB = defaults.integer(forKey: "maxItemSizeMB").nonZero ?? 10
        sensitiveAutoExpiry = defaults.double(forKey: "sensitiveAutoExpiry").nonZero ?? Constants.defaultSensitiveExpiry
        sensitiveDetectionEnabled = defaults.object(forKey: "sensitiveDetectionEnabled") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled

        loadBlacklist()
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — user may not have granted permission
        }
    }

    func addBlacklistedApp(_ app: AppInfo) {
        guard !blacklistedApps.contains(where: { $0.bundleId == app.bundleId }) else { return }
        blacklistedApps.append(app)
        saveBlacklist()
    }

    func removeBlacklistedApp(_ app: AppInfo) {
        blacklistedApps.removeAll { $0.bundleId == app.bundleId }
        saveBlacklist()
    }

    func clearAllHistory(storageService: StorageServiceProtocol) async {
        // Delete all items by fetching and deleting in batches
        while let items = try? await storageService.fetch(limit: 100, offset: 0), !items.isEmpty {
            for item in items {
                try? await storageService.delete(item.id)
            }
        }
    }

    private func loadBlacklist() {
        guard let data = UserDefaults.standard.data(forKey: "blacklistedApps"),
              let decoded = try? JSONDecoder().decode([AppInfo].self, from: data) else {
            blacklistedApps = defaultBlacklistApps
            return
        }
        blacklistedApps = decoded
    }

    private func saveBlacklist() {
        if let data = try? JSONEncoder().encode(blacklistedApps) {
            UserDefaults.standard.set(data, forKey: "blacklistedApps")
        }
    }

    private var defaultBlacklistApps: [AppInfo] {
        [
            AppInfo(bundleId: "com.apple.keychainaccess", name: "Keychain Access", iconPath: nil),
            AppInfo(bundleId: "com.agilebits.onepassword7", name: "1Password 7", iconPath: nil),
            AppInfo(bundleId: "com.agilebits.onepassword-osx", name: "1Password", iconPath: nil),
            AppInfo(bundleId: "com.bitwarden.desktop", name: "Bitwarden", iconPath: nil),
            AppInfo(bundleId: "com.lastpass.LastPass", name: "LastPass", iconPath: nil),
            AppInfo(bundleId: "com.apple.Passwords", name: "Passwords", iconPath: nil),
        ]
    }
}
