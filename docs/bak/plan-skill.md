# Skill & Testing Infrastructure Redesign

**Design reference:** [docs/design/testing.md](design/testing.md)

This plan closes the gap between the current state and the design: dynamic username, correct UID, multiple named test configs, externalized environment config, and updated skills.

---

## Current State

- `Dockerfile.ubuntu` — hardcoded `babeal`, no build args
- `docker-compose.yml` — no USERNAME build arg passthrough
- `tests/e2e/config/chezmoi.toml` — single config, `install_packages=true`
- `test-ubuntu-docker` SKILL.md — hardcoded `babeal` and absolute host paths
- `test-macos` SKILL.md — needs environment config reference

---

## Phase 1: Rename and Fix the Dockerfile

### 1a. Rename

```bash
git mv tests/e2e/ubuntu/Dockerfile.ubuntu tests/e2e/ubuntu/Dockerfile
```

### 1b. Replace contents

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

Key changes:

- `ARG USERNAME=brandt` — no more hardcoded `babeal`
- `USER_UID=1001` — Ubuntu 24.04 ships with `ubuntu:1000`; avoids UID collision
- chezmoi is NOT pre-installed — `setup.sh` handles that (this is what's being tested)

**Validate:** `docker build -t dotfiles-ubuntu tests/e2e/ubuntu/ --build-arg USERNAME=$(whoami)` — must succeed.

---

## Phase 2: Update docker-compose.yml

Pass `USERNAME` from the host environment as a build arg. The skill sets `export USERNAME=$(whoami)` before invoking docker-compose.

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

---

## Phase 3: Create Multiple Test Configs

Replace the single `tests/e2e/config/chezmoi.toml` with named scenario configs. The skill discovers all `*.toml` files in this directory — no hardcoded filenames. The current config can be renamed to default.md and the skills can default to that one unless another one is named.

## Phase 4: Create `tests/e2e/macos/env.toml`

Externalizes the macOS VM connection values that would otherwise be hardcoded in the skill. Only things that vary per machine belong here — paths and log dirs are constants in the skill commands.

```toml
# tests/e2e/macos/env.toml
# macOS VM connection details. Update here when the VM changes.

[macos]
  vm_name       = "macOS"
  base_snapshot = "Base"
  ip            = "192.168.10.59"
  ssh_user      = "brandt"
  ssh_key       = "~/.ssh/id_ed25519_personal_mac"
```

---

## Phase 5: Rewrite `test-ubuntu-docker` SKILL.md

Replace all hardcoded `babeal` references and host paths with dynamic values. Core workflow does not change — `setup.sh` is still the full-test entry point.

### Container Configuration

Point the skill at the compose file and let it read the rest:

```markdown
## Container Configuration

Compose file: `tests/e2e/ubuntu/docker-compose.yml` — read this file for service name,
container name, and volume mount paths. Username is always `$(whoami)` set as `USERNAME`
before any docker-compose call. Config dir is `tests/e2e/config/`, log dir is `logs/ubuntu/`.
```

### Full test workflow

```bash
export USERNAME=$(whoami)
USER_HOME="/home/${USERNAME}"

# 1. Tear down any existing container and volumes
docker compose -f tests/e2e/ubuntu/docker-compose.yml down -v

# 2. Build and start a fresh container
docker compose -f tests/e2e/ubuntu/docker-compose.yml up -d --build ubuntu

# 3. Rsync dotfiles from read-only mount to writable chezmoi source dir
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  bash -c "mkdir -p ${USER_HOME}/.local/share/chezmoi && rsync -a /tmp/dotfiles-source/ ${USER_HOME}/.local/share/chezmoi/"

# 4. Inject test config (e.g. dev.toml)
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  bash -c "mkdir -p ${USER_HOME}/.config/chezmoi && cat > ${USER_HOME}/.config/chezmoi/chezmoi.toml" \
  < tests/e2e/config/dev.toml

# 5. Run setup.sh — installs Homebrew, chezmoi, applies dotfiles
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  bash "${USER_HOME}/.local/share/chezmoi/setup.sh" 2>&1
```

### Reapply workflow

```bash
export USERNAME=$(whoami)
USER_HOME="/home/${USERNAME}"

# Rsync updated dotfiles
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  bash -c "rsync -a /tmp/dotfiles-source/ ${USER_HOME}/.local/share/chezmoi/"

# Re-inject config
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  bash -c "cat > ${USER_HOME}/.config/chezmoi/chezmoi.toml" \
  < tests/e2e/config/dev.toml

# Re-apply
docker compose -f tests/e2e/ubuntu/docker-compose.yml exec -T ubuntu \
  zsh -c "chezmoi init --apply --no-tty 2>&1"
```

### Multi-config testing

When asked to "test all configs", loop over `tests/e2e/config/*.toml`:

```bash
for CONFIG in tests/e2e/config/*.toml; do
  echo "--- Testing with $(basename ${CONFIG}) ---"
  # full test workflow using ${CONFIG} instead of dev.toml
done
```

---

## Phase 6: Update `test-macos` SKILL.md

Add environment config reference and simplify rsync.

### 6a. Add environment config note at the top

```markdown
## Environment Config

VM connection values (IP, SSH user, SSH key) are in `tests/e2e/macos/env.toml`.
Update values there rather than editing this skill.
```

### 6b. rsync command

Transfer everything except the dirs that have no business on the VM:

```bash
rsync -avz --delete \
  --exclude='reference/' \
  --exclude='docs/' \
  --exclude='logs/' \
  -e "ssh ${SSH_OPTS[*]}" \
  /Users/brandt/dev/chezmoi/ \
  brandt@192.168.10.59:~/.local/share/chezmoi/
```

---

## Phase 7: Remove Stale Files

```bash
git rm tests/e2e/ubuntu/README.md      # references old docker-compose workflow
git rm tests/e2e/ubuntu/QUICK_START.md # same
```

---

## Phase 8: Validate

1. **Build succeeds:** `export USERNAME=$(whoami) && docker compose -f tests/e2e/ubuntu/docker-compose.yml build`
2. **Automated skill — dev config:** `/test-ubuntu-docker full test with dev config` → PASS
3. **Automated skill — all configs:** `/test-ubuntu-docker test all configs` → PASS for each
4. **macOS skill still works:** `/test-macos verify current state` → PASS
