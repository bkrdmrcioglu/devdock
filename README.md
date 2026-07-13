# DevDock

macOS developer workspace manager — scan local projects, start/stop stacks, mobile device targets, workspaces, menu bar control.

**Version:** 0.2.0

## Install (users)

```bash
brew install --cask bkrdmrcioglu/devdock/devdock
```

Or download the zip from the [marketing site](https://bkrdmrcioglu.github.io/devdock-site/).

## Requirements

- macOS 14+
- Xcode 15+ (to build from source)
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
xcodebuild -scheme DevDock -configuration Debug -derivedDataPath .derivedData build
open .derivedData/Build/Products/Debug/DevDock.app
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

### Scan & detect

- Folder scan + Browse… (home dirs + `/Volumes/*/Projeler|Projects`)
- **36 frameworks**, including: Next, Nuxt, Remix, Astro, Gatsby, Angular, Svelte/SvelteKit, Solid, Ember, Vite, Vue, React, Quasar, Expo, React Native, Flutter, Ionic, Nest, Express, Fastify, Hono, Koa, Laravel, Symfony, Django, Flask, FastAPI, Rails, Spring Boot, .NET, Phoenix, Go, Rust, Electron, Tauri
- Markers include `pubspec.yaml`, `pom.xml`, `.csproj`, `app.py`, `requirements.txt`, and more
- Monorepo-aware names (`studio/web`)
- Stack roles (Web / Mobile / API / Desktop) for workspace suggestions
- Auto-rescan on launch (keeps newly supported stacks visible)

### Runtime

- Start / Stop / Restart with GUI-friendly `PATH`
- Process-tree stop + port remap when busy (no surprise kills by default)
- External port detection (Terminal-started → yellow / external)
- **Stack commands** per framework (install, migrate, test, build, artisan, etc.)
- Custom project + global one-shot commands
- CPU / RAM for the managed process tree (includes Flutter Simulator `Runner` when applicable)

### Mobile (Expo · React Native · Ionic · Flutter)

- **Connected devices** list (booted simulators, adb devices, physical when visible)
- **Quick targets:** iOS Simulator / Android Emulator / Web (/ Flutter: macOS)
  - Simulator/Emulator shortcuts **never** fall back to a physical phone
  - iOS Simulator boots via `simctl` when needed
- Flutter: `flutter run -d <id>` (FVM-aware); hot reload / restart / inspector keys
- Expo / RN / Ionic: Metro keys (`r`, `m`, `j`…) after opening a target
- Refresh devices without leaving the project detail

### Logs

- Right-edge **off-canvas drawer** (not a modal sheet)
- Tabs: **All / Errors / Warnings** with counts
- **Copy** current tab to clipboard
- Selectable text; auto-scroll

### Workspaces & chrome

- Workspaces + auto suggestions
- Favorites, recent, sidebar filters
- Menu bar + About
- Freemium: Free = 3 projects; Pro unlocks all (Lemon Squeezy)

## Stack fixtures (dev)

Minimal detection fixtures for every supported framework:

```bash
./scripts/generate-stack-fixtures.sh
./scripts/verify-stack-fixtures.swift
```

See [Fixtures/README.md](Fixtures/README.md). Add `Fixtures/stacks` as a scan root in DevDock to browse them in the UI.

## Docs / site

- Marketing copy: [`docs/`](docs/) → sync to [devdock-site](https://github.com/bkrdmrcioglu/devdock-site)
- Live site: https://bkrdmrcioglu.github.io/devdock-site/
- Lemon notes: [`docs/LEMON.md`](docs/LEMON.md)

## Notes

App sandbox is off so DevDock can spawn processes and scan folders. Keep local / notarize carefully if you ship.
