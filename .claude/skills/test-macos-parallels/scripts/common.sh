#!/usr/bin/env bash
# Shared functions for test-macos scripts.
# Source this file; do not execute it directly.

# Sets up SSH_OPTS array and TARGET string from explicit parameters.
# Usage: setup_ssh <ip> <user> <ssh_key_path>
setup_ssh() {
  local ip="$1" user="$2" key="$3"
  key="${key/#\~/$HOME}"
  SSH_OPTS=(-i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
  TARGET="${user}@${ip}"
}
