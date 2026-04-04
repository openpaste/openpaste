# OpenPaste UI Map

## Repo-specific rules
- Use `DS.*` tokens from `OpenPaste/Views/Shared/DesignSystem.swift`; no hardcoded colors or spacing.
- Keep SwiftUI files small and focused.
- Preserve MVVM + DI boundaries; most design fixes belong in `Views/`, sometimes `App/`.

## High-value review areas
- `OpenPaste/OpenPasteApp.swift`
- `OpenPaste/ContentView.swift`
- `OpenPaste/App/AppDelegate.swift`
- `OpenPaste/App/WindowManager.swift`
- `OpenPaste/App/OnboardingWindowManager.swift`
- `OpenPaste/Views/BottomShelf/`
- `OpenPaste/Views/History/`
- `OpenPaste/Views/Search/`
- `OpenPaste/Views/Collections/`
- `OpenPaste/Views/PasteStack/`
- `OpenPaste/Views/Settings/`
- `OpenPaste/Views/Onboarding/`
- `OpenPaste/Views/Shared/`

## What to look for in OpenPaste
- MenuBarExtra or status-item entry behavior and app-level discoverability
- Menu bar utility discoverability without relying only on the menu bar icon
- Content shell choices like the standard layout versus bottom-shelf layout
- Floating panel behavior that still feels like macOS, not a custom shell
- Search placement and scope clarity in history and search surfaces
- Settings screens that use grouped forms, clear labels, and keyboard accessibility
- Onboarding that uses progressive disclosure and avoids timed or brittle steps
- Toolbar, sidebar, and menu choices that match Mac conventions
- Sufficient contrast and accessible labels for icon-heavy UI
- Window resizing and safe placement of critical actions away from bottom edges

## Good follow-up questions
- Is this screen global app navigation or local filtering?
- Should this command also exist in the menu bar?
- Is this action critical enough to stay visible at small window sizes?
- Is the custom styling helping, or fighting system UI?
- Does this work with keyboard-only navigation and VoiceOver?