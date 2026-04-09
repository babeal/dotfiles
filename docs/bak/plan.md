# Dotfiles Finalization Plan — Phase 1: Repo Shape

Get the repository into its final structure and skills minimally patched so they continue to work. Full skill and testing infrastructure redesign is a separate effort — see [plan-skill.md](plan-skill.md).

> **How `.chezmoiroot` works**: Setting `.chezmoiroot = home` means chezmoi only reads files under `home/`. Everything else at the repo root (`tests/`, `docs/`, `.github/`, `README.md`, etc.) is invisible to chezmoi — never read, never deployed. The repo-root-as-source layout is safe.

---

## Phase 1: Comment Out `use_secrets` Usage

The variable stays in `home/.chezmoi.toml.tmpl` for future use. Comment out the two places that reference it since neither is implemented yet.

### `home/dot_config/shell/env.sh.tmpl` — lines 35–40

```diff
-{{ if and (.use_secrets) (.dev_computer) -}}
-# Configure gitleaks to use a custom config file
-if [ -f "${HOME}/.local/share/git_stopwords/gitleaks.toml" ]; then
-    export GITLEAKS_CONFIG="${HOME}/.local/share/git_stopwords/gitleaks.toml"
-fi
-{{- end }}
+{{/* use_secrets not yet implemented — gitleaks config pending Bitwarden integration
+{{ if and (.use_secrets) (.dev_computer) -}}
+if [ -f "${HOME}/.local/share/git_stopwords/gitleaks.toml" ]; then
+    export GITLEAKS_CONFIG="${HOME}/.local/share/git_stopwords/gitleaks.toml"
+fi
+{{- end }}
+*/}}
```

### `home/dot_config/shell.d/third-party/homebrew.sh.tmpl` — lines 6–8

```diff
-{{ if .use_secrets -}}
-export HOMEBREW_GITHUB_API_TOKEN={{- onepasswordRead .secrets.homebrew_github_token }}
-{{ end }}
+{{/* use_secrets not yet implemented — secrets integration pending
+{{ if .use_secrets -}}
+export HOMEBREW_GITHUB_API_TOKEN={{- onepasswordRead .secrets.homebrew_github_token }}
+{{ end }}
+*/}}
```

**Validate:** `chezmoi execute-template -f home/dot_config/shell/env.sh.tmpl` — must render without error.

---

## Phase 2: Repository Directory Restructure

Moves the `dotfiles/` wrapper so the repo root becomes the chezmoi source. The `home/` subdirectory stays — it just moves up one level.

### 2a. Create new directory tree

```bash
mkdir -p tests/e2e/ubuntu
mkdir -p tests/e2e/config
mkdir -p docs/old
```

### 2b. Move `docker-test/` → `tests/e2e/ubuntu/`

```bash
git mv docker-test/docker-compose.yml tests/e2e/ubuntu/docker-compose.yml
git mv docker-test/Dockerfile.ubuntu  tests/e2e/ubuntu/Dockerfile.ubuntu
git mv docker-test/README.md          tests/e2e/ubuntu/README.md
git mv docker-test/QUICK_START.md     tests/e2e/ubuntu/QUICK_START.md
rmdir docker-test
```

### 2c. Move `dotfiles/testing/` → `tests/e2e/config/`

```bash
git mv dotfiles/testing/chezmoi.toml tests/e2e/config/chezmoi.toml
rmdir dotfiles/testing
```

### 2d. Move `dotfiles/home/` → `home/`

The `home/` directory stays — it just moves up one level out of `dotfiles/`.

```bash
git mv dotfiles/home home
```

### 2e. Move `dotfiles/` root files and clean up

```bash
git mv dotfiles/.chezmoiroot .chezmoiroot   # content stays "home" — no edit needed
git mv dotfiles/setup.sh     setup.sh

# Delete — no longer needed
git rm dotfiles/setup-parallels.sh
git rm dotfiles/parallels-test.sh

# Archive dotfiles README
git mv dotfiles/README.md docs/old/dotfiles-README.md

# Remove empty dirs
rmdir dotfiles/install
rmdir dotfiles
```

