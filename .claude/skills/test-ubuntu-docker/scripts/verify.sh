#!/usr/bin/env bash
# Runs verification checks on the Ubuntu Docker container.
#
# Usage: verify.sh <compose_file> <username>
#   compose_file  Path to docker-compose.yml
#   username      Container username (matches Dockerfile USERNAME arg)
set -euo pipefail

COMPOSE_FILE="$1"
USERNAME="$2"

docker compose -f "$COMPOSE_FILE" exec -T ubuntu zsh -c '
  # Source Homebrew env so brew-installed binaries (chezmoi, mise) are on PATH.
  [ -f /home/linuxbrew/.linuxbrew/bin/brew ] \
    && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

  test -f ~/.zshrc \
    && echo "PASS: ~/.zshrc exists" \
    || echo "FAIL: ~/.zshrc missing"

  if command -v chezmoi &>/dev/null; then
    STATUS=$(chezmoi status 2>&1 | head -20)
    [ -z "$STATUS" ] \
      && echo "PASS: chezmoi status clean" \
      || printf "WARN: chezmoi status has diffs:\n%s\n" "$STATUS"
  else
    echo "FAIL: chezmoi not found"
  fi

  zsh --login -c "echo PASS: zsh login clean" 2>&1 || echo "FAIL: zsh --login errored"

  if command -v mise &>/dev/null; then
    echo "PASS: mise available"
  elif command -v asdf &>/dev/null; then
    echo "PASS: asdf available"
  else
    echo "SKIP: no version manager (mise/asdf) found"
  fi
'
