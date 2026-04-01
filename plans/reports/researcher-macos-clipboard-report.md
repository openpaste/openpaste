# macOS Clipboard Manager Research Report

## Executive Summary
This report investigates core implementation strategies for a macOS clipboard manager, focusing on real-time clipboard monitoring, content capture, source detection, and UI patterns. Key findings indicate NSPasteboard change notifications enable efficient monitoring, content-type detection requires UTType framework, and global keyboard shortcuts demand accessibility permissions. Critical gaps remain in persistent content handling and cross-app compatibility.

## Research Methodology
Synthesized from macOS frameworks documentation, open-source clipboard tools (ClipMenu, Pasty), and Cocoa best practices. Focuses on High Sierra+ APIs and accessibility requirements.

---

## Findings

### 1. NSPasteboard Monitoring Approach
Use `NSPasteboard.generalPasteboard()` with change count polling or NSPasteboardChangeNotification listener. Change count comparison (integer diff) is lightweight; notification-based approach requires app foregrounding. Hybrid: poll when app backgrounded, notify when active.

### 2. Content Type Capture Strategy
Leverage UTType framework to detect available content types via `availableTypeFromArray()`. Store text (NSPasteboardTypeString), images (NSPasteboardTypeTIFF), RTF, and URLs separately. Use type priorities to handle multiple formats gracefully.

### 3. Source App Detection Method
Query `NSRunningApplication.runningApplications()` and check active app via `frontmostApplication`. Capture bundle ID and process name at paste timestamp. Limitation: system services and some Electron apps don't expose source reliably.

### 4. Menu Bar UI Pattern
Standard NSStatusBar with NSStatusBarButton + NSMenu for quick access. Emoji/icon ≤16x16 for retina. Menu items show 30-50 char preview. Follow macOS Sonoma guidelines: light/dark mode vector assets, no custom shapes without UX research.

### 5. Overlay Panel Creation
Floating NSPanel (canBeHiddenByHotKey = true) with NSVisualEffectView (Material.hudWindow) for semi-transparent blur effect. Position near cursor or keyboard center. Support keyboard navigation with NSResponder chain. Hide on focus loss or Escape key press.

### 6. Global Keyboard Shortcuts
Use `DDHotKey` library or native `NSEvent.addGlobalMonitorForEvents()` (requires accessibility permissions via Info.plist + System Preferences delegation). Mac App Store apps cannot use global shortcuts without sandboxing workarounds; recommend notarized independent app.

### 7. Programmatic Paste
Simulate keystroke via `CGEvent(keyboardEventSource:, virtualKey:, keyDown:)` for Cmd+V. Alternative: use accessibility API for AXWriteAttribute on focused text element. First approach is simpler but less reliable in controlled environments; second requires accessibility permissions.

### 8. Transient Content Detection
Track clipboard age via timestamp comparison. Implement 5-10 minute auto-expire heuristic or user-configurable TTL. Flag sensitive content (passwords, API keys via regex) for deletion on app close. Limitation: cannot distinguish user-initiated vs. programmatic clipboard changes reliably.

### 9. Deduplication Approach
Hash content (SHA-256 for text, MD5 for binary) and store in SQLite with timestamps. Compare new paste hash against last 100 entries; skip duplicates within 30-sec window. For images, use perceptual hashing or pixel-level comparison. Performance tradeoff: stricter = slower.

---

## Unresolved Questions

- How to audit clipboard access for security/privacy compliance post-Monterey?
- Can we detect clipboard changes initiated by system services vs. user apps?
- What is the maximum sustainable history size (GB) without performance degradation?
- How to safely handle sensitive content (passwords, auth tokens) without user awareness?
- Are background clipboard monitors compatible with macOS App Store sandbox restrictions?

---

**Report Date:** 2025  
**Target Platform:** macOS 12.0+ (Intel & Apple Silicon)  
**Key Constraint:** Accessibility permissions mandatory for global shortcuts and programmatic paste simulation.
