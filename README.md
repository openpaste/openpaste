<p align="center">
  <img src="OpenPaste/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="OpenPaste Icon" />
</p>

<h1 align="center">OpenPaste</h1>

<p align="center">
  <strong>Privacy-first, AI-native clipboard manager for macOS</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPLv3-blue.svg" alt="License: AGPLv3" /></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-brightgreen.svg" alt="Platform: macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange.svg" alt="Swift 6" />
</p>

---

## About

OpenPaste is an open-source clipboard manager built natively for macOS with SwiftUI and AppKit. It's designed for developers and power users who need fast recall, smart organization, and privacy by default.

**No telemetry. No cloud dependency. Encryption at rest.**

## Features

- **Infinite Clipboard History** — Never lose anything you copy
- **Blazing Fast Search** — Sub-50ms fuzzy search across all content types
- **Paste Stack** — Queue multiple items and paste them in sequence (FIFO)
- **Collections** — Organize clips by project, topic, or workflow
- **Privacy-First** — Encryption at rest (SQLCipher), sensitive content auto-detection
- **Screen Sharing Protection** — Automatically pauses capture during screen sharing
- **AI-Native** — Semantic search, auto-tagging, smart content actions *(coming soon)*
- **Keyboard-First** — Global hotkey (⌘⇧V) with full keyboard navigation
- **Content Types** — Text, images, files, URLs, code with syntax highlighting
- **Source App Tracking** — Know where each clip came from

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

## Support Development

OpenPaste uses an **open-core model**:

| Edition | License | Features |
|---------|---------|----------|
| **Community** | AGPLv3 (free forever) | Full-featured clipboard manager |
| **Pro** | Commercial | Premium features — coming soon |

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
- [Report Issues](https://github.com/openpaste/openpaste/issues)

## License

OpenPaste is licensed under the [GNU Affero General Public License v3.0](LICENSE).

```
Copyright (C) 2025–present Le Anh Tuan <tuanle.works@gmail.com>
```

See [CLA.md](CLA.md) for contributor licensing terms.
