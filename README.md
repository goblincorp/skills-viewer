# Skills Viewer

A native macOS app for browsing and inspecting Claude Code skills, hooks, MCP servers, and configuration.

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6

## Build from Source

```bash
swift build && swift run SkillsViewer
```

## Build `.app` Bundle

The `scripts/build-app.sh` script creates a distributable `.app` bundle.

```bash
# Unsigned dev build
./scripts/build-app.sh
open build/SkillsViewer.app

# Signed build
./scripts/build-app.sh --sign "Developer ID Application: Your Name (TEAMID)"

# Signed universal binary with DMG
./scripts/build-app.sh --sign "Developer ID Application: Your Name (TEAMID)" --universal --dmg

# Signed, notarized, and stapled
./scripts/build-app.sh \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  --notarize \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password @keychain:AC_PASSWORD
```

Run `./scripts/build-app.sh --help` for all options.
