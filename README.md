# DevDock

macOS developer workspace manager — scan local projects, start/stop stacks, workspaces, menu bar control.

**Version:** 0.2.0

## Requirements

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run (Debug)

```bash
cd /path/to/DevDock
xcodegen generate
open DevDock.xcodeproj
```

Or:

```bash
xcodegen generate
xcodebuild -scheme DevDock -configuration Debug -destination 'platform=macOS' build
```

## Release `.app`

```bash
./scripts/release.sh
open dist/DevDock.app
```

Creates:
- `dist/DevDock.app`
- `dist/DevDock-0.2.0.zip`

Ad-hoc signed for local use. Notarize before public distribution.

## Features

- Folder scan + custom Browse… (home dirs + `/Volumes/*/Projeler|Projects`)
- Framework detection (Next.js, React, Vue, Nest, Express, Laravel, Django, Flask, Rails, Go, Rust)
- Monorepo-aware names (`hqtv-app/web`)
- Start / Stop / Logs (GUI PATH, process tree kill)
- External port detection (Terminal-started → yellow)
- Workspaces + auto suggestions
- Favorites, recent, sidebar filters
- Menu bar + About

## Notes

App sandbox is off so DevDock can spawn processes and scan folders. Keep local / notarize carefully if you ship.
