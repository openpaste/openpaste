import Foundation

extension SettingsViewModel {
    private var blacklistKey: String { "blacklistedApps" }

    func loadBlacklist() {
        guard let data = UserDefaults.standard.data(forKey: blacklistKey),
            let decoded = try? JSONDecoder().decode([AppInfo].self, from: data)
        else {
            blacklistedApps = defaultBlacklistApps
            saveBlacklist()
            return
        }
        blacklistedApps = decoded
    }

    func saveBlacklist() {
        if let data = try? JSONEncoder().encode(blacklistedApps) {
            UserDefaults.standard.set(data, forKey: blacklistKey)
        }
    }

    private var defaultBlacklistApps: [AppInfo] {
        [
            AppInfo(bundleId: "com.apple.keychainaccess", name: "Keychain Access", iconPath: nil),
            AppInfo(bundleId: "com.agilebits.onepassword7", name: "1Password 7", iconPath: nil),
            AppInfo(
                bundleId: "com.agilebits.onepassword-osx", name: "1Password (Legacy)", iconPath: nil
            ),
            AppInfo(bundleId: "com.1password.1password", name: "1Password", iconPath: nil),
            AppInfo(bundleId: "com.bitwarden.desktop", name: "Bitwarden", iconPath: nil),
            AppInfo(bundleId: "com.lastpass.LastPass", name: "LastPass", iconPath: nil),
            AppInfo(bundleId: "com.apple.Passwords", name: "Passwords", iconPath: nil),
        ]
    }
}
