# Continuous Integration Detection

## Overview

Some installation steps are skipped or modified when running in a CI environment — cask installs require a display session, and MAS installs require an App Store login. CI is detected via the standard `CI` environment variable rather than a chezmoi data variable.

## How It Works

chezmoi templates use the built-in `env` function to read the `CI` environment variable at render time:

```go
{{ if eq (env "CI") "" }}
  {{/* not CI — safe to run GUI/interactive steps */}}
{{ end }}
```

GitHub Actions, CircleCI, and most other CI systems set `CI=true` automatically. On a local machine, `CI` is unset, so `env "CI"` returns an empty string.

## Why `env` Instead of a chezmoi Data Variable

The previous approach used `promptBoolOnce . "is_ci_workflow"` in `.chezmoi.toml.tmpl`, storing the answer as a persistent data variable. This had two problems:

1. **It's a human prompt for a machine fact.** Whether you're in CI is determined by the environment, not by the person running the dotfiles.
2. **It required callers to know the prompt order.** Non-interactive runs (setup scripts, CI pipelines) had to pipe the correct answer at the correct position in stdin, which was brittle.

Using `env "CI"` directly is self-contained — no prompt, no stored value, no coordination needed.

## What Changes in CI

| Script | CI behaviour |
|---|---|
| `before_10-homebrew-packages.sh.tmpl` | Formulae install normally; casks are skipped |
| `before_11-mas-apps.sh.tmpl` | Entire script is skipped (top-level template guard) |

Formulae are safe to install in CI (no GUI or session required). Casks are skipped because they require a windowing environment. MAS installs are skipped because they require an active App Store login.

## Testing CI Mode Locally

To simulate CI behaviour locally, set `CI` before running chezmoi:

```bash
CI=true chezmoi apply
```

## Relationship to App Store Login Detection

CI detection and App Store login detection are separate concerns handled at different layers:

- **CI detection** happens at template render time via `env "CI"` — determines whether the MAS script is generated at all
- **App Store login detection** happens at runtime inside `before_11-mas-apps.sh.tmpl` via `mas account` — handles the case where the script runs but the user isn't signed in

See [macos-homebrew-packages.md](macos-homebrew-packages.md) for the MAS installation design.
