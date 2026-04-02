# OpenPaste – Product Requirements Document (PRD)

## 1. Overview

**Product name:** OpenPaste
**Platform:** macOS (native – SwiftUI + AppKit)
**Positioning:** Open-source, developer-first, privacy-first clipboard manager with AI-native capabilities
**License:** AGPLv3 (open-core model — see LICENSE and CLA.md)

### Problem

macOS clipboard is limited to a single item with no history, search, or organization. Developers and power users copy/paste 50–100+ times daily — losing valuable content constantly.

Existing solutions fail to address the full picture:

* **Paste (paid, $3.99/mo):** Beautiful UI, iCloud sync, but closed-source, subscription-locked, no AI, privacy concerns with cloud storage
* **Maccy (open-source, free):** Fast and lightweight, but text-focused, no AI, no plugin system, no paste stack, no OCR
* **Raycast (free/paid):** Clipboard history is a secondary feature, not a dedicated tool. AI features locked behind Pro subscription
* **CopyQ (open-source, cross-platform):** Powerful scripting but dated UI, not macOS-native, steep learning curve
* **Flycut (open-source):** Text-only, minimal features, effectively abandoned

**No existing open-source tool combines: AI-native intelligence + privacy-first encryption + modern macOS-native UX + plugin extensibility.**

### Vision

Build a **modular, blazing-fast, privacy-first clipboard system** that becomes:

> "The memory layer for everything you copy."

### Unique Selling Proposition

The **only** open-source macOS clipboard manager that delivers all three:

1. **AI-native** — Semantic search, auto-tagging, smart content actions
2. **Privacy-first** — Encryption at rest by default, smart sensitive detection
3. **Extensible** — Plugin SDK with lifecycle hooks

---

## 2. Competitive Analysis

| Feature | OpenPaste | Maccy | Paste | Raycast | CopyQ |
|---|:---:|:---:|:---:|:---:|:---:|
| Open-source | ✅ | ✅ | ❌ | ❌ | ✅ |
| macOS-native UI | ✅ | ✅ | ✅ | ✅ | ❌ |
| AI-native | ✅ | ❌ | ❌ | ⚠️ (Pro only) | ❌ |
| Semantic search | ✅ | ❌ | ❌ | ❌ | ❌ |
| Plugin system | ✅ | ❌ | ❌ | ✅ | ✅ (scripting) |
| Image support | ✅ | ✅ | ✅ | ✅ | ✅ |
| OCR | ✅ | ❌ | ❌ | ✅ | ❌ |
| Paste stack | ✅ | ❌ | ✅ | ❌ | ❌ |
| Encryption at rest | ✅ (default) | ❌ | ❌ | ❌ | ❌ |
| Sensitive detection | ✅ | ❌ | ⚠️ (basic) | ❌ | ❌ |
| Content transformation | ✅ | ❌ | ❌ | ⚠️ (limited) | ✅ |
| Inline edit | ✅ | ❌ | ❌ | ❌ | ✅ |
| Snippets/Templates | ✅ | ❌ | ⚠️ (pinboards) | ✅ | ✅ |
| Price | Free | Free | $3.99/mo | Free (basic) | Free |

---

## 3. Goals

* Infinite clipboard history with zero data loss
* Sub-50ms recall/search latency
* Encryption at rest by default (SQLCipher)
* Offline-first, privacy-first — no telemetry, no cloud dependency
* Extensible via plugin SDK
* AI-enhanced workflows (on-device first, cloud-optional)

---

## 4. Target Users

### Persona 1: Minh — Backend Developer

* **Profile:** Senior Go/Python developer, uses Terminal + VS Code daily
* **Behavior:** Copies/pastes 80+ times/day — API endpoints, SQL queries, JSON payloads, env variables, error messages
* **Pain points:**
  * Accidentally pastes an old API key instead of the current one
  * Can't find a code snippet copied 2 hours ago
  * Copies sensitive env vars that shouldn't persist in history
* **Needs:** Fuzzy search (<50ms), auto-detect sensitive content, source app context, keyboard-first navigation

### Persona 2: Lan — Content Creator & Designer

