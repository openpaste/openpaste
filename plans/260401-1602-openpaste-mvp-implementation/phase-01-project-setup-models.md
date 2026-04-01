# Phase 1: Project Setup + Core Models

## Priority: Critical | Status: not-started
## Dependencies: None

## Overview
Set up project structure, add GRDB.swift dependency, create all data models, enums, protocols, and the event bus system.

## File Ownership (EXCLUSIVE)
- `OpenPaste/Models/ClipboardItem.swift`
- `OpenPaste/Models/ContentType.swift`
- `OpenPaste/Models/AppInfo.swift`
- `OpenPaste/Models/AppEvent.swift`
- `OpenPaste/Services/Protocols/ClipboardServiceProtocol.swift`
- `OpenPaste/Services/Protocols/StorageServiceProtocol.swift`
- `OpenPaste/Services/Protocols/SearchServiceProtocol.swift`
- `OpenPaste/Services/Protocols/OCRServiceProtocol.swift`
- `OpenPaste/Services/Protocols/SecurityServiceProtocol.swift`
- `OpenPaste/Services/EventBus.swift`

## Implementation Steps

### 1. Add GRDB.swift SPM dependency
- Add GRDB.swift package via Xcode SPM (URL: https://github.com/groue/GRDB.swift.git)
- Target: OpenPaste app

### 2. Create folder structure
```
OpenPaste/
├── App/
├── Models/
├── Services/
│   ├── Protocols/
│   ├── Clipboard/
│   ├── Storage/
│   ├── Search/
│   ├── Processing/
│   └── Security/
├── ViewModels/
├── Views/
│   ├── History/
│   ├── Search/
│   ├── Settings/
│   └── Shared/
└── Utilities/
```

### 3. Create ContentType enum
```swift
enum ContentType: String, Codable, Sendable {
    case text, richText, image, file, link, color, code
}
```

### 4. Create AppInfo struct
- bundleId, name, iconPath — all Codable + Sendable

### 5. Create ClipboardItem model
- All fields from PRD data model
- Conform to Identifiable, Codable, Sendable, Hashable
- GRDB FetchableRecord + PersistableRecord conformance

### 6. Create AppEvent enum
- All events from PRD event flow
- Sendable conformance

### 7. Create EventBus
- Actor-based, uses AsyncStream<AppEvent>
- Methods: emit(_:), stream() -> AsyncStream<AppEvent>

### 8. Create service protocols
- ClipboardServiceProtocol: startMonitoring(), stopMonitoring()
- StorageServiceProtocol: save, fetch, delete, search operations
- SearchServiceProtocol: search(query:filters:) -> [ClipboardItem]
- OCRServiceProtocol: extractText(from:) async -> String?
- SecurityServiceProtocol: detectSensitive(_:) -> Bool

## Success Criteria
- All models compile with Swift 6 strict concurrency
- Protocols define clear contracts
- EventBus can emit and receive events
- GRDB dependency resolves
