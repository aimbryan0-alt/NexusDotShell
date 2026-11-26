#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v pacman >/dev/null 2>&1; then
    echo "Este instalador foi feito para Arch Linux e derivados."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "O comando sudo não está disponível."
    exit 1
fi

CORE_PACKAGES=(
    quickshell
    matugen
    cava
    base-devel
    python
    qt6-5compat
    qt6-multimedia
    qt6-quick3d
    qt6-shadertools
    qt6-svg
    qt6-wayland
    networkmanager
    bluez-utils
    brightnessctl
    libnotify
    ffmpeg
    iproute2
    curl
    playerctl
    zenity
)

OPTIONAL_PACKAGES=(
    yt-dlp
    neovim
    python-pynvim
    iw
    assimp
    hyprpicker
    hyprsunset
    power-profiles-daemon
    baobab
    libcanberra
)

echo "========================================"
echo " NexusDotShell - Dependências"
echo "========================================"
echo
echo "Pacotes principais:"
printf '  - %s\n' "${CORE_PACKAGES[@]}"
echo
echo "O comando abaixo atualizará o sistema e instalará"
echo "as dependências principais do NexusDotShell."
echo

read -r -p "Continuar? [S/n] " answer
case "$answer" in
    n|N|no|NO) echo "Instalação cancelada."; exit 0 ;;
esac

sudo pacman -Syu --needed -- "${CORE_PACKAGES[@]}"

echo
read -r -p "Instalar também os recursos complementares? [S/n] " answer
case "$answer" in
    n|N|no|NO)
        echo "Complementos ignorados."
        ;;
    *)
        sudo pacman -S --needed -- "${OPTIONAL_PACKAGES[@]}"
        ;;
esac

echo
read -r -p "Instalar as ferramentas ASUS (asusctl)? [y/N] " answer
case "$answer" in
    y|Y|yes|YES)
        sudo pacman -S --needed asusctl
        ;;
esac

echo
echo "===== VERIFICAÇÃO ====="
missing=()

for command_name in quickshell qs matugen cava cc python3; do
    if command -v "$command_name" >/dev/null 2>&1; then
        printf 'OK       %s\n' "$command_name"
    else
        printf 'AUSENTE  %s\n' "$command_name"
        missing+=("$command_name")
    fi
done

if ((${#missing[@]})); then
    echo
    echo "Algumas dependências principais não foram encontradas."
    printf 'Verifique: %s\n' "${missing[*]}"
    exit 1
fi

echo
echo "Dependências principais instaladas."
echo "Próxima etapa: ./auto-config.sh"
