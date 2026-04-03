# OpenPaste Project Changelog

All notable changes to the OpenPaste project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

### Fixed

- `fix(ui)`: Use `maskImage` for reliable panel corner rounding across macOS versions
- `fix(settings)`: Correct database size calculation path
- `fix(ci)`: Skip UI tests in pre-push hook to unblock local developer workflows
- `fix(test)`: Add `UserDefaults.synchronize()` to prevent flaky CI test failures

### Performance

- `perf`: Optimized Bottom Shelf window positioning and rendering performance

---

## [Unreleased]

### Changed

#### Trust Reset & Positioning Alignment (April 2026)
- `README.md`: repositioned OpenPaste as a native, local-first clipboard manager for developers instead of leading with unshipped AI claims
- `README.md`: added explicit `Shipped Today`, `Still Maturing`, and `Planned Later` sections to reduce promise/product drift
- `prd.md`: added a status note clarifying the PRD is long-term product vision, not a claim that every feature is shipped today
- `Views/Settings/AboutView.swift`: updated in-app About messaging to match the current product story
- `docs/development-roadmap.md`: added the active first-users validation track and linked the 6-week roadmap

### Added

#### In-App Feedback Handoff (April 2026)
- `feat(settings)`: Added `Send Feedback…` entry point in Settings > About
- `feat(feedback)`: Added a local-first feedback form that pre-fills app version, macOS version, and likely install method
- `feat(feedback)`: Routes workflow feedback, bug reports, and feature requests to GitHub’s structured feedback form with pre-filled fields
- `feat(feedback)`: Routes praise / other feedback to a pre-filled Mail draft for private follow-up
- `test(feedback)`: Added route-generation and view-model tests for validation, metadata defaults, and reset behavior

#### First-Users Launch Surfaces (April 2026)
- `docs/positioning.md` — frozen 6-week positioning statement, public-message variants, and messaging guardrails
- `docs/launch-faq.md` — honest FAQ covering privacy, sync, encryption, and roadmap status
- `docs/feedback-template.md` — copy/paste template for bugs, workflow feedback, and testimonial capture
- `docs/first-users-dashboard.md` — privacy-safe weekly acquisition and retention dashboard template
- `docs/design-partner-outreach.md` — design-partner invite script and short interview plan
- `.github/ISSUE_TEMPLATE/feedback.yml` — structured workflow feedback intake form

#### UI/UX Overhaul — Design System & Liquid Glass (April 2026)
Comprehensive three-phase UI/UX overhaul delivering a centralized design system, competitive-parity features, and delight-layer polish.

**Phase 1 — Essential Polish:**
- Centralized `DS` design system enum in `Views/Shared/DesignSystem.swift` with namespaced tokens:
  - `DS.Colors` — Brand accent (`#2EC4B6`), secondary (`#6159DB`), and per-content-type colors (text, richText, image, file, link, color, code)
  - `DS.Spacing` — 7 steps: `xxs` (2pt) through `xxl` (24pt)
  - `DS.Radius` — `sm` (4pt), `md` (8pt), `lg` (12pt)
  - `DS.Animation` — `springDefault`, `springSnappy`, `springGentle`, `quick`
  - `DS.Typography` — `rowTitle`, `rowMeta`, `codePreview`, `filterChip`, `sectionHeader`
  - `DS.Shadow` — `card` (black 8% opacity, radius 4, y-offset 2)
  - `DS.Glass` — `isAvailable` flag for Liquid Glass feature detection
- Reusable `.hoverHighlight()` view modifier (`Views/Shared/HoverHighlightModifier.swift`) with configurable `cornerRadius` and `DS.Animation.quick` transitions
- Paste confirmation overlay (`Views/Shared/PasteConfirmationOverlay.swift`) — green `checkmark.circle.fill` with bounce symbol effect, ultra-thin material background, asymmetric scale+opacity transition, auto-dismiss via structured concurrency (`Task.sleep` 800ms)
- Redesigned filter chips using `DS` tokens with count badges
- `TypeIcon` sizes updated from 14pt → 18pt in 28×28 frame; colors mapped through `DS.Colors`

