# OpenPaste — System Architecture

Technical architecture overview for the OpenPaste macOS clipboard manager.

**Last Updated:** April 2026 (v1.5.0 — iCloud Sync Stabilization + Smart Lists)

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────┐
│                    OpenPasteApp                       │
│              (SwiftUI App lifecycle)                  │
└──────────────┬───────────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────────┐
│                   AppController                       │
│  @Observable · @MainActor                            │
│  Owns: ViewModels, WindowManager, HotkeyManager      │
│  Bootstraps: DependencyContainer → Services           │
└──────────────┬───────────────────────────────────────┘
               │
    ┌──────────▼──────────┐
    │ DependencyContainer  │
    │  Creates & wires all │
    │  services at init    │
    └──────────┬──────────┘
               │
  ┌────────────┼────────────────────────┐
  │            │                        │
  ▼            ▼                        ▼
Services   ViewModels                Views
(actors/   (@Observable              (SwiftUI)
 classes)   @MainActor)
```

---

## Layer Breakdown

### 1. App Layer (`App/`)

| Component | Responsibility |
|-----------|---------------|
| `OpenPasteApp` | SwiftUI `@main` entry, creates `AppDelegate` and root `ContentView` |
| `AppDelegate` | NSApplicationDelegate — LSUIElement (menu bar app), status item |
| `AppController` | Coordinator — creates DI container, wires ViewModels, starts services |
| `DependencyContainer` | Pure composition root — instantiates all services with their dependencies |
| `WindowManager` | Creates/shows/hides floating panel, cursor-positioned mode, focus management |
| `HotkeyManager` | Carbon-based global hotkey registration and callback |
| `OnboardingWindowManager` | Separate window for first-launch onboarding flow |

### 2. Model Layer (`Models/`)

All models are value types (`struct`) conforming to `Sendable`.

| Model | Purpose |
|-------|---------|
| `ClipboardItem` | Core data entity — content, type, metadata, tags, pin/star, hash, sensitivity |
| `ContentType` | Enum: `text`, `richText`, `image`, `file`, `link`, `color`, `code` |
| `SmartList` | Rule-based dynamic filter — name, icon, color, rules (JSON), matchMode, sortOrder |
| `SmartListRule` | Individual filter rule — field, comparison operator, value |
| `AppEvent` | Enum for EventBus messages (clipboard changed, item pasted, OCR completed, sync completed, etc.) |
| `AppInfo` | Source application metadata (name, bundle ID, icon) |
| `Collection` | User-created collection/folder for organizing items |
| `SearchFilters` | Search query parameters (text, type, time range, pinned/starred) |

### 3. Service Layer (`Services/`)

All services expose protocols (defined in `Services/Protocols/`). Implementations are injected via `DependencyContainer`.

```
Services/
├── Clipboard/
│   ├── ClipboardService        — NSPasteboard polling loop, dedup, normalize, emit events
│   └── PasteInterceptor        — Programmatic paste via CGEvent
├── Processing/
│   ├── ContentHasher           — SHA-256 content hashing for deduplication
│   └── OCRService              — Vision framework text extraction from images
├── Search/
│   └── SearchEngine            — FTS5 full-text search + LIKE fallback
├── Security/
│   ├── SensitiveContentDetector — Regex patterns + entropy analysis for secrets
│   ├── SecurityService          — Auto-expiry cleanup for sensitive items
│   └── ScreenSharingDetector    — Pause capture during screen sharing
├── SmartList/
│   ├── SmartListService         — CRUD, evaluate, countMatches, presets, import/export
│   └── SmartListQueryBuilder    — Rule → SQL predicate translation, regex post-filter
├── Storage/
│   ├── DatabaseManager          — GRDB setup, migrations (v1–v8), schema
│   ├── StorageService           — CRUD operations on ClipboardItem
│   ├── SmartListRecord          — GRDB record type for smartLists table
│   └── KeychainHelper           — macOS Keychain for encryption keys
├── Sync/
│   ├── SyncService              — CKSyncEngine delegate, lifecycle, retry engine, NWPathMonitor
│   ├── SyncService+Send         — Outbox → CKRecord build, rate limit handling, zone recovery
│   ├── SyncService+RemoteApply  — Inbound record decode, conflict resolve, upsert, EventBus emit
│   ├── SyncService+Outbox       — Outbox claim, tombstone cleanup, metadata pruning
│   ├── SyncService+EngineState  — Zone creation/recreation, state persistence
│   ├── SyncChangeTracker        — GRDB TransactionObserver for clipboardItems/collections/smartLists
│   ├── CloudKitMapper           — Record type mapping (ClipboardItem, Collection, SmartList)
│   ├── CloudKitMapper+Decode    — CKRecord → local record conversion
│   ├── CloudKitMapperPayloads   — Codable payload structs for encrypted CKAssets
│   ├── SyncEncryptionService    — AES-GCM encryption/decryption for sync payloads
│   ├── ConflictResolver         — LWW merge with field-level semantics (tags: union, bools: true-wins)
│   ├── SyncMetadataRecord       — Outbox tracking record (status, retryCount, retryAfter)
│   ├── SyncEngineStateRecord    — CKSyncEngine state serialization
│   └── NoopSyncService          — No-op fallback for non-premium users
├── Update/
│   └── UpdaterService           — Sparkle 2.9.1 (@Observable wrapper), in-app update checks and installation
└── Protocols/
    ├── ClipboardServiceProtocol
    ├── StorageServiceProtocol
    ├── SearchServiceProtocol
    ├── SecurityServiceProtocol
    ├── OCRServiceProtocol
    ├── SyncServiceProtocol      — SyncStatus enum (disabled/idle/syncing(progress:)/error/notPremium)
    ├── SmartListServiceProtocol
    └── UpdaterServiceProtocol
