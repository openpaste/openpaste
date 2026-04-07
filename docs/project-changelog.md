# OpenPaste Project Changelog

All notable changes to the OpenPaste project are documented in this file. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Fixed
- `fix(bottomShelf)`: Bottom Shelf drag-to-other-app regression — summary-based `NSItemProvider` export was using lossy/truncated `ClipboardItemSummary` data instead of canonical full-item helpers. Now routes summary drags back through canonical `ClipboardTransferSupport` export logic (`BottomShelfView`, `ClipboardTransferSupport`)

### Testing
- `test(drag)`: Added regression coverage for long text export, rich text HTML→RTF conversion, and sourceURL-backed links in Bottom Shelf drag sessions (`ClipboardTransferSupportTests`)

## [1.6.0] — 2026-04-06

### Added
- `feat(bottomShelf)`: Bottom Shelf cards can now be dragged directly into other macOS apps while still supporting in-shelf reordering via a private reorder payload (`BottomShelfView`, `ClipboardTransferSupport`, `BottomShelfPanel`)
- `feat(uitest)`: Configurable window mode, shortcut hints, and text seed items for E2E test scenarios (`AppController`)

### Fixed
- `fix(hotkey)`: Replace NSEvent global/local monitors with a session-scoped `CGEvent` tap that swallows the configured hotkey before it reaches the foreground app, preventing `⇧⌘V` from triggering "Paste and Match Style" in Safari, Notes, and Pages (`HotkeyManager`)
- `fix(permissions)`: Open System Settings Accessibility pane directly and reveal the app bundle in Finder, working around App Sandbox suppressing `kAXTrustedCheckOptionPrompt` (`OnboardingViewModel`, `GeneralSettingsView`)
- `fix(statusBar)`: Build status bar menu synchronously in `menuWillOpen` so AppKit sees items before displaying (`StatusBarController`)

### Testing
- `test(drag)`: Unit, integration, and E2E coverage for drag payload generation, pasteboard export, drag-session lifecycle, and Bottom Shelf reorder / drag-hint flows (`ClipboardTransferSupportTests`, `ClipboardCopyIntegrationTests`, `BottomShelfPanelDragSessionTests`, `HistoryViewModelReorderTests`, `OpenPasteE2EBottomShelfDragTests`)
- `test(hotkey)`: CGEvent flag matching, auto-repeat rejection, and recording suspension token tests (`HotkeyManagerTests`)

## [1.5.1] — 2026-04-06

### Fixed
- `fix(settings)`: Use SwiftUI `openSettings` environment for reliable Settings window opening; cache menu items to prevent repeated `didChangeImage` warnings (`SettingsViewModel`, `AppController`)
- `fix(sync)`: Prevent infinite loop in SyncService `accountChange(.signIn)` handler — added `isResetting` re-entrancy guard (`SyncService`)

### Changed
- `refactor(storage)`: Simplify path resolution with standard `FileManager.urls(for:in:)` API instead of manual container path construction (`DatabaseManager`)

### Testing
- `test(e2e)`: Add Settings window E2E tests — verifies all sections appear and navigation between sections works (`OpenPasteE2ESettingsTests`)

## [1.5.0] — 2026-04-06

### Added

#### iCloud Sync Stabilization (April 2026)
Production-hardening pass for iCloud sync: 16 tasks across reliability, data integrity, and observability.

**Reliability & Network (A-track):**
- `feat(sync)`: Retry engine with exponential backoff — periodic 60s check loop, `min(60 × 2^retryCount, 3600)` delay, max 5 retries per outbox entry (`SyncService.startRetryLoop()`, `retryFailedOutboxEntries()`)
- `feat(sync)`: `NWPathMonitor` network reachability monitor — defers engine creation when offline, auto-starts sync on reconnect (`SyncService.startNetworkMonitor()`)
- `feat(sync)`: iCloud account status validation before `CKSyncEngine` creation; guards on `CKAccountStatus`
- `feat(sync)`: Account change event handling — `signIn` resets and restarts, `signOut` stops engine, `switchAccounts` resets sync data (`SyncService.handleAccountChange(_:)`)
- `feat(sync)`: CloudKit rate limit handling — detects `requestRateLimited`, `zoneBusy`, `serviceUnavailable` via `isRetryableCloudKitError(_:)` and respects server `retryAfterSeconds` (`SyncService+Send.swift`)
- `feat(sync)`: Max item size picker in Settings — `SyncSettingsView` adds a "Max item size to sync" picker (Unlimited, 1 MB, 5 MB, 10 MB) stored via `iCloudSyncMaxItemSizeBytes`

