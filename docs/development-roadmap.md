# OpenPaste Development Roadmap

Strategic roadmap for OpenPaste development phases, milestones, and feature priorities.

**Last Updated:** April 2026  
**Current Phase:** Foundation (95% → feature-complete for iCloud Sync + Smart Lists)  
**Active Go-to-Market Track:** First-users validation roadmap — see `../plans/260403-first-users-roadmap/plan.md`

---

## Phase 1: Foundation – Core Clipboard Management ⚙️

**Status:** In Progress (95% complete)
**Target Completion:** Q2 2026

### Completed Milestones ✅

1. **Project Setup & Architecture**
   - macOS app structure (SwiftUI + AppKit blend)
   - Core data model (Clipboard, ClipboardItem)
   - Persistence layer (SQLite + SQLCipher encryption at rest)

2. **Basic Clipboard Capture & History**
   - Clipboard monitoring loop
   - Item deduplication logic
   - SQLite + SQLCipher storage (encrypted at rest)
   - Item metadata (timestamp, source app, content type)

3. **Global Hotkey System**
   - `HotkeyManager` for global keyboard shortcuts
   - Customizable hotkey binding
   - Persistence to `UserDefaults`

4. **Onboarding & First-Launch Experience** ✨
   - 5-step guided setup flow
   - Accessibility permission handling with system integration
   - Global hotkey customization during onboarding
   - Launch at login configuration UI
   - Live permission status polling
   - 20 unit tests validating navigation and state

5. **UI/UX Overhaul — Design System & Liquid Glass** ✨ NEW
   Comprehensive three-phase UI/UX overhaul (28 tasks including fixes):
   
   **Phase 1 — Essential Polish:**
   - Centralized `DS` design system enum (Colors, Spacing, Radius, Animation, Typography, Shadows, Glass)
   - Reusable `.hoverHighlight()` view modifier with configurable corner radius
   - Paste confirmation overlay (green checkmark, spring animation, 800ms auto-dismiss)
   - Redesigned filter chips with DS tokens and count badges
   - Updated TypeIcon sizes (14→18pt) and brand colors via `DS.Colors`

   **Phase 2 — Competitive Parity:**
   - Settings migrated from `TabView` to `NavigationSplitView` with 7 sections (general, privacy, keyboard, appearance, sync, storage, about)
   - New `AppearanceSettingsView` (theme picker, window position mode)
   - New `StorageSettingsView` (database size, item counts by type, optimize action)
   - Pinned items section in history list with dedicated header
   - Keyboard shortcut overlay (`?` key cheatsheet) with `@FocusState` management
   - Spring-based animations replacing `easeInOut` throughout
   - Panel fade-in animation (scale 0.96→1.0 + opacity)
   - Content preview improvements (larger images, spring transitions)

   **Phase 3 — Delight & Differentiation:**
   - Liquid Glass integration (`.glassEffect` on filter chips, tab picker, paste button)
   - Redesigned empty states with animated icons (`.symbolEffect(.pulse.byLayer)`) and shortcut hints
   - Smart filter bar (Last 24h, Last 7 days, Last 30 days, Pinned, Starred)
   - Cursor-positioned window mode (open near mouse, clamped to screen)
   - Bottom Shelf (Paste-style) window mode (Appearance setting)
   - Resizable window support (350×400 to 700×900)

   **Code Quality Fixes:**
   - Thread safety: `MainActor.run` for `HistoryViewModel` mutations
   - Paste confirmation timing (600ms delay before dismiss)
   - `NotificationCenter` observer leak fix in `WindowManager`
   - Removed double opacity animation
   - Structured concurrency (`Task.sleep` replacing `DispatchQueue.main.asyncAfter`)
   - `@FocusState` + `.onAppear` for `KeyboardShortcutOverlay` key capture

   **New files:** `DesignSystem.swift`, `HoverHighlightModifier.swift`, `PasteConfirmationOverlay.swift`, `KeyboardShortcutOverlay.swift`, `SmartFilterBar.swift`, `AppearanceSettingsView.swift`, `StorageSettingsView.swift`

