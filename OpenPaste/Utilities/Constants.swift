import Foundation

enum Constants {
    static let defaultPollingInterval: TimeInterval = 0.5
    static let maxItemSize: Int = 10_485_760
    static let defaultSensitiveExpiry: TimeInterval = 3600
    static let defaultHistoryPageSize: Int = 50
    static let searchDebounceInterval: TimeInterval = 0.15
    static let appName = "OpenPaste"
    static let bundleIdentifier = "com.openshot.OpenPaste"

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

    // Appearance
    static let appearanceThemeKey = "appearanceTheme"
    static let historyRetentionDaysKey = "historyRetentionDays"
    static let windowPositionModeKey = "windowPositionMode"
    static let savedWindowFrameKey = "savedWindowFrame"
}
