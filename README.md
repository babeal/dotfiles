# dotfiles

[![CI](https://github.com/babeal/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/babeal/dotfiles/actions/workflows/ci.yml)

## Overview

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/) with support for macOS and Ubuntu.

- Support for both `zsh` and `bash` shells
- Homebrew (macOS) and Linuxbrew (Ubuntu) package management
- [mise](https://mise.jdx.dev/) for software development tools and runtimes

## Setup

Use one of the following methods for setup:

### MacOS

```console
bash -c "$(curl -fsLS https://raw.githubusercontent.com/babeal/dotfiles/main/setup.sh)"
```

### Ubuntu

```console
bash -c "$(wget -qO - https://raw.githubusercontent.com/babeal/dotfiles/main/setup.sh)"
```

### Restricted Environments or Minimal Setup

For work machines, where packages installation is restricted, you can install chezmoi and then pass `install_packages = false` during configuration to skip package installation.

```console
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply babeal
```

- or -

```console
chezmoi init --apply babeal
```

## Daily operations

```bash
# Pull latest and apply
chezmoi update

# Preview changes
chezmoi diff

# Apply dotfiles
chezmoi apply

# Edit a file
chezmoi edit ~/.zshrc

# Check for common problems.
chezmoi doctor
```
