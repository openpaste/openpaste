### Added
• **Optimize Storage** — new button in Settings → Storage to reclaim disk space by purging soft-deleted items and running SQLite VACUUM, with before/after size comparison

### Fixed
• **iCloud Sync reliability** — fixed 5 sync bugs including ServerRecordChanged errors, stuck records from "already exists" failures, orphaned tombstone metadata, incorrect last-write-wins for pinned/starred fields, and missing device ID on smart list operations
• **Ignore Applications overhaul** — blacklisted apps are now stored in UserDefaults (no more hardcoded defaults being ignored), added 1Password 8 detection, recognizes proprietary transient/confidential pasteboard types (nspasteboard.org), and added file browser to select apps from disk
• **Bottom shelf keyboard navigation** — arrow keys now work immediately on open instead of being captured by search; type any character to auto-focus search, press ⌘F to focus search explicitly, and Escape unfocuses search before dismissing the panel
