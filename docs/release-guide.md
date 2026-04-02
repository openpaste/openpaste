# OpenPaste — Release Guide

Step-by-step guide for cutting a new release.

**Last Updated:** April 2026

---

## Prerequisites

### GitHub Secrets (already configured)

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID_CERT_BASE64` | Developer ID Application certificate (.p12 → base64) |
| `DEVELOPER_ID_CERT_PASSWORD` | .p12 password (empty string if none) |
| `APPLE_TEAM_ID` | Apple Developer Team ID (`VGQU7EVXZV`) |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_ID_PASSWORD` | App-specific password (not account password) |
| `TAP_REPO_TOKEN` | GitHub PAT with `repo` scope for `openpaste/homebrew-tap` |

### Apple Developer Portal

- **Certificate type:** Developer ID Application (NOT Apple Development)
- **App-specific password:** Generate at [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords

---

## Release Workflow

### 1. Bump Version

Update `MARKETING_VERSION` in **all 6** build configurations in `project.pbxproj`:

```bash
# Check current version
grep -c 'MARKETING_VERSION' OpenPaste.xcodeproj/project.pbxproj
# Should show 6

# Find & replace (or use Xcode: target → Build Settings → Marketing Version)
sed -i '' 's/MARKETING_VERSION = 1.0.0/MARKETING_VERSION = 1.1.0/g' OpenPaste.xcodeproj/project.pbxproj
```

> **CRITICAL:** Version must be semver (`X.Y.Z`). The tag `v1.0.0` produces DMG `OpenPaste-1.0.0.dmg`. A mismatch causes Homebrew 404.

### 2. Commit & Tag

```bash
git add -A
git commit -m "chore(build): bump version to 1.1.0"
git tag v1.1.0
git push origin main --tags
```

### 3. Automated Pipeline (triggered by tag push)

The tag push triggers `.github/workflows/release.yml`:

```
Tag Push → Build → Sign → Notarize → Staple → DMG → GitHub Release → Update Homebrew Tap
```

| Step | What happens |
|------|-------------|
| **Build** | `xcodebuild archive` with `Developer ID Application` identity |
| **Sign** | Certificate injected from `DEVELOPER_ID_CERT_BASE64` into temporary keychain |
| **Notarize** | `notarytool submit --wait` sends zip to Apple, waits up to 600s |
| **Staple** | `stapler staple` attaches notarization ticket to .app |
| **DMG** | `scripts/create-dmg.sh` creates `OpenPaste-X.Y.Z.dmg` |
| **Release** | `softprops/action-gh-release` publishes DMG + auto-generated release notes |
| **Homebrew** | `repository-dispatch` triggers `openpaste/homebrew-tap` to update cask SHA256 |

### 4. Verify

```bash
# Check release was created
gh release view v1.1.0

# Verify Homebrew tap updated (wait ~1min for dispatch workflow)
brew untap openpaste/tap 2>/dev/null
brew tap openpaste/tap
brew info --cask openpaste

# Test install
brew install --cask openpaste
open -a OpenPaste
```

---

## Manual Release (fallback)

If CI fails, build and release manually:

```bash
# 1) Build archive
xcodebuild archive \
  -scheme OpenPaste \
  -configuration Release \
  -archivePath build/OpenPaste.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="Developer ID Application"

# 2) Export .app
cp -R build/OpenPaste.xcarchive/Products/Applications/OpenPaste.app build/

# 3) Notarize
ditto -c -k --keepParent build/OpenPaste.app build/OpenPaste.zip
xcrun notarytool submit build/OpenPaste.zip \
  --apple-id "YOUR_APPLE_ID" \
  --password "APP_SPECIFIC_PASSWORD" \
  --team-id "VGQU7EVXZV" \
  --wait
xcrun stapler staple build/OpenPaste.app

# 4) Create DMG
./scripts/create-dmg.sh build/OpenPaste.app build/

# 5) Upload release
gh release create v1.1.0 build/OpenPaste-1.1.0.dmg --generate-notes

# 6) Manually update homebrew-tap Casks/openpaste.rb with new version + SHA256
```

---

## Versioning Rules

| Field | Location | Format |
|-------|----------|--------|
| `MARKETING_VERSION` | `project.pbxproj` (×6 configs) | `X.Y.Z` (semver) |
| `CURRENT_PROJECT_VERSION` | `project.pbxproj` | Integer build number |
| Git tag | `git tag vX.Y.Z` | Must match MARKETING_VERSION with `v` prefix |

**Version ↔ Tag ↔ DMG name chain:**
```
MARKETING_VERSION=1.2.0 → tag v1.2.0 → OpenPaste-1.2.0.dmg → brew cask version "1.2.0"
```

---

## Troubleshooting

### Notarization fails
- Check Apple ID has 2FA enabled and app-specific password is valid
- Check the app isn't using any disallowed entitlements
- View notarization log: `xcrun notarytool log <submission-id> --apple-id ... --password ... --team-id ...`

### Homebrew tap not updating
- Verify `TAP_REPO_TOKEN` has `repo` scope and isn't expired
- Check `openpaste/homebrew-tap` Actions tab for `update-cask` workflow runs
- Manual fix: edit `Casks/openpaste.rb` in homebrew-tap repo directly

### Wrong certificate type
- **"Developer ID Application"** — for distributing outside App Store (Homebrew, website)
- **"Apple Development"** — for debug builds only, will NOT pass notarization
- **"3rd Party Mac Developer Application"** — for Mac App Store only

### DMG 404 on brew install
- Version mismatch: `MARKETING_VERSION` in pbxproj must exactly match tag (without `v` prefix)
- Example: tag `v1.0.0` requires `MARKETING_VERSION = 1.0.0`, NOT `1.0`

---

## Repositories

| Repo | Purpose |
|------|---------|
| `openpaste/openpaste` | Main app source code |
| `openpaste/homebrew-tap` | Homebrew Cask formula, auto-updated by CI |

---

## Rotating Certificates

When the Developer ID Application certificate expires (every 5 years):

1. Generate new cert in Apple Developer Portal → Certificates
2. Download and export as .p12 from Keychain Access
3. Base64 encode: `base64 -i new-cert.p12 | tr -d '\n'`
4. Update `DEVELOPER_ID_CERT_BASE64` and `DEVELOPER_ID_CERT_PASSWORD` in GitHub Secrets