6. **Menubar Overhaul — Native AppKit Status Bar** ✅ NEW
   Full replacement of SwiftUI `MenuBarExtra` with AppKit `NSStatusItem` + `NSMenu` via `StatusBarController`:

   **Menu Bar Infrastructure:**
   - `StatusBarController` split into core, `+MenuBuilder`, `+Actions` extensions
   - Dynamic SF Symbol icon (`clipboard` / `clipboard.badge.clock`) reflects monitoring state
   - Menu rebuilt on every open via `NSMenuDelegate` with async data refresh

   **Pause / Resume Monitoring:**
   - `MonitoringState` (`@MainActor @Observable`) + `PauseReason` enum (manual, timed, smartDetect)
   - Manual toggle + timed presets (15m, 30m, 1h, 3h, 8h) with auto-resume
   - `ClipboardServiceProtocol` extended with `pauseMonitoring()` / `resumeMonitoring()`
   - `ClipboardMonitor.isPaused` guard skips pasteboard polling

   **Smart Auto-Pause:**
   - `SmartPauseDetector` uses `NSWorkspace` notifications to detect sensitive apps (1Password, Bitwarden, LastPass, Keychain Access, Apple Passwords, Dashlane, Keeper)
   - Auto-pauses on sensitive app activation, auto-resumes on deactivation

   **Submenus & Features:**
   - Recent Copies submenu with content-type icons and click-to-paste
   - New Text Item floating panel (`NSPanel`, ⌘N) to create items from scratch
   - Quick Actions: Clear All History (with confirmation), Force Sync, Storage Stats
   - Help & Community: Getting Started, Docs, Bug Report, Feature Request, Star on GitHub

   **New files:** `StatusBarController.swift`, `StatusBarController+MenuBuilder.swift`, `StatusBarController+Actions.swift`, `NewTextItemWindow.swift`, `PauseReason.swift`, `MonitoringState.swift`, `SmartPauseDetector.swift`

### Active Milestones 🔄

6. **Distribution & CI/CD** ✅
   - Bundle ID: `dev.tuanle.OpenPaste` (unique, no conflicts)
   - Developer ID Application certificate for code signing
   - Apple notarization (notarytool + stapler) — Gatekeeper pass
   - `scripts/create-dmg.sh` for DMG packaging
   - GitHub Actions release workflow (tag push → build → sign → notarize → DMG → release)
   - Homebrew Cask via `openpaste/homebrew-tap` with auto-update on release
   - `brew tap openpaste/tap && brew install --cask openpaste` verified working
   - See [Release Guide](release-guide.md) for full procedure

7. **Sparkle Auto-Update Framework** ✅
   - Sparkle 2.9.1 SPM dependency integrated
   - `UpdaterService` (@Observable wrapper) for in-app updates
   - EdDSA code signing pipeline in `release.yml`
   - Appcast generation and GitHub Pages deployment
   - MenuBar "Check for Updates…" + Settings UI toggle for auto-check
   - See [Release Guide](release-guide.md) — EdDSA key setup section

8. **iCloud Sync Stabilization** ✅ NEW
   Production-hardening of CloudKit sync — 16 tasks across 3 tracks:

   **Reliability & Network:**
   - Retry engine with exponential backoff (60s periodic, max 5 retries, capped at 3600s)
   - `NWPathMonitor` network reachability — auto-starts sync on reconnect
   - iCloud account status validation before engine creation
   - Account change event handling (signIn / signOut / switchAccounts)
   - CloudKit rate limit handling (`requestRateLimited`, `zoneBusy`, `serviceUnavailable`)
   - Max item size picker in Settings (Unlimited / 1 MB / 5 MB / 10 MB)

   **Data Integrity:**
   - Proper GRDB upsert (`record.save(db)`) replacing insert-catch-update
   - Zone-not-found recovery — auto-recreate zone + re-enqueue all records
   - Sync progress reporting (`SyncStatus.syncing(progress:)` with percentage)
   - `EventBus.emit` after remote apply for immediate UI refresh
   - Tombstone cleanup — 30-day purge of soft-deleted synced items
   - `sync_metadata` pruning — caps table at 10,000 synced entries

   **UI & Observability:**
   - First sync progress indicator with `ProgressView` in Settings
   - Sync conflict notification logging (LWW merge with field-level semantics)
   - Sync health dashboard (synced/pending/error counts, last error, last sync date)
   - Device name display in sync settings

9. **Smart Lists / Rules Engine** ✅ NEW
   Dynamic rule-based clipboard filtering — 14 tasks across 3 tracks:

   **Data Model & Service:**
   - `SmartList` + `SmartListRule` models (11 rule fields, 10 comparison operators, AND/OR match modes)
   - Database migration `v8_createSmartLists` with full schema
   - `SmartListService` — CRUD, evaluate, countMatches, seedPresets, import/export
   - `SmartListQueryBuilder` — rule → SQL predicate translation, regex post-filter, relative date parsing
   - 5 built-in presets: Today, Images, Links, Code Snippets, Sensitive

   **UI:**
   - 3-tab picker in vertical mode (History / Smart Lists / Collections)
   - `SmartListSidebarView` — list with SF Symbol icons, count badges, context menus
   - `PinboardTabBar` extension — Smart List tabs in bottom shelf mode
   - `SmartListEditorView` — full rule builder sheet with icon/color pickers
   - `SmartListViewModel` — @Observable with EventBus integration

   **Integration:**
   - Live badge counts (debounced 500ms event-driven refresh)
   - iCloud sync for Smart Lists (full CK pipeline, LWW conflict resolution)
   - Import/export Smart Lists as JSON
   - Event-driven count refresh via EventBus subscription

