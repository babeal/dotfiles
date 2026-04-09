# 2. Tiered Package management architecture

Date: 2026-04-04

## Status

Accepted

## Context

Packages and tools installed on a machine fall into meaningfully different categories. System utilities and GUI applications don't change based on which project you're working in. Language runtimes (python, node, go) often do — different projects pin different versions, and mixing them causes subtle breakage. Language ecosystem packages (pip packages, npm globals) sit a layer below that, managed by their own tooling.

Trying to manage all of these with a single tool creates friction. A system package manager like apt or Homebrew isn't designed for per-project version isolation. A version manager like mise isn't the right place for GUI applications. Using one tool for everything means either losing capabilities or working around the tool's design.

Additionally, not all machines need the same tiers. Client workstations (macOS or Linux) need the full setup — GUI tools, dev tooling, package management. Linux servers need minimal shell setup with apt-only packages and no Homebrew or mise. Restricted work machines may need shell config and dotfiles but cannot install packages at all (corporate restrictions may block installs or require specific channels).

## Decision

We use a three-tier model:

1. **System packages and applications** — managed by the platform-native package manager (brew bundle on macOS, apt on Linux). This covers CLI tools, GUI apps, and anything that doesn't need per-project versioning.
2. **Language runtimes and dev tools requiring per-project version isolation** — managed by [mise](https://mise.jdx.dev/). The deciding factor for whether something belongs here is whether it needs to be version-pinned per project. Tools that are used universally across all projects belong in tier one, even if they're developer-oriented (e.g. `shellcheck`, `shfmt`).
3. **Language ecosystem packages** — managed by the language's own tooling (`uv` for Python packages, `pnpm` for Node packages, etc.). These sit below mise and are not managed by the dotfiles directly beyond bootstrapping the tools themselves.

**Two boolean flags control which tiers apply on a given machine:**

- `is_server` — distinguishes Linux servers from client workstations. Servers get apt-only system packages (tier 1) with no Homebrew or mise. macOS is always a client; this flag is Linux-only in practice.
- `install_packages` — controls whether chezmoi runs package installation scripts at all. Defaults to true on client machines. Set to false on restricted work machines where package installation must happen manually or through corporate channels. Always false on servers.

Both are booleans to avoid fat-fingering (no "client" vs "Client" vs "clinet").

## Consequences

Each tier has a clear owner and a clear scope, which makes it obvious where a new package belongs. The tier boundary (does it need per-project version switching?) is a practical rule that's easy to apply consistently. The flags (`is_server`, `install_packages`) cover all the real machine variants without string-matching risk.

Setting up a new machine requires multiple tools to be bootstrapped in the right order. There are two explicit bootstrap paths, each targeting a different machine class:

**Path 1 — `setup.sh` (personal machines you control):** Installs Homebrew, uses Homebrew to install chezmoi, then runs `chezmoi apply`. This is the standard path for personal macOS and Linux client machines. chezmoi scripts assume `brew` is already in PATH — `setup.sh` guarantees this. This avoids the PATH isolation problem (chezmoi scripts run as subprocesses and don't inherit environment changes from sibling scripts).

**Path 2 — chezmoi-first (restricted or work machines):** Install chezmoi directly via `curl` (no Homebrew), run `chezmoi init`, then set `install_packages=false`. This covers corporate machines, servers, or any environment where you don't have full control. Package installation happens out-of-band through whatever channel the environment allows.

Running `chezmoi init` directly on a Linux client without `install_packages=false` will fail at the package installation step — that path is intentionally only for Path 2 machines.
