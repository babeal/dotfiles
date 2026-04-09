# Testing Design

## Overview

Two testing modes serve different purposes:

| Mode | Who | When | Trigger |
|------|-----|------|---------|
| **Automated skill** | Orchestrating agent | Before committing | `/test-ubuntu-docker` or `/test-macos` |
| **GitHub CI** | Everyone | Every push / PR | GitHub Actions |

Both modes validate that `setup.sh` works end-to-end on a clean system.

---

## Mode 1: Automated Skill Testing

### Purpose

End-to-end validation that dotfiles deploy correctly under a given configuration. The skill handles the full lifecycle: build, rsync source, inject config, run `setup.sh`, verify, write a log.

For macOS, the `test-macos` skill uses a Parallels VM via SSH — Docker is Ubuntu-only.

### Key Principle

**`setup.sh` is always the entry point for a full test.** It installs Homebrew, brew-installs chezmoi, and applies the dotfiles. Chezmoi is never pre-installed in the image — the image is a clean Ubuntu environment. This is what makes the test meaningful: it validates the real user experience.

### Docker Image

A single `Dockerfile` at `tests/e2e/ubuntu/Dockerfile` provides a clean Ubuntu environment with the system packages needed for `setup.sh` to run (curl, git, sudo, zsh, etc.). Chezmoi is intentionally absent.

The image is built with a `USERNAME` build arg so the container user always matches the host user — no hardcoded usernames.

```
docker-compose build → docker-compose up → rsync → inject config → setup.sh → verify
```

### Why a Read-Only Volume + rsync

The repo root is mounted read-only at `/tmp/dotfiles-source`. Before `setup.sh` runs, the skill rsyncs this to `/home/$USERNAME/.local/share/chezmoi` (writable). This is required because chezmoi writes into its source directory (git init, etc.) — the read-only mount protects host files from container writes.

### Workflows

#### Full Test (clean container)

1. Tear down any existing container and volumes
2. Build and start a fresh container
3. Rsync source from `/tmp/dotfiles-source` → `/home/$USERNAME/.local/share/chezmoi`
4. Inject test config into `/home/$USERNAME/.config/chezmoi/chezmoi.toml`
5. Run `setup.sh` — installs Homebrew, chezmoi, applies dotfiles
6. Run verification checks

#### Reapply (running container, chezmoi already installed)

1. Rsync updated source (picks up host edits)
2. Re-inject test config
3. `chezmoi init --apply --no-tty`

The container is left running after a full test so reapply can follow without rebuilding.

### Test Configs

Stored in `tests/e2e/config/`. Each file is a complete `chezmoi.toml` data block for a distinct scenario:

- `dev.toml` — `dev_computer=true`, `personal_computer=true`, `install_packages=false`
- `server.toml` — `is_server=true`, `dev_computer=false`, `install_packages=false`
- `minimal.toml` — all flags false, absolute minimum deployment

The skill discovers all `*.toml` files at runtime — no hardcoded filenames.

> `install_packages=false` in all skill configs. Package installs (Linuxbrew, apt) are slow and not the point of these tests. `setup.sh` itself is what's being tested, not every package it installs.

### Skill Interface

The `test-ubuntu-docker` skill accepts natural language:

- `"full test with dev config"` → clean container, dev.toml, setup.sh, verify
- `"reapply"` → rsync, re-inject config, chezmoi apply
- `"test all configs"` → sequential full test for each `*.toml`
- `"verify current state"` → verification checks only

---

## Mode 2: GitHub CI

### Purpose

Automated gate on every push and pull request. Catches template rendering failures, missing files, and OS-conditional errors before they reach main.

### What CI Validates (and What It Doesn't)

CI runs `chezmoi apply` with `install_packages=false`. This is intentional:

- **Validates**: template rendering, file placement, OS-conditional logic, permission bits — the chezmoi-specific correctness that's hard to verify by inspection
- **Does not validate**: package installation (`setup.sh` bootstrap, Homebrew, apt, mise installs)

Package installation is validated separately via the local Docker test skill (`/test-ubuntu-docker`). Running full package installs in CI would add 20-30 minutes per run, introduce network flakiness (Homebrew rate limits, download failures), and fail on MAS apps which require App Store login. The tradeoff is intentional — CI stays fast and reliable.