### 2f. Move stale root docs to `docs/old/`

These will be replaced by the new README.

```bash
git mv COMPARISON.md       docs/old/
git mv MACOS_VM.md         docs/old/
git mv QUICK_REFERENCE.md  docs/old/
git mv SETUP_COMPLETE.md   docs/old/
git mv TESTING-STRATEGY.md docs/old/
git mv TODO.md             docs/old/
git mv README.md           docs/old/
```

### 2g. Update docker-compose volume mount

The compose file is now 3 levels deep. Update `tests/e2e/ubuntu/docker-compose.yml`:

```yaml
volumes:
  - ../../../:/tmp/dotfiles-source:ro
```

### 2h. Update CLAUDE.md

Replace all path references:

| Old | New |
|-----|-----|
| `docker-test/docker-compose.yml` | `tests/e2e/ubuntu/docker-compose.yml` |
| `dotfiles/testing/chezmoi.toml` | `tests/e2e/config/chezmoi.toml` |
| `dotfiles/home/` | `home/` |

**Validate:**

```bash
chezmoi -S . status           # chezmoi sees the source correctly
cat .chezmoiroot              # prints: home
chezmoi -S . managed | head   # only home/ files listed
```

---

## Phase 3: Minimal Skill Path Fixes

Patch both skills so they continue to work after the restructure. This is path surgery only — the full skill redesign (new Dockerfile, Mise tasks, multi-config support, USERNAME) is in [plan-skill.md](plan-skill.md) and can be done after the repo is in shape.

### 3a. Update `.claude/skills/test-ubuntu-docker/SKILL.md`

Update the **Container Configuration** table:

| Field | Old value | New value |
|-------|-----------|-----------|
| Compose file | `docker-test/docker-compose.yml` | `tests/e2e/ubuntu/docker-compose.yml` |
| Test chezmoi config | `dotfiles/testing/chezmoi.toml` | `tests/e2e/config/chezmoi.toml` |

Update every inline bash command that references `docker-test/` or `dotfiles/testing/`.

### 3b. Update `.claude/skills/test-macos/SKILL.md`

Update the **VM Configuration** table:

| Field | Old value | New value |
|-------|-----------|-----------|
| Dotfiles source (host) | `/Users/brandt/dev/chezmoi/dotfiles/` | `/Users/brandt/dev/chezmoi/` |
| Test chezmoi config | `/Users/brandt/dev/chezmoi/dotfiles/testing/chezmoi.toml` | `/Users/brandt/dev/chezmoi/tests/e2e/config/chezmoi.toml` |

Update all rsync commands. Source changes from `dotfiles/` to repo root. Add excludes so non-chezmoi content doesn't land on the VM:

```bash
rsync -avz --delete \
  --exclude='.git' \
  --exclude='tests/' \
  --exclude='docs/' \
  --exclude='log/' \
  --exclude='reference/' \
  --exclude='.claude/' \
  --exclude='.agents/' \
  -e "ssh ${SSH_OPTS[*]}" \
  /Users/brandt/dev/chezmoi/ \
  brandt@192.168.10.59:~/.local/share/chezmoi/
```

Also update the test config rsync path from `dotfiles/testing/chezmoi.toml` to `tests/e2e/config/chezmoi.toml`.

**Validate:** Run `/test-ubuntu-docker full test from clean container` — must pass all checks.

---

## Phase 4: CI Gate (GitHub Actions)

CI must be in place before pushing to the real repository.

### 4a. Create `.github/workflows/ci.yml`

