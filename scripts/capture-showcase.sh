#!/usr/bin/env bash
set -euo pipefail
if ! command -v hyprshot >/dev/null 2>&1; then
  echo "hyprshot is required for this shortcut. Install it with your preferred AUR helper, for example: yay -S hyprshot" >&2
  exit 1
fi
PICTURE_HOME="\${XDG_PICTURES_DIR:-$HOME/Pictures}"
OUTPUT_DIR="$PICTURE_HOME/Nexus-Showcase"
mkdir -p "$OUTPUT_DIR"
filename="nexus-$(date +%Y%m%d-%H%M%S).png"
exec hyprshot -m output -o "$OUTPUT_DIR" -f "$filename"
