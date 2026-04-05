# OpenPaste Launch FAQ

## What is OpenPaste today?

OpenPaste is a native macOS clipboard manager built with SwiftUI and AppKit. Today it focuses on fast local recall, keyboard-first workflows, collections, paste stack, OCR, and privacy-aware defaults.

## What ships today?

- Clipboard history
- Fast local search
- Collections, pin/star, and paste stack
- OCR for copied images
- Quick edit before paste
- Keyboard-first navigation and global hotkey
- Sensitive-content detection, app blacklist, and screen-sharing pause

## Is OpenPaste “AI-native” today?

No. AI-oriented work such as semantic search or smart content actions is part of the longer-term roadmap, not the current shipped experience.

## Does OpenPaste require the cloud?

No. OpenPaste is local-first by default and works without a cloud account.

## Does OpenPaste collect telemetry?

No. OpenPaste does not ship with analytics or usage tracking.

## How does privacy work today?

Today the app focuses on local-first defaults, sensitive-content detection, per-app blacklist controls, and pausing capture during screen sharing.

## Is iCloud sync available?

There is a CloudKit sync foundation in the codebase, but in current builds it is a premium-gated, still-maturing feature path and not the core story for the first-user launch window.

## Is encryption at rest enabled?

Yes in current builds: the local database is encrypted at rest with **SQLCipher by default**, using a per-install passphrase stored in the macOS Keychain. The app also writes a `.encrypted` marker file next to the database after the initial open/migration to prevent repeated migration loops (it contains no secrets).

## Why be this explicit?

Because developer trust is easier to lose than to earn back. OpenPaste would rather undersell and ship than overclaim and disappoint.

## Where should I look for the roadmap?

- `docs/development-roadmap.md` for product phases
- `../plans/260403-first-users-roadmap/plan.md` for the current 6-week first-users push

## How do I give feedback?

- Open `Settings` → `About` → `Send Feedback…` to open a pre-filled draft in GitHub or Mail
- Use the GitHub issue form in `.github/ISSUE_TEMPLATE/feedback.yml`
- Or copy the template from `docs/feedback-template.md`
- Best feedback includes: install method, macOS version, what you copied, what you expected, and what broke or felt slow