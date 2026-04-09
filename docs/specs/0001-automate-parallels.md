# 0001: Automate Parallels VM Dotfiles Testing

## Overview

This spec describes automating dotfiles testing against a Parallels Desktop macOS VM. Currently testing is done manually by following the steps in `MACOS_VM.md`. The goal is a script that:

1. Restores a named snapshot
2. Starts the VM
3. Waits for it to be reachable
4. Runs the dotfiles setup script inside the guest
5. Verifies the result
6. Reports pass/fail

### Feasibility: High

The Parallels CLI (`prlctl`) supports everything needed: snapshot management, VM lifecycle control, and command execution inside the guest. Two execution approaches are available; SSH is recommended (see below).

---

## Discovered Infrastructure

From running `prlctl` commands against the host system:

| Item              | Value                                              |
| ----------------- | -------------------------------------------------- |
| Parallels version | 26.3.0 (build 57392)                               |
| prlctl path       | `/usr/local/bin/prlctl`                            |
| VM name           | `macOS`                                            |
| VM UUID           | `819365e6-ae60-4f4b-a64f-ab61765ae764`             |
| Shared network    | `10.211.55.0/24` (host at `10.211.55.2`)           |
| VM static IP      | `192.168.10.59` (manually set, confirmed working)  |
| SSH key           | `~/.ssh/id_ed25519_personal_mac`                   |
| Parallels Tools   | Installed (`state=installed version=26.3.0-57392`) |

### Existing Snapshots

| Name | UUID                                   | Date       | Notes                           |
| ---- | -------------------------------------- | ---------- | ------------------------------- |
| Base | `71dd7a04-6faa-4e97-b5cd-7da5c0459f4b` | 2026-04-03 | Fresh user + SSH enabled (current) |

### Existing Shared Folder

Parallels already has a shared folder configured:

- Host path: `~/dev/chezmoi/dotfiles`
- Guest mount: `/Volumes/dotfiles` (automounted by Parallels Tools)
- Mode: read-only

This means the setup script is already accessible inside the guest — no file transfer step needed.

---

## Execution Approaches

### Option A: `prlctl exec` (Parallels Tools)

Runs commands inside the guest via the Parallels Tools agent.

```bash
prlctl exec macOS --current-user /bin/zsh -c "echo hello"
```

**Pros**: No SSH setup required, no network dependency.  
**Cons**: Requires a logged-in user session (auto-login must be enabled). Output may be buffered for long-running commands. The `--current-user` flag relies on a live GUI session.

### Option B: SSH (Recommended)

Standard SSH once the VM's IP is known. The IP is readable from the host:

```bash
VM_IP=$(prlctl list macOS -o ip --no-header | tr -d ' ')
ssh -i ~/.ssh/id_ed25519_personal_mac brandt@"$VM_IP" "/Volumes/My Shared Files/dotfiles/setup-parallels.sh"
```

**Pros**: Reliable streaming output, works for long-running scripts, no GUI session dependency, standard tooling.  
**Cons**: Requires one-time SSH setup in each snapshot (see Prerequisites). IP is dynamic (DHCP).

**Recommendation: SSH.** It handles long-running dotfiles installs better, streams output correctly, and is more scriptable.

---

## Prerequisites (One-Time Setup Per Snapshot)

These steps must be done inside each snapshot **before** saving/using it for automation. Only needed once per snapshot.

### 1. Enable Remote Login (SSH)

Inside the guest macOS VM:

```
System Settings > General > Sharing > Remote Login > toggle ON
```

Optionally lock it down to specific users. This setting persists in the snapshot.

### 2. Add Host SSH Public Key

Inside the guest, add the host machine's public key to `~/.ssh/authorized_keys`:

```bash
# On the guest VM, in Terminal:
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# Paste your host's public key:
echo "ssh-ed25519 AAAA... brandt@host" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

To get your host public key: `cat ~/.ssh/id_ed25519.pub` (or `id_rsa.pub`).

The shared folder makes this easy — on the guest:

```bash
cat "/Volumes/My Shared Files/.ssh/id_ed25519.pub" >> ~/.ssh/authorized_keys
```

### 3. Passwordless Sudo

The dotfiles `setup.sh` installs Homebrew non-interactively over SSH (no TTY). The Homebrew
installer needs `sudo` but cannot prompt for a password. Grant the `brandt` user passwordless sudo:

```bash
# On the guest VM, in Terminal:
echo 'brandt ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/brandt
sudo chmod 440 /etc/sudoers.d/brandt
```

Verify (should not prompt for password):

```bash
sudo ls /root
```

### 4. Save the Updated Snapshot

After completing steps 1–3, update/re-save the snapshot:

```bash
# Delete the old snapshot, take a new one with the same name
prlctl snapshot macOS --name "Base" --description "Fresh user + SSH enabled"
```

Or simply update the existing snapshot from within Parallels Desktop GUI (Actions > Manage Snapshots).

### 5. Static IP

```
System Settings > Network > Ethernet (or Wi-Fi) > Details > TCP/IP > Configure IPv4: Manually
IP: 192.168.10.59
Subnet: 255.255.255.0
Router: 192.168.10.1
```

---

## Key `prlctl` Commands

```bash
# List all VMs
prlctl list -a