**Data Integrity (B-track):**
- `fix(sync)`: Proper GRDB upsert — replaced insert-catch-update with `record.save(db)` for atomic upsert semantics (`SmartListService.save(_:)`, outbox flows)
- `feat(sync)`: Zone-not-found recovery — detects `CKError.zoneNotFound`, auto-recreates `OpenPasteZone`, and re-enqueues all local records as pending (`SyncService+Send.swift`, `SyncService+EngineState.swift`)
- `feat(sync)`: Progress reporting — tracks `syncTotalPending` / `syncCompletedCount` and emits `SyncStatus.syncing(progress:)` with percentage during send sessions
- `feat(sync)`: `EventBus.emit(.clipboardChanged)` after remote apply so UI refreshes immediately when new items arrive from other devices (`SyncService+RemoteApply.swift`)
- `feat(sync)`: Tombstone cleanup — purges soft-deleted synced items and Smart Lists older than 30 days on each engine start (`SyncService+Outbox.cleanupTombstones()`)
- `feat(sync)`: `sync_metadata` pruning — caps table at 10,000 synced entries, deletes oldest surplus (`SyncService+Outbox.pruneSyncMetadata(keepCount:)`)

**UI & Observability (C-track):**
- `feat(sync)`: First sync progress indicator — shows "Initial sync in progress…" with `ProgressView` when `syncLastSyncDate` is nil and sync is active (`SyncSettingsView`)
- `feat(sync)`: Sync conflict notification logging — `ConflictResolver` uses LWW merge with field-level semantics (tags: set-union, booleans: true-wins, counters: max) for all record types
- `feat(sync)`: Sync health dashboard in Settings — shows synced count, pending changes, error count, last error message, and last sync timestamp (`SyncSettingsView`)
- `feat(sync)`: Device name display in sync settings — shows `syncDeviceName` in "This device" row (`SyncSettingsView`)

#### Smart Lists / Rules Engine (April 2026)
Dynamic, rule-based clipboard filtering: 14 tasks covering data model, service layer, UI, and sync integration.

**Data Model & Service (A-track):**
- `feat(smartLists)`: `SmartList` + `SmartListRule` data models — 11 rule fields (`contentType`, `sourceApp`, `createdDate`, `textContains`, `textRegex`, `contentLength`, `tag`, `pinned`, `starred`, `isSensitive`, `ocrText`), 10 comparison operators, `MatchMode.all` / `.any` (`Models/SmartList.swift`)
- `feat(smartLists)`: Database migration `v8_createSmartLists` — new `smartLists` table with id, name, icon, color, rules (JSON), matchMode, sortOrder, isBuiltIn, position, createdAt, modifiedAt, deviceId, isDeleted, ckSystemFields (`Migrations.swift`)
- `feat(smartLists)`: `SmartListService` — full CRUD via `SmartListServiceProtocol`, evaluate (rules → matching items), `countMatches`, `seedPresetsIfNeeded`, `exportAsJSON`, `importFromJSON` (`Services/SmartList/SmartListService.swift`)
- `feat(smartLists)`: `SmartListQueryBuilder` — translates rules to SQL WHERE predicates with proper escaping; regex rules use post-fetch `NSRegularExpression` filter; supports relative date parsing (`today`, `-24h`, `-7d`, ISO 8601) (`Services/SmartList/SmartListQueryBuilder.swift`)
- `feat(smartLists)`: 5 built-in presets seeded on first launch — Today, Images, Links, Code Snippets, Sensitive (`SmartListService.builtInPresets`)

