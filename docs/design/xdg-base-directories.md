# XDG Base Directory Specification

Reference for where files should live under the XDG Base Directory Specification.

## Directories

| Variable           | Default path     | Purpose                           |
| ------------------ | ---------------- | --------------------------------- |
| `$XDG_CONFIG_HOME` | `~/.config`      | User-specific configuration files |
| `$XDG_DATA_HOME`   | `~/.local/share` | User-specific data files          |
| `$XDG_STATE_HOME`  | `~/.local/state` | User-specific state data          |
| `$XDG_CACHE_HOME`  | `~/.cache`       | Non-essential cached data         |
| _(no variable)_    | `~/.local/bin`   | User executables                  |

### XDG_CONFIG_HOME

Default: `~/.config`

For settings you would reasonably check into git, copy between machines, edit manually

```sh
~/.config/git/config
~/.config/starship.toml
```

if you'd want to version control it, it belongs here.

### XDG_DATA_HOME

Default: `~/.local/share`

Data generated or consumed by apps that is persistent, not configuration, not easily regenerated.

```sh
~/.local/share/nvim/site/pack/*        # plugins
~/.local/share/fonts/*
~/.local/share/applications/*.desktop
~/.local/share/flatpak/*
~/.local/share/zoxide/db.zo
~/.local/share/gnupg/*
```

### XDG_CACHE_HOME

Default: `~/.cache`

Anything that can be safely deletes without breaking correctness; performance optimizations

```sh
~/.cache/pip/*
~/.cache/nvim/*
~/.cache/google-chrome/*
~/.cache/node-gyp/*
~/.cache/mesa_shader_cache/*
```

If you can run rm -rf ~/.cache/<app> and only lose speed, not data, it belongs here.

### XDG_STATE_HOME

Default: `~/.local/state`

Data that is persistent, machine specific, not meant to be edited or synced

```sh
~/.local/state/bash/history
~/.local/state/zsh/history
~/.local/state/nvim/shada
~/.local/state/myapp/session.db
~/.local/state/myapp/logs/*
```

If it’s important to runtime behavior but not something you’d configure, it goes here.

### XDG_RUNTIME_DIR

Default: `/run/user/<uid>`

Short lived session bound artifacts: sockets, pid files, locks, ipc

```sh
/run/user/1000/wayland-0
/run/user/1000/pulse/native
/run/user/1000/myapp.sock
/run/user/1000/systemd/*
```

If it must disappear on logout/reboot, it belongs here.

## Common Mistakes

- Putting logs in ~/.config → wrong, use state
- Putting databases in ~/.cache → wrong, use data
- Putting history files in ~/.config → wrong, use state
- Treating ~/.local/share as a dumping ground → it should hold meaningful data only

## Data vs State

This is where even experienced developers get it wrong:

- DATA = “I care about this content”
  - notes, plugins, assets, databases
- STATE = “the app cares, I don’t”
  - history, session restore, logs, undo files

## Shell Script Placement

The key distinction is **sourced vs executed**:

- **Sourced** scripts (shell configuration, loaded at startup) → `~/.config`
- **Executed** scripts (utilities, run directly) → `~/.local/bin`

### Examples

| File                 | Location               | Reason                         |
| -------------------- | ---------------------- | ------------------------------ |
| `shell.d/*.sh`       | `~/.config/shell.d/`   | Sourced as shell configuration |
| `shell.d/*.zsh`      | `~/.config/shell.d/`   | Sourced as shell configuration |
| `git/config`         | `~/.config/git/config` | Application configuration      |
| Custom CLI utilities | `~/.local/bin/`        | Executed directly              |
| ZSH completion cache | `~/.cache/zsh/`        | Non-essential cache            |
| ZSH plugin data      | `~/.local/share/zsh/`  | Application data               |

## Resources

- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
