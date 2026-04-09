# macOS Homebrew Package Installation Design

## Overview

Homebrew packages are installed via `brew bundle` using a dynamically generated Brewfile. The Brewfile is emitted inline by a chezmoi `run_onchange_` script, driven by package data in `.chezmoidata/packages.homebrew.toml`.

See [ADR-0004](../adr/0004-macos-package-management.md) for the decision to use Homebrew. The use of `brew bundle` as the installation mechanism is a design decision documented here.

## Package Data Structure

Packages are defined in `.chezmoidata/packages.homebrew.toml` using TOML inline tables:

```toml
formulae = [
    {name = "gnu-sed"},
    {name = "sqlite3", extra = "link: true"},
]
```

Each entry has:
- `name` (**required**) — the Homebrew formula or cask name
- `extra` (**optional**) — raw Brewfile DSL appended after the quoted name

The template renders this as:

```ruby
brew "gnu-sed"
brew "sqlite3", link: true
```

## The `extra` Field

The `extra` field exists to express per-package Brewfile DSL options that a plain name list cannot represent. The most common use case is `link: true` for keg-only formulae, but it supports any valid Brewfile option.

### Keg-only formulae requiring `link: true`

Several GNU utilities are installed as keg-only because they conflict with macOS system binaries. Homebrew deliberately does not symlink them into `/opt/homebrew/bin`. For these dotfiles, we want the GNU versions to take precedence.

| Formula      | Conflicts with                               |
| ------------ | -------------------------------------------- |
| `coreutils`  | macOS BSD coreutils                          |
| `gnu-sed`    | macOS `sed`                                  |
| `gnu-tar`    | macOS `tar`                                  |
| `grep`       | macOS `grep`                                 |
| `findutils`  | macOS `find`, `xargs`                        |
| `sqlite3`    | macOS system SQLite                          |

Without `link: true`, these are only accessible via their full Cellar path or explicit PATH additions.

### Other `extra` values

```toml
# Install from HEAD
{name = "some-formula", extra = "args: [\"HEAD\"]"}

# Restart a service after install/upgrade
{name = "postgresql", extra = "restart_service: true"}

# Mark conflicts explicitly
{name = "mysql@8.0", extra = "restart_service: :changed, conflicts_with: [\"mysql\"]"}

# Cask: allow unsigned package
{name = "some-cask", extra = "pkg_allow_untrusted: true"}
```

## MAS (Mac App Store) Apps

brew bundle supports `mas` entries natively:

```ruby
mas "Refined GitHub", id: 1519867270
```

MAS apps are defined in `.chezmoidata/packages.mas.toml` under a `mas` section with `name` and `id` fields (not the `extra` pattern, since `id:` is required, not optional DSL). The install script emits `mas "name", id: XXXXXX` lines alongside formulae and casks in the same Brewfile.

## Profiles

Packages are organized by profile across `packages.homebrew.toml`, `packages.apt.toml`, and `packages.mas.toml`:

- `common` — installed on all macOS machines
- `dev` — development machines only
- `personal` — personal machines
- `work` — work machines

The `run_onchange_` script conditionally includes each profile's packages based on chezmoi template variables (`is_dev_computer`, `is_personal_computer`, etc.).

## Template Safety Note

The template uses `index . "extra"` rather than `.extra` when checking for the field. In Go templates, accessing a missing key on a TOML-derived map causes a fatal error. `index . "extra"` safely returns empty string for entries that omit the field:

```go
brew {{ .name | quote }}{{ if index . "extra" }}, {{ index . "extra" }}{{ end }}
```

## PATH Configuration for Keg-only Formulae

Keg-only GNU utilities are also prepended to `PATH` in the shell configuration (`040-path.sh.tmpl`) so they shadow the system BSD versions in interactive shells. The `link: true` Brewfile option handles non-shell contexts (scripts run without a full login environment). Both are needed for complete coverage.
