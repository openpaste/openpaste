# OpenPaste Project Changelog

All notable changes to the OpenPaste project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed

- `chore(release)`: enabled repo auto-merge so protected `develop -> main` release PRs can use `gh pr merge --auto` instead of requiring a second manual merge after CI turns green
- `ci(workflows)`: upgraded official GitHub Actions pins in CI/release workflows to Node 24-ready versions where available (`actions/checkout`, `actions/upload-artifact`)
- `ci(release)`: replaced JavaScript-based GitHub Release publishing and Homebrew tap dispatch steps with `gh` CLI commands so release reruns are idempotent and stop depending on Node 20-only actions
- `fix(release)`: release workflow reruns now skip duplicate GitHub Release asset uploads and duplicate Sparkle appcast entries for the same tag, while suppressing the Homebrew dispatch once the tap already reflects that version
- `.gitignore`: now ignores generated root-level `OpenPaste-*.dmg` artifacts to keep local release experiments out of future ship commits

## [1.3.1] — 2026-04-04

### Added

- `test(update)`: added an opt-in installed-app Sparkle UI validation path in `OpenPasteUITests/OpenPasteUITests.swift` for local end-to-end updater verification

### Fixed

- `fix(update)`: enabled Sparkle’s required installer launcher XPC service in `OpenPaste/Info.plist` and added the documented `-spks` / `-spki` mach-lookup entitlement exceptions so sandboxed builds can hand off update installation instead of failing with “An error occurred while launching the installer.”

### Changed

- `docs/release-guide.md`: aligned the release guide with the real git-flow release process, including `main..develop` analysis, pipefail-safe test commands, semver-matched `CURRENT_PROJECT_VERSION`, explicit wait/re-check after auto-merge, and the actual Sparkle appcast update flow
- `.github/workflows/release.yml`: GitHub Releases now build the public release body directly from `RELEASE_NOTES.md` in the tagged commit instead of reconstructing it from git tag contents

## [1.3.0] — 2026-04-04

### Added

#### In-App Feedback Handoff (April 2026)
- `feat(settings)`: Added `Send Feedback…` to Settings > About
- `feat(feedback)`: Added a local-first feedback form that pre-fills app version, macOS version, and likely install method
- `feat(feedback)`: Routes workflow feedback, bug reports, and feature requests to GitHub’s structured feedback form with pre-filled fields
- `feat(feedback)`: Routes praise and general feedback to a pre-filled Mail draft for private follow-up
- `test(feedback)`: Added route-generation and view-model tests for validation, metadata defaults, and reset behavior

#### First-Users Launch Surfaces (April 2026)
- Added `docs/positioning.md`, `docs/launch-faq.md`, `docs/feedback-template.md`, `docs/first-users-dashboard.md`, and `docs/design-partner-outreach.md`
- Added `.github/ISSUE_TEMPLATE/feedback.yml` for structured workflow feedback intake
- Added `.github/skills/apple-hig-review/` guidance and reference docs to support future macOS UI audits

### Changed

#### Trust Reset & Positioning Alignment (April 2026)
- `README.md`: repositioned OpenPaste as a native, local-first clipboard manager for developers instead of leading with unshipped AI claims
- `README.md`: added explicit `Shipped Today`, `Still Maturing`, and `Planned Later` sections to reduce promise/product drift
- `prd.md`: clarified that the PRD is a longer-term product vision, not a claim that every feature is already shipped
- `Views/Settings/AboutView.swift`: updated in-app About messaging to match the current product story
- `Views/Settings/SettingsView.swift`: renamed the sync section label to `Sync (Premium Beta)` for clearer expectations in Settings
- Developer docs now reflect the macOS 15+ and Xcode 16+ minimum baseline
- Release automation stopped generating GitHub Release notes from commit history and moved toward explicit release-note inputs

### Fixed

