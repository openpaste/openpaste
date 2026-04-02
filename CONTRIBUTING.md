# Contributing to OpenPaste

Thank you for your interest in contributing to OpenPaste! This guide will help you get started.

## Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** with Swift 6 toolchain
- **Git** with conventional commit knowledge

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork:
   ```bash
   git clone https://github.com/<your-username>/openpaste.git
   cd openpaste
   ```
3. **Open** the project in Xcode:
   ```bash
   open OpenPaste.xcodeproj
   ```
4. **Build** and run (⌘R) to verify everything works

## Project Structure

```
OpenPaste/
├── App/              # Application lifecycle, hotkeys, window management
├── Models/           # Data models (ClipboardItem, Collection, etc.)
├── Services/         # Core services (clipboard, storage, search, security)
├── Utilities/        # Constants, extensions, helpers
├── ViewModels/       # MVVM view models
├── Views/            # SwiftUI views organized by feature
├── Assets.xcassets/  # App icons and colors
OpenPasteTests/       # Unit tests
OpenPasteUITests/     # UI tests
docs/                 # Project documentation
```

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI and modern Swift concurrency (`async`/`await`, `@Observable`)
- Prefer `@MainActor` for UI-bound code
- Use protocol-based dependency injection
- Keep files under 200 lines where practical

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`

**Examples:**
```
feat(clipboard): add image preview for clipboard items
fix(search): resolve crash when filtering by date range
docs(readme): update installation instructions
test(storage): add edge case tests for collection deletion
```

## Branch Naming

```
feat/short-description
fix/issue-number-description
docs/what-changed
refactor/what-changed
```

## Pull Request Process

1. Create a feature branch from `develop` (not `main`)
2. Make your changes with clear, focused commits
3. Write or update tests for your changes
4. Ensure all tests pass (⌘U in Xcode)
5. Run any linting/formatting tools
6. Open a pull request with a clear description

### PR Checklist

- [ ] Code compiles without warnings
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Commit messages follow conventional commit format
- [ ] No secrets, API keys, or credentials committed
- [ ] Changelog updated (if applicable)
- [ ] CLA agreed to (see [CLA.md](CLA.md))

## Contributor License Agreement

By opening a pull request, you agree to the terms of our [Contributor License Agreement](CLA.md). A CLA bot will confirm your agreement on your first PR.

## Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include macOS version, steps to reproduce, and expected vs. actual behavior
- Screenshots or screen recordings are appreciated

## License

By contributing to OpenPaste, you agree that your contributions will be licensed under the [GNU Affero General Public License v3.0](LICENSE).
