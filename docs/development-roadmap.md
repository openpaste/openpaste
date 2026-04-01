# OpenPaste Development Roadmap

Strategic roadmap for OpenPaste development phases, milestones, and feature priorities.

**Last Updated:** April 2026  
**Current Phase:** Foundation (In Progress)  

---

## Phase 1: Foundation – Core Clipboard Management ⚙️

**Status:** In Progress (70% complete)
**Target Completion:** Q2 2026

### Completed Milestones ✅

1. **Project Setup & Architecture**
   - macOS app structure (SwiftUI + AppKit blend)
   - Core data model (Clipboard, ClipboardItem)
   - Persistence layer (SQLCipher integration study)

2. **Basic Clipboard Capture & History**
   - Clipboard monitoring loop
   - Item deduplication logic
   - SQLite/SQLCipher storage proof-of-concept
   - Item metadata (timestamp, source app, content type)

3. **Global Hotkey System**
   - `HotkeyManager` for global keyboard shortcuts
   - Customizable hotkey binding
   - Persistence to `UserDefaults`

4. **Onboarding & First-Launch Experience** ✨ NEW
   - 5-step guided setup flow
   - Accessibility permission handling with system integration
   - Global hotkey customization during onboarding
   - Launch at login configuration UI
   - Live permission status polling
   - 20 unit tests validating navigation and state

### Active Milestones 🔄

3. **UI/UX Foundation**
   - Main clipboard history window (list view with previews)
   - Quick search interface
   - Item detail inspector
   - Dark mode support

### Planned Milestones 📋

4. **Advanced Search & Filtering**
   - Full-text search with Spotlight integration
   - Filtering by content type (text, image, URL)
   - Time-based filtering (today, this week, older)

5. **Image Support & Preview**
   - Capture clipboard images
   - Image preview in history
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

2. **Cloud Sync** (Optional)
   - iCloud integration for multi-device sync
   - End-to-end encryption for synced data
   - Conflict resolution

3. **Advanced UI**
   - Inline editing for clipboard items
   - Drag-and-drop organization
   - Collection/folder management
   - Custom themes and layouts

---

## Success Metrics

- [ ] Clipboard history with 5,000+ items without performance degradation
- [ ] Global hotkey response time < 100ms
- [ ] Accessibility permission check and deep linking reliable
- [ ] All onboarding tests passing (20/20)
- [ ] User can customize hotkey and set launch-at-login preferences
- [ ] Onboarding completes in < 2 minutes for typical user

---

## Dependencies & Blockers

| Dependency | Status | Impact |
|-----------|--------|--------|
| SQLCipher integration | Pending | Required for Phase 2 |
| macOS version targeting (11.0+) | Confirmed | Security baseline |
| Accessibility framework stability | Validated | Onboarding Phase 1 ✅ |
| SwiftUI animation performance | Validated | UI polish ✅ |

---

## Notes

- **Q2 2026 Focus:** Complete foundation phases (basic history, search, image support)
- **Onboarding Release:** Ready for initial user feedback loop
- **Testing Strategy:** Unit tests prioritized for ViewModel logic; integration tests for permission detection
- **Future:** Consider OAuth-based cloud sync if community demand exists