#### Bottom Shelf Interaction Responsiveness (April 2026)
- `fix(bottomShelf)`: Replaced competing single-click and double-click tap gestures on `ClipboardCard` with a native button click path so selection highlights immediately without waiting for macOS double-click disambiguation
- `fix(bottomShelf)`: Preserved double-click paste by routing card activation through `NSApp.currentEvent.clickCount` instead of stacked SwiftUI tap recognizers
- `fix(bottomShelf)`: Synced search focus with card selection and suspended `ShelfKeyboardSink` while a sheet or text responder owns input to avoid Delete/arrow key interception in the “New Pinboard” flow
- `fix(bottomShelf)`: Cached original image dimensions in `ThumbnailCache` so image card footers stop decoding full image data on every selection rerender
- `fix(code)`: Precompiled `SyntaxHighlightedCode` regex rules to reduce repeated work when code cards re-render during Bottom Shelf selection changes

---

## [1.2.0] — 2026-04-03

### Added

#### iCloud Sync via CKSyncEngine (April 2026)
Foundation for real-time clipboard sync across devices using CloudKit.

- `feat(sync)`: Introduced iCloud sync foundation with CKSyncEngine integration
- `feat(sync)`: Added lifecycle management with start/stop coordination
- `feat(sync)`: Added outbox callback to notify CKSyncEngine of new changes
- `feat(sync)`: Handle CloudKit push notifications for real-time sync
- `feat(sync)`: Added synced item count, sync observer, and UI indicators in Settings
- APNs entitlements added for push notification delivery (`chore(push)`)
- Database + iCloud sync architecture documented (`docs`)

#### Clipboard Enhancements (April 2026)
- `feat(clipboard)`: Duplicate copied items are deduplicated — existing item moves to top of history instead of creating a new entry
- `feat(clipboard)`: Enhanced paste functionality with target app awareness and structured logging
- `feat(viewmodels)`: Pinned items are now sorted consistently in History and Search view models

#### Direct Paste & Drag-Drop (April 2026)
- `feat(settings)`: New toggle for direct pasting behavior (paste immediately without panel interaction)
- `feat(history)`: Direct paste logic wired into paste function
- `feat(bottomShelf)`: Drag-and-drop reordering for clipboard items in Bottom Shelf mode

#### Release Infrastructure (April 2026)
- `feat(release)`: Dynamic release body generation from commit history; structured release notes in GitHub Releases

#### UI & Settings Refresh (April 2026)
- Centralized `DS` design system tokens for colors, spacing, radius, animation, typography, shadow, and Liquid Glass feature detection
- Added reusable hover highlight, paste confirmation, keyboard shortcut overlay, and smart filter bar components
- Migrated Settings from `TabView` to `NavigationSplitView` with six sections: General, Privacy, Keyboard, Appearance, Storage, and About
- Added `AppearanceSettingsView` for theme and window-position controls
- Added `StorageSettingsView` for database size, item counts, and storage optimization actions
- Improved History and Search presentation with pinned sections, larger previews, spring animations, empty-state polish, and cursor-positioned windows

#### Bottom Shelf (Paste-style) Window Mode (April 2026)
- Added a new window mode option in Settings > Appearance
- Added a slide-up bottom panel with a horizontal card grid, preview toggle, and shortcut hint bar
- Added keyboard shortcuts for paste, plain-text paste, quick selection, delete, pin, and star actions
- Pinboard tabs now show collection color; existing pinboard items migrate automatically

#### Onboarding Feature (April 2026)
- Added a 5-step onboarding flow: Welcome → Permissions → Shortcut → Preferences → Ready
- Added onboarding state management, window presentation, permission polling, and a custom hotkey recorder
- Added launch-at-login setup and onboarding coverage in `OnboardingViewModelTests.swift`

#### Sparkle Auto-Update Framework (April 2026)
In-app automatic update system powered by Sparkle 2.9.1 with EdDSA code signing.

**Components:**
- **Sparkle 2.9.1** SPM dependency — industry-standard macOS app updater
- `UpdaterService` (@Observable wrapper) at `Services/UpdaterService.swift` — Observable facade around `SPUStandardUpdaterController`
- `UpdaterServiceProtocol` at `Services/Protocols/UpdaterServiceProtocol.swift` — Protocol for dependency injection
- `Info.plist` configuration — `SUFeedURL` (appcast location) + `SUPublicEDKey` (EdDSA verification key)
- **Appcast hosting** — GitHub Pages at `https://openpaste.github.io/openpaste/appcast.xml`

