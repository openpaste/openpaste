import Foundation

enum Constants {
    static let defaultPollingInterval: TimeInterval = 0.5
    static let maxItemSize: Int = 10_485_760
    static let defaultSensitiveExpiry: TimeInterval = 3600
    static let defaultHistoryPageSize: Int = 50
    static let searchDebounceInterval: TimeInterval = 0.15
    static let appName = "OpenPaste"
    static let bundleIdentifier = "dev.tuanle.OpenPaste"

    // iCloud Sync
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    static let iCloudSyncIncludeSensitiveKey = "iCloudSyncIncludeSensitive"
    static let iCloudSyncMaxItemSizeBytesKey = "iCloudSyncMaxItemSizeBytes"

    static let syncMaxRetries = 5
    static let syncRetryBaseInterval: TimeInterval = 60
    static let syncRetryMaxInterval: TimeInterval = 3600
    static let syncRetryCheckInterval: TimeInterval = 60

    // Onboarding
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let customHotkeyModifiersKey = "customHotkeyModifiers"
    static let customHotkeyKeyCodeKey = "customHotkeyKeyCode"

    // Screen Sharing
    static let screenSharingAutoHideKey = "screenSharingAutoHide"

    // Paste Stack
    static let pasteStackClearShortcutKey = "pasteStackClearShortcut"

    // URL Preview
    static let urlPreviewEnabledKey = "urlPreviewEnabled"

    // Support
    static let repositoryURLString = "https://github.com/openpaste/openpaste"
    static let issueTrackerURLString = "https://github.com/openpaste/openpaste/issues/new"
    static let supportEmail = "tuanle.works@gmail.com"

    // Appearance
    static let appearanceThemeKey = "appearanceTheme"
    static let historyRetentionDaysKey = "historyRetentionDays"
    static let windowPositionModeKey = "windowPositionMode"
    static let windowPositionModeBottomShelf = "bottomShelf"
    static let savedWindowFrameKey = "savedWindowFrame"
    static let showShortcutHintsKey = "showShortcutHints"

    // Paste Behavior
    static let pasteDirectlyKey = "pasteDirectly"

    // Monitoring Pause
    static let smartAutoPauseEnabledKey = "smartAutoPauseEnabled"
    static let showRecentItemsInMenuKey = "showRecentItemsInMenu"
    static let recentItemsCountKey = "recentItemsCount"

}
