#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_CONFIG="$CONFIG_HOME/hypr/hyprland.conf"
BEGIN_MARKER="# >>> NexusDotShell autostart >>>"
END_MARKER="# <<< NexusDotShell autostart <<<"

if [[ ! -f "$HYPR_CONFIG" ]]; then
  echo "Hyprland config not found: $HYPR_CONFIG"
  exit 1
fi

if ! grep -Fq "$BEGIN_MARKER" "$HYPR_CONFIG"; then
  echo "No NexusDotShell autostart block was found."
  exit 0
fi

backup="$HYPR_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$HYPR_CONFIG" "$backup"

temporary_file="$(mktemp)"
awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skipping = 1; next }
  $0 == end { skipping = 0; next }
  !skipping { print }
' "$HYPR_CONFIG" > "$temporary_file"
cat "$temporary_file" > "$HYPR_CONFIG"
rm -f "$temporary_file"

echo "NexusDotShell autostart removed from $HYPR_CONFIG"
echo "Backup: $backup"