10. **Advanced Search & Filtering**
   - Full-text search with Spotlight integration
   - Filtering by content type (text, image, URL)
   - Time-based filtering (today, this week, older) — ✅ partially done via SmartFilterBar
   - Rule-based dynamic filtering — ✅ done via Smart Lists engine

11. **Image Support & Preview**
   - Capture clipboard images
   - Image preview in history — ✅ partially done via ContentPreviewView improvements
   - Image metadata (dimensions, format)

---

## Phase 2: Privacy & Encryption 🔐

**Status:** Not Started  
**Target Completion:** Q3 2026

### Milestones

1. **Encryption-at-Rest Implementation**
   - SQLCipher database encryption
   - Master key derivation from system keychain
   - Transparent encryption/decryption in data layer

2. **Sensitive Content Detection**
   - Regex patterns for credentials (API keys, passwords, tokens)
   - Automatic flagging of sensitive items
   - User-configurable sensitivity rules
   - Option to exclude sensitive items from history

3. **Secure Deletion**
   - Cryptographic data wiping before deletion
   - Batch secure deletion for expired items
   - Configurable retention policies

---

## Phase 3: AI-Native Intelligence 🧠

**Status:** Not Started  
**Target Completion:** Q4 2026

### Milestones

1. **Semantic Search**
   - Embedding generation (on-device or cloud-optional)
   - Vector database integration
   - Semantic similarity ranking

2. **Auto-Tagging**
   - Content classification (code, text, URL, email, etc.)
   - Automatic tag suggestion
   - User-configurable tag schemas

3. **Smart Content Actions**
   - Context-aware actions (format, transform, execute)
   - Snippet expansion and template loading
   - Paste stack (multi-item sequential paste)

---

## Phase 4: Plugin System & Extensibility 🎛️

**Status:** Not Started  
**Target Completion:** Q1 2027

### Milestones

1. **Plugin SDK Design**
   - Plugin loading and lifecycle hooks
   - Sandbox environment for security
   - IPC/plugin communication layer

2. **Example Plugins**
   - Markdown formatter
   - JSON pretty-printer
   - URL shortener integration
   - OCR text extractor

3. **Plugin Marketplace** (Future)
   - Plugin discovery and distribution
   - Version management
   - Community contribution guidelines

---

## Phase 5: Advanced Features & Optimization

**Status:** Not Started  
**Target Completion:** Q2 2027

### Milestones

1. **Performance Optimization**
   - Sub-50ms search latency verification
   - Database query optimization
   - Memory footprint reduction for large histories

2. **Cloud Sync (iCloud / CloudKit)** ✅ SHIPPED
   - Implemented using CloudKit `CKSyncEngine` (macOS 14+), syncing clipboard items + collections + Smart Lists
   - Encrypted payload assets (AES-GCM) with keys stored in Keychain (synchronizable)
   - User controls for excluding sensitive items from upload
   - Production-hardened: retry engine, NWPathMonitor reachability, account change handling, rate limit handling, zone-not-found recovery, progress reporting, tombstone/metadata cleanup

3. **Advanced UI**
   - Inline editing for clipboard items ✅ (QuickEditView)
   - Drag-and-drop organization
   - Collection/folder management ✅ (CollectionListView)
   - Custom themes and layouts ✅ (AppearanceSettingsView theme picker)

---

## Parallel Track: First Users & Positioning 📣

**Status:** In Progress  
**Target Completion:** Q2 2026

### Milestones

1. **Trust Reset & Honest Positioning**
   - Align README, docs, and in-app copy with shipped reality
   - Add explicit shipped / maturing / roadmap framing
   - Establish feedback intake and weekly dashboard
   - In-app feedback handoff shipped in Settings > About with local-first GitHub/Mail draft routing ✅

2. **Sticky Recall Pack**
   - Snippets/templates MVP
   - Quick text transformations for developer workflows
   - Search ranking and filter improvements

3. **Private Beta → Public Launch**
   - Recruit design partners
   - Validate cold install + first-use experience
   - Launch via GitHub, Homebrew, Hacker News, Reddit, Indie Hackers, and dev Twitter/X

---

## Success Metrics

