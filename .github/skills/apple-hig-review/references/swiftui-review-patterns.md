# SwiftUI Review Patterns

## Prefer these system components
- `NavigationSplitView` for sidebar, content, and detail layouts
- `Form` and grouped sections for settings and structured input
- `List` or `Table` for dense, scannable content
- `ToolbarItem` placements instead of custom top bars
- `.searchable(...)` instead of bespoke search UI
- `Menu`, `Commands`, and `confirmationDialog` for standard actions
- `MenuBarExtra` or status-item patterns for lightweight utilities
- `backgroundExtensionEffect()` when content should visually continue under sidebars
- standard bars or scroll edge effects instead of custom blurred overlays

## Controls and icons
- Prefer SF Symbols for common actions.
- Add `accessibilityLabel` to every icon-only control.
- Avoid mixing symbol-only and text-labeled actions inside one shared visual group.
- Use one prominent primary action at most.
- Leave spacing to system defaults unless a real usability problem exists.

## Search review cues
- Check whether search is global or local; place it accordingly.
- Toolbar trailing position usually means global search on macOS.
- Sidebar-top search usually means filtering navigation or the current collection.
- Placeholder text should describe content types, not repeat the word “Search”.
- Suggestions, scopes, or tokens should narrow the search, not complicate it.

## Accessibility review cues
- Verify keyboard navigation and Full Keyboard Access paths.
- Check text scaling, contrast, hover and focus states, and Reduce Motion behavior.
- Never rely on color alone to signal status.
- Keep controls comfortably sized and spaced.
- Prefer explicit buttons in addition to gestures for important actions.

## Copy and writing
- Use concise, task-based labels.
- Use title-style capitalization for menu items and section headers.
- Prefer standard labels like Settings…, Help, Copy, Paste, Delete, and Done when they fit.
- Avoid cute wording when standard Apple language is clearer.

## Review-to-code translation
When the user wants fixes, convert findings into:
1. affected view or modifier
2. specific system API to prefer
3. smallest code change
4. accessibility follow-up