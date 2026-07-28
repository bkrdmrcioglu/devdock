# Contributing to DevDock

Thanks for considering it — DevDock is free and open source, and issues/PRs are welcome.

## Setup

```bash
brew install xcodegen
git clone https://github.com/bkrdmrcioglu/devdock.git
cd devdock
xcodegen generate
open DevDock.xcodeproj
```

See [README.md](README.md#build-from-source) for the headless build path.

## Reporting a bug

Open an [issue](https://github.com/bkrdmrcioglu/devdock/issues/new/choose) — the bug
report template asks for the DevDock version, macOS version, and repro steps, which
covers most of what's needed to track it down.

## Adding a new framework/stack

This is the most common kind of contribution. Detection lives in two places:

- [`DevDock/Models/Framework.swift`](DevDock/Models/Framework.swift) — add the case
- [`DevDock/Services/FrameworkDetector.swift`](DevDock/Services/FrameworkDetector.swift) —
  add the marker file(s)/heuristic that identify it, and the default start command in
  [`StartCommandResolver.swift`](DevDock/Services/StartCommandResolver.swift)

Add a minimal fixture under `Fixtures/stacks/` so detection has a regression test:

```bash
./scripts/generate-stack-fixtures.sh
./scripts/verify-stack-fixtures.swift
```

See [Fixtures/README.md](Fixtures/README.md) for the fixture format.

## Pull requests

- Keep PRs focused — one feature or fix per PR is easier to review than a bundle
- Make sure `xcodebuild -scheme DevDock -configuration Debug build` succeeds
- Run the app and exercise whatever you changed before opening the PR
- Describe *why* the change is needed, not just what it does — the PR template has a
  spot for that
