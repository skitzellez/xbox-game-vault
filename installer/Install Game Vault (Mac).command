#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Game Vault all-in-one setup: double-click on a Mac on the same network as the Xbox (Dev Mode).
cd "$(dirname "$0")" || exit 1
bash ./GameVault-Setup.sh "$@"
echo
read -r -n 1 -s -p "Press any key to close this window."
echo
