# Security Policy

## Supported versions

Only the latest released version of DevDock receives security fixes.

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report privately instead:

- GitHub: [Security advisories](https://github.com/bkrdmrcioglu/devdock/security/advisories/new)
- Email: [bkrdmrcioglu@gmail.com](mailto:bkrdmrcioglu@gmail.com)

Include what you can:

- What the issue is and where it lives in the code
- Steps to reproduce it
- macOS and DevDock versions
- Any impact you have already confirmed

You should get a first response within a few days. Once a fix ships, credit is given in the release notes unless you prefer to stay anonymous.

## Scope notes

DevDock runs with the App Sandbox disabled so it can scan project folders and spawn development processes. That is intentional and required for the app to work — it is not, on its own, a vulnerability.

Findings that are in scope include:

- Command injection through project paths, names, or detected scripts
- Privilege escalation beyond what a user-launched process should have
- Unexpected network calls or data leaving the machine
- Tampering with the update or Homebrew cask flow
