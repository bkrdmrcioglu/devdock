# Stack fixtures

Minimal marker projects for every framework DevDock detects. These are **detection fixtures**, not full runnable apps (no `node_modules` / SDKs).

## Layout

- `stacks/<name>/` — one folder per framework
- `expected.json` — expected `Framework` raw value + default port

## Regenerate

```bash
./scripts/generate-stack-fixtures.sh
```

## Verify (uses real `FrameworkDetector` + `ProjectScanner`)

```bash
./scripts/verify-stack-fixtures.swift
```

Expect `ALL PASSED` for **36** stacks (detect + scan).

## See them in DevDock UI

1. Open Debug DevDock
2. Settings → add scan folder:  
   `…/DevDock/Fixtures/stacks`
3. Rescan (⌘⇧R)

You should see ~36 projects with correct framework badges (Next.js, Expo, Flutter, Laravel, …).

## Start / Stop

Most fixtures will fail to start (no toolchain deps). Use your real projects for runtime / mobile / logs smoke tests.
