#!/usr/bin/env bash
set -euo pipefail
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_LUA="${1:-$CONFIG_HOME/hypr/hyprland.lua}"
BEGIN_MARKER="-- >>> NexusDotShell integration >>>"
END_MARKER="-- <<< NexusDotShell integration <<<"
if [[ ! -f "$HYPR_LUA" ]]; then printf 'Hyprland Lua config not found: %s\n' "$HYPR_LUA" >&2; exit 1; fi
if ! grep -Fq "$BEGIN_MARKER" "$HYPR_LUA"; then echo "No NexusDotShell Lua integration block was found."; exit 0; fi
backup="$HYPR_LUA.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$HYPR_LUA" "$backup"
temporary_file="$(mktemp)"
awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skipping = 1; next }
  $0 == end { skipping = 0; next }
  !skipping { print }
' "$HYPR_LUA" > "$temporary_file"
cat "$temporary_file" > "$HYPR_LUA"
rm -f "$temporary_file"
echo "NexusDotShell integration removed from: $HYPR_LUA"
echo "Backup: $backup"
