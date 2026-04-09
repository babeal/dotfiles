#!/usr/bin/env bash
# Runs verification checks on the macOS VM.
#
# Usage: verify.sh <ip> <ssh_user> <ssh_key>
#   ip           VM IP address
#   ssh_user     SSH username
#   ssh_key      Path to SSH private key
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

setup_ssh "$1" "$2" "$3"

ssh "${SSH_OPTS[@]}" "$TARGET" 'zsh --login -s' << 'ENDSSH'
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

  brew --version 2>/dev/null | head -1 | grep -q Homebrew \
    && echo "PASS: brew available" \
    || echo "FAIL: brew missing"
ENDSSH