```

### 4. ViewModel Layer (`ViewModels/`)

All ViewModels use `@Observable` (Swift 6 Observation framework), run on `@MainActor`.

| ViewModel | Manages |
|-----------|---------|
| `HistoryViewModel` | Clipboard history list, pagination, pin/star, paste action |
| `SearchViewModel` | Search query, filters, results |
| `CollectionViewModel` | Collection CRUD, item assignment |
| `SmartListViewModel` | Smart List CRUD, rule evaluation, debounced badge counts, EventBus subscription |
| `PasteStackViewModel` | Multi-item sequential paste queue |
| `SettingsViewModel` | User preferences, storage info, sync health dashboard state |
| `OnboardingViewModel` | First-launch wizard state machine |

### 5. View Layer (`Views/`)

SwiftUI views organized by feature:

```
Views/
├── History/         — Main clipboard history list + item rows
├── Search/          — Search bar + results
├── Collections/     — Collection sidebar + management
├── SmartLists/      — Smart List sidebar, editor sheet, rule rows
├── PasteStack/      — Multi-paste queue UI
├── Settings/        — Settings panes (general, privacy, keyboard, appearance, sync, storage, about)
├── Onboarding/      — 5-step first-launch wizard
└── Shared/          — Design system (DS), reusable modifiers, overlays
```

**Navigation:** `ContentView` uses a 3-tab `Picker` (`enum Tab { case history, smartLists, collections }`) in vertical window mode. Bottom Shelf mode uses `PinboardTabBar` with Smart List tabs.

---

## Data Flow

### Clipboard Capture Pipeline

```
NSPasteboard (polling every 0.5s)
  │
  ▼
ClipboardService
  ├── Change detected? (changeCount comparison)
  ├── App blacklisted? (skip password managers)
  ├── Screen sharing active? (skip if enabled)
  ├── Content normalization (extract type, data, plain text)
  ├── ContentHasher → dedup check
  ├── SensitiveContentDetector → flag + set expiresAt
  └── OCRService (async, for images)
  │
  ▼
