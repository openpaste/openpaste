# OpenPaste — Release Guide

Step-by-step guide for cutting a new release. **All builds are done locally** (sign, notarize, DMG).

**Last Updated:** April 2026

---

## Prerequisites

### Local Environment

| Requirement | How to verify |
|-------------|---------------|
| Developer ID Application certificate | `security find-identity -v -p codesigning \| grep "Developer ID"` |
| Apple Team ID | `VGQU7EVXZV` |
| Notarization credentials (keychain) | `xcrun notarytool store-credentials "notarytool-profile"` |
| Xcode (latest stable) | `xcodebuild -version` |
| GitHub CLI | `gh auth status` |

### One-Time Setup: Notarization Credentials

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "YOUR_APPLE_ID" \
  --password "APP_SPECIFIC_PASSWORD" \
  --team-id "VGQU7EVXZV"
```

Generate app-specific password at [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords.

### GitHub Secrets (for future CI restoration)

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID_CERT_BASE64` | Developer ID Application certificate (.p12 → base64) |
| `DEVELOPER_ID_CERT_PASSWORD` | .p12 password |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_ID_PASSWORD` | App-specific password |
| `TAP_REPO_TOKEN` | GitHub PAT with `repo` scope for `openpaste/homebrew-tap` |
| `SPARKLE_EDDSA_PRIVATE_KEY` | Ed25519 private key for Sparkle DMG signing |

---

## Release Workflow (Local Build)

### 1. Pre-flight & Analyze Release Scope

All release prep happens on `develop`.

```bash
git checkout develop && git pull origin develop
git status --short
git log --format='%h %s' main..develop
git diff --stat main..develop
```

### 2. Run Tests (Mandatory Gate)

```bash
set -o pipefail
xcodebuild test -project OpenPaste.xcodeproj -scheme OpenPaste \
  -destination 'platform=macOS' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/openpaste-release-tests.log | tail -30
```

**If ANY test fails: STOP. Fix tests first.**

### 3. Bump Version

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in all 6 build configurations:

```bash
OLD=X.Y.Z
NEW=X.Y.Z

sed -i '' "s/MARKETING_VERSION = $OLD/MARKETING_VERSION = $NEW/g" OpenPaste.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = $OLD/CURRENT_PROJECT_VERSION = $NEW/g" OpenPaste.xcodeproj/project.pbxproj

# Verify (should show 6 each)
grep -c "MARKETING_VERSION = $NEW" OpenPaste.xcodeproj/project.pbxproj
grep -c "CURRENT_PROJECT_VERSION = $NEW" OpenPaste.xcodeproj/project.pbxproj
```

### 4. Generate Release Notes & Update Changelog

- Update `RELEASE_NOTES.md` with user-facing notes
- Update `docs/project-changelog.md` — move `[Unreleased]` to `[X.Y.Z] — YYYY-MM-DD`

### 5. Commit, PR & Merge to Main

```bash
git add -A
git commit -m "chore(build): bump version to $NEW"
git push origin develop

# Create or update PR to main
gh pr create --base main --head develop --title "chore: release v$NEW"
gh pr merge <pr-number> --merge --subject "chore: release v$NEW"
```

### 6. Tag on Main

```bash
git checkout main && git pull origin main
git tag -a "v$NEW" -F RELEASE_NOTES.md
git push origin v$NEW
```

### 7. Build Archive (unsigned)

```bash
xcodebuild archive \
  -scheme OpenPaste \
  -configuration Release \
  -archivePath build/OpenPaste.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

### 8. Sign with Developer ID

```bash
APP="build/OpenPaste.xcarchive/Products/Applications/OpenPaste.app"

# Sign embedded frameworks
find "$APP/Contents/Frameworks" -name "*.framework" | while read f; do
  codesign --force --deep --sign "Developer ID Application: LE ANH TUAN (VGQU7EVXZV)" \
    --options runtime --timestamp "$f"
done

# Sign main app with entitlements
codesign --force --deep --sign "Developer ID Application: LE ANH TUAN (VGQU7EVXZV)" \
  --options runtime --timestamp \
  --entitlements OpenPaste/OpenPasteRelease.entitlements "$APP"

# Verify
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Authority|TeamIdentifier'
```

### 9. Notarize

```bash
ditto -c -k --keepParent "$APP" build/OpenPaste.zip

xcrun notarytool submit build/OpenPaste.zip \
  --keychain-profile "notarytool-profile" \
  --wait

xcrun stapler staple "$APP"
```

### 10. Create DMG

```bash
mkdir -p build/release
./scripts/create-dmg.sh "$APP" build/release
# Outputs: build/release/OpenPaste-X.Y.Z.dmg with SHA-256
```

### 11. Create GitHub Release

```bash
gh release create v$NEW build/release/OpenPaste-$NEW.dmg \
  --title "v$NEW" \
  --notes-file RELEASE_NOTES.md \
  --latest
```

### 12. Update Homebrew Tap

Edit `homebrew-tap/Casks/openpaste.rb`:
- Update `version` to new version
- Update `sha256` to the DMG's SHA-256

```bash
cd homebrew-tap
git add Casks/openpaste.rb
git commit -m "chore: bump OpenPaste to $NEW"
git push origin main
```

### 13. Update Sparkle Appcast (gh-pages)

```bash
git fetch origin gh-pages
git checkout gh-pages

# Edit appcast.xml — add new <item> entry with:
#   sparkle:version, sparkle:shortVersionString, url, sparkle:edSignature, length

git add appcast.xml
git commit -m "chore: update appcast for v$NEW"
git push origin gh-pages
git checkout develop
```

### 14. Clean Up

```bash
git checkout develop
rm -rf build/OpenPaste.zip build/OpenPaste.xcarchive build/release
```

---

## Verification

```bash
# Verify GitHub Release
gh release view v$NEW

# Verify Homebrew
brew untap openpaste/tap 2>/dev/null
brew tap openpaste/tap
brew info --cask openpaste

# Test install
brew install --cask openpaste
open -a OpenPaste
```

---

## Versioning Rules

| Field | Location | Format |
|-------|----------|--------|
| `MARKETING_VERSION` | `project.pbxproj` (×6 configs) | `X.Y.Z` (semver) |
| `CURRENT_PROJECT_VERSION` | `project.pbxproj` (×6 configs) | `X.Y.Z` (same as MARKETING_VERSION) |
| `RELEASE_NOTES.md` | Project root | User-facing notes for tag annotation |
| Git tag | `git tag vX.Y.Z` | Must match MARKETING_VERSION with `v` prefix |

**Version chain:**
```
MARKETING_VERSION=1.2.0 = CURRENT_PROJECT_VERSION=1.2.0 → tag v1.2.0 → OpenPaste-1.2.0.dmg → brew cask "1.2.0"
```

---

## Sparkle Update Feed

### Appcast Location

**Public URL:** `https://openpaste.github.io/openpaste/appcast.xml`

### Testing Updates Locally

```bash
# 1. Build and archive the current app
# 2. Install into /Applications
# 3. Launch and use menu → "Check for Updates…"
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Notarization fails | Check Apple ID 2FA + app-specific password. View log: `xcrun notarytool log <id> --keychain-profile "notarytool-profile"` |
| SPM signing conflict | Use `CODE_SIGNING_ALLOWED=NO` for archive, then sign manually after |
| Wrong certificate | Must be "Developer ID Application", NOT "Apple Development" |
| Homebrew tap not updating | Edit `Casks/openpaste.rb` directly in homebrew-tap repo |
| Sparkle version mismatch | Ensure `MARKETING_VERSION` = `CURRENT_PROJECT_VERSION` = tag version |
