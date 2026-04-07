### Fixed
• **Drag-and-drop to VS Code & Electron apps** — images can now be dragged into VS Code, Slack, and other Electron-based apps via file URL + PNG export
• **Drag-and-drop reliability** — panel no longer closes prematurely during cross-app drags; a grace period ensures destination apps can read the dragged data
• **Faster drag start** — text, links, and URLs now register synchronously so the drag begins instantly without waiting for a database fetch
• **Image drag formats** — images are now offered as PNG, TIFF, NSImage, and file URL for maximum compatibility across macOS apps
