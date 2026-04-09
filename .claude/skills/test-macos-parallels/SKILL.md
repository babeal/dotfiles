---
name: test-macos-parallels
description: Test dotfiles on the Parallels macOS VM. Use whenever the user wants to test dotfiles on macOS, after making changes to dotfiles configs or scripts, or when asked to validate/verify the macOS setup. Always use this skill rather than writing ad-hoc SSH commands for dotfiles testing.
argument-hint: "What to test, e.g. 'run a full test from the Base snapshot', 'reapply dotfiles on the running VM', 'just verify current state', 'do a full test but keep the VM running after'"
allowed-tools: Bash
---

Test dotfiles on the Parallels macOS VM. Runs the appropriate workflow based on the instruction, writes a log, and returns a summary to the orchestrating agent.

## Instruction

Request: $ARGUMENTS

Read this instruction carefully and choose the right workflow from the options below. The instruction is natural language — use judgment to match intent.

---

## Environment Config

VM connection values are in `tests/e2e/macos/env.toml`. **Read this file first** before any workflow to get: `vm_name`, `base_snapshot`, `ip`, `ssh_user`, `ssh_key`. Update values there when the VM changes — never hardcode them in commands.

Test chezmoi configs are in `tests/e2e/config/`. Default is `default.toml` unless the instruction names another.

## Paths

| Item                   | Value                            |
| ---------------------- | -------------------------------- |
| Chezmoi source (guest) | `~/.local/share/chezmoi/`        |
| Chezmoi config (guest) | `~/.config/chezmoi/chezmoi.toml` |
| Test config dir (host) | `tests/e2e/config/`              |
| Log dir                | `logs/macos/`                    |

## Scripts

All scripts are in `.claude/skills/test-macos/scripts/`.

| Script              | Usage                                                          |
| ------------------- | -------------------------------------------------------------- |
| `copy.sh`           | `copy.sh <ip> <ssh_user> <ssh_key> <source_dir> <config_file>` |
| `verify.sh`         | `verify.sh <ip> <ssh_user> <ssh_key>`                          |
| `get-log-number.sh` | Returns next sequential log file path                          |

## File Transfer

**Do NOT rely on the Parallels shared folder mount.** Host changes do not reliably appear in the VM through the mount. Always use `copy.sh` to transfer files via rsync over SSH.

The shared folder mount at `/Volumes/My Shared Files/` is left intact for the user's manual testing.

## SSH Helper

Always run remote commands through a login shell to simulate real user environment (`.zprofile` sourced, brew on PATH, etc.):

```bash
SSH_OPTS=(-i <ssh_key> -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
ssh "${SSH_OPTS[@]}" <ssh_user>@<ip> 'zsh --login -c "<command>"'
```

Substitute values from `tests/e2e/macos/env.toml`.

## Chezmoi Variables

Variables are sourced from the test config file (e.g. `tests/e2e/config/<config-name>.toml`) on the host. This file is pushed to `~/.config/chezmoi/chezmoi.toml` on the VM by `copy.sh`. Because the template uses `promptStringOnce`/`promptBoolOnce`, chezmoi reads existing values from this config and skips all interactive prompts.

---

## Workflows

**Before any workflow:** Read `tests/e2e/macos/env.toml` to get connection values. Determine which config to use from the instruction (default: `default.toml`). Set these variables for the commands below:

```bash
# Values from env.toml
VM_NAME="..."        # vm_name
BASE_SNAPSHOT="..."  # base_snapshot
IP="..."             # ip
SSH_USER="..."       # ssh_user
SSH_KEY="..."        # ssh_key (expand ~ to $HOME)

SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
TARGET="${SSH_USER}@${IP}"

REPO_ROOT="$(pwd)"
CONFIG="$REPO_ROOT/tests/e2e/config/<config_name>.toml"
SCRIPTS="$REPO_ROOT/.claude/skills/test-macos/scripts"
```

### Full Test (clean slate from Base snapshot)

Use when the instruction asks for a fresh, end-to-end test, resetting to a known good state, or testing from scratch. This is the highest-confidence test.

**The VM is left running at the end** so the orchestrating agent can diagnose failures, SSH in manually, or issue a quick reapply without waiting for another boot.