```yaml
name: CI

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
    paths:
      - ".github/workflows/ci.yml"
      - ".chezmoiroot"
      - "home/**"
      - "setup.sh"
      - "tests/e2e/config/**"

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Copy repository to chezmoi source dir
        run: |
          if [ -d /home/runner ]; then HOMEDIR="/home/runner"; else HOMEDIR="/Users/runner"; fi
          mkdir -p "${HOMEDIR}/.local/share/chezmoi"
          cp -a . "${HOMEDIR}/.local/share/chezmoi"

      - name: Create chezmoi config
        run: |
          if [ -d /home/runner ]; then HOMEDIR="/home/runner"; else HOMEDIR="/Users/runner"; fi
          mkdir -p "${HOMEDIR}/.config/chezmoi"
          cat > "${HOMEDIR}/.config/chezmoi/chezmoi.toml" << EOF
          [data]
              name              = "CI Test"
              email             = "ci@example.com"
              github_user       = "babeal"
              dev_computer      = false
              personal_computer = false
              is_server         = false
              install_packages  = false
              use_secrets       = false
              xdgCacheDir       = "${HOMEDIR}/.cache"
              xdgConfigDir      = "${HOMEDIR}/.config"
              xdgDataDir        = "${HOMEDIR}/.local/share"
              xdgStateDir       = "${HOMEDIR}/.local/state"
          EOF
          # CI detection uses env "CI" (set by GitHub Actions) — see docs/design/ci-detection.md

      - name: Install chezmoi
        run: sh -c "$(curl -fsLS get.chezmoi.io)"

      - name: Run chezmoi apply
        run: ./bin/chezmoi apply --no-tty

      - name: Verify dotfiles (Ubuntu)
        if: startsWith(matrix.os, 'ubuntu')
        run: |
          HOMEDIR="/home/runner"
          for f in .zshrc .bashrc .config/git/config; do
            [ -f "${HOMEDIR}/${f}" ] || { echo "FAIL: ${f} missing"; exit 1; }
          done
          [ -f "${HOMEDIR}/.config/shell.d/080-linux.sh" ] || { echo "FAIL: 080-linux.sh missing"; exit 1; }
          [ -f "${HOMEDIR}/.config/shell.d/080-macos.sh" ] && { echo "FAIL: 080-macos.sh present on linux"; exit 1; } || true
          [ -d "${HOMEDIR}/.ssh" ] || { echo "FAIL: ~/.ssh directory missing"; exit 1; }
          SSH_MODE=$(stat -c '%a' "${HOMEDIR}/.ssh")
          [ "${SSH_MODE}" = "700" ] || { echo "FAIL: ~/.ssh mode is ${SSH_MODE}, expected 700"; exit 1; }
          echo "PASS: all Ubuntu checks passed"

      - name: Verify dotfiles (macOS)
        if: startsWith(matrix.os, 'macos')
        run: |
          HOMEDIR="/Users/runner"
          for f in .zshrc .bashrc .config/git/config; do
            [ -f "${HOMEDIR}/${f}" ] || { echo "FAIL: ${f} missing"; exit 1; }
          done
          [ -f "${HOMEDIR}/.config/shell.d/080-macos.sh" ] || { echo "FAIL: 080-macos.sh missing"; exit 1; }
          [ -f "${HOMEDIR}/.config/shell.d/080-linux.sh" ] && { echo "FAIL: 080-linux.sh present on macos"; exit 1; } || true
          [ -d "${HOMEDIR}/.ssh" ] || { echo "FAIL: ~/.ssh directory missing"; exit 1; }
          SSH_MODE=$(stat -f '%A' "${HOMEDIR}/.ssh")
          [ "${SSH_MODE}" = "700" ] || { echo "FAIL: ~/.ssh mode is ${SSH_MODE}, expected 700"; exit 1; }
          echo "PASS: all macOS checks passed"
```

### 4b. Verify CI guards in existing templates

CI-incompatible blocks use `env "CI"` per `docs/design/ci-detection.md`. Confirm any scripts touched during this finalization follow the same pattern. Verify `.install-core-packages.sh` exits cleanly when `$CI` is set.

**Validate:** Push to a branch and confirm Actions pass on both Ubuntu and macOS.

---

## Phase 5: New README.md

Create `README.md` at the repo root after Phase 2f moves the old one to `docs/old/`.

```markdown
# dotfiles

> Managed with [chezmoi](https://www.chezmoi.io/). Targets macOS and Ubuntu 24.04.

[![CI](https://github.com/babeal/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/babeal/dotfiles/actions/workflows/ci.yml)

## Quick install

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply babeal
```

