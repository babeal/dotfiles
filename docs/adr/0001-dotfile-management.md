# 1. Dotfile Management via Chezmoi

Date: 2026-04-04

## Status

Accepted

## Context

Personal configuration files need to be kept in sync across multiple machines running macOS and Linux. The previous setup used a custom bash script (`install.sh`) that symlinked files from a central repo to the home directory, with one-off setup steps handled manually. This worked for a single machine but didn't scale: no OS-specific templating, no idempotent setup automation, and adding a new machine required manual intervention.

The main options were to extend the custom script approach or adopt a dedicated dotfile manager. Extending bash scripts means reimplementing templating, secret handling, and change detection — things purpose-built tools already solve. Dedicated managers evaluated included [GNU Stow](https://www.gnu.org/software/stow/) (symlink farm, no templating), [yadm](https://yadm.io/) (git-based, limited conditionals), and [chezmoi](https://www.chezmoi.io/).

chezmoi was the strongest fit: Go template support for OS/machine-role conditionals, `run_once_` and `run_onchange_` scripts for idempotent setup, native [Bitwarden CLI](https://bitwarden.com/help/cli/) integration for secrets, and `.chezmoiexternal.toml` for pulling in external resources. It's also under active development with good documentation.

## Decision

We use chezmoi to manage all dotfiles across macOS and Linux machines. The source directory lives in this repo under `home/` (referenced via `.chezmoiroot`), keeping chezmoi's source separate from the repo root.

## Consequences

Go templates make it straightforward to write one config file that conditionally adapts to macOS vs Linux or dev vs personal machines. `run_onchange_` scripts handle package installation and one-time setup in a way the old symlink approach never could.

The main cost is chezmoi's naming conventions (`dot_`, `executable_`, `.tmpl`, etc.) which make the source directory harder to read at a glance. chezmoi itself also needs to be bootstrapped before any managed config is available, which means the first-install story requires a small manual step. These are acceptable trade-offs given the gains in maintainability across machines.
