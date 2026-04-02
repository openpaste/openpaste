import Foundation
import Testing
@testable import OpenPaste

@Suite(.serialized)
struct SettingsViewModelTests {

    // MARK: - Helpers

    private func cleanupDefaults() {
        let keys = [
            "pollingInterval", "maxItemSizeMB", "sensitiveAutoExpiry",
            "sensitiveDetectionEnabled", Constants.screenSharingAutoHideKey,
            Constants.urlPreviewEnabledKey, "launchAtLogin", "blacklistedApps"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
    }

    // MARK: - Screen Sharing Auto-Hide

    @Test func screenSharingAutoHideDefaultsToTrue() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.screenSharingAutoHide == true)
    }

    @Test func screenSharingAutoHideToggle() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        vm.screenSharingAutoHide = false
        #expect(UserDefaults.standard.bool(forKey: Constants.screenSharingAutoHideKey) == false)

        vm.screenSharingAutoHide = true
        #expect(UserDefaults.standard.bool(forKey: Constants.screenSharingAutoHideKey) == true)
    }

    @Test func screenSharingAutoHidePersistsAcrossInstances() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm1 = SettingsViewModel()
        vm1.screenSharingAutoHide = false
        UserDefaults.standard.synchronize()

        let vm2 = SettingsViewModel()
        #expect(vm2.screenSharingAutoHide == false)
    }

    // MARK: - URL Preview Enabled

    @Test func urlPreviewEnabledDefaultsToTrue() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.urlPreviewEnabled == true)
    }

    @Test func urlPreviewEnabledToggle() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        vm.urlPreviewEnabled = false
        #expect(UserDefaults.standard.bool(forKey: Constants.urlPreviewEnabledKey) == false)

        vm.urlPreviewEnabled = true
        #expect(UserDefaults.standard.bool(forKey: Constants.urlPreviewEnabledKey) == true)
    }

    @Test func urlPreviewEnabledPersistsAcrossInstances() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm1 = SettingsViewModel()
        vm1.urlPreviewEnabled = false
        UserDefaults.standard.synchronize()

        let vm2 = SettingsViewModel()
        #expect(vm2.urlPreviewEnabled == false)
    }

    // MARK: - Sensitive Detection Enabled

    @Test func sensitiveDetectionEnabledDefaultsToTrue() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.sensitiveDetectionEnabled == true)
    }

    @Test func sensitiveDetectionEnabledToggle() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        vm.sensitiveDetectionEnabled = false
        #expect(UserDefaults.standard.bool(forKey: "sensitiveDetectionEnabled") == false)
    }

    // MARK: - Polling Interval

    @Test func pollingIntervalDefault() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.pollingInterval == Constants.defaultPollingInterval)
    }

    @Test func pollingIntervalPersists() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        vm.pollingInterval = 1.5
        #expect(UserDefaults.standard.double(forKey: "pollingInterval") == 1.5)
    }

    // MARK: - Max Item Size

    @Test func maxItemSizeMBDefault() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.maxItemSizeMB == 10)
    }

    @Test func maxItemSizeMBPersists() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        vm.maxItemSizeMB = 20
        #expect(UserDefaults.standard.integer(forKey: "maxItemSizeMB") == 20)
    }

    // MARK: - Sensitive Auto Expiry

    @Test func sensitiveAutoExpiryDefault() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        #expect(vm.sensitiveAutoExpiry == Constants.defaultSensitiveExpiry)
    }

    // MARK: - Blacklist

    @Test func blacklistedAppsLoadDefaults() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        // Should have default blacklisted apps (password managers)
        #expect(!vm.blacklistedApps.isEmpty)
        #expect(vm.blacklistedApps.contains(where: { $0.bundleId == "com.apple.keychainaccess" }))
    }

    @Test func addBlacklistedApp() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        let initialCount = vm.blacklistedApps.count
        let newApp = AppInfo(bundleId: "com.test.app", name: "Test App", iconPath: nil)
        vm.addBlacklistedApp(newApp)

        #expect(vm.blacklistedApps.count == initialCount + 1)
        #expect(vm.blacklistedApps.contains(where: { $0.bundleId == "com.test.app" }))
    }

    @Test func addDuplicateBlacklistedAppIgnored() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        let newApp = AppInfo(bundleId: "com.test.unique", name: "Test", iconPath: nil)
        vm.addBlacklistedApp(newApp)
        let countAfterFirst = vm.blacklistedApps.count
        vm.addBlacklistedApp(newApp)
        #expect(vm.blacklistedApps.count == countAfterFirst)
    }

    @Test func removeBlacklistedApp() {
        cleanupDefaults()
        defer { cleanupDefaults() }

        let vm = SettingsViewModel()
        let app = AppInfo(bundleId: "com.test.removable", name: "Removable", iconPath: nil)
        vm.addBlacklistedApp(app)
        let countBefore = vm.blacklistedApps.count
        vm.removeBlacklistedApp(app)
        #expect(vm.blacklistedApps.count == countBefore - 1)
        #expect(!vm.blacklistedApps.contains(where: { $0.bundleId == "com.test.removable" }))
    }
}
