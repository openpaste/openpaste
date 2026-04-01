# Onboarding Implementation Plan

**Status:** In Progress
**Created:** 2026-04-01
**Phases:** 3

## Overview
Full onboarding experience for OpenPaste: welcome, permissions, shortcut setup, preferences, and interactive demo.

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Onboarding ViewModel + Permission utilities | pending |
| 2 | Onboarding UI views (5 steps) | pending |
| 3 | App integration + onboarding window | pending |

## Architecture

```
OnboardingViewModel (@Observable)
├── currentStep: OnboardingStep (enum: welcome, permissions, shortcut, preferences, ready)
├── accessibilityGranted: Bool (polled via Timer)
├── selectedModifiers: NSEvent.ModifierFlags
├── selectedKeyCode: UInt16
├── launchAtLogin: Bool
├── hasCompletedOnboarding: Bool (@AppStorage)
└── Methods: nextStep(), previousStep(), skipOnboarding(), completeOnboarding()
    openAccessibilitySettings(), checkAccessibilityPermission()

OnboardingWindow (NSWindow subclass)
├── Fixed 600x500, centered, non-resizable
├── Shows only on first run
└── Closes on complete/skip → starts normal app flow

Views (5 steps):
├── OnboardingWelcomeStep — Logo, tagline, spring animation
├── OnboardingPermissionStep — Accessibility check + deep link + live status
├── OnboardingShortcutStep — Interactive key recorder
├── OnboardingPreferencesStep — Launch at login toggle
└── OnboardingReadyStep — Summary + "Try it now" button
```

## Files

### New Files
- `OpenPaste/ViewModels/OnboardingViewModel.swift`
- `OpenPaste/Views/Onboarding/OnboardingView.swift`
- `OpenPaste/Views/Onboarding/OnboardingWelcomeStep.swift`
- `OpenPaste/Views/Onboarding/OnboardingPermissionStep.swift`
- `OpenPaste/Views/Onboarding/OnboardingShortcutStep.swift`
- `OpenPaste/Views/Onboarding/OnboardingPreferencesStep.swift`
- `OpenPaste/Views/Onboarding/OnboardingReadyStep.swift`
- `OpenPaste/App/OnboardingWindowManager.swift`

### Modified Files
- `OpenPaste/App/AppController.swift` — check first-run, show onboarding window
- `OpenPaste/App/HotkeyManager.swift` — support custom key combo from UserDefaults
- `OpenPaste/Utilities/Constants.swift` — add onboarding UserDefaults keys
- `OpenPaste/OpenPasteApp.swift` — route onboarding vs main flow

### Test Files
- `OpenPasteTests/OnboardingViewModelTests.swift`
