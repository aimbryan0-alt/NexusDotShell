#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_LUA="${1:-$CONFIG_HOME/hypr/hyprland.lua}"
STARTER="$PROJECT_DIR/scripts/start-hyprland.sh"
CAPTURE="$PROJECT_DIR/scripts/capture-showcase.sh"
BEGIN_MARKER="-- >>> NexusDotShell integration >>>"
END_MARKER="-- <<< NexusDotShell integration <<<"

if [[ ! -f "$HYPR_LUA" ]]; then printf 'Hyprland Lua config not found: %s\n' "$HYPR_LUA" >&2; exit 1; fi
if ! grep -Eq 'local[[:space:]]+mainMod[[:space:]]*=' "$HYPR_LUA"; then echo "Could not find local mainMod; refusing to add a keybind." >&2; exit 1; fi
if grep -Fq -- "$BEGIN_MARKER" "$HYPR_LUA"; then echo "NexusDotShell Lua integration is already configured."; exit 0; fi
if grep -Eq 'hl\.bind\(.*(SUPER|mainMod).*SHIFT.*S' "$HYPR_LUA"; then echo "SUPER + SHIFT + S appears to be in use. Resolve the conflict first." >&2; exit 1; fi
if grep -Eiq 'hl\.on\(["'\'']hyprland\.start|quickshell.*(-p|--path)|start-hyprland\.sh' "$HYPR_LUA"; then echo "A possible Quickshell autostart already exists. Review it first." >&2; exit 1; fi

backup="$HYPR_LUA.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$HYPR_LUA" "$backup"
python3 - "$HYPR_LUA" "$STARTER" "$CAPTURE" "$BEGIN_MARKER" "$END_MARKER" <<'PY'
import json, pathlib, sys
config, starter, capture, begin, end = sys.argv[1:]
path = pathlib.Path(config)
text = path.read_text()
block = f'''
{begin}
-- Start NexusDotShell once when the Hyprland session starts.
hl.on("hyprland.start", function()
    hl.exec_cmd("bash " .. {json.dumps(starter)})
end)

-- Capture the full output without opening a terminal.
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("bash " .. {json.dumps(capture)}))
{end}
'''
path.write_text(text.rstrip() + "\n\n" + block.lstrip())
PY
echo "NexusDotShell integration added to: $HYPR_LUA"
echo "Backup: $backup"
echo "Reload/restart Hyprland to apply."