**Phase 2 — Competitive Parity:**
- Settings migrated from `TabView` to `NavigationSplitView` with 7 sections via `SettingsSection` enum:
  - `.general` (gear), `.privacy` (lock.shield), `.keyboard` (keyboard), `.appearance` (paintbrush), `.sync` (icloud), `.storage` (internaldrive), `.about` (info.circle)
  - Fixed frame: 650×480
- New `AppearanceSettingsView` (`Views/Settings/AppearanceSettingsView.swift`):
  - Theme picker (System / Light / Dark) via `@AppStorage(Constants.appearanceThemeKey)`
  - Window position mode (Center / Near cursor) via `@AppStorage(Constants.windowPositionModeKey)`
- New `StorageSettingsView` (`Views/Settings/StorageSettingsView.swift`):
  - Database size display, total item count, breakdown by `ContentType`
  - "Optimize Storage…" action (calls `viewModel.optimizeStorage()`)
  - Data loaded via `viewModel.loadStorageInfo()` in `.task`
- Pinned items section in `HistoryView` — items with `pinned == true` render in a dedicated section with `pin.fill` icon header styled with `DS.Colors.accent`
- Keyboard shortcut overlay (`Views/Shared/KeyboardShortcutOverlay.swift`):
  - Two sections: Navigation (`j/k`, `gg`, `G`) and Actions (`Enter`, `Tab`, `Escape`, `/`, `?`)
  - `@FocusState` management for immediate key capture; any key press dismisses
  - Ultra-thick material backdrop with `DS.Shadow.card` shadow
  - Toggled via `?` key in `HistoryView`
- Spring-based animations replacing `easeInOut` throughout — all list mutations, transitions, and state changes use `DS.Animation.springDefault` or `DS.Animation.springSnappy`
- Panel fade-in: `ContentView` applies `scaleEffect(0.96→1.0)` + `opacity(0→1)` on appear with `DS.Animation.springDefault`
- Content preview improvements: larger image previews, spring-animated transitions

**Phase 3 — Delight & Differentiation:**
- Liquid Glass integration via `.glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.md))` on tab picker in `ContentView`
- Redesigned empty state in `HistoryView`: animated clipboard icon with `.symbolEffect(.pulse.byLayer)`, shortcut hint badge (`⇧⌘V`), and scale+opacity transition
- Smart filter bar (`Views/Shared/SmartFilterBar.swift`):
  - Time range filters: "Last 24h", "Last 7 days", "Last 30 days" via `TimeRange` enum in `SearchFilters.swift`
  - Toggle filters: "Pinned", "Starred"
  - Horizontal scroll with `DS.Spacing.sm` chip spacing
- `SettingsViewModel` storage info: `databaseSize`, `totalItemCount`, `itemCountByType` properties with `loadStorageInfo()` computing counts by paginated fetch and `ByteCountFormatter`
- Cursor-positioned window mode in `WindowManager`: `positionNearCursor()` reads `Constants.windowPositionModeKey`, centers panel at mouse location clamped to visible screen frame
- Resizable window: `FloatingPanel` `minSize` 350×400, `maxSize` 700×900; `ContentView` frame constraints match

**New Files:**

| File | Purpose |
|------|---------|
| `Views/Shared/DesignSystem.swift` | Centralized `DS` enum with Colors, Spacing, Radius, Animation, Typography, Shadow, Glass tokens |
| `Views/Shared/HoverHighlightModifier.swift` | Reusable `.hoverHighlight()` ViewModifier |
| `Views/Shared/PasteConfirmationOverlay.swift` | Green checkmark flash overlay with structured concurrency auto-dismiss |
| `Views/Shared/KeyboardShortcutOverlay.swift` | `?`-key cheatsheet with `@FocusState` and key-press dismissal |
| `Views/Shared/SmartFilterBar.swift` | Time-range and pin/star filter chips |
| `Views/Settings/AppearanceSettingsView.swift` | Theme and window position settings |
| `Views/Settings/StorageSettingsView.swift` | Database size, item counts, optimize action |

