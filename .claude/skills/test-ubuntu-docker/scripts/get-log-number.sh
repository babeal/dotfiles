#!/usr/bin/env bash
# Returns the next sequential log file path for the Ubuntu Docker test log.
# Usage: bash get-log-number.sh [log-dir]
#   log-dir  Optional absolute path to the log directory.
#            Defaults to <repo-root>/logs/ubuntu where repo-root is inferred
#            from this script's location (.claude/skills/test-ubuntu-docker/scripts/).
# Output: absolute path to the next log file (e.g. /path/to/logs/ubuntu/0001.md)

if [ -n "$1" ]; then
  LOG_DIR="$1"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  LOG_DIR="$REPO_ROOT/logs/ubuntu"
fi

mkdir -p "$LOG_DIR"

LAST=$(ls "$LOG_DIR"/*.md 2>/dev/null | sort | tail -1 | xargs basename 2>/dev/null | sed 's/\.md//')
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
echo "$LOG_DIR/${NEXT}.md"
