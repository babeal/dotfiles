#!/usr/bin/env bash
# Syncs dotfiles source and chezmoi config to the macOS VM.
#
# Usage: copy.sh <ip> <ssh_user> <ssh_key> <source_dir> <config_file>
#   ip           VM IP address
#   ssh_user     SSH username
#   ssh_key      Path to SSH private key
#   source_dir   Local directory to rsync as chezmoi source
#   config_file  Local path to chezmoi.toml to push as VM config
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

setup_ssh "$1" "$2" "$3"

SOURCE_DIR="$4"
CONFIG_FILE="$5"

echo "Syncing dotfiles to ${TARGET}..."
rsync -avz --delete --delete-excluded \
  --exclude='.git/' \
  --filter=':- .gitignore' \
  -e "ssh ${SSH_OPTS[*]}" \
  "$SOURCE_DIR/" \
  "${TARGET}:~/.local/share/chezmoi/"

echo "Pushing config: $(basename "$CONFIG_FILE")"
rsync -avz -e "ssh ${SSH_OPTS[*]}" \
  "$CONFIG_FILE" \
  "${TARGET}:~/.config/chezmoi/chezmoi.toml"

echo "Setting setup.sh executable..."
ssh "${SSH_OPTS[@]}" "$TARGET" 'chmod +x ~/.local/share/chezmoi/setup.sh'

echo "Done."