**Modified Files (26 total, +634 / −77 lines):**
- `App/AppController.swift` — Wired new overlay and filter components
- `App/WindowManager.swift` — Cursor-positioned mode, `NotificationCenter` observer leak fix, resizable panel
- `ContentView.swift` — Panel fade-in animation, `.glassEffect` on tab picker, resizable frame constraints
- `Models/SearchFilters.swift` — Added `TimeRange` enum, `pinnedOnly`, `starredOnly`, `timeRange` fields
- `Utilities/Constants.swift` — Added `appearanceThemeKey`, `historyRetentionDaysKey`, `windowPositionModeKey`, `savedWindowFrameKey`
- `ViewModels/HistoryViewModel.swift` — `showPasteConfirmation` state, `MainActor.run` for thread-safe mutations in `observeEvents()`, 600ms paste confirmation timing before dismiss
- `ViewModels/SearchViewModel.swift` — Smart filter bar integration
- `ViewModels/SettingsViewModel.swift` — Storage info properties (`databaseSize`, `totalItemCount`, `itemCountByType`), `loadStorageInfo()`, `optimizeStorage()`
- `Views/Collections/CollectionListView.swift` — Brand color and DS token updates
- `Views/History/ClipboardItemRow.swift` — Hover highlight integration
- `Views/History/HistoryView.swift` — Pinned section, keyboard shortcut overlay, vim-style navigation (`j/k/gg/G`), empty state redesign, paste confirmation overlay
- `Views/PasteStack/PasteStackOverlay.swift` — Brand color and spring animation updates
- `Views/Search/SearchView.swift` — Smart filter bar integration, DS token adoption
- `Views/Settings/AboutView.swift` — Layout adjustments for NavigationSplitView
- `Views/Settings/GeneralSettingsView.swift` — Added retention days setting
- `Views/Settings/SettingsView.swift` — Migrated to `NavigationSplitView` with `SettingsSection` enum
- `Views/Shared/ContentPreviewView.swift` — Larger image previews, spring animations
- `Views/Shared/TypeIcon.swift` — 14pt → 18pt icons, colors via `DS.Colors`

#### Bottom Shelf (Paste-style) window mode (April 2026)
- New window mode option in Settings > Appearance
- Slide-up bottom panel with a horizontal card grid
- Preview pane toggle (`Tab` / `Space`)
- Shortcut hint bar
- Keyboard shortcuts: `Enter` (paste), `Shift+Enter` (paste as plain text), `⌘1`–`⌘9` (select), `d` (delete), `p` (pin), `s` (star)
- Pinboard tabs now show collection color; existing pinboard items migrated automatically

### Fixed

#### Code Review Fixes (April 2026)
- **Thread safety:** `MainActor.run` wrapping for `HistoryViewModel` item mutations in `observeEvents()` async stream handler
- **Paste confirmation timing:** 600ms `Task.sleep` delay before `dismissAction` ensures overlay is visible
- **NotificationCenter observer leak:** `WindowManager.show()` now removes previous `closeObserver` before adding a new one
- **Double opacity animation:** Removed conflicting animation on panel appearance
- **Storage counts:** `StorageSettingsView` wired to `SettingsViewModel.loadStorageInfo()` with paginated type counting
- **KeyboardShortcutOverlay focus:** `@FocusState` + `.focused()` + `.onAppear { isFocused = true }` ensures immediate key capture
- **Structured concurrency:** `PasteConfirmationOverlay` uses `.task` + `Task.sleep` instead of `DispatchQueue.main.asyncAfter`

---

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

---

## Format Rules

- Use `[Unreleased]` for pending changes
- Use semantic versioning: `[X.Y.Z] - YYYY-MM-DD`
- Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`
- Cross-reference feature names with code file names for discoverability
