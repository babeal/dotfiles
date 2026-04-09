---
name: test-ubuntu-docker
description: Test dotfiles in a Docker Ubuntu container. Use whenever the user wants to test dotfiles on Ubuntu/Linux, after making changes to dotfiles configs or scripts, or when asked to validate/verify the Linux setup.
argument-hint: "What to test, e.g. 'run a full test from a clean container', 'reapply dotfiles on the running container', 'just verify current state', 'test all configs'"
allowed-tools: Bash
---

Test dotfiles in an ephemeral Ubuntu Docker container. Runs the appropriate workflow based on the instruction, writes a log, and returns a summary to the orchestrating agent.

## Instruction

Request: $ARGUMENTS

Read this instruction carefully and choose the right workflow from the options below. The instruction is natural language — use judgment to match intent.

---

## Container Configuration

Compose file: `tests/e2e/ubuntu/docker-compose.yml` — read this file for service name, container name, and volume mount paths. Username is always `$(whoami)` set as `USERNAME` before any docker-compose call.

Test chezmoi configs are in `tests/e2e/config/`. Default is `default.toml` unless the instruction names another.

## Paths

| Item                      | Value                                 |
| ------------------------- | ------------------------------------- |
| Compose file              | `tests/e2e/ubuntu/docker-compose.yml` |
| Service name              | `ubuntu`                              |
| Container name            | `dotfiles-test-ubuntu`                |
| Dotfiles source (mounted) | `/tmp/dotfiles-source` (read-only)    |
| Chezmoi source (guest)    | `~/.local/share/chezmoi/`             |
| Chezmoi config (guest)    | `~/.config/chezmoi/chezmoi.toml`      |
| Test config dir (host)    | `tests/e2e/config/`                   |
| Log dir                   | `logs/ubuntu/`                        |

## Scripts

All scripts are in `.claude/skills/test-ubuntu-docker/scripts/`.

| Script              | Usage                                             |
| ------------------- | ------------------------------------------------- |
| `copy.sh`           | `copy.sh <compose_file> <username> <config_file>` |
| `verify.sh`         | `verify.sh <compose_file> <username>`             |
| `get-log-number.sh` | Returns next sequential log file path             |

## Notes on the Setup

- **Dotfiles are volume-mounted read-only** at `/tmp/dotfiles-source`. They must be rsync'd to the writable chezmoi source dir before chezmoi runs. This protects the host files — chezmoi can only write to the rsync'd copy.
- **Never remove `:ro` from the volume mount** — that would expose the host dotfiles to writes from chezmoi (git init, etc.).
- **chezmoi is NOT pre-installed** in the image. The full-test workflow installs it at runtime via `setup.sh`.
- Use `-T` with `docker compose exec` when piping stdin or capturing output (suppresses TTY allocation).
- **Never use `~` in docker compose exec arguments** — the host shell expands `~` before docker sees it. Always use the `USER_HOME` variable with absolute container paths.

## Chezmoi Variables

Variables come from the test config file (e.g. `tests/e2e/config/default.toml`) on the host. This file is injected into the container by `copy.sh` before chezmoi runs. Because the template uses `promptStringOnce`/`promptBoolOnce`, chezmoi reads existing values and skips all interactive prompts. To change test variables, update the config file — the skill picks it up automatically on next run.

---

## Workflows

**Before any workflow:** Determine which config to use from the instruction (default: `default.toml`). Set these variables for the commands below:

```bash
export USERNAME=$(whoami)
USER_HOME="/home/${USERNAME}"

REPO_ROOT="$(pwd)"
COMPOSE_FILE="$REPO_ROOT/tests/e2e/ubuntu/docker-compose.yml"
CONFIG="$REPO_ROOT/tests/e2e/config/<config_name>.toml"
SCRIPTS="$REPO_ROOT/.claude/skills/test-ubuntu-docker/scripts"
```

### Full Test (clean container)

Use when the instruction asks for a fresh, end-to-end test, rebuilding from scratch, or testing from a clean state. This is the highest-confidence test.

**The container is left running at the end** so the orchestrating agent can exec in, inspect state, or issue a quick reapply without rebuilding.