## Prerequisites (when `install_packages = false`)

Install these manually before running chezmoi if you are not using the built-in package management:

- **Homebrew** (macOS) — https://brew.sh
- **mise** (version manager) — https://mise.jdx.dev/getting-started.html
- **Starship** (prompt) — https://starship.rs/guide/

## What's managed

| Area | Files |
|------|-------|
| Shell (zsh + bash) | `~/.zshrc`, `~/.bashrc`, `~/.config/shell.d/` |
| Git | `~/.config/git/config` |
| Prompt | `~/.starship.toml` (Starship) |
| Editors | nano (`~/.config/nano/nanorc`) |
| npm | `~/.config/npm/npmrc` |
| Packages | Homebrew (macOS) / apt (Ubuntu) when `install_packages = true` |

## Testing

See [docs/design/testing.md](docs/design/testing.md) for the full testing strategy.
```

---

## Phase 6: Additions from Reference

Small items worth landing before pushing.

### 6a. SSH directory creation

SSH configs vary per machine, so `~/.ssh/config` is **not** managed by chezmoi. Instead, create an empty keep file so chezmoi provisions the directory with correct permissions:

```bash
mkdir -p home/private_dot_ssh
touch home/private_dot_ssh/dot_keep
```

The `private_` prefix ensures chezmoi creates `~/.ssh` with `700` permissions. The `dot_keep` file becomes `~/.ssh/.keep` (empty, harmless). SSH keys and config remain machine-specific and unmanaged.

### 6b. zsh prompt

Verify `home/dot_config/shell.d/` covers the zsh prompt. `third-party/starship.sh` should handle it; if not, add `030-prompt.zsh` alongside the existing `030-prompt.bash`.

### 6c. macOS Library exclusion

Add to `home/.chezmoiignore` so macOS app configs don't accidentally get managed:

```
{{ if eq .chezmoi.os "darwin" -}}
Library/
{{- end }}
```

---

## Phase 7: Final Validation

1. `/test-ubuntu-docker full test from clean container` → all checks PASS
2. `/test-macos full test from Base snapshot` → all checks PASS
3. CI green on pushed branch (Ubuntu + macOS)
4. Template spot-check:
   ```bash
   chezmoi -S . execute-template -f home/.chezmoi.toml.tmpl
   chezmoi -S . execute-template -f home/dot_config/shell/env.sh.tmpl
   chezmoi -S . execute-template -f home/dot_zshrc.tmpl
   ```

---

## Deferred Items

| Item | Reference | Priority |
|------|-----------|----------|
| Skill redesign (Dockerfile, Mise tasks, multi-config, USERNAME) | [plan-skill.md](plan-skill.md) | Do next |
| Ghostty terminal config | `reference/nate-dotfiles/.../dot_config/ghostty/` | High |
| Git credential manager | `reference/nate-dotfiles/.chezmoiscripts/run_after_30-*` | High |
| Post-install scripts (atuin, eza, fd symlinks) | `reference/nate-dotfiles/.chezmoiscripts/run_after_*` | Medium |
| Cursor/VS Code settings | `Library/Application Support/private_Cursor/` | Medium |
| Espanso text expander | `Library/Application Support/espanso/` | Medium |
| `bin/` utility scripts | `reference/nate-dotfiles/bin/` | Medium |
| bats unit tests | `reference/skunk-dotfiles/tests/` | Medium |
| Codecov coverage | `reference/skunk-dotfiles/.github/workflows/test.yaml` | Low |
| iTerm2 profile | `reference/nate-dotfiles/.assets/iterm2/` | Low |
| Atuin shell history | `reference/nate-dotfiles/dot_config/atuin/` | Low |
| gitleaks / git stopwords | `reference/nate-dotfiles/dot_local/share/git_stopwords/` | Low |
| Shell benchmark CI | `reference/skunk-dotfiles/.github/workflows/macos.yaml` | Low |
