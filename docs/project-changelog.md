# OpenPaste Project Changelog

All notable changes to the OpenPaste project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

#### Onboarding Feature (April 2026)
Complete first-launch onboarding experience with step-by-step guided setup.

**Components:**
- 5-step onboarding flow: Welcome → Permissions → Shortcut → Preferences → Ready
- `OnboardingViewModel` — State management and navigation logic
- `OnboardingView` — Container view with spring animations and progress indicators
- `OnboardingWindowManager` — NSWindow-based presentation (first launch detection)
- Step views: `WelcomeStepView`, `PermissionsStepView`, `ShortcutStepView`, `PreferencesStepView`, `ReadyStepView`

**Features:**
- Accessibility permission check with `AXIsProcessTrusted()` + System Settings deep link
- Live permission status polling with auto-detection when user grants access
- Interactive hotkey recorder UI for customizable global shortcut configuration
- Custom key combination saved to `UserDefaults` with automatic loading by `HotkeyManager`
- Launch at login configuration during onboarding flow
- Spring animations and staggered reveal animations for UI polish
- Progress indicator dots showing current step
- Responsive layout adapting to window size
- Back/Next navigation with previous step disabling on first step

**Tests:**
- 20 unit tests in `OnboardingViewModelTests.swift` covering:
  - Initial state validation (default step, total steps, default hotkey)
  - Navigation logic (next/previous step transitions)
  - Progress calculation and state tracking
  - Hotkey customization and persistence
  - Permission polling and status updates
  - Launch at login settings

**Integration:**
- Modified `AppDelegate` for first-launch detection and window presentation
- Modified `AppController` to coordinate onboarding flow
- Modified `HotkeyManager` to load custom hotkeys from UserDefaults
- Updated `Constants.swift` with onboarding-related key strings
- Updated `OpenPasteApp` to support onboarding workflow

**Breaking Changes:** None

---

## Format Rules

- Use `[Unreleased]` for pending changes
- Use semantic versioning: `[X.Y.Z] - YYYY-MM-DD`
- Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`
- Cross-reference feature names with code file names for discoverability