```bash
# 1. Tear down any existing container and volumes
docker compose -f "$COMPOSE_FILE" down -v

# 2. Build and start a fresh container
docker compose -f "$COMPOSE_FILE" up -d --build ubuntu

# 3. Transfer files (rsync dotfiles + inject config)
bash "$SCRIPTS/copy.sh" "$COMPOSE_FILE" "$USERNAME" "$CONFIG"

# 4. Run setup.sh — installs Homebrew, brew-installs chezmoi + mise, then applies dotfiles
#    Running via pipe (non-TTY) so setup.sh skips keepalive_sudo and uses --no-tty automatically
docker compose -f "$COMPOSE_FILE" exec -T ubuntu \
  bash "${USER_HOME}/.local/share/chezmoi/setup.sh" 2>&1
```

### Reapply (running container, chezmoi already installed)

Use when iterating on dotfiles — tweaking configs, adding files, testing new templates. Only the source files and chezmoi config are refreshed; no setup or installation steps run.

If a chezmoi `run_onchange_` script doesn't re-trigger as expected, note this in the summary and suggest a full test.

```bash
# 1. Transfer files (rsync dotfiles + inject config)
bash "$SCRIPTS/copy.sh" "$COMPOSE_FILE" "$USERNAME" "$CONFIG"

# 2. Re-init and apply
docker compose -f "$COMPOSE_FILE" exec -T ubuntu \
  zsh -c 'chezmoi init --apply --no-tty 2>&1'
```

### Verify Only

Use when the instruction asks to check, verify, or inspect the current state without making any changes. Just runs the verification script and reports.

### Multi-Config Testing

When asked to "test all configs", loop over `tests/e2e/config/*.toml`:

```bash
for CONFIG in tests/e2e/config/*.toml; do
  echo "--- Testing with $(basename ${CONFIG}) ---"
  # full test workflow using ${CONFIG}
done
```

---

## Verification Checks

Run after any workflow (or alone for verify-only). Captures PASS/FAIL/WARN for each check.

```bash
bash "$SCRIPTS/verify.sh" "$COMPOSE_FILE" "$USERNAME"
```

---

## Log File

Determine the next log file path before starting work by running the helper script:

```bash
LOG_FILE=$(bash .claude/skills/test-ubuntu-docker/scripts/get-log-number.sh)
```

Write the log:

```markdown
---
date: YYYY-MM-DDTHH:MM:SS
workflow: <full-test|reapply|verify>
result: <PASS|FAIL>
---

# Ubuntu Docker Test Log <NNNN>

**Date:** YYYY-MM-DD HH:MM:SS
**Workflow:** <workflow>
**Result:** <PASS|FAIL>

## Steps Executed

<numbered list of what was done>

## setup.sh Output

<captured stdout/stderr from setup.sh>

## Verification

| Check                   | Result         |
| ----------------------- | -------------- |
| ~/.zshrc exists         | PASS/FAIL      |
| chezmoi status clean    | PASS/FAIL/WARN |
| zsh --login clean       | PASS/FAIL      |
| version manager present | PASS/FAIL/SKIP |

## Errors / Notes

<failures, warnings, observations, suggested next step>
```

---

## Return Summary

After writing the log, return this to the orchestrating agent (under 150 words):

```
Ubuntu Docker Test <NNNN> — <PASS|FAIL>
Workflow: <workflow> | Date: <datetime>

Checks: X/Y passed
- <bullet per failure or notable finding>
- <suggested next step if FAIL>

Log: logs/ubuntu/<NNNN>.md
```

## Failure Guidance

| Failure point            | Suggested next step                                      |
| ------------------------ | -------------------------------------------------------- |
| Container won't start    | Check `docker compose logs ubuntu`, may be a build error |
| Homebrew install fails   | Check network connectivity in container, retry full test |
| setup.sh error           | Fix failing template/script, then reapply                |
| run*onchange* not re-run | Issue a full test for clean script state                 |
| Verify fails only        | Fix config, reapply (no full test needed)                |
| Variables missing        | Update test config in `tests/e2e/config/`, then reapply  |
