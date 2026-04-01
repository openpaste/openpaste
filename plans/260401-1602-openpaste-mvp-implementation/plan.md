# OpenPaste MVP Implementation Plan

## Overview
Implement Phase 1 MVP of OpenPaste — a macOS-native clipboard manager with clipboard capture, SQLite/FTS5 storage, timeline UI, search, OCR, and sensitive content detection.

**Target:** macOS 14+ (Sonoma) | **Lang:** Swift 6 strict concurrency | **UI:** SwiftUI + AppKit

## Scope (Phase 1 MVP)
- Clipboard capture engine (text, rich text, images, files, URLs, colors)
- SQLite + FTS5 storage via GRDB.swift
- Timeline UI (vertical, keyboard-first)
- Global shortcut activation (⇧⌘V)
- Full-text search with fuzzy matching
- Sensitive content auto-detection with auto-expire
- Per-app blacklist
- OCR for images (Apple Vision)
- Menu bar app with basic settings

## Architecture
Single Xcode app target with organized folders following protocol-based DI:
```
OpenPaste/
├── App/          → App lifecycle, DI container, window management
├── Models/       → Data models, enums, protocols
├── Services/     → Business logic (clipboard, storage, search, processing)
├── ViewModels/   → @Observable view models
├── Views/        → SwiftUI views organized by feature
└── Utilities/    → Extensions, constants
```

## Dependency Graph
```
Phase 1 ──┬── Phase 2 (Storage)     ──┐
           ├── Phase 3 (Clipboard)    ├── Phase 5 (Feature UI) ── Phase 6 (Settings)
           └── Phase 4 (App Shell)   ──┘
```

## Phases

| # | Phase | Status | Deps | File Ownership |
|---|-------|--------|------|----------------|
| 1 | Project Setup + Models | ✅ complete | none | Models/*, Services/Protocols/* |
| 2 | Storage Layer | ✅ complete | 1 | Services/Storage/* |
| 3 | Clipboard Capture + Processing | ✅ complete | 1 | Services/Clipboard/*, Services/Processing/* |
| 4 | App Shell + UI Foundation | ✅ complete | 1 | App/*, Views/Shared/*, Utilities/* |
| 5 | Feature UI (History + Search) | ✅ complete | 2,3,4 | Views/History/*, Views/Search/*, ViewModels/* |
| 6 | Settings + Final Integration | ✅ complete | 5 | Views/Settings/*, Services/Security/* |

## Execution Strategy
- **Group A (Sequential):** Phase 1
- **Group B (Parallel):** Phases 2, 3, 4
- **Group C (Sequential):** Phase 5 (after Group B)
- **Group D (Sequential):** Phase 6 (after Phase 5)

## Dependencies
- GRDB.swift v7.x (SPM)
- Apple Vision framework (system)
- AppKit (system, for NSPanel/NSStatusItem)

## Key Decisions
- No SQLCipher (deferred) — plain SQLite for MVP
- No HotKey library — use NSEvent.addGlobalMonitorForEvents
- Single app target (not modular SPM packages) — modularize post-MVP
- MenuBarExtra for menu bar presence
