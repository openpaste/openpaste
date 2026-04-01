# Phase 3: Clipboard Capture + Processing

## Priority: High | Status: not-started
## Dependencies: Phase 1

## Overview
Implement pasteboard monitoring, content capture for all types, source app detection, deduplication, sensitive content detection, and OCR.

## File Ownership (EXCLUSIVE)
- `OpenPaste/Services/Clipboard/ClipboardMonitor.swift`
- `OpenPaste/Services/Clipboard/ContentNormalizer.swift`
- `OpenPaste/Services/Clipboard/ClipboardService.swift`
- `OpenPaste/Services/Processing/SensitiveContentDetector.swift`
- `OpenPaste/Services/Processing/OCRService.swift`
- `OpenPaste/Services/Processing/ContentHasher.swift`

## Implementation Steps

### 1. ClipboardMonitor
- Poll NSPasteboard.general every 500ms (configurable)
- Track changeCount to detect new content
- Use Timer + async/await pattern
- Start/stop methods

### 2. ContentNormalizer
- Detect content type from pasteboard types (UTType)
- Extract: plain text, RTF, images (PNG/JPEG/TIFF), file URLs, web URLs, colors
- Convert to ClipboardItem with appropriate ContentType
- Size limit check (10MB default)

### 3. ClipboardService (implements ClipboardServiceProtocol)
- Orchestrates: monitor → normalize → dedup → detect sensitive → emit event
- Uses EventBus to emit clipboardChanged events
- Handles app blacklist filtering
- Source app detection via NSWorkspace.shared.frontmostApplication

### 4. ContentHasher
- SHA-256 hash of content Data
- Used for deduplication

### 5. SensitiveContentDetector (implements SecurityServiceProtocol)
- Regex patterns for: credit cards, API keys (AWS/GCP/Stripe), JWT tokens, private keys, SSN
- Heuristic: high entropy strings
- Returns isSensitive flag + suggested expiry

### 6. OCRService (implements OCRServiceProtocol)
- Apple Vision VNRecognizeTextRequest
- Async processing, doesn't block capture
- Returns extracted text string
- English language default

## Success Criteria
- Captures all content types from pasteboard
- Deduplicates via content hash
- Detects sensitive content patterns
- OCR extracts text from images asynchronously
- Source app tracked accurately