StorageService.save()
  │
  ▼
EventBus.emit(.itemStored)
  │
  ▼
HistoryViewModel (via AsyncStream) → UI update
```

### Paste Action

```
User selects item → HistoryViewModel.paste(item)
  │
  ▼
ClipboardService.copy(item)    — Write to NSPasteboard
  │
  ▼
WindowManager.hide()            — Dismiss panel
  │
  ▼
PasteInterceptor.paste()       — Simulate ⌘V via CGEvent
  │
  ▼
EventBus.emit(.itemPasted)
```

---

## Event System

`EventBus` is an `actor` providing thread-safe pub/sub via `AsyncStream`.

```swift
// Publisher
await eventBus.emit(.clipboardChanged(item))

// Subscriber (in ViewModel .task or init)
for await event in await eventBus.stream() {
    switch event {
    case .itemStored(let item): ...
    }
}
```

**Events:** `clipboardChanged`, `itemStored`, `itemPasted`, `searchRequested`, `stackPasted`, `previewOpened`, `sensitiveDetected`, `ocrCompleted`, `settingsUpdated`, `syncStarted`, `syncCompleted`

---

## Persistence

### Database

- **Engine:** SQLite via GRDB.swift 7.10.0
- **Primary file:** `clipboard.sqlite` (WAL mode may also create `clipboard.sqlite-wal` and `clipboard.sqlite-shm`)
- **Location (preferred, sandbox-compatible):**
  - `~/Library/Containers/<bundleId>/Data/Library/Application Support/OpenPaste/`
  - Example (current bundle id): `~/Library/Containers/dev.tuanle.OpenPaste/Data/Library/Application Support/OpenPaste/`
- **Legacy location (pre-sandbox builds):** `~/Library/Application Support/OpenPaste/`
- **One-time legacy copy behavior:**
  - On startup, if `~/Library/Application Support/OpenPaste/clipboard.sqlite` exists **and** the target DB does **not**, the app **copies** the legacy DB forward (including `-wal` / `-shm` if present) into the sandbox-compatible directory.
  - The legacy database is **not deleted**.
  - If the legacy directory contains the `.encrypted` marker, it is also copied.
  - This read requires the sandbox temporary exception entitlement for `Library/Application Support/OpenPaste/`.
- **Search:** FTS5 full-text index on `plainTextContent` + `ocrText`
- **Thread safety:** `DatabaseQueue` serializes all access
- **Encryption:** SQLCipher encryption at rest (enabled by default)
- **Key storage:** macOS Keychain via `KeychainHelper`
- **Encryption marker:** `.encrypted` file in the DB directory indicates the DB has been migrated/opened with SQLCipher (prevents re-migration loops; contains no secrets)
- **Migrations:** Versioned via `DatabaseMigrations.registerMigrations(&migrator)` (v1–v8; v8 adds `smartLists` table)

### User Preferences

- **Storage:** `UserDefaults` via `@AppStorage`
- **Keys:** Defined in `Utilities/Constants.swift`
- **Settings:** Hotkey, theme, window position, retention, screen sharing behavior

---

## CloudKit Sync (iCloud)

> Implemented in `Services/Sync/` and available on **macOS 14+**.

- **API:** CloudKit `CKSyncEngine` (private database)
- **Container:** `iCloud.dev.tuanle.OpenPaste`
- **Zone:** `OpenPasteZone`
- **Synced record types:** `ClipboardItem`, `Collection`, `SmartList`
- **Payload:** Records store an encrypted payload as a `CKAsset` (staged under `FileManager.default.temporaryDirectory/OpenPaste-Sync/` and cleaned up after send).
- **Encryption:** AES-GCM with per-version symmetric keys stored in Keychain (synchronizable items).
- **Privacy control:** If `iCloudSyncIncludeSensitive` is disabled, items marked `isSensitive` are not uploaded.
- **Max item size:** Configurable via Settings picker (Unlimited / 1 MB / 5 MB / 10 MB).
- **Persistence:** Sync engine state/outbox metadata is stored in the same SQLite database (`sync_engine_state`, `sync_metadata`), and per-row CloudKit system fields are persisted in `ckSystemFields` columns.

### Sync Reliability

| Feature | Implementation |
|---------|---------------|
| **Retry engine** | Periodic 60s check loop with exponential backoff (`min(60 × 2^retryCount, 3600)`, max 5 retries) |
| **Network reachability** | `NWPathMonitor` defers start when offline, auto-starts on reconnect |
| **Account validation** | `CKAccountStatus` checked before engine creation |
| **Account changes** | `signIn` → reset + restart, `signOut` → stop, `switchAccounts` → reset |
| **Rate limiting** | Detects `requestRateLimited`, `zoneBusy`, `serviceUnavailable`; respects `retryAfterSeconds` |
| **Zone recovery** | `CKError.zoneNotFound` triggers zone recreation + full re-enqueue |
| **Progress reporting** | `SyncStatus.syncing(progress:)` with percentage during send sessions |
| **Tombstone cleanup** | Purges soft-deleted synced items older than 30 days on each start |
| **Metadata pruning** | Caps `sync_metadata` table at 10,000 synced entries |

### Conflict Resolution

- **Strategy:** Last-Writer-Wins (LWW) with field-level merge in `ConflictResolver`
- **Tags:** Set union (merged from both sides)
- **Booleans (pinned/starred):** True wins; otherwise LWW
- **Counters (accessCount/accessedAt):** Max of both sides
- **Metadata dict:** Dictionary merge, prefer winner
- **SmartList:** LWW on `modifiedAt`
- **EventBus integration:** `.clipboardChanged` emitted after remote apply for immediate UI refresh

---

## Security Model

```
┌─ Capture Time ─────────────────────────────┐
│ App blacklist check (password managers)     │
│ Screen sharing detection (pause capture)    │
│ Sensitive content detection (regex/entropy) │
│ → Flag isSensitive + set expiresAt          │
└─────────────────────────────────────────────┘