**UI (B-track):**
- `feat(smartLists)`: Vertical mode 3-tab picker — `ContentView` now uses `enum Tab { case history, smartLists, collections }` with a `Picker` for switching views (`ContentView.swift`)
- `feat(smartLists)`: `SmartListSidebarView` — list with SF Symbol icons, match count badges, and context menus for edit/delete (`Views/SmartLists/SmartListSidebarView.swift`)
- `feat(smartLists)`: `PinboardTabBar` extension — Smart List tabs appear in bottom shelf mode for quick access
- `feat(smartLists)`: `SmartListEditorView` — full rule builder sheet with icon/color pickers, add/remove rules, match mode toggle (`Views/SmartLists/SmartListEditorView.swift`)
- `feat(smartLists)`: `SmartListViewModel` — `@Observable` with EventBus integration, debounced 500ms count refresh, selection-based item evaluation (`ViewModels/SmartListViewModel.swift`)

**Integration (C-track):**
- `feat(smartLists)`: Live badge counts — event-driven refresh debounced at 500ms, triggered by `clipboardChanged`, `itemStored`, and `syncCompleted` events (`SmartListViewModel.scheduleCountRefresh()`)
- `feat(smartLists)`: iCloud sync for Smart Lists — full CloudKit pipeline (`SmartList` record type in `CloudKitMapper`), `SyncChangeTracker` observes `smartLists` table, LWW conflict resolution in `SyncService+RemoteApply`, tombstone cleanup covers Smart Lists
- `feat(smartLists)`: Import/export Smart Lists as JSON — `SmartListService.exportAsJSON(_:)` / `importFromJSON(_:)` with ISO 8601 dates, new UUID on import to avoid conflicts
- `feat(smartLists)`: Event-driven count refresh — `SmartListViewModel.observeEvents()` subscribes to EventBus and debounces DB count queries

### Changed

- `refactor(sync)`: `SyncChangeTracker` now observes `smartLists` table in addition to `clipboardItems` and `collections`, with field-level filtering for `modifiedAt`, `isDeleted`, `name`, `rules`
- `refactor(sync)`: `CloudKitMapper` / `CloudKitMapper+Decode` / `CloudKitMapperPayloads` extended with `SmartList` record type, `SmartListPayload` struct, and `decodeSmartList(from:encryption:)`
- `refactor(ui)`: `ContentView` restructured from single-list to 3-tab layout (History / Smart Lists / Collections)
- `refactor(di)`: `DependencyContainer` and `AppController` updated to wire `SmartListService`, `SmartListViewModel`, and inject into views

**New Files:**

| File | Purpose |
|------|---------|
| `Models/SmartList.swift` | `SmartList`, `SmartListRule`, `MatchMode`, `SmartListSortOrder`, `RuleField`, `RuleComparison` |
| `Services/SmartList/SmartListService.swift` | CRUD, evaluate, countMatches, presets, import/export |
| `Services/SmartList/SmartListQueryBuilder.swift` | Rule → SQL predicate translation, relative date parsing |
| `Services/Storage/SmartListRecord.swift` | GRDB record type for `smartLists` table |
| `ViewModels/SmartListViewModel.swift` | @Observable VM with EventBus, debounced counts |
| `Views/SmartLists/SmartListSidebarView.swift` | Sidebar list with icons, counts, context menus |
| `Views/SmartLists/SmartListEditorView.swift` | Rule builder sheet with icon/color pickers |
| `Views/SmartLists/SmartListRuleRow.swift` | Individual rule row in editor |

**Modified Files (22):**

| File | Changes |
|------|---------|
| `SyncService.swift` | Retry engine, NWPathMonitor, account handling, progress tracking |
| `SyncService+Send.swift` | Rate limit handling, zone-not-found recovery |
| `SyncService+Outbox.swift` | Tombstone cleanup, metadata pruning |
| `SyncService+RemoteApply.swift` | SmartList decode + upsert, EventBus emit |
| `SyncService+EngineState.swift` | Zone recreation, re-enqueue |
| `SyncChangeTracker.swift` | smartLists table observation |
| `CloudKitMapper.swift` | SmartList record type + makeSmartListRecord |
| `CloudKitMapper+Decode.swift` | decodeSmartList |
| `CloudKitMapperPayloads.swift` | SmartListPayload struct |
| `ConflictResolver.swift` | LWW merge for ClipboardItem, Collection |
| `ContentView.swift` | 3-tab picker (history/smartLists/collections) |
| `PinboardTabBar.swift` | Smart List tabs in bottom shelf |
| `BottomShelfView.swift` | Smart List selection support |
| `SyncSettingsView.swift` | Health dashboard, device name, progress, max size picker |
| `DependencyContainer.swift` | SmartListService wiring |
| `AppController.swift` | SmartListViewModel creation |
| `Migrations.swift` | v8_createSmartLists migration |
| `Constants.swift` | syncRetryBaseInterval, syncRetryMaxInterval, syncRetryCheckInterval |

