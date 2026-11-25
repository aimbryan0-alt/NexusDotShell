#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_LUA="${1:-$CONFIG_HOME/hypr/hyprland.lua}"
BIN_DIR="$HOME/.local/bin"
NEXUS_LINK="$BIN_DIR/nexus"
cd "$PROJECT_DIR"

if [[ ! -f "$HYPR_LUA" ]]; then
  printf 'Hyprland Lua config not found: %s\n' "$HYPR_LUA" >&2
  echo "Pass the exact config path as the first argument if stored elsewhere." >&2
  exit 1
fi

missing=()
for command_name in quickshell qs matugen cc python3; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
if ((${#missing[@]})); then
  printf 'Missing required command(s): %s\n' "${missing[*]}" >&2
  echo "Install these dependencies with your distribution package manager, then rerun bash install.sh." >&2
  exit 1
fi

echo "[1/4] Building NexusDotShell helpers..."
cc -std=c11 -O2 -Wall -Wextra -o nob nob.c
./nob build
echo "[2/4] Installing desktop entry..."
./nob install-desktop
echo "[3/4] Installing the 'nexus' command..."
mkdir -p "$BIN_DIR"
ln -sfn "$PROJECT_DIR/scripts/nexus" "$NEXUS_LINK"
chmod +x "$PROJECT_DIR/scripts/nexus" "$PROJECT_DIR/scripts/start-hyprland.sh" "$PROJECT_DIR/scripts/enable-hyprland-lua.sh" "$PROJECT_DIR/scripts/disable-hyprland-lua.sh" "$PROJECT_DIR/scripts/capture-showcase.sh"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Add $BIN_DIR to PATH to use 'nexus' from any terminal." ;; esac

echo "[4/4] Hyprland Lua integration"
read -r -p "Enable NexusDotShell autostart and SUPER + SHIFT + S screenshot shortcut? [Y/n] " answer
case "$answer" in
  n|N|no|NO) echo "Autostart was not changed." ;;
  *) bash "$PROJECT_DIR/scripts/enable-hyprland-lua.sh" "$HYPR_LUA" ;;
esac

echo
echo "Installation complete. Launch manually with: nexus"
echo "Remove integration: bash scripts/disable-hyprland-lua.sh"
echo "Remove command: rm -f \"$NEXUS_LINK\""
echo "No system packages were installed and no sudo commands were run."
