### Added
• Drag clipboard cards from the Bottom Shelf directly into external apps — text, rich text, images, files, and links are exported via standard pasteboard types so they land correctly in any target application (0984c18)

### Fixed
• Global hotkey no longer triggers unintended actions in the foreground app (e.g. Paste and Match Style in Safari/Notes) — replaced NSEvent monitors with a CGEvent tap that swallows the configured shortcut before it reaches other apps (deba1d9)
• Accessibility permission prompt now works reliably on first launch — opens System Settings directly and reveals the app bundle for easy drag-and-drop granting, bypassing the silent App Sandbox suppression of the system dialog (ae550b9)
• Status bar menu items appear instantly on click — menu is now built synchronously in menuWillOpen, with caches refreshed asynchronously afterward (86c0ec1)
