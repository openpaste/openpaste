# OpenPaste — System Architecture

Technical architecture overview for the OpenPaste macOS clipboard manager.

**Last Updated:** April 2026

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
| `AppEvent` | Enum for EventBus messages (clipboard changed, item pasted, OCR completed, etc.) |
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
├── Storage/
│   ├── DatabaseManager          — GRDB setup, migrations, schema
│   ├── StorageService           — CRUD operations on ClipboardItem
│   └── KeychainHelper           — macOS Keychain for encryption keys
├── Update/
│   └── UpdaterService           — Sparkle 2.9.1 (@Observable wrapper), in-app update checks and installation
└── Protocols/
    ├── ClipboardServiceProtocol
    ├── StorageServiceProtocol
    ├── SearchServiceProtocol
    ├── SecurityServiceProtocol
    ├── OCRServiceProtocol
    └── UpdaterServiceProtocol
```

### 4. ViewModel Layer (`ViewModels/`)

All ViewModels use `@Observable` (Swift 6 Observation framework), run on `@MainActor`.

| ViewModel | Manages |
|-----------|---------|
| `HistoryViewModel` | Clipboard history list, pagination, pin/star, paste action |
| `SearchViewModel` | Search query, filters, results |
| `CollectionViewModel` | Collection CRUD, item assignment |
| `PasteStackViewModel` | Multi-item sequential paste queue |
| `SettingsViewModel` | User preferences, storage info |
| `OnboardingViewModel` | First-launch wizard state machine |

### 5. View Layer (`Views/`)

SwiftUI views organized by feature:

```
Views/
├── History/         — Main clipboard history list + item rows
├── Search/          — Search bar + results
├── Collections/     — Collection sidebar + management
├── PasteStack/      — Multi-paste queue UI
├── Settings/        — Settings panes (general, privacy, keyboard, appearance, storage, about)
├── Onboarding/      — 5-step first-launch wizard
└── Shared/          — Design system (DS), reusable modifiers, overlays
```

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

**Events:** `clipboardChanged`, `itemStored`, `itemPasted`, `searchRequested`, `stackPasted`, `previewOpened`, `sensitiveDetected`, `ocrCompleted`, `settingsUpdated`

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
- **Migrations:** Versioned via `DatabaseMigrations.registerMigrations(&migrator)`

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
- **Synced record types:** `ClipboardItem`, `Collection`
- **Payload:** Records store an encrypted payload as a `CKAsset` (staged under `FileManager.default.temporaryDirectory/OpenPaste-Sync/` and cleaned up after send).
- **Encryption:** AES-GCM with per-version symmetric keys stored in Keychain (synchronizable items).
- **Privacy control:** If `iCloudSyncIncludeSensitive` is disabled, items marked `isSensitive` are not uploaded.
- **Persistence:** Sync engine state/outbox metadata is stored in the same SQLite database (`sync_engine_state`, `sync_metadata`), and per-row CloudKit system fields are persisted in `ckSystemFields` columns.

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
