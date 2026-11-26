#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$HOME/.local/bin"
NEXUS_LINK="$BIN_DIR/nexus"
HYPR_LUA="$CONFIG_HOME/hypr/hyprland.lua"
HYPR_CONF="$CONFIG_HOME/hypr/hyprland.conf"

cd "$PROJECT_DIR"

echo "========================================"
echo " NexusDotShell - Auto-config"
echo "========================================"

required_commands=(quickshell qs matugen cava cc python3)
missing=()

for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing+=("$command_name")
    fi
done

if ((${#missing[@]})); then
    echo "Dependências principais ausentes: ${missing[*]}"
    echo "Execute primeiro: ./install-dependencies.sh"
    exit 1
fi

echo
echo "[1/5] Preparando scripts..."
chmod +x \
    "$PROJECT_DIR/scripts/nexus" \
    "$PROJECT_DIR/scripts/start-hyprland.sh" \
    "$PROJECT_DIR/scripts/enable-hyprland-lua.sh" \
    "$PROJECT_DIR/scripts/disable-hyprland-lua.sh" \
    "$PROJECT_DIR/scripts/enable-hyprland-autostart.sh" \
    "$PROJECT_DIR/scripts/disable-hyprland-autostart.sh" \
    "$PROJECT_DIR/scripts/capture-showcase.sh"

echo
echo "[2/5] Compilando auxiliares nativos..."
cc -std=c11 -O2 -Wall -Wextra -o nob nob.c
./nob build

echo
echo "[3/5] Instalando entrada do aplicativo..."
./nob install-desktop

echo
echo "[4/5] Configurando o comando nexus..."
mkdir -p "$BIN_DIR"

if [[ -L "$NEXUS_LINK" ]]; then
    current_target="$(readlink -f "$NEXUS_LINK" 2>/dev/null || true)"
    if [[ "$current_target" != "$PROJECT_DIR/scripts/nexus" ]]; then
        backup="${NEXUS_LINK}.backup.$(date +%Y%m%d-%H%M%S)"
        mv -- "$NEXUS_LINK" "$backup"
        echo "Link anterior preservado em: $backup"
    fi
elif [[ -e "$NEXUS_LINK" ]]; then
    backup="${NEXUS_LINK}.backup.$(date +%Y%m%d-%H%M%S)"
    mv -- "$NEXUS_LINK" "$backup"
    echo "Arquivo anterior preservado em: $backup"
fi

if [[ ! -e "$NEXUS_LINK" && ! -L "$NEXUS_LINK" ]]; then
    ln -s "$PROJECT_DIR/scripts/nexus" "$NEXUS_LINK"
fi

case ":${PATH}:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo "Aviso: adicione $BIN_DIR ao PATH para usar 'nexus' de qualquer terminal."
        ;;
esac

echo
echo "[5/5] Integração com Hyprland"
echo

if [[ -f "$HYPR_LUA" && -f "$PROJECT_DIR/scripts/enable-hyprland-lua.sh" ]]; then
    echo "Configuração Lua encontrada:"
    echo "  $HYPR_LUA"
    echo
    echo "1) Integrar com hyprland.lua"
    echo "2) Integrar com hyprland.conf"
    echo "3) Não configurar inicialização agora"
    echo
    read -r -p "Escolha [1/2/3]: " choice

    case "$choice" in
        1)
            bash "$PROJECT_DIR/scripts/enable-hyprland-lua.sh" "$HYPR_LUA"
            ;;
        2)
            if [[ -f "$HYPR_CONF" ]]; then
                bash "$PROJECT_DIR/scripts/enable-hyprland-autostart.sh" "$HYPR_CONF"
            else
                echo "Arquivo não encontrado: $HYPR_CONF"
                echo "Integração não realizada."
            fi
            ;;
        *)
            echo "Integração com Hyprland ignorada."
            ;;
    esac
elif [[ -f "$HYPR_CONF" ]]; then
    echo "Configuração tradicional encontrada:"
    echo "  $HYPR_CONF"
    read -r -p "Adicionar inicialização automática do NexusDotShell? [S/n] " answer
    case "$answer" in
        n|N|no|NO) echo "Inicialização automática não alterada." ;;
        *) bash "$PROJECT_DIR/scripts/enable-hyprland-autostart.sh" "$HYPR_CONF" ;;
    esac
else
    echo "Nenhuma configuração Hyprland reconhecida foi encontrada."
    echo "A integração automática foi ignorada."
fi

echo
echo "========================================"
echo " Auto-config concluído"
echo "========================================"
echo
echo "Iniciar manualmente: nexus"
echo "Executar pelo projeto: $PROJECT_DIR/scripts/start-hyprland.sh"
echo "Integração Lua: bash scripts/disable-hyprland-lua.sh"
echo "Integração tradicional: bash scripts/disable-hyprland-autostart.sh"
echo
echo "O auto-config não instalou pacotes nem usou sudo."
