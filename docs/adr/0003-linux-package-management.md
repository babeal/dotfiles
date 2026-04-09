# 3. Linux system package management via native distribution package manager

Date: 2026-04-04

## Status

Accepted

## Context

Linux machines may run different distributions, each with their own native package manager. Debian/Ubuntu-based systems use apt; Red Hat/Fedora-based systems use yum or dnf. The primary target today is Ubuntu, but the architecture should not assume that.

The alternative would be to standardize on a cross-distro tool like [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) or [Nix](https://nixos.org/), which would give a single package management interface across distributions. That trades distribution-native familiarity and integration for consistency — a trade-off that doesn't make sense for a personal dotfiles setup where the distribution is always known at setup time.

However, relying solely on the native package manager creates management fragmentation across machines. macOS uses `brew upgrade`, Linux uses `apt upgrade`, and individually curl-installed tools like chezmoi and mise each have their own self-update commands. On a personal multi-machine setup you have to remember *how* each tool was installed to know how to update it.

## Decision

Use the native package manager as the primary tool for system-level packages on all Linux machines — apt for Debian/Ubuntu, yum/dnf for Red Hat/Fedora-based systems. Package lists are defined per distribution so each manager gets only what it understands.

On Linux **client workstations**, Homebrew is also used for tools not in apt or where apt's version is too old. The rule is: apt first, Homebrew when apt isn't sufficient. This gives a single update command (`brew upgrade`) across macOS and Linux clients for the tooling layer.

Linux **servers** remain apt-only — no Homebrew.

## Consequences

Each distribution gets its native tooling for system packages, which means better integration, faster installs, and no extra dependencies. The setup feels natural on each system.

The cost is that packages need to be listed separately per distribution, and package names don't always match across managers (e.g. `fd-find` on apt vs `fd` elsewhere). That duplication is manageable and preferable to forcing a non-native tool onto every Linux machine.

On Linux clients, Homebrew adds ~400MB overhead (bzip2, ca-certificates, openssl@3, and dependencies). This is acceptable for client workstations but not for servers. apt and Homebrew coexist on Linux clients, so there's still a per-package decision about which manager to use. The rule (apt first, Homebrew when needed) is simple but requires judgment.

The upside is that `brew upgrade` works the same way on macOS and Linux clients — no per-machine mental overhead for keeping tools current.

**Bootstrap paths by machine class:**

- **Personal Linux client** — use `setup.sh` (installs Homebrew, then chezmoi). Homebrew is available for the tooling layer.
- **Linux server** — install chezmoi via `curl`, set `install_packages=false` or rely on apt-only scripts. No Homebrew.
- **Restricted/work Linux machine** — install chezmoi via `curl`, set `install_packages=false`. Packages managed out-of-band.

The `is_server` and `install_packages` flags in `.chezmoi.toml.tmpl` map directly to these machine classes and control which package scripts run.