* **Profile:** Creates content across Figma, browser, Notion, social media tools
* **Behavior:** Copies text, links, images between 10+ apps daily
* **Pain points:**
  * Loses rich text formatting when pasting between apps
  * Can't preview images before pasting — guesses which screenshot is which
  * No way to organize clips by project or campaign
* **Needs:** Rich preview, plain text toggle, image preview, collections by project

### Persona 3: Tuấn — Indie Hacker / AI Engineer

* **Profile:** Builds side projects, heavily uses ChatGPT/Claude, writes prompts daily
* **Behavior:** Reuses prompts, copies code between AI chat and IDE, manages multiple projects
* **Pain points:**
  * Clipboard history too long, can't organize or find reusable prompts
  * Frequently used snippets get buried in chronological history
  * Wants to paste multiple items in sequence (e.g., fill form fields)
* **Needs:** Pinboards, tagging, AI prompt history, paste stack, snippets with variables

---

## 5. Core Features (MVP)

### 5.1 Clipboard Capture Engine

* Listen to macOS pasteboard changes via polling (configurable interval, default 500ms)
* Capture all content types:
  * Plain text
  * Rich text (RTF/HTML)
  * Images (PNG, JPEG, TIFF)
  * Files (paths + metadata)
  * URLs (with link preview metadata)
  * Colors (hex/rgb from design tools)
* Content-hash-based deduplication
* Source app tracking (bundle ID, app name, app icon)
* Configurable capture size limits (default: 10MB per item)

### 5.2 History Timeline UI

* Vertical timeline with type-based icons
* Rich preview by content type:
  * Text: First 3 lines with syntax highlighting for code
  * Images: Thumbnail preview
  * URLs: Favicon + title (fetched asynchronously)
  * Files: Icon + filename + size
* Quick open via global shortcut (default: ⇧⌘V)
* Keyboard-first navigation:
  * Arrow keys for browsing
  * Enter to paste to active app
  * Tab to preview
  * Vim-like optional (j/k/gg/G)
* Source app badge on each item
* Relative timestamps ("2 minutes ago", "yesterday")
* Infinite scroll with virtualization (handle 100k+ items)

### 5.3 Search Engine

* Full-text search via SQLite FTS5
* Fuzzy matching (typo-tolerant)
* Filter by:
  * Content type (text/image/file/link/code)
  * Source app
  * Date range
  * Tags
  * Pinned/starred status
* Search-as-you-type with <50ms latency
* Highlight matching terms in results

### 5.4 Pin, Star & Collections

* **Pin:** Keep items at top of timeline (persistent quick access)
* **Star:** Mark as favorite for later reference
* **Collections:** Named groups (e.g., "Project Alpha", "API Keys", "Prompts")
* Drag-and-drop to organize
* Collection-scoped search

### 5.5 Paste Stack (Power Feature)

* Select multiple items from history
* Paste sequentially — each ⌘V pastes the next item in stack
* Visual indicator showing stack position (e.g., "3/7")
* Reorder stack via drag-and-drop
* Clear stack with shortcut

### 5.6 OCR Engine

* Auto-detect text in copied images using Apple Vision framework
* Store extracted text alongside image for full-text search
* Supported content: Screenshots, photos of documents, whiteboard photos
* Languages: English (default), extensible via system languages
* OCR runs asynchronously — does not block capture pipeline

### 5.7 Quick Edit

* Edit clipboard content inline before pasting
* Syntax highlighting for detected code
* Markdown preview toggle for rich text
* Crop/resize for images
* Accessible via shortcut or context menu

### 5.8 Privacy & Security (Core Pillar)

#### Threat Model

* Malware clipboard hijacking
* Shoulder surfing / screen sharing leak
* Unauthorized local disk access
* Cloud sync interception (if sync enabled)

#### Security Features (MVP)

* **SQLCipher encryption at rest** — enabled by default, not optional
* **Smart sensitive content detection:**
  * Regex + heuristic patterns for: credit card numbers, API keys (AWS/GCP/Stripe/etc.), passwords, JWT tokens, private keys, SSN
  * Auto-flag sensitive items with visual indicator
  * Configurable auto-expire for sensitive items (default: 1 hour)
