# Phase 6: Settings + Final Integration

## Priority: Medium | Status: not-started
## Dependencies: Phase 5

## Overview
Settings UI, app blacklist management, and final integration wiring all components together.

## File Ownership (EXCLUSIVE)
- `OpenPaste/Views/Settings/SettingsView.swift`
- `OpenPaste/Views/Settings/GeneralSettingsView.swift`
- `OpenPaste/Views/Settings/PrivacySettingsView.swift`
- `OpenPaste/Views/Settings/BlacklistView.swift`
- `OpenPaste/Views/Settings/AboutView.swift`
- `OpenPaste/ViewModels/SettingsViewModel.swift`
- `OpenPaste/Services/Security/SecurityService.swift`

## Implementation Steps

### 1. SettingsViewModel (@Observable, @MainActor)
- pollingInterval: TimeInterval
- maxItemSize: Int
- sensitiveAutoExpiry: TimeInterval
- blacklistedApps: [AppInfo]
- Persist to UserDefaults
- Load/save methods

### 2. SettingsView
- TabView with tabs: General, Privacy, About
- Standard macOS settings window style
- Open via menu bar menu item

### 3. GeneralSettingsView
- Polling interval slider
- Max item size picker
- Launch at login toggle
- Global shortcut display

### 4. PrivacySettingsView
- Sensitive content detection toggle
- Auto-expire duration picker
- Clear all history button (with confirmation)
- Blacklist management link

### 5. BlacklistView
- List of blacklisted apps
- Add app picker (running apps or browse)
- Remove app
- Preset apps: Keychain Access, 1Password, Bitwarden, LastPass

### 6. AboutView
- App name, version
- GitHub link
- License (MIT)

### 7. SecurityService
- Coordinates sensitive detection settings
- Manages blacklist state
- Auto-expire cleanup timer

### 8. Final Integration
- Wire SettingsViewModel to DependencyContainer
- Add Settings menu item to menu bar
- Ensure all services start on app launch
- Ensure clipboard monitoring respects blacklist
- Test end-to-end flow

## Success Criteria
- Settings persist across app launches
- Blacklist prevents capture from specified apps
- Sensitive auto-expire works
- All components integrated and functioning
- App launches as menu bar app, captures clipboard, searchable
