# OpenPaste — Copilot Instructions

## Project Info
- **Platform**: macOS (SwiftUI, Swift 6)
- **Bundle ID**: `dev.tuanle.OpenPaste`
- **Build**: Xcode project (`OpenPaste.xcodeproj`)
- **Architecture**: MVVM with dependency injection (`DependencyContainer`)

## Fresh Install / Reset All Data
When asked to reset, fresh install, or clear all app data, run:
```bash
defaults delete dev.tuanle.OpenPaste
rm -rf "$HOME/Library/Application Support/dev.tuanle.OpenPaste" "$HOME/Library/Application Support/OpenPaste" "$HOME/Library/Caches/dev.tuanle.OpenPaste" "$HOME/Library/Saved Application State/dev.tuanle.OpenPaste.savedState"
```
This clears: UserDefaults (onboarding, hotkey, settings), database (clipboard history sqlite), caches, and window saved state. macOS Accessibility permission is NOT affected.

## Build & Verify
After code changes, always compile-check:
```bash
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste -destination 'platform=macOS' build 2>&1 | tail -10
```

## Key Paths
- **App entry**: `OpenPaste/OpenPasteApp.swift`
- **App controller**: `OpenPaste/App/AppController.swift`
- **Models**: `OpenPaste/Models/`
- **ViewModels**: `OpenPaste/ViewModels/`
- **Views**: `OpenPaste/Views/`
- **Services**: `OpenPaste/Services/`
- **Tests**: `OpenPasteTests/`
- **Database**: `OpenPaste/Services/Storage/DatabaseManager.swift` (GRDB + SQLite)

## Conventions
- Use `@Observable` (not `ObservableObject`) — Swift Observation framework
- Use `@MainActor` for all ViewModels and UI-related classes
- Use `async/await` for concurrency, not Combine (except where unavoidable)
- Constants go in `OpenPaste/Utilities/Constants.swift`
- Keep files under 200 lines