## [1.4.0] — 2026-04-05

### Added

- `feat(quick-edit)`: added `ImageCropView` plus the new `ImageExport` pipeline so Quick Edit can crop or resize clipboard images and export the transformed result without mutating the original history item
- `test(quick-edit)`: added `OpenPasteTests/ImageExportTests.swift` and `OpenPasteUITests/OpenPasteE2EQuickEditTests.swift` to cover image export math and the seeded Quick Edit flow end to end
- `test(e2e)`: added a DEBUG-only UI test harness in `AppController` / `DependencyContainer` with deterministic seeding, auto-open hooks, per-run database overrides, and SQLCipher diagnostics publishing for full-flow XCUITest scenarios
- `test(storage)`: added `OpenPasteUITests/OpenPasteE2ESQLCipherTests.swift` to verify encrypted database creation and SQLCipher header state end to end

### Changed

- `chore(release)`: enabled repo auto-merge so protected `develop -> main` release PRs can use `gh pr merge --auto` instead of requiring a second manual merge after CI turns green
- `ci(workflows)`: upgraded official GitHub Actions pins in CI/release workflows to Node 24-ready versions where available (`actions/checkout`, `actions/upload-artifact`)
- `ci(release)`: replaced JavaScript-based GitHub Release publishing and Homebrew tap dispatch steps with `gh` CLI commands so release reruns are idempotent and stop depending on Node 20-only actions
- `fix(release)`: release workflow reruns now skip duplicate GitHub Release asset uploads and duplicate Sparkle appcast entries for the same tag, while suppressing the Homebrew dispatch once the tap already reflects that version
- `.gitignore`: now ignores generated root-level `OpenPaste-*.dmg` artifacts to keep local release experiments out of future ship commits
- `docs`: updated `docs/code-standards.md` to document the full DEBUG UI-test hook surface and refreshed `docs/system-architecture.md` for the new SQLCipher-by-default storage/security flow

### Fixed

- `fix(test)`: stabilized hosted-app startup for local and CI test runs by honoring UI-test launch mode earlier, suppressing updater interference during test sessions, and adding a pre-push path for installed-app updater verification
- `fix(test)`: stabilized `OpenPasteUITests/OpenPasteE2EQuickEditTests` by replacing flaky macOS slider automation with a deterministic UI-test image-scale hook and by waiting for a real pasteboard change before reading exported TIFF data
- `fix(test)`: stabilized `OpenPasteUITests/OpenPasteE2ESQLCipherTests` across signed local runs and unsigned CI-like runs by switching SQLCipher verification from brittle cross-process file reads to app-emitted diagnostics over a named pasteboard
- `fix(test)`: isolated `OpenPasteTests/KeychainHelperTests` keychain entries per worker process so parallelized test hosts stop colliding on the same test credential namespace
- `fix(build)`: excluded `OpenPaste/Info.plist` from the app target's auto-synced target membership so Xcode no longer warns that the target Info.plist is being copied via Copy Bundle Resources

### Security

- `feat(storage)`: switched persistence to the SQLCipher build of GRDB and now encrypt clipboard history at rest by default, including one-time migration support for legacy plain SQLite stores and a non-secret `.encrypted` marker to avoid re-migration loops
- `feat(security)`: sensitive clipboard buffers now flow through `SecureBytes` zeroization so temporary plaintext data is wiped from memory after processing; added integration coverage in `OpenPasteTests/SecureZeroIntegrationTests.swift`

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