**UI Integration:**
- MenuBar: "Check for Updates…" menu item in app menu (manually triggered check)
- Settings > General: "Automatically check for updates" toggle via `@AppStorage(Constants.autoCheckUpdatesKey)`
- Settings > About: "Check for Updates…" button with update status feedback
- `SettingsViewModel` — Property `autoCheckUpdates` wired to Sparkle config

**CI/CD Pipeline (release.yml):**
- **EdDSA signing:** Generate ephemeral 25519 keypair during build; sign DMG + appcast.xml
- **Appcast generation:** `generate_appcast` tool creates versioned feed with delta patches
- **GitHub Pages deployment:** DMG + appcast.xml pushed to `gh-pages` branch via `peaceiris/actions-gh-pages@v4`
- **Update cycle:** Tag push → build → sign → DMG → appcast gen → GitHub Pages deploy

**Files:**
- `Info.plist` — SUFeedURL, SUPublicEDKey (committed; private key in Actions secrets)
- `.github/workflows/release.yml` — DMG signing + appcast generation steps
- `docs/release-guide.md` — EdDSA key generation and SPARKLE_EDDSA_PRIVATE_KEY secret setup

**Secrets (GitHub Actions):**
- `SPARKLE_EDDSA_PRIVATE_KEY` — Base64-encoded Ed25519 private key (imported during build)

**Breaking Changes:** None

### Fixed

- `fix(ui)`: Use `maskImage` for reliable panel corner rounding across macOS versions
- `fix(settings)`: Correct database size calculation path
- `fix(ci)`: Skip UI tests in pre-push hook to unblock local developer workflows
- `fix(test)`: Add `UserDefaults.synchronize()` to prevent flaky CI test failures

#### Code Review Fixes (April 2026)
- Wrapped `HistoryViewModel.observeEvents()` item mutations in `MainActor.run` for thread safety
- Ensured paste confirmation stays visible before dismissal by using a 600ms delay
- Removed the previous `WindowManager.show()` close observer before adding a new one
- Wired `StorageSettingsView` to paginated storage counts from `SettingsViewModel.loadStorageInfo()`
- Ensured `KeyboardShortcutOverlay` captures focus immediately on appearance
- Moved paste confirmation auto-dismiss logic to structured concurrency

### Performance

- `perf`: Optimized Bottom Shelf window positioning and rendering performance

---

## [1.0.0] — 2026-04-02

### Added

#### Distribution & CI/CD Pipeline (April 2026)
Full release pipeline: code signing, Apple notarization, DMG packaging, GitHub Releases, and Homebrew Cask distribution.

- **Bundle ID** changed from `com.openshot.OpenPaste` to `dev.tuanle.OpenPaste` (6 locations in `project.pbxproj` + `Constants.swift`)
- **Code signing:** Developer ID Application certificate (Team ID: `VGQU7EVXZV`)
- **Notarization:** Apple `notarytool submit --wait` + `stapler staple` — app passes Gatekeeper
- **DMG packaging:** `scripts/create-dmg.sh` — creates compressed DMG with /Applications symlink
- **GitHub Actions:** `.github/workflows/release.yml` — tag push triggers: build → sign → notarize → staple → DMG → GitHub Release → Homebrew tap update
- **Homebrew Cask:** `openpaste/homebrew-tap` repo with `Casks/openpaste.rb` — auto-updated via `repository-dispatch` on every release
- **Installation:** `brew tap openpaste/tap && brew install --cask openpaste`
- **Version format:** Semver `X.Y.Z` (`MARKETING_VERSION` in 6 build configs must match git tag)

**New Files:**

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | CI/CD: build, sign, notarize, release, update Homebrew |
| `scripts/create-dmg.sh` | DMG creation script with SHA-256 output |
| `docs/release-guide.md` | Step-by-step release procedure document |
| `docs/system-architecture.md` | Full architecture overview |

### Fixed
- `SettingsViewModel.onClearAllHistory` — added `@ObservationIgnored` to fix Swift 6.2 `@Observable` macro type conflict with `nonisolated(nonsending)` closure type

---

## Format Rules

- Use `[Unreleased]` for pending changes
- Use semantic versioning: `[X.Y.Z] - YYYY-MM-DD`
- Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`
- Cross-reference feature names with code file names for discoverability