* **Per-app blacklist** with presets:
  * Built-in: Keychain Access, 1Password, Bitwarden, LastPass, macOS Passwords
  * User-configurable
* **Transient content detection** — ignore pasteboard items marked as transient by source apps
* **Screen sharing mode** — auto-hide clipboard overlay during screen share (detect via `CGDisplayStream`)
* **Secure memory handling** — zero sensitive content from RAM after processing
* **No telemetry** — zero analytics, zero network calls by default

---

## 6. Advanced Features (v2+)

### 6.1 AI Layer (Core Differentiator)

* **Auto-tagging:** Classify content type and context (e.g., "SQL query", "API endpoint", "meeting notes")
* **Semantic search:** On-device embedding model for meaning-based search (not just keyword matching)
* **Content actions:**
  * Summarize long text
  * Fix grammar/spelling
  * Translate (on-device or API)
  * Explain code snippet
  * Rewrite/rephrase
* **Prompt history:** Dedicated view for AI prompt/response pairs
* **Smart suggestions:** Recommend relevant clipboard items based on active app context

### 6.2 Content Transformation Pipeline

* Format JSON / XML (auto-detect and prettify)
* Strip HTML formatting → clean plain text
* URL encode/decode
* Base64 encode/decode
* Escape/unescape strings (SQL, regex, HTML entities)
* Code syntax detection and formatting
* Custom transformation scripts (via plugin hooks)
* Accessible via right-click menu or shortcut

### 6.3 Snippets & Templates

* Save frequently used text as named snippets
* Support variables/placeholders: `{{date}}`, `{{time}}`, `{{clipboard}}`, `{{cursor}}`
* Organize into folders with drag-and-drop
* Quick access via abbreviation expansion or search
* Import/export snippet libraries
* Differentiation from history: Snippets are permanent, curated, and user-created

### 6.4 Sync (Optional, Opt-in)

* iCloud sync with end-to-end encryption (CryptoKit)
* Self-hosted sync option (WebDAV/S3-compatible)
* Selective sync — choose which collections to sync
* Conflict resolution: last-write-wins with manual merge option
* Sync excluded by default for sensitive items

### 6.5 Plugin System

* Developer SDK (Swift Package)
* Lifecycle hooks:
  * `onCopy(item)` — transform/filter before storing
  * `onSearch(query, results)` — augment search results
  * `onPaste(item)` — transform before pasting
  * `onStore(item)` — post-processing after storage
* Plugin manifest (JSON) for metadata, permissions, settings
* Plugin manager UI in settings
* Community plugin registry (GitHub-based)

### 6.6 Rules Engine

* **Ignore apps:** Don't capture from specific apps
* **Auto-expire:** TTL per content type or tag
* **Auto-tag:** Rules-based tagging (e.g., "if source app is Terminal → tag as 'code'")
* **Auto-collection:** Route items to collections by rule
* **Data classification:** Auto-classify as personal/work/sensitive

### 6.7 Additional Integrations

* **CLI interface:** `openpaste search "query"`, `openpaste paste --last`, `openpaste list --tag code`
* **Shortcuts.app actions:** macOS Shortcuts integration for automation workflows
* **macOS Widget:** Show pinned items and recent clips in Notification Center
* **Content type actions:** Detect URL → show "Open in Browser" / "Generate QR"; Color hex → show swatch preview

---

## 7. System Architecture

### 7.1 Architectural Style

OpenPaste follows a modular, protocol-oriented architecture:

* **Thin App Shell** — minimal code in the app target
* **Modular Swift packages** — dependency direction: Core → Feature → App
* **Protocol-oriented services** — all services defined as protocols for testability
* **Observable state** — `@Observable` macro for reactive UI
* **AppKit bridges** — overlay panels, global shortcuts, menu bar integration

**Dependency direction:**

```text
Core modules → Feature modules → App shell
```

---

### 7.2 App Shell (OpenPasteApp)

The app target owns:

* `OpenPasteApp` — entry point, menu bar app lifecycle
* `DependencyContainer` — composition root (protocol-based DI)
* `EventBus` — async clipboard event stream (`AsyncStream<AppEvent>`)
* `AppRouter` — orchestrates flows (search, paste, preview, settings)
* `WindowManager` — manages overlay panels + settings window

