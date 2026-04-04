# macOS HIG Checklist

## Platform fit
- Use the menu bar to expose commands people expect.
- Support keyboard-first workflows and standard shortcuts.
- Let people resize, move, hide, show, and use full-screen windows.
- Prefer comfortable information density over oversized empty layouts.
- Support personalization when practical, like toolbar customization and accent-aware UI.

## Windows and panels
- Use system-provided window chrome; avoid custom frames and controls.
- Open new windows only when preserving context or enabling multitasking helps.
- Use the word `window` in user-facing copy.
- Avoid critical actions or information at the bottom edge of a window.
- Keep floating panels visually consistent with active and inactive window states.

## Menus and menu bar
- Keep standard top-level ordering: app, File, Edit, Format, View, app-specific, Window, Help.
- Disable unavailable menu items instead of hiding them.
- Use title-style capitalization and short menu titles.
- Add an ellipsis only when more input is required.
- Use standard keyboard shortcuts and standard selectors for common actions.
- Keep app-specific commands discoverable in the menu bar.

## Menu bar extras
- Prefer a symbol or SF Symbol for the extra.
- Show a menu by default, not a popover, unless complexity truly requires it.
- Let people choose whether the extra appears in the menu bar.
- Never rely only on the menu bar extra; keep alternate access paths.

## Toolbars and sidebars
- Use no more than about three toolbar groups.
- Put navigation on the leading side and any primary action on the trailing side.
- Prefer standard symbols without decorative borders.
- Keep every toolbar action available somewhere in the menu bar.
- Extend content beneath sidebars when the layout supports it.
- Avoid critical actions at the bottom of sidebars.

## Search
- For macOS, a trailing toolbar search field is the default global-search home.
- Put search in the sidebar only when it filters sidebar content or navigation.
- Use descriptive placeholder text; never waste the prompt on “Search”.
- Start search as someone types when possible.
- Default to broad scope, then let people refine.

## Liquid Glass and polish
- Rebuild with the latest SDKs and review standard components first.
- Reduce custom toolbar and control backgrounds that fight system materials.
- Use system colors or full light, dark, and high-contrast variants.
- Test reduce transparency, increase contrast, and reduce motion settings.