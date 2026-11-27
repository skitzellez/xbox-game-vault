#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Game Vault all-in-one setup: run or double-click on a Linux PC on the same network as the Xbox (Dev Mode).
cd "$(dirname "$0")" || exit 1
if [ ! -t 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    self="$(pwd)/$(basename "$0")"
    for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal kgx mate-terminal tilix kitty alacritty lxterminal xterm; do
        if command -v "$term" >/dev/null 2>&1; then
            case "$term" in
                gnome-terminal|kgx) exec "$term" -- bash "$self" "$@" ;;
                xfce4-terminal|mate-terminal) exec "$term" -x bash "$self" "$@" ;;
                *) exec "$term" -e bash "$self" "$@" ;;
            esac
        fi
    done
fi
bash "./Setup Files/GameVault-Setup.sh" "$@"
echo
read -r -n 1 -s -p "Press any key to close this window."
echo
