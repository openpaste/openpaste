# Phase 2: Storage Layer (CorePersistence + CoreSearch)

## Priority: High | Status: not-started
## Dependencies: Phase 1

## Overview
Implement GRDB-based SQLite storage with FTS5 full-text search, migrations, and CRUD operations.

## File Ownership (EXCLUSIVE)
- `OpenPaste/Services/Storage/DatabaseManager.swift`
- `OpenPaste/Services/Storage/ClipboardItemRecord.swift`
- `OpenPaste/Services/Storage/Migrations.swift`
- `OpenPaste/Services/Storage/StorageService.swift`
- `OpenPaste/Services/Search/SearchEngine.swift`
- `OpenPaste/Services/Search/FuzzyMatcher.swift`

## Implementation Steps

### 1. DatabaseManager
- Create DatabaseQueue (not Pool for MVP simplicity)
- WAL mode enabled
- App Support directory path
- Run migrations on init

### 2. Migrations
- v1: Create clipboard_items table with all ClipboardItem fields
- v1: Create FTS5 virtual table for full-text search
- v1: Create indexes on createdAt, contentHash, sourceApp

### 3. ClipboardItemRecord
- GRDB record type matching ClipboardItem
- FetchableRecord + PersistableRecord conformance
- Column definitions

### 4. StorageService (implements StorageServiceProtocol)
- save(_ item:) async throws
- fetch(limit:offset:) async throws -> [ClipboardItem]
- delete(_ id:) async throws
- fetchByHash(_ hash:) async throws -> ClipboardItem?
- updateAccessCount(_ id:) async throws
- deleteExpired() async throws
- itemCount() async throws -> Int

### 5. SearchEngine (implements SearchServiceProtocol)
- search(query:filters:) async throws -> [ClipboardItem]
- FTS5 MATCH queries
- Filter by: type, source app, date range, pinned/starred
- Highlight matching terms

### 6. FuzzyMatcher
- Typo-tolerant matching using String distance
- Prefix matching for search-as-you-type

## Success Criteria
- Can save and retrieve ClipboardItems
- FTS5 search returns relevant results <50ms
- Deduplication via contentHash works
- Expired items auto-deleted
