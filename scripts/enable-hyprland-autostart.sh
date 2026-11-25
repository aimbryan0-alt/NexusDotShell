#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_CONFIG="$CONFIG_HOME/hypr/hyprland.conf"
STARTER="$PROJECT_DIR/scripts/start-hyprland.sh"
BEGIN_MARKER="# >>> NexusDotShell autostart >>>"
END_MARKER="# <<< NexusDotShell autostart <<<"

if [[ ! -f "$HYPR_CONFIG" ]]; then
  printf 'Hyprland config not found: %s\n' "$HYPR_CONFIG" >&2
  exit 1
fi

if grep -Fq "$STARTER" "$HYPR_CONFIG"; then
  echo "NexusDotShell autostart is already configured."
  exit 0
fi

# Do not silently create two shell instances if another Quickshell autostart exists.
if grep -Eq '^[[:space:]]*exec-once[[:space:]]*=.*(quickshell|qs[[:space:]]+run)' "$HYPR_CONFIG"; then
  echo "An existing Quickshell exec-once entry was found in $HYPR_CONFIG."
  echo "Review that entry before enabling NexusDotShell to avoid duplicate shells."
  exit 1
fi

backup="$HYPR_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$HYPR_CONFIG" "$backup"

{
  printf '\n%s\n' "$BEGIN_MARKER"
  printf 'exec-once = bash "%s"\n' "$STARTER"
  printf '%s\n' "$END_MARKER"
} >> "$HYPR_CONFIG"

echo "NexusDotShell autostart added to $HYPR_CONFIG"
echo "Backup: $backup"
echo "Log out and back into Hyprland to start NexusDotShell automatically."