# List with IP addresses (running VMs only)
prlctl list -o uuid,name,status,ip -a

# List snapshots (JSON)
prlctl snapshot-list macOS -j

# Restore a snapshot (VM must be stopped)
prlctl snapshot-switch macOS --id {54485f00-5bc0-4a8c-9d13-7e3716f02856}

# Start VM
prlctl start macOS

# Stop VM (graceful)
prlctl stop macOS

# Force stop
prlctl stop macOS --kill

# Run command in guest (requires Parallels Tools + logged-in user)
prlctl exec macOS --current-user /bin/zsh -c "command"

# Set VM to start headless (no window)
prlctl set macOS --startup-view headless

# Take a screenshot (useful for debugging headless runs)
prlctl capture macOS --file /tmp/vm-screenshot.png

# Get VM status
prlctl status macOS
# → "macOS running" or "macOS stopped"

# Monitor events (JSON stream)
prlctl monitor-events macOS --json
```

---

## Automation Workflow

### Script: `scripts/test-parallels.sh`

Proposed location: `/Users/brandt/dev/chezmoi/scripts/test-parallels.sh`

```
Usage: test-parallels.sh [--snapshot <name>] [--vm <name>] [--keep]

  --snapshot  Snapshot name to restore (default: "Base")
  --vm        VM name (default: "macOS")
  --keep      Don't stop the VM after testing
```

### Step-by-Step Flow

```
1. VALIDATE
   └─ Check prlctl is available
   └─ Verify VM exists (prlctl list -a | grep <name>)
   └─ Find snapshot UUID by name from: prlctl snapshot-list <vm> -j

2. STOP VM (if running)
   └─ prlctl status <vm> → check if running
   └─ prlctl stop <vm> (graceful, timeout 30s)
   └─ prlctl stop <vm> --kill (if graceful fails)

3. RESTORE SNAPSHOT
   └─ prlctl snapshot-switch <vm> --id <uuid>

4. START VM
   └─ prlctl start <vm>

5. WAIT FOR SSH READINESS
   └─ Poll: prlctl list <vm> -o ip --no-header
   └─ Wait until IP is non-empty (up to 120s)
   └─ Poll: ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            -o BatchMode=yes brandt@<ip> true
   └─ Wait until SSH succeeds (up to 120s)

6. RUN DOTFILES SETUP
   └─ ssh brandt@<ip> '/Volumes/My\ Shared\ Files/dotfiles/setup-parallels.sh'
   └─ Or via the read-only shared folder path

7. VERIFY
   └─ ssh brandt@<ip> 'zsh --login -c "chezmoi status"'
   └─ ssh brandt@<ip> 'test -f ~/.zshrc && echo OK'
   └─ Add more verification commands as dotfiles grow

8. REPORT
   └─ Print PASS/FAIL with exit code
   └─ Optionally capture screenshot: prlctl capture <vm> --file /tmp/result.png

9. CLEANUP (unless --keep)
   └─ prlctl stop <vm>
