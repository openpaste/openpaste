### Fixed
• Settings window now opens reliably using SwiftUI `openSettings` environment instead of `NSApp.sendAction` (4a7a319)
• Prevented infinite loop in iCloud sync when `CKSyncEngine` fires `accountChange(.signIn)` on init — added re-entrancy guard (a37bc40)
• Resolved repeated `didChangeImage` warnings by caching menu bar items (4a7a319)

### Changed
• Simplified storage path resolution using standard `FileManager` API instead of manual container path construction (1752eb0)

### Testing
• Added E2E tests for Settings window: verifies all sections appear and navigation works (fd8cb37)
