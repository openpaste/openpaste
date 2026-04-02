# OpenPaste — Code Standards

Coding conventions and patterns for the OpenPaste macOS app.

**Last Updated:** April 2026

---

## Language & Toolchain

| Item | Value |
|------|-------|
| **Language** | Swift 6 |
| **UI Framework** | SwiftUI + AppKit (hybrid) |
| **Min Deployment** | macOS 14+ (Sonoma) |
| **IDE** | Xcode 15+ |
| **Package Manager** | Swift Package Manager (SPM) |

---

## Architecture: MVVM + Service Layer

```
App/                  → Application lifecycle, coordinator, DI
Models/               → Data models (value types preferred)
Services/             → Business logic behind protocols
  ├── Clipboard/      → Clipboard monitoring & paste
  ├── Processing/     → Content normalization, hashing, OCR
  ├── Search/         → FTS5 search engine
  ├── Security/       → Sensitive detection, screen sharing
  ├── Storage/        → SQLite persistence (GRDB)
  └── Protocols/      → Service protocol definitions
ViewModels/           → @Observable view models
Views/                → SwiftUI views, organized by feature
  ├── History/
  ├── Search/
  ├── Collections/
  ├── PasteStack/
  ├── Settings/
  ├── Onboarding/
  └── Shared/         → Reusable components, design system
Utilities/            → Constants, extensions, helpers
```

---

## Swift Concurrency

### `@Observable` (Swift 6 Observation)
- All ViewModels use `@Observable` macro (not `ObservableObject`)
- Properties that should NOT be observed use `@ObservationIgnored`
- Closures/callbacks stored on `@Observable` classes must be `@ObservationIgnored` if they are not simple value types

```swift
@Observable
final class ExampleViewModel {
    var items: [Item] = []                              // ✅ observed
    @ObservationIgnored var onAction: (() -> Void)?     // ✅ ignored
}
```

### `@MainActor`
- ViewModels and UI-bound code run on `@MainActor`
- Use `MainActor.run { }` when mutating `@Observable` properties from background contexts
- `AppController`, `WindowManager`, `OnboardingWindowManager` are `@MainActor`

### `Sendable`
- Models used across concurrency boundaries must conform to `Sendable`
- Use `@Sendable` for closures crossing actor boundaries
- `EventBus` is an `actor` for thread-safe pub/sub

### Structured Concurrency
- Prefer `Task { }` + `Task.sleep` over `DispatchQueue.main.asyncAfter`
- Use `AsyncStream` for event observation (e.g., `EventBus.stream(for:)`)
- Cancel tasks in `deinit` or `.onDisappear`

---

## Protocol-Based Services

Every service exposes a protocol. Implementations are injected via `DependencyContainer`.

```swift
// ✅ Correct pattern
protocol StorageServiceProtocol: Sendable {
    func save(_ item: ClipboardItem) async throws
    func fetch(limit: Int, offset: Int) async throws -> [ClipboardItem]
}

final class StorageService: StorageServiceProtocol { ... }
```

**Protocols defined in:** `Services/Protocols/`

| Protocol | Purpose |
|----------|---------|
| `ClipboardServiceProtocol` | Monitor, copy, paste |
| `StorageServiceProtocol` | CRUD persistence |
| `SearchServiceProtocol` | Full-text search |
| `SecurityServiceProtocol` | Sensitive content detection |
| `OCRServiceProtocol` | Image text extraction |

---

## Event System

- `EventBus` (actor) — centralized pub/sub
- Events defined in `Models/AppEvent.swift`
- ViewModels subscribe via `AsyncStream` in `.task` modifiers or `init`
- Prefer EventBus over direct ViewModel-to-ViewModel communication

---

## Database (GRDB)

- **ORM**: GRDB.swift — lightweight SQLite wrapper
- **Search**: FTS5 full-text search with LIKE fallback
- **Schema**: Managed via `DatabaseManager` with migrations
- **Thread safety**: `DatabaseQueue` serializes access
- **Encryption**: Optional SQLCipher via `#if GRDBCIPHER` conditional compilation
- **Key storage**: Encryption passphrase stored in macOS Keychain via `KeychainHelper`

---

## Design System (`DS` Enum)

All UI tokens live in `Views/Shared/DesignSystem.swift`:

```swift
DS.Colors.accent        // Brand color (#2EC4B6)
DS.Spacing.md           // 12pt
DS.Radius.md            // 8pt
DS.Animation.springDefault
DS.Typography.rowTitle
DS.Shadow.card
DS.Glass.isAvailable    // Liquid Glass feature check
```

**Rules:**
- Use `DS.*` tokens instead of hardcoded values
- New colors/spacing must be added to `DS` enum first
- Use `.hoverHighlight()` modifier for interactive elements

---

## File Conventions

| Rule | Detail |
|------|--------|
| **Naming** | kebab-case not applicable (Swift uses PascalCase for types, camelCase for properties) |
| **File size** | Keep under 200 lines; split large views into subviews |
| **One type per file** | Each file contains one primary type |
| **Feature folders** | Views grouped by feature under `Views/` |
| **Shared components** | Reusable views go in `Views/Shared/` |

---

## Error Handling

- Use `do/catch` at service boundaries
- ViewModels surface errors via published properties (`var errorMessage: String?`)
- Never force-unwrap (`!`) in production code
- Use `guard` for early returns on precondition failures

---

## Testing

- Framework: **XCTest**
- Test files: `OpenPasteTests/` — one test file per service/viewmodel
- Mocking: Create mock implementations of service protocols
- Shared helpers: `TestHelpers.swift` for common test factories
- Run tests: `⌘U` in Xcode or `xcodebuild test -scheme OpenPaste`

**Coverage targets:**
- Services: High coverage (business logic)
- ViewModels: Medium coverage (state transitions)
- Views: UI tests in `OpenPasteUITests/`

---

## Security Standards

| Practice | Implementation |
|----------|----------------|
| **Sensitive detection** | Regex for CC#, API keys, JWT, SSH keys + entropy analysis |
| **Auto-expiry** | Sensitive items expire after configurable interval (default 1hr) |
| **App blacklist** | Skip capture from password managers (1Password, Bitwarden, etc.) |
| **Screen sharing** | Pause monitoring during detected screen sharing sessions |
| **Secure deletion** | Cryptographic wipe before deletion |
| **No telemetry** | Zero data collection, no analytics, no network calls |

---

## Commit Convention

[Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`  
**Scopes:** `clipboard`, `search`, `storage`, `security`, `ui`, `settings`, `onboarding`, `build`

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| **GRDB.swift** | 7.10.0 | SQLite ORM + FTS5 |

**Apple Frameworks:** SwiftUI, AppKit, CryptoKit, Vision, CoreGraphics, Carbon (hotkeys)

> Keep third-party dependencies minimal. Prefer Apple frameworks.