If full `setup.sh` CI coverage is needed in the future, it can be added as a separate nightly workflow with caching.

### Approach

Uses GitHub-hosted runners (no Docker). The repo is checked out, copied into the runner's home as the chezmoi source dir, a config is injected with all flags set to safe defaults (`install_packages=false`, `use_secrets=false`), chezmoi is installed via `curl`, and `chezmoi apply` runs. File existence checks verify the output.

Path-filtered triggers so CI only runs when relevant files change.

### Trigger (path-filtered)

```yaml
on:
  push:
    branches: [main]
    paths:
      - ".github/workflows/ci.yml"
      - ".chezmoiroot"
      - "home/**"
      - "setup.sh"
      - "tests/e2e/config/**"
  pull_request:
    branches: [main]
    paths: [same as above]
```

### Matrix

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
```

### Config Injection

CI injects a config inline (not from `tests/e2e/config/`) with these values:

```toml
[data]
    name              = "CI Test"
    email             = "ci@example.com"
    github_user       = "babeal"
    dev_computer      = false
    personal_computer = false
    is_server         = false
    install_packages  = false
    use_secrets       = false
```

No interactive prompts are possible on a runner — the full config is written before chezmoi runs.

### CI Detection

CI-specific template guards use `env "CI"` (set automatically by GitHub Actions), not a chezmoi data variable. See [ci-detection.md](ci-detection.md).

```go
{{ if eq (env "CI") "" }}
  {{/* safe to run GUI/interactive operations */}}
{{ end }}
```

### Verification

After `chezmoi apply` completes, the workflow asserts:

- Key files exist: `.zshrc`, `.bashrc`, `.config/git/config`
- OS-specific files are present on the right OS and absent on the wrong one:
  - Ubuntu: `080-linux.sh` present, `080-macos.sh` absent
  - macOS: `080-macos.sh` present, `080-linux.sh` absent
- `~/.ssh` directory exists with mode 700

---

## Docker Image Design

### Dockerfile

Located at `tests/e2e/ubuntu/Dockerfile`. Clean Ubuntu — no chezmoi, no Homebrew. `setup.sh` installs everything.

```dockerfile
FROM ubuntu:24.04

ARG USERNAME=brandt
ARG USER_UID=1001
ARG USER_GID=$USER_UID

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo zsh rsync locales build-essential ca-certificates \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -G sudo -s /bin/zsh \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $USERNAME
WORKDIR /home/$USERNAME
ENV SHELL=/bin/zsh

CMD ["/bin/zsh"]
```

UID 1001 because Ubuntu 24.04 ships with a default `ubuntu` user at UID 1000.

### docker-compose.yml

Passes `USERNAME` from the host environment as a build arg:

```yaml
services:
  ubuntu:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        USERNAME: ${USERNAME:-brandt}
    image: dotfiles-test-ubuntu:latest
    volumes:
      - ../../../:/tmp/dotfiles-source:ro
    stdin_open: true
    tty: true
    container_name: dotfiles-test-ubuntu
```

The skill sets `export USERNAME=$(whoami)` before invoking docker-compose so the container user always matches the host.

> macOS VM connection values (IP, SSH user, SSH key) live in `tests/e2e/macos/env.toml` — the only values that change when the VM moves. All other paths are hardcoded in the skill.

---

## Relationship Between Modes

| | Skill (`/test-ubuntu-docker`, `/test-macos`) | GitHub CI |
|---|---|---|
| **Entry point** | `setup.sh` | `chezmoi apply` |
| **Packages installed** | No (`install_packages=false`) | No (`install_packages=false`) |
| **Homebrew bootstrapped** | Yes (via `setup.sh`) | No |
| **What it proves** | Full bootstrap works end-to-end | Templates render and files land correctly |
| **When to run** | Before committing significant changes | Every push / PR |
| **Speed** | ~5 min (without packages) | ~2 min |

```
Developer edits file
        │
        ▼
  /test-ubuntu-docker ─── setup.sh → chezmoi apply ── full bootstrap validation
  /test-macos
        │
        ▼ (committed, pushed)
  GitHub Actions CI ───── chezmoi apply only ────────── template/file correctness gate
```
