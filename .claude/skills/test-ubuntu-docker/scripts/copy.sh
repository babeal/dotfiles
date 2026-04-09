#!/usr/bin/env bash
# Syncs dotfiles and chezmoi config into the Ubuntu Docker container.
#
# Usage: copy.sh <compose_file> <username> <config_file>
#   compose_file  Path to docker-compose.yml
#   username      Container username (matches Dockerfile USERNAME arg)
#   config_file   Local path to chezmoi.toml to inject as container config
set -euo pipefail

COMPOSE_FILE="$1"
USERNAME="$2"
CONFIG_FILE="$3"
USER_HOME="/home/${USERNAME}"

echo "Syncing dotfiles from read-only mount to writable chezmoi source dir..."
docker compose -f "$COMPOSE_FILE" exec -T ubuntu \
  bash -c "mkdir -p ${USER_HOME}/.local/share/chezmoi && rsync -a /tmp/dotfiles-source/ ${USER_HOME}/.local/share/chezmoi/"

echo "Injecting config: $(basename "$CONFIG_FILE")"
docker compose -f "$COMPOSE_FILE" exec -T ubuntu \
  bash -c "mkdir -p ${USER_HOME}/.config/chezmoi && cat > ${USER_HOME}/.config/chezmoi/chezmoi.toml" \
  < "$CONFIG_FILE"

echo "Done."
