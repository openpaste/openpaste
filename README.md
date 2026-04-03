<p align="center">
  <img src="OpenPaste/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="OpenPaste Icon" />
</p>

<h1 align="center">OpenPaste</h1>

<p align="center">
  <strong>Native, local-first clipboard manager for developers on macOS</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPLv3-blue.svg" alt="License: AGPLv3" /></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-brightgreen.svg" alt="Platform: macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" alt="Swift 6" />
</p>

---

## About

OpenPaste is an open-source clipboard manager built natively for macOS with SwiftUI and AppKit. It is designed for developers and power users who copy code, JSON, URLs, prompts, files, and images all day and need fast recall without handing over control of their data.

**Local-first by default. No telemetry. Homebrew + notarized DMG.**

## Shipped Today

- **Infinite Clipboard History** — Never lose anything you copy
- **Fast Local Search** — FTS5-backed search across text, OCR text, tags, and source app metadata
- **Paste Stack** — Queue multiple items and paste them in sequence (FIFO)
- **Collections** — Organize clips by project, topic, or workflow
- **Quick Edit** — Edit text before paste, preview markdown, and review code-friendly content
- **Privacy Guards** — Sensitive content detection, app blacklist, and screen-sharing protection
- **OCR for Images** — Extract text from copied screenshots and images for recall later
- **Screen Sharing Protection** — Automatically pauses capture during screen sharing
- **Keyboard-First** — Global hotkey (⌘⇧V) with full keyboard navigation
- **Content Types** — Text, images, files, URLs, code with syntax highlighting
- **Source App Tracking** — Know where each clip came from

## Still Maturing

- **iCloud Sync Foundation** — CloudKit sync exists in the codebase, is premium-gated in current builds, and is still being hardened for real-world rollout
- **Privacy Hardening Across Builds** — SQLCipher support exists in the codebase and is being standardized across build variants
- **Distribution Polish** — Sparkle auto-update and release plumbing are in place and still being validated in public use

## Planned Later

- **Semantic Search and AI Actions**
- **Snippets, Templates, and Text Expansion**
- **Content Transformations**
- **Plugin SDK and Extensibility**

## Privacy at a Glance

- **Local-first by default** — OpenPaste works without a cloud account
- **No telemetry** — No analytics, tracking pixels, or usage reporting
- **Sensitive-aware capture** — Built-in detection plus app blacklist support
- **Screen-sharing pause** — Capture can be suspended during screen sharing
- **Honest build/privacy notes** — See the [Launch FAQ](docs/launch-faq.md) for current sync, encryption, and roadmap status

## Install

### Homebrew

```bash
brew tap openpaste/tap
brew install --cask openpaste
```

### GitHub Releases

Download the latest `.dmg` from [Releases](https://github.com/openpaste/openpaste/releases).

### Build from Source

```bash
git clone https://github.com/openpaste/openpaste.git
cd openpaste
open OpenPaste.xcodeproj
# Build and run in Xcode (⌘R)
```

**Requirements:** macOS 14+, Xcode 15+, Swift 6

## Docs for Evaluating OpenPaste

- [Launch FAQ](docs/launch-faq.md)
- [Positioning Snapshot](docs/positioning.md)
- [Feedback Template](docs/feedback-template.md)

## Support Development

OpenPaste is free and open source for the core clipboard workflow.

Commercial options may evolve later for advanced sync or support, but the first-user phase is focused on making the local-first product genuinely useful and trustworthy.

Visit **[tuanle.dev](https://tuanle.dev)** for Pro license information.

## Sponsors

OpenPaste is maintained by [Le Anh Tuan](https://tuanle.dev) and supported by the community.

<a href="https://github.com/sponsors/openpaste">
  <img src="https://img.shields.io/badge/Sponsor-❤️-ea4aaa.svg?style=for-the-badge" alt="Sponsor on GitHub" />
</a>

Your sponsorship helps fund development and keeps the Community Edition free.

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, code style, and PR guidelines.

By contributing, you agree to our [Contributor License Agreement](CLA.md).

## Community

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Use the feedback template](docs/feedback-template.md)
- [Report Issues](https://github.com/openpaste/openpaste/issues)

## License

OpenPaste is licensed under the [GNU Affero General Public License v3.0](LICENSE).

```
Copyright (C) 2025–present Le Anh Tuan <tuanle.works@gmail.com>
```

See [CLA.md](CLA.md) for contributor licensing terms.
