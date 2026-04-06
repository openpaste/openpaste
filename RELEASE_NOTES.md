### Added
• Smart Lists — create custom rules to automatically filter your clipboard history by content type, text, tags, date, length, and more. Combine rules with AND/OR logic and choose from 5 built-in presets (Today, Images, Links, Code Snippets, Sensitive)
• Smart List editor with icon picker, color picker, sort order, and item limit options
• Smart Lists sync across devices via iCloud with conflict resolution
• Import and export Smart Lists as JSON for backup and sharing
• Native menu bar — migrated to a full AppKit NSStatusItem menu with recent copies, quick actions, and diagnostics
• Pause clipboard monitoring directly from the menu bar with configurable duration (5 min, 15 min, 1 hour, or until resume)
• Smart auto-pause detection that stops monitoring when sensitive apps like 1Password are in the foreground
• New Text Item floating panel — manually add text entries to your clipboard history from the menu bar
• Quick actions in the menu bar: clear history, open preferences, toggle launch at login
• iCloud sync health dashboard showing sync status, last sync time, and device name
• Sync retry engine with exponential backoff for reliable iCloud operations
• Network reachability monitoring — sync pauses gracefully when offline and resumes automatically
• iCloud account change detection with automatic re-initialization
• CloudKit rate limit handling to avoid throttling

### Changed
• Menu bar icon dynamically reflects monitoring state (active, paused, or disabled)
• Improved sync reliability with zone-not-found recovery, tombstone cleanup, and metadata pruning