┌─ Storage ───────────────────────────────────┐
│ SQLCipher encryption at rest (default)      │
│ Encryption key in macOS Keychain            │
│ `.encrypted` marker after migration/open    │
│ Secure deletion (cryptographic wipe)        │
└─────────────────────────────────────────────┘

┌─ Runtime ───────────────────────────────────┐
│ SecurityService cleanup loop (auto-expire)  │
│ No network calls, no telemetry              │
│ SecureBytes for in-memory sensitive data    │
└─────────────────────────────────────────────┘
```

---

## Window System

- **Type:** `NSPanel` (floating, non-activating) via custom `FloatingPanel`
- **Activation:** Global hotkey (Carbon) → `WindowManager.toggle()`
- **Position modes:** Center screen or cursor-positioned (clamped to visible frame)
- **Size:** Resizable 350×400 to 700×900
- **Behavior:** LSUIElement (no Dock icon), activates/deactivates previous app on show/hide

---

## Build & Distribution

```
Source (GitHub) → Tag Push → GitHub Actions
  │
  ├── xcodebuild archive (Developer ID Application signed)
  ├── notarytool submit --wait (Apple notarization)
  ├── stapler staple (attach ticket)
  ├── create-dmg.sh → OpenPaste-X.Y.Z.dmg
  ├── GitHub Release (DMG + release notes)
  └── repository-dispatch → openpaste/homebrew-tap (auto-update cask)
```

See [release-guide.md](release-guide.md) for full release procedure.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| GRDB.swift | 7.10.0 | SQLite ORM, migrations, FTS5 |

**Apple Frameworks:** SwiftUI, AppKit, CryptoKit, Vision, CoreGraphics, Carbon, Security
