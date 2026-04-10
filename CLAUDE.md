# Dotfiles (chezmoi)

## Overview

Cross-platform dotfiles system using [chezmoi](https://www.chezmoi.io/) for macOS and Debian Linux. The `home/` directory contains all managed dotfiles. `.chezmoiroot` points chezmoi at that subdirectory automatically.

**Version manager**: mise only
**Secrets**: Bitwarden CLI (not yet implemented — keep `use_secrets = false`).
**Target platforms**: macOS, Debian Linux.

## Docs

- `docs/adr/` — Architecture Decision Records; authoritative decisions about how this project works
- `docs/design/` — Design documents for specific subsystems
- `docs/specs/` — Temporary implementation specs; written before implementation and may drift from reality over time. **Do not consult specs when making decisions unless explicitly told to.**

## Chezmoi Basics

File naming conventions:

- `dot_` → `.` (e.g., `dot_zshrc` → `~/.zshrc`)
- `executable_` → mark file executable
- `.tmpl` → process as Go template
- `private_` → not world-readable
- `symlink_` → create symlink

Templates use `.chezmoi.os` (`"darwin"` / `"linux"`) and custom data fields (`dev_computer`, `personal_computer`, `is_server`, `install_packages`, `use_secrets`) defined in `.chezmoi.toml.tmpl`.

**Common pitfalls:**

- `-S/--source` is a **global flag** — must come before the command: `chezmoi -S /path apply`
- `execute-template` needs `-f` for files: `chezmoi execute-template -f file.tmpl`
- Never run `chezmoi apply` on the host without confirming with the user first.

When unsure about a command, check `chezmoi <command> --help` or the Context7 tool (has chezmoi docs).

## Testing

**Always use the testing skills — do not write ad-hoc scripts.**

- `/test-ubuntu-docker` — test in a Docker Ubuntu container
- `/test-macos-parallels` — test in the Parallels macOS VM

### Ubuntu Docker

The repo root is mounted read-only into the container at `/tmp/dotfiles-source`. See `tests/e2e/ubuntu/docker-compose.yml` for details.

### macOS Parallels

VM connection details are in `tests/e2e/macos/env.toml`. Test config (skips interactive prompts) lives in `tests/e2e/config/default.toml` — update it when new prompts are added to `.chezmoi.toml.tmpl`.

## Committing

Always use conventional commit syntax.

### Host system rule

**Never run chezmoi commands that modify the host's dotfiles.** All testing must happen in containers or VMs.
