# SSH Keys and Bitwarden Secrets Design

## Overview

This document describes how SSH keys and other secrets are managed using Bitwarden
as the secrets backend, replacing Nate's 1Password approach. It covers the two
distinct Bitwarden products involved, how chezmoi integrates with each, and the
directory layout for SSH key storage.

## Bitwarden Products

There are two separate Bitwarden CLI tools with different purposes:

| Product | CLI | Chezmoi function | Use case |
|---|---|---|---|
| Bitwarden Password Manager | `bw` | `bitwarden`, `bitwardenFields`, `bitwardenAttachment` | SSH keys, passwords, personal secrets |
| Bitwarden Secrets Manager | `bws` | `bitwardenSecrets` | Machine API tokens, service credentials |

**SSH keys live in the Password Manager** (`bw`) as item attachments — stored as
files on the Bitwarden item, not as text fields. The Secrets Manager (`bws`) is
better suited for non-file secrets like API tokens.

## SSH Key Directory Layout

Following Nate's pattern, SSH keys are stored in a vault directory separate from
`~/.ssh`:

```
~/.ssh_keys/          # chezmoi-managed vault (populated from Bitwarden)
    id_github         # private key
    id_github.pub     # public key
    id_work           # private key
    id_work.pub       # public key

~/.ssh/               # standard SSH directory (not fully chezmoi-managed)
    config            # chezmoi-managed, references keys in ~/.ssh_keys
    known_hosts       # unmanaged
    authorized_keys   # unmanaged
```

**Why the separation?** `~/.ssh` contains files that accumulate over time
(`known_hosts`, `authorized_keys`) and should not be clobbered by chezmoi. The
vault directory is fully owned by chezmoi and only contains keys fetched from
Bitwarden. `~/.ssh/config` then references the keys by absolute path via
`IdentityFile`.

## Bitwarden Item Structure

SSH keys are stored in Bitwarden as **Login items** with **file attachments**:

- Item name: descriptive (e.g., `SSH Key - GitHub Personal`)
- Attachments: `id_github` (private key), `id_github.pub` (public key)
- Custom fields: any metadata (hostname, username, etc.)

## Chezmoi Data File

Item IDs are stored in `.chezmoidata/bitwarden.toml` to keep templates clean.
This is the equivalent of Nate's `onepassword.toml`:

```toml
[ssh_keys]
    github_personal  = "bf22e4b4-ae4a-4d1c-8c98-ac620004b628"
    work             = "c3d4e5f6-..."

[secrets]
    homebrew_github_token = "a1b2c3d4-..."
    github_pat            = "e5f6g7h8-..."
```

## Chezmoi Template Functions

### SSH keys (attachments)

```go
{{- bitwardenAttachment "id_github" "bf22e4b4-ae4a-4d1c-8c98-ac620004b628" -}}
```

Or using the data file to avoid hardcoding IDs in scripts:

```go
{{- bitwardenAttachmentByRef "id_github" "item" .bitwarden.ssh_keys.github_personal -}}
```

### Secrets (fields)

```go
export HOMEBREW_GITHUB_API_TOKEN={{ (bitwardenFields "item" .bitwarden.secrets.homebrew_github_token).value.value }}
```

### Secrets Manager (bws)

For machine-scoped API tokens managed via `bws`:

```go
{{ (bitwardenSecrets "be8e0ad8-d545-4017-a55a-b02f014d4158").value }}
```

## SSH Key Install Script

The script `run_after_20-create-ssh-keys.sh.tmpl` creates `~/.ssh_keys/` and
populates it from Bitwarden attachments. It only runs when `use_secrets` is true.

Key behaviors:
- Creates `~/.ssh_keys/` if it does not exist
- Writes each key file only if it does not already exist (idempotent)
- Sets correct permissions: `600` for private keys, `644` for public keys
- Requires `bw` to be unlocked before chezmoi runs (see Session Management below)

Conceptual structure (mirrors Nate's 1Password script):

```bash
{{- if .use_secrets }}
#!/usr/bin/env bash

mkdir -p "{{ .directories.ssh_keys_dir }}"

{{- range $name, $id := .bitwarden.ssh_keys }}
if [ ! -f "{{ $.directories.ssh_keys_dir }}/{{ $name }}" ]; then
    # write private key from Bitwarden attachment
    chmod 600 "{{ $.directories.ssh_keys_dir }}/{{ $name }}"
fi
if [ ! -f "{{ $.directories.ssh_keys_dir }}/{{ $name }}.pub" ]; then
    # write public key from Bitwarden attachment
    chmod 644 "{{ $.directories.ssh_keys_dir }}/{{ $name }}.pub"
fi
{{- end }}
{{- end }}
```

The actual template will use `bitwardenAttachment` directly in the script body to
emit the key content.

## SSH Config

`dot_config/git/../ssh/config.tmpl` (or a chezmoi-managed `~/.ssh/config`)
references keys by path:

```
Host github.com
    IdentityFile ~/.ssh_keys/id_github
    User git

Host work.example.com
    IdentityFile ~/.ssh_keys/id_work
    User deploy
```

This file is a regular chezmoi template (not `modify_`, not `create_`) since we
fully own its content.

## Session Management

`bw` must be authenticated and unlocked before chezmoi can call any `bitwarden*`
functions. The session token is passed via the `BW_SESSION` environment variable.

Typical flow before running `chezmoi apply` on a new machine:

```bash
bw login
export BW_SESSION=$(bw unlock --raw)
chezmoi apply
```

For machines where `use_secrets = false` (servers, CI), no Bitwarden session is
needed — all `bitwarden*` calls are guarded by `{{- if .use_secrets }}`.

## Machines Where Secrets Are Disabled

On servers or CI machines where `use_secrets = false`:
- No Bitwarden CLI is required
- SSH keys are managed manually or via other means
- The install script emits an empty file (the `{{- if .use_secrets }}` guard
  means the script body is empty, so chezmoi skips it)

## Open Questions

- Should `bws` (Secrets Manager) be used for any secrets, or is `bw` (Password
  Manager) sufficient for everything?
- Do work vs. personal machines need different Bitwarden vaults or collections?
  This would affect whether `github_user` needs to be parameterized alongside
  the SSH key set.
