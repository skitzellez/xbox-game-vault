#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Build xemu and package it: build.sh <version>. Run from Windows with
#   C:\msys64\usr\bin\env.exe -i MSYSTEM=UCRT64 HOME=/home/<you> SYSTEMROOT=C:\Windows TAR_OPTIONS=--force-local
#     PATH=/usr/bin C:\msys64\usr\bin\bash.exe -lc "<this folder>/build.sh 0.3.3.0"
# Stops when make fails, so an old exe is never repackaged under a new version.
set -e
V=${1:?version}
R=${GAMEVAULT_ROOT:?set GAMEVAULT_ROOT}   # the folder holding xemu-src, XemuUWP and sdl3-uwp-pc
export PKG_CONFIG_PATH=$R/sdl3-uwp-pc:$PKG_CONFIG_PATH
cd $R/xemu-src/build-uwp-opt
make -j14 qemu-system-i386w.exe
cp qemu-system-i386w.exe $R/XemuUWP/dist/xemu_${V}_unstripped.exe
XEMU_EXE=$R/xemu-src/build-uwp-opt/qemu-system-i386w.exe $R/XemuUWP/package.sh $V
echo BUILD_OK $V
