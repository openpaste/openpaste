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
    var screenSharingAutoHide: Bool {
        didSet { UserDefaults.standard.set(screenSharingAutoHide, forKey: Constants.screenSharingAutoHideKey) }
    }
    var urlPreviewEnabled: Bool {
        didSet { UserDefaults.standard.set(urlPreviewEnabled, forKey: Constants.urlPreviewEnabledKey) }
    }
    var blacklistedApps: [AppInfo] = []
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    var hotkeyDisplayString: String = HotkeyManager.currentHotkeyDisplayString()
    var isRecordingHotkey: Bool = false

    // Storage info
    var databaseSize: String = "—"
    var totalItemCount: Int = 0
    var itemCountByType: [ContentType: Int] = [:]

    var storageService: StorageServiceProtocol?
    @ObservationIgnored var onClearAllHistory: (() async -> Void)?

    init() {
        let defaults = UserDefaults.standard
        pollingInterval = defaults.double(forKey: "pollingInterval").nonZero ?? Constants.defaultPollingInterval
        maxItemSizeMB = defaults.integer(forKey: "maxItemSizeMB").nonZero ?? 10
        sensitiveAutoExpiry = defaults.double(forKey: "sensitiveAutoExpiry").nonZero ?? Constants.defaultSensitiveExpiry
        sensitiveDetectionEnabled = defaults.object(forKey: "sensitiveDetectionEnabled") as? Bool ?? true
        screenSharingAutoHide = defaults.object(forKey: Constants.screenSharingAutoHideKey) as? Bool ?? true
        urlPreviewEnabled = defaults.object(forKey: Constants.urlPreviewEnabledKey) as? Bool ?? true
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

    func recordHotkey(modifiers: NSEvent.ModifierFlags, characters: String) {
        guard isRecordingHotkey else { return }
        guard modifiers.contains(.command) || modifiers.contains(.control) else { return }

        let keyCode = HotkeyManager.mapCharacterToKeyCode(characters)
        guard keyCode != 0xFF else { return }

        HotkeyManager.saveHotkey(modifiers: modifiers, keyCode: keyCode)
        hotkeyDisplayString = HotkeyManager.displayString(modifiers: modifiers, keyCode: keyCode)
        isRecordingHotkey = false
    }

    func resetHotkey() {
        let defaultMods: NSEvent.ModifierFlags = [.shift, .command]
        let defaultKey: UInt16 = 0x09
        HotkeyManager.saveHotkey(modifiers: defaultMods, keyCode: defaultKey)
        hotkeyDisplayString = HotkeyManager.displayString(modifiers: defaultMods, keyCode: defaultKey)
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

    func loadStorageInfo() async {
        let dbPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OpenPaste")
            .appendingPathComponent("database.sqlite")
        if let dbPath, let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path) {
            let size = attrs[.size] as? Int64 ?? 0
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            databaseSize = formatter.string(fromByteCount: size)
        }

        guard let storageService else { return }

        // Populate total count
        if let count = try? await storageService.itemCount() {
            totalItemCount = count
        }

        // Populate count by type — fetch all items and group
        // Use a large enough limit to cover all items
        var offset = 0
        let pageSize = 500
        var typeCounts: [ContentType: Int] = [:]
        while true {
            guard let batch = try? await storageService.fetch(limit: pageSize, offset: offset) else { break }
            for item in batch {
                typeCounts[item.type, default: 0] += 1
            }
            if batch.count < pageSize { break }
            offset += batch.count
        }
        itemCountByType = typeCounts
    }

    func optimizeStorage() async {
        // Placeholder for VACUUM and expired item cleanup
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
