# 0002: tmux Setup

## Overview

Add tmux to the dotfiles with a modern, minimal configuration. The goal is a working, clipboard-capable tmux on both macOS and Linux with a clean structure that supports future additions without external plugin infrastructure.

## Goals

- Install tmux via existing package management scripts (no new install machinery)
- One config assembled from small, focused partials via chezmoi templating
- Clipboard works on both platforms without helper binaries
- Client and server machines get different prefix keys
- No plugins, no TPM, no status bar frameworks

## Non-Goals

- TPM or any plugin manager
- Powerline or external status bar tools
- `tmux-mem-cpu-load`, `cmake`, `reattach-to-user-namespace`, `xsel`
- Shell auto-start or tmux attach-on-login scripts

## Design Decisions

### Terminal type: `tmux-256color` not `screen-256color`

`tmux-256color` is the official tmux recommendation and is objectively better than `screen-256color`. It adds missing capabilities for modified function and arrow keys (e.g., `C-Up`, `M-PageUp`) that `screen-256color` lacks, which matters for Vim/Neovim inside tmux.

**Caveat:** `tmux-256color` ships with ncurses 6.x and is not present on older or minimal Linux systems. If connecting via SSH to a server that lacks this terminfo entry, applications may display garbled output. Workaround: copy the entry with `infocmp tmux-256color | ssh <host> tic -x -`, or configure a per-host fallback in `~/.ssh/config` with `SetEnv TERM=xterm-256color`.

### Clipboard: OSC 52 not helper binaries

tmux 3.2+ supports OSC 52 natively via `set -g set-clipboard on`. The terminal emulator handles the actual clipboard write, eliminating the need for `reattach-to-user-namespace` on macOS or `xsel` on Linux.

**Requirements for OSC 52 to work:**

1. `set-clipboard on` in tmux (set in `common.conf`)
2. The terminal emulator must support OSC 52 — **iTerm2 requires enabling this explicitly** in Preferences → General → "Applications in terminal may access clipboard" (it is off by default)
3. `allow-passthrough on` must be set in tmux when the clipboard sequence needs to pass through to an outer terminal (e.g., running tmux over SSH, or nested tmux sessions) — see `server.conf` and `os/macos.conf`

### Client vs server split

Different machines need different prefix keys:
- **Client** (macOS, Linux desktop): `C-z` — ergonomic on a workstation
- **Server** (Linux headless): `C-a` — `C-q` is commonly intercepted by XON/XOFF terminal flow control (`stty ixon`) in Linux SSH pseudo-terminals at the kernel level, before tmux can receive it. `C-a` (classic screen/tmux default) is safe in all terminal environments.

The split also provides a clear place to add client-only features (richer status bar, future plugins) without cluttering server config.

### No TPM

For a minimal setup with no plugins declared, TPM adds install complexity (git clone, plugin install script) with no benefit. A plain `~/.tmux.conf` is sufficient. TPM can be added later if plugins are needed.

## File Structure

```
home/
  dot_tmux.conf.tmpl              # assembles partials via {{ include }}
  dot_tmux.conf.d/
    common.conf                   # shared settings: mouse, history, keybindings, colors, clipboard
    client.conf                   # prefix C-z, status bar
    server.conf                   # prefix C-a, allow-passthrough for clipboard over SSH
    os/
      macos.conf                  # allow-passthrough (Touch ID / sudo, clipboard)
      linux.conf                  # default-shell /usr/bin/zsh
```

### Template assembly logic

```
common.conf         → always
client.conf         → if not .is_server
server.conf         → if .is_server
os/macos.conf       → if .chezmoi.os == "darwin"
os/linux.conf       → if .chezmoi.os == "linux"
```

## Package Changes

### `home/.chezmoidata/packages.homebrew.toml`
Add `tmux` to `packages.homebrew.common.formulae`.

### `home/.chezmoidata/packages.apt.toml`
Add `tmux` to `packages.apt.common.packages`.

No additional packages on either platform.

## Configuration Details

### `common.conf`

```
# Terminal
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Clipboard (OSC 52, tmux 3.2+)
# Requires terminal emulator support; iTerm2 needs "Applications in terminal
# may access clipboard" enabled in Preferences → General
set -g set-clipboard on

# Mouse
set -g mouse on

# History
set -g history-limit 100000

# Start windows and panes at 1
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Copy mode
setw -g mode-keys vi

# Unbind default prefix
unbind C-b

# Keybindings
bind c new-window -c "#{pane_current_path}"
bind 2 split-window -vc "#{pane_current_path}"
bind 3 split-window -hc "#{pane_current_path}"
bind C-p select-pane -U
bind C-n select-pane -D
bind C-k kill-pane
bind k kill-window
bind C-r source-file ~/.tmux.conf \; display-message "Config reloaded"
```

### `client.conf`

```
set -g prefix C-z
bind C-z send-prefix

# Status bar (built-in, no external tools)
set -g status on
set -g status-interval 5
set -g status-left " #S "
set -g status-right " %Y-%m-%d  %H:%M "
```

### `server.conf`

```
set -g prefix C-a
bind C-a send-prefix

# Allow OSC 52 clipboard sequences to pass through to the outer terminal
# when connecting to this server over SSH
set -g allow-passthrough on
```

### `os/macos.conf`

```
# Required for Touch ID sudo to work inside tmux (tmux 3.3+ disables passthrough
# by default for security; this re-enables it for the local macOS session)
# Also required for OSC 52 clipboard to reach iTerm2/WezTerm in nested contexts
set -g allow-passthrough on
```

### `os/linux.conf`

```
# Ensure zsh is used (login shell may default to bash on fresh systems)
set-option -g default-shell /usr/bin/zsh
```

## Testing

After implementation, validate with:
- `/test-ubuntu-docker` — verify tmux installs and config deploys on Linux
- `/test-macos-parallels` — verify tmux installs and config deploys on macOS
