#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Avoid opening a second instance when the shell was already started manually.
if command -v qs >/dev/null 2>&1; then
  running_instances="$(qs list --json --path "$PROJECT_DIR" 2>/dev/null || true)"
  if grep -Eq '"pid"[[:space:]]*:' <<< "$running_instances"; then
    exit 0
  fi
fi

exec quickshell -p "$PROJECT_DIR" -d
