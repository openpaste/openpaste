# Phase 5: Feature UI (History + Search)

## Priority: High | Status: not-started
## Dependencies: Phase 2, 3, 4

## Overview
Build the main clipboard history timeline UI and search interface. Integration of capture, storage, and search with the UI layer.

## File Ownership (EXCLUSIVE)
- `OpenPaste/Views/History/HistoryView.swift`
- `OpenPaste/Views/History/ClipboardItemRow.swift`
- `OpenPaste/Views/History/QuickEditView.swift`
- `OpenPaste/Views/Search/SearchView.swift`
- `OpenPaste/Views/Search/SearchFilterView.swift`
- `OpenPaste/ViewModels/HistoryViewModel.swift`
- `OpenPaste/ViewModels/SearchViewModel.swift`
- `OpenPaste/ContentView.swift` (modify existing → becomes main container)

## Implementation Steps

### 1. HistoryViewModel (@Observable, @MainActor)
- items: [ClipboardItem] — loaded from StorageService
- Load items on appear, observe for changes
- paste(_ item:) — copy to pasteboard + simulate ⌘V
- delete(_ item:)
- pin/unpin, star/unstar
- Handle pagination (load more on scroll)

### 2. HistoryView
- Vertical ScrollView with LazyVStack
- ClipboardItemRow for each item
- Keyboard navigation (arrow keys, Enter to paste)
- Pull to refresh
- Empty state
- Loading state

### 3. ClipboardItemRow
- TypeIcon + content preview + source app badge
- RelativeTimestamp
- Pin/Star indicators
- Sensitive content indicator (🔒)
- Swipe actions: delete, pin, star
- Click to paste

### 4. SearchViewModel (@Observable, @MainActor)
- query: String (debounced)
- filters: SearchFilters (type, source app, date range)
- results: [ClipboardItem]
- Search via SearchServiceProtocol
- Highlight matching text

### 5. SearchView
- Search text field (focused on panel open)
- Filter bar (content type pills, source app dropdown)
- Results list using ClipboardItemRow
- Search-as-you-type

### 6. SearchFilterView
- Content type filter buttons
- Date range picker
- Source app filter

### 7. QuickEditView
- Inline text editor for clipboard content
- Save modified content
- Cancel/dismiss

### 8. ContentView (modify)
- Main container: SearchView on top + HistoryView below
- Tab between search and browse modes
- Receives DependencyContainer from environment

## Success Criteria
- History shows captured items in reverse chronological order
- Search returns results <50ms with highlighting
- Keyboard navigation works (arrows, enter, escape)
- Pin/Star/Delete actions work
- Quick edit allows modifying content before paste