---

### 7.3 Module Map

#### Core packages

| Package           | Responsibility                              |
| ----------------- | ------------------------------------------- |
| `CoreModels`      | ClipboardItem, events, service protocols    |
| `CoreClipboard`   | Pasteboard listener, normalization pipeline |
| `CoreHotkeys`     | Global shortcut registration (Carbon API)   |
| `CoreProcessing`  | Dedup, formatting, sensitive detection, OCR |
| `CorePersistence` | SQLite + FTS5 + SQLCipher storage           |
| `CoreSearch`      | Full-text + fuzzy + semantic search engine  |
| `CoreAI`          | Embedding + AI processing layer             |
| `CoreUI`          | Shared UI components (list, preview, cells) |
| `CoreSecurity`    | Encryption, secure memory, threat detection |

#### Feature packages

| Package             | Responsibility                           |
| ------------------- | ---------------------------------------- |
| `FeatureHistory`    | Timeline UI + browsing clipboard         |
| `FeatureSearch`     | Search UI + query interaction + filters  |
| `FeaturePasteStack` | Multi-item paste workflow                |
| `FeaturePreview`    | Floating preview panel + quick edit      |
| `FeatureSettings`   | Settings UI + app blacklist management   |
| `FeatureRules`      | Rules engine UI (ignore apps, auto-tags) |
| `FeatureSnippets`   | Snippets & templates management          |
| `FeatureDevTools`   | Debug tools, logs, event inspector       |

---

### 7.4 Composition Root

`DependencyContainer` wires all services using protocol-based DI:

**Core services:**

* `ClipboardService` — pasteboard monitoring + capture
* `SearchService` — full-text + semantic search
* `StorageService` — SQLite + SQLCipher persistence
* `HotkeyManager` — global shortcut registration
* `AIService` — embedding + content actions
* `SecurityService` — encryption, sensitive detection
* `OCRService` — Vision framework text extraction
* `EventBus` — app-wide event stream
* `TransformService` — content transformation pipeline

**Feature view models:**

* `HistoryViewModel`
* `SearchViewModel`
* `PasteStackViewModel`
* `PreviewViewModel`
* `SnippetsViewModel`

---

### 7.5 Event Flow

`EventBus` exposes `AsyncStream<AppEvent>`:

Events include:

* `clipboardChanged(ClipboardItem)` — new item captured
* `itemStored(ClipboardItem)` — item persisted to database
* `itemPasted(ClipboardItem)` — item pasted to active app
* `searchRequested(query: String)` — search initiated
* `stackPasted(items: [ClipboardItem])` — paste stack completed
* `previewOpened(ClipboardItem)` — preview panel shown
* `sensitiveDetected(ClipboardItem)` — sensitive content flagged
* `ocrCompleted(ClipboardItem, extractedText: String)` — OCR finished
* `settingsUpdated(key: String, value: Any)` — settings changed

---

### 7.6 Clipboard Flow

```text
Copy event (pasteboard change detected)
  → CoreClipboard listener
  → Normalize content + detect type
  → Check blacklist (source app)
  → Check transient flag
  → Content-hash deduplication
  → Sensitive content detection
  → Encrypt + Store (SQLCipher/SQLite)
  → Index (FTS5 for full-text)
  → OCR (async, if image)
  → Embedding (async, if AI enabled)
  → EventBus.clipboardChanged
  → UI refresh (timeline/search)
```

---

### 7.7 Windowing Architecture

Uses AppKit for correctness:

* **Main overlay panel** (clipboard history popup)

  * Borderless NSPanel, non-activating
  * Global shortcut triggered (⇧⌘V)
  * Keyboard-first navigation
  * Search field focused on open
  * Auto-dismiss on paste or Escape

* **Preview panel**

  * Floating, non-activating NSPanel
  * Rich content preview (syntax highlighting, image zoom)
  * Quick edit mode
  * Dismiss on click outside

* **Settings window**

  * Standard NSWindow
  * Tab-based navigation (General, Privacy, Shortcuts, AI, Plugins)

---

## 8. Data Model

### ClipboardItem