```bash
# 1. Stop VM
prlctl status "$VM_NAME" | grep -q running && prlctl stop "$VM_NAME" 2>/dev/null || true
sleep 3
prlctl stop "$VM_NAME" --kill 2>/dev/null || true

# 2. Find Base snapshot UUID
SNAP_UUID=$(prlctl snapshot-list "$VM_NAME" -j | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
for uuid, s in snaps.items():
    if s['name'] == '$BASE_SNAPSHOT':
        print(uuid); break
")
[ -z "$SNAP_UUID" ] && echo "ERROR: $BASE_SNAPSHOT snapshot not found" && exit 1

# 3. Restore + start
prlctl snapshot-switch "$VM_NAME" --id "$SNAP_UUID"
prlctl start "$VM_NAME"

# 4. Wait for SSH (up to 120s)
for i in $(seq 1 24); do
  ssh "${SSH_OPTS[@]}" -o BatchMode=yes "$TARGET" true 2>/dev/null && break
  echo "Waiting for SSH... ($((i*5))s)"
  sleep 5
  [ $i -eq 24 ] && echo "ERROR: SSH timeout" && exit 1
done

# 5. Prepare directories on VM
ssh "${SSH_OPTS[@]}" "$TARGET" 'mkdir -p ~/.config/chezmoi ~/.local/share/chezmoi'

# 6. Transfer files
bash "$SCRIPTS/copy.sh" "$IP" "$SSH_USER" "$SSH_KEY" "$REPO_ROOT" "$CONFIG"

# 7. Run setup.sh — installs prerequisites (Homebrew, chezmoi) and applies dotfiles
ssh "${SSH_OPTS[@]}" "$TARGET" 'zsh --login -c "bash ~/.local/share/chezmoi/setup.sh" 2>&1'
```

### Reapply (running VM, chezmoi already initialized)

Use when iterating on dotfiles — adding files, tweaking config, testing new packages, etc. Requires chezmoi to already be installed and initialized on the VM (i.e., a Full Test has been run at least once). Only the source files and chezmoi config are refreshed; no setup or installation steps run.

If the instruction mentions a change to a chezmoi run*onchange* script and the script doesn't re-trigger, note this in the summary and suggest a full test.

```bash
# 1. Transfer files
bash "$SCRIPTS/copy.sh" "$IP" "$SSH_USER" "$SSH_KEY" "$REPO_ROOT" "$CONFIG"

# 2. Re-init and apply — re-processes .chezmoi.toml.tmpl so computed values (xdg dirs etc.)
# are derived correctly from .chezmoi.homeDir, not from the literal ~ in testing/chezmoi.toml.
# promptStringOnce/promptBoolOnce read existing values from the rsync'd config, so no prompts appear.
# Login shell simulates real user environment (.zprofile sourced, brew on PATH).
ssh "${SSH_OPTS[@]}" "$TARGET" 'zsh --login -c "/opt/homebrew/bin/chezmoi init --apply --no-tty" 2>&1'
```

---

## Verification Checks

Run after any workflow (or alone for verify-only). Captures PASS/FAIL/WARN for each check.

```bash
bash "$SCRIPTS/verify.sh" "$IP" "$SSH_USER" "$SSH_KEY"
```

---

## Log File

Determine the next log file path before starting work by running the helper script:

```bash
LOG_FILE=$(bash .claude/skills/test-macos/scripts/get-log-number.sh)
```

The script infers the repo root from its own location, so it works on any machine or path. You may also pass an explicit log directory as the first argument if needed.

Write the log:

```markdown
---
date: YYYY-MM-DDTHH:MM:SS
workflow: <full-test|reapply|verify>
result: <PASS|FAIL>
---

# macOS Test Log <NNNN>

**Date:** YYYY-MM-DD HH:MM:SS
**Workflow:** <workflow>
**Result:** <PASS|FAIL>

## Steps Executed

<numbered list of what was done>

## setup.sh Output

<captured stdout/stderr from setup.sh>

## Verification

| Check                | Result         |
| -------------------- | -------------- |
| ~/.zshrc exists      | PASS/FAIL      |
| chezmoi status clean | PASS/FAIL/WARN |
| zsh --login clean    | PASS/FAIL      |
| brew available       | PASS/FAIL      |

## Errors / Notes

<failures, warnings, observations, suggested next step>
```

---

## Return Summary

After writing the log, return this to the orchestrating agent (under 150 words):

```
macOS Test <NNNN> — <PASS|FAIL>
Workflow: <workflow> | Date: <datetime>

Checks: X/Y passed
- <bullet per failure or notable finding>
- <suggested next step if FAIL>

Log: logs/macos/<NNNN>.md
```

## Failure Guidance

| Failure point            | Suggested next step                                       |
| ------------------------ | --------------------------------------------------------- |
| SSH timeout              | Check `prlctl status macOS`, may need manual intervention |
| Homebrew install fails   | May need XCode CLT — escalate to user                     |
| setup.sh error           | Fix failing template/script, then reapply                 |
| run*onchange* not re-run | Issue a full test for clean script state                  |
| Verify fails only        | Fix config, reapply (no full test needed)                 |
| Variables missing        | Update test config in `tests/e2e/config/`, then reapply   |
