#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
missing=()
for command_name in quickshell qs matugen cc python3; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
if (("\${#missing[@]}")); then
  printf 'Missing required command(s): %s\n' "\${missing[*]}" >&2
  echo "Install the missing dependencies using your distribution's package manager, then run: bash install.sh" >&2
  exit 1
fi
if ! command -v hyprshot >/dev/null 2>&1; then
  echo "Optional: hyprshot is not installed. The screenshot shortcut will be added, but will report this dependency when used."
fi
echo "[1/3] Bootstrapping build driver..."
cc -std=c11 -O2 -Wall -Wextra -o nob nob.c
echo "[2/3] Building native helpers and desktop entry..."
./nob build
./nob install-desktop
echo "[3/3] Hyprland Lua integration"
read -r -p "Enable NexusDotShell autostart and SUPER + SHIFT + S screenshot shortcut? [Y/n] " answer
case "$answer" in
  n|N|no|NO) echo "Build completed. Autostart was not changed." ;;
  *) bash scripts/enable-hyprland-lua.sh ;;
esac
echo
echo "Installation preparation complete."
echo "Start manually with: quickshell -p \"$PROJECT_DIR\" -d"
echo "Remove the Lua integration with: bash scripts/disable-hyprland-lua.sh"
echo "No system packages were installed and no sudo commands were run."