| Field | Type | Description |
|---|---|---|
| `id` | `UUID` | Unique identifier |
| `type` | `ContentType` | Enum: text, richText, image, file, link, color, code |
| `content` | `Data` | Raw content (encrypted at rest via SQLCipher) |
| `plainTextContent` | `String?` | Plain text representation for search indexing |
| `ocrText` | `String?` | Text extracted from images via OCR |
| `sourceApp` | `AppInfo` | Bundle ID, app name, app icon path |
| `sourceURL` | `URL?` | Origin URL for web content |
| `createdAt` | `Date` | When the item was captured |
| `accessedAt` | `Date` | Last time the item was pasted |
| `accessCount` | `Int` | Number of times pasted |
| `tags` | `[String]` | Manual + auto-generated tags |
| `pinned` | `Bool` | Pinned to top of timeline |
| `starred` | `Bool` | Marked as favorite |
| `collectionId` | `UUID?` | Parent collection (nullable) |
| `embedding` | `[Float]?` | Vector embedding for semantic search |
| `contentHash` | `String` | SHA-256 hash for deduplication |
| `isSensitive` | `Bool` | Auto-detected sensitive content flag |
| `expiresAt` | `Date?` | Auto-expire time (for sensitive items) |
| `metadata` | `[String: String]` | Extensible key-value metadata |

### ContentType Enum

```swift
enum ContentType: String, Codable {
    case text
    case richText
    case image
    case file
    case link
    case color
    case code
}
```

### AppInfo

```swift
struct AppInfo: Codable {
    let bundleId: String
    let name: String
    let iconPath: String?
}
```

---

## 9. Performance Requirements

| Metric | Target | Measurement |
|---|---|---|
| Capture latency | < 10ms | Time from pasteboard change to EventBus emission |
| Search latency (FTS) | < 50ms (P95) | Time from keystroke to rendered results |
| Search latency (semantic) | < 200ms (P95) | Embedding similarity search |
| OCR processing | < 500ms | Per image, async |
| Memory (idle, menu bar) | < 30MB | No history panel open |
| Memory (active, 10k items) | < 200MB | History panel open with scrolling |
| Memory (active, 100k items) | < 400MB | Virtualized list, lazy loading |
| Storage (10k text items) | < 50MB | SQLCipher database |
| Startup time | < 1s | Cold start to menu bar ready |
| Paste latency | < 20ms | From Enter key to paste in target app |

---

## 10. Tech Stack

* **Language:** Swift 6 (strict concurrency)
* **UI:** SwiftUI + AppKit bridges (NSPanel, NSWindow)
* **Storage:** SQLite + FTS5 via GRDB.swift
* **Encryption:** SQLCipher (encryption at rest)
* **OCR:** Apple Vision framework (VNRecognizeTextRequest)
* **AI:** On-device embedding (Core ML) / API pluggable (OpenAI, Ollama)
* **Hotkeys:** Carbon API (RegisterEventHotKey) via HotKey library
* **Networking:** URLSession (for sync and link previews, optional)
* **Build:** Xcode + Swift Package Manager

---

## 11. Roadmap

### Phase 1 — MVP (8 weeks)

* Clipboard capture engine (all content types)
* SQLite + FTS5 storage with SQLCipher encryption
* Timeline UI (vertical, keyboard-first, virtualized)
* Global shortcut activation (⇧⌘V)
* Full-text search with fuzzy matching
* Sensitive content auto-detection with auto-expire
* Per-app blacklist (with presets)
* Quick edit before paste
* OCR for images (Apple Vision)
* Menu bar app with basic settings

### Phase 2 — Power Features (6 weeks)

* Pin / Star / Collections with drag-and-drop
* Paste Stack (multi-item sequential paste)
* Snippets & Templates with variables
* Content transformation pipeline (JSON format, URL encode, etc.)
* Tag system (manual + auto-generated)
* Rich preview panel (syntax highlighting, image zoom, link preview)
* Screen sharing auto-hide mode
* Keyboard shortcuts customization

### Phase 3 — AI & Extensibility (8 weeks)

* On-device embedding model (Core ML)
* Semantic search
* AI content actions (summarize, translate, rewrite, explain code)
* Plugin SDK with lifecycle hooks
* Plugin manager UI
* Developer documentation + example plugins
* CLI interface (`openpaste` command)

