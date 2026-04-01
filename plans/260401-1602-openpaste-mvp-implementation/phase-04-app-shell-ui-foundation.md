# Phase 4: App Shell + UI Foundation

## Priority: High | Status: not-started
## Dependencies: Phase 1

## Overview
Convert app to menu bar app, create floating overlay panel, implement global shortcuts, and build shared UI components.

## File Ownership (EXCLUSIVE)
- `OpenPaste/App/OpenPasteApp.swift` (modify existing)
- `OpenPaste/App/AppDelegate.swift`
- `OpenPaste/App/DependencyContainer.swift`
- `OpenPaste/App/WindowManager.swift`
- `OpenPaste/App/HotkeyManager.swift`
- `OpenPaste/Views/Shared/TypeIcon.swift`
- `OpenPaste/Views/Shared/RelativeTimestamp.swift`
- `OpenPaste/Views/Shared/ContentPreviewView.swift`
- `OpenPaste/Utilities/Constants.swift`
- `OpenPaste/Utilities/Extensions.swift`

## Implementation Steps

### 1. OpenPasteApp (modify)
- Convert to menu bar app using MenuBarExtra
- Add NSApplicationDelegateAdaptor for AppDelegate
- Remove WindowGroup, use MenuBarExtra with window style
- App icon in menu bar (clipboard icon)

### 2. AppDelegate
- NSApplicationDelegate conformance
- Set up app as agent (LSUIElement behavior)
- Handle activation/deactivation
- Register for accessibility permissions check

### 3. DependencyContainer
- Create all services: ClipboardService, StorageService, SearchService, OCRService
- Wire protocols to implementations
- @Observable for SwiftUI injection via @Environment
- Lazy initialization

### 4. WindowManager
- Create NSPanel for clipboard history overlay
- Non-activating, floating, borderless
- Positioned near menu bar or center screen
- Show/hide with animation
- Auto-dismiss on Escape or click outside
- NSVisualEffectView for vibrancy

### 5. HotkeyManager
- NSEvent.addGlobalMonitorForEvents for ⇧⌘V
- Toggle overlay panel
- Handle accessibility permission prompt

### 6. Shared UI Components
- TypeIcon: SF Symbols per ContentType (doc.text, photo, link, etc.)
- RelativeTimestamp: "2m ago", "yesterday", etc.
- ContentPreviewView: text preview (3 lines), image thumbnail, file info

### 7. Constants
- Default polling interval (500ms)
- Max item size (10MB)
- Default sensitive expiry (1 hour)
- Blacklist presets

### 8. Extensions
- Date+RelativeFormatting
- String+Truncation
- Data+SHA256
- NSImage+Thumbnail

## Success Criteria
- App runs as menu bar only (no dock icon)
- ⇧⌘V toggles overlay panel
- Panel dismisses on Escape/click outside
- Shared UI components render correctly