- [ ] Clipboard history with 5,000+ items without performance degradation
- [ ] Global hotkey response time < 100ms
- [x] Accessibility permission check and deep linking reliable
- [x] All onboarding tests passing (20/20)
- [x] User can customize hotkey and set launch-at-login preferences
- [x] Onboarding completes in < 2 minutes for typical user
- [x] Centralized design system adopted across all views (`DS` enum)
- [x] Spring-based animations replace all `easeInOut` transitions
- [x] Settings organized into 7 navigable sections (NavigationSplitView)
- [x] Keyboard shortcuts discoverable via `?` overlay
- [x] Vim-style navigation (j/k/gg/G) operational in history list
- [x] Window resizable within defined bounds (350×400 to 700×900)
- [x] Cursor-positioned window mode functional
- [x] Paste confirmation overlay with auto-dismiss
- [x] Signed + notarized release via GitHub Actions CI/CD
- [x] Homebrew Cask installable (`brew install --cask openpaste`)
- [x] Automated Homebrew tap update on every release
- [x] iCloud sync retry engine with exponential backoff operational
- [x] Network reachability auto-recovery for sync
- [x] iCloud account change handling (sign in/out/switch)
- [x] Sync health dashboard in Settings (synced/pending/error counts)
- [x] Smart Lists CRUD with 5 built-in presets
- [x] Smart List rules engine with 11 fields and 10 comparisons
- [x] Smart Lists synced via iCloud with LWW conflict resolution
- [x] 3-tab navigation (History / Smart Lists / Collections)
- [x] Live badge counts with debounced 500ms refresh
- [x] Native AppKit status bar replacing SwiftUI MenuBarExtra
- [x] Pause/resume monitoring (manual + timed presets with auto-resume)
- [x] Smart auto-pause when sensitive apps (password managers) in foreground
- [x] Recent Copies submenu with content-type icons and click-to-paste
- [x] New Text Item floating panel for creating items from scratch (⌘N)
- [x] Quick Actions submenu (Clear All, Force Sync, Storage Stats)
- [x] Dynamic menubar icon reflecting monitoring state

---

## Dependencies & Blockers

| Dependency | Status | Impact |
|-----------|--------|--------|
| SQLCipher encryption at rest | Shipped | Protects local clipboard DB at rest |
| macOS version targeting (11.0+) | Confirmed | Security baseline |
| Accessibility framework stability | Validated | Onboarding Phase 1 ✅ |
| SwiftUI animation performance | Validated | UI polish ✅ |
| Liquid Glass API (macOS 26+) | Integrated | `.glassEffect` on filter chips & tab picker ✅ |
| NavigationSplitView (macOS 13+) | Integrated | Settings redesign ✅ |
| SwiftUI `symbolEffect` API | Integrated | Empty state and paste confirmation animations ✅ |
| CloudKit CKSyncEngine (macOS 14+) | Shipped | iCloud sync with retry, reachability, progress ✅ |
| NWPathMonitor (Network framework) | Shipped | Network reachability for sync auto-recovery ✅ |
| GRDB v7.10.0 Smart List support | Shipped | v8 migration, SmartListRecord, upsert ✅ |
| AppKit NSStatusItem + NSMenu | Shipped | Native menubar replacing SwiftUI MenuBarExtra ✅ |
| NSWorkspace app notifications | Shipped | Smart auto-pause for sensitive app detection ✅ |

---

## Notes

- **Q2 2026 Focus:** Complete advanced search & filtering; image metadata; performance benchmarks
- **Q2 2026 Go-to-Market Focus:** Run the first-users roadmap in `../plans/260403-first-users-roadmap/plan.md` before expanding AI/plugin claims publicly
- **Distribution:** v1.0.0 released — signed, notarized, Homebrew installable. See [release-guide.md](release-guide.md)
- **UI/UX Overhaul:** Complete — design system (`DS` enum), Liquid Glass, spring animations, vim navigation, and settings redesign shipped
- **Menubar Overhaul:** Complete — native AppKit `StatusBarController` with pause/resume, smart auto-pause, recent copies, quick actions, new text item panel shipped
- **iCloud Sync:** Production-hardened — retry engine, NWPathMonitor reachability, account change handling, rate limits, zone recovery, progress reporting, tombstone/metadata cleanup shipped in v1.5.0
- **Smart Lists:** Shipped — 11-field rules engine, 5 built-in presets, iCloud sync, import/export, 3-tab navigation, live badge counts shipped in v1.5.0
- **Onboarding Release:** Ready for initial user feedback loop
- **Testing Strategy:** Unit tests prioritized for ViewModel logic; integration tests for permission detection
- **Future:** Consider OAuth-based cloud sync if community demand exists
- **Design System:** All new views should use `DS` tokens exclusively — avoid hardcoded colors, spacing, or animation values
