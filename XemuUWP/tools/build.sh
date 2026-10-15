#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Build xemu and package it: build.sh <version> [nocounter]. Run from Windows with
#   C:\msys64\usr\bin\env.exe -i MSYSTEM=UCRT64 HOME=/home/GamerDad SYSTEMROOT=C:\Windows TAR_OPTIONS=--force-local
#     PATH=/usr/bin C:\msys64\usr\bin\bash.exe -lc "/c/Users/GamerDad/XboxEmu/XemuUWP/tools/build.sh 0.3.3.0"
# Stops when make fails, so an old exe is never repackaged under a new version.
set -e
V=${1:?version}
R=/c/Users/GamerDad/XboxEmu
export PKG_CONFIG_PATH=$R/sdl3-uwp-pc:$PKG_CONFIG_PATH
# The frame-rate display (ui/xui/xemu-uwp-testhud.inc) is in every build, shown when Game Vault asks for it. build.sh <version> nocounter: a build
# without it; the file is set aside for the build, and the result is checked for it.
HUD=$R/xemu-src/ui/xui/xemu-uwp-testhud.inc
if [ "${2:-}" = nocounter ] && [ -f $HUD ]; then
  mv $HUD $HUD.off
  # touch: the next test build must compile the counter back in (the release build's deps lack it)
  trap 'mv $HUD.off $HUD; touch $R/xemu-src/ui/xui/main.cc' EXIT
fi
cd $R/xemu-src/build-uwp-opt
make -j14 qemu-system-i386w.exe
if [ "${2:-}" = nocounter ] && grep -a -q "lowest last min" qemu-system-i386w.exe; then
  echo "THE BUILD STILL HAS THE FPS COUNTER"; exit 1
fi
cp qemu-system-i386w.exe $R/XemuUWP/dist/xemu_${V}_unstripped.exe
XEMU_EXE=$R/xemu-src/build-uwp-opt/qemu-system-i386w.exe $R/XemuUWP/package.sh $V
echo BUILD_OK $V