```

---

## Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

VM="${VM_NAME:-macOS}"
SNAPSHOT="${SNAPSHOT_NAME:-Base}"
SSH_USER="${SSH_USER:-brandt}"
BOOT_TIMEOUT=120
SSH_TIMEOUT=120

# --- Helpers ---

vm_status() {
  prlctl status "$VM" | awk '{print $2}'
}

vm_ip() {
  prlctl list "$VM" -o ip --no-header | tr -d ' '
}

get_snapshot_uuid() {
  local name="$1"
  prlctl snapshot-list "$VM" -j \
    | python3 -c "
import sys, json
snaps = json.load(sys.stdin)
for uuid, s in snaps.items():
    if s['name'] == '$name':
        print(uuid)
        break
"
}

wait_for_ip() {
  local elapsed=0
  while [[ $elapsed -lt $BOOT_TIMEOUT ]]; do
    local ip
    ip=$(vm_ip)
    if [[ -n "$ip" && "$ip" != "-" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 5
    (( elapsed += 5 ))
  done
  echo "ERROR: VM did not get an IP within ${BOOT_TIMEOUT}s" >&2
  return 1
}

wait_for_ssh() {
  local ip="$1"
  local elapsed=0
  while [[ $elapsed -lt $SSH_TIMEOUT ]]; do
    if ssh -i ~/.ssh/id_ed25519_personal_mac \
           -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
           -o BatchMode=yes "$SSH_USER@$ip" true 2>/dev/null; then
      return 0
    fi
    sleep 5
    (( elapsed += 5 ))
  done
  echo "ERROR: SSH not ready within ${SSH_TIMEOUT}s" >&2
  return 1
}

# --- Main ---

echo "==> Finding snapshot: $SNAPSHOT"
SNAP_UUID=$(get_snapshot_uuid "$SNAPSHOT")
if [[ -z "$SNAP_UUID" ]]; then
  echo "ERROR: Snapshot '$SNAPSHOT' not found" >&2
  exit 1
fi
echo "    UUID: $SNAP_UUID"

echo "==> Stopping VM (if running)"
if [[ "$(vm_status)" == "running" ]]; then
  prlctl stop "$VM" || prlctl stop "$VM" --kill
fi

echo "==> Restoring snapshot"
prlctl snapshot-switch "$VM" --id "$SNAP_UUID"

echo "==> Starting VM"
prlctl start "$VM"

echo "==> Waiting for IP address..."
IP=$(wait_for_ip)
echo "    IP: $IP"

echo "==> Waiting for SSH..."
wait_for_ssh "$IP"

echo "==> Running dotfiles setup"
ssh -i ~/.ssh/id_ed25519_personal_mac -o StrictHostKeyChecking=no "$SSH_USER@$IP" \
  '"/Volumes/My Shared Files/dotfiles/setup-parallels.sh"'

echo "==> Verifying"
ssh -i ~/.ssh/id_ed25519_personal_mac -o StrictHostKeyChecking=no "$SSH_USER@$IP" \
  'test -f ~/.zshrc && echo "PASS: ~/.zshrc exists" || echo "FAIL: ~/.zshrc missing"'

echo "==> Done"
```

---

## Limitations and Notes

### Snapshot state

- `prlctl snapshot-switch` requires the VM to be **stopped**. The script handles this by stopping first.
- Snapshots in the XCode state (poweroff) can be restored faster than suspended ones.

### IP address timing

- The IP appears in `prlctl list` only after the guest's network comes up, which can take 20-40 seconds after `prlctl start`.
- Polling in 5-second intervals is reliable.

### SSH host key changes

- After restoring a snapshot, the guest's SSH host key is the same (it's baked into the snapshot). Use `StrictHostKeyChecking=no` with `UserKnownHostsFile=/dev/null` to avoid stale host key issues if you're testing multiple snapshots.

### SSH key must be specified explicitly

- The host has multiple SSH keys (`id_ed25519_personal_mac`, `nas01_ed25519`, `nas01_rsa`). Without `-i`, SSH cycles through all of them and hits the server's `MaxAuthTries` limit, causing "Too many authentication failures". Always pass `-i ~/.ssh/id_ed25519_personal_mac` explicitly.

### Parallels Tools exec alternative

- If you want to avoid SSH entirely, `prlctl exec macOS --current-user` works but requires auto-login enabled in the guest. Not recommended for automation since snapshots may restore a locked screen.

### Headless mode

- Set the VM to headless so it doesn't pop up a window during automated tests:
  ```bash
  prlctl set macOS --startup-view headless
  ```
  This persists as a VM setting (not snapshot-specific).

### Long-running installs

- Homebrew and other installers can take 10+ minutes. SSH handles this fine with a persistent connection. If running unattended, consider using `tmux` or `nohup` inside the guest and polling for a completion marker file.

---

## What You Need to Do

These are the one-time user actions required before the automation script will work:

- [x] Enable Remote Login in the macOS guest (System Settings > General > Sharing > Remote Login)
- [x] Add your host SSH public key (`cat ~/.ssh/id_ed25519.pub`) to `~/.ssh/authorized_keys` inside the guest
- [ ] Add passwordless sudo for `brandt` (`/etc/sudoers.d/brandt`) — required for non-interactive Homebrew install
- [ ] Re-save the "Base" snapshot after making those changes
- [ ] (Optional) Set the VM to headless: `prlctl set macOS --startup-view headless`
- [x] (Optional) Verify with: `ssh -i ~/.ssh/id_ed25519_personal_mac brandt@$(prlctl list macOS -o ip --no-header | tr -d ' ') ifconfig` ✓ confirmed working