### Phase 4 — Sync & Polish (4 weeks)

* iCloud sync with end-to-end encryption
* Touch ID / Apple Watch unlock
* macOS Shortcuts.app integration
* Notification Center widget
* Onboarding flow for new users
* Performance optimization pass
* Public beta release on GitHub

---

## 12. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|:---:|---|
| macOS permission constraints (Accessibility, screen recording) | High | Clear onboarding flow, minimal permissions for MVP, graceful degradation |
| Performance with large history (100k+ items) | High | Virtualized lists, lazy loading, database pagination, async indexing |
| AI cost if cloud-based | Medium | On-device models first (Core ML), cloud AI as opt-in with user's own API keys |
| Clipboard event miss during high CPU | Medium | Configurable polling interval, event queue with retry, health monitoring |
| Competition from Raycast's clipboard feature | Medium | Deeper AI integration, open-source community, plugin ecosystem |
| SQLCipher performance overhead | Low | Benchmark early, WAL mode, optimize queries, page-level encryption |
| App Store rejection (if distributed via MAS) | Low | Primary distribution via GitHub/Homebrew, MAS as optional channel |

---

## 13. Success Metrics

### Adoption (within 6 months of public release)

| Metric | Target |
|---|---|
| GitHub stars | > 1,000 |
| Monthly active installs | > 5,000 |
| Community contributors | > 10 |
| Homebrew installs | > 2,000 |

### Engagement (per daily active user)

| Metric | Target |
|---|---|
| Items captured per day | > 30 |
| Search-to-paste ratio | > 40% (users search instead of scroll) |
| Paste Stack usage | > 15% of daily active users |
| AI feature usage | > 20% of daily active users |
| Average session duration | > 5 minutes |

### Quality

| Metric | Target |
|---|---|
| Crash-free rate | > 99.5% |
| Capture miss rate | < 0.1% |
| Search latency P95 | < 50ms |
| Memory footprint (idle) | < 30MB |
| Memory footprint (10k items) | < 200MB |

### Community Health

| Metric | Target |
|---|---|
| Issue response time | < 48 hours |
| PR review time | < 1 week |
| Community plugins | > 5 within first year |
| Documentation coverage | > 80% of public APIs |

---

## 14. Future Ideas (Post v1)

* **Cross-platform:** Windows/Linux via Electron or Tauri (separate project)
* **Universal Clipboard enhancement:** Extend Apple Universal Clipboard with history on iPhone/iPad
* **Team clipboard:** Share clipboard items via local network (Bonjour/mDNS)
* **Context-aware paste:** Auto-suggest relevant items based on active app and recent activity
* **Clipboard analytics:** Statistics on copy/paste habits, top apps, peak hours
* **Knowledge graph:** Build connections between related clipboard items over time
* **Browser extension:** Dedicate "copy to OpenPaste" action with metadata

---

## 15. UX/Design Direction

### Design Principles

1. **Speed over chrome** — Every interaction must feel instant. Prefer function over decoration
2. **Keyboard-first, mouse-friendly** — Power users never leave the keyboard, casual users can click
3. **Progressive disclosure** — Show simple by default, reveal power on demand
4. **System-native feel** — Follow macOS HIG, support dark/light mode, respect system font size

### Visual Direction

* **Color palette:** Monochrome base with accent color (user-configurable)
* **Typography:** SF Pro (system font) for consistency with macOS
* **Layout:** Compact vertical list (inspired by Spotlight/Raycast), not horizontal timeline
* **Animations:** Subtle, functional — spring animations for panel open/close, fade for search results
* **Dark mode:** First-class support, auto-follow system setting
* **Accessibility:** VoiceOver support, sufficient contrast ratios, keyboard-only navigation

### Key UI Patterns

* **Spotlight-style overlay:** Center-screen panel with search at top, results below
* **Type badges:** Visual icons for content type (text, image, file, link, code)
* **Source app indicator:** Small app icon next to each item
* **Sensitive content blur:** Auto-blur sensitive items, reveal on hover/click
* **Paste Stack indicator:** Floating badge showing stack count and position

---

## 16. Tagline

> "Clipboard is not temporary. It's memory."
