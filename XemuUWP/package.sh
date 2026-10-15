#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Builds dist/Xemu_x64.appx from build-uwp/qemu-system-i386w.exe: copies the exe as xemu.exe, every MinGW (UCRT64)
# DLL it needs, SDL3.dll (UWP) and Mesa's OpenGL DLLs, marks the exe AppContainer, then packs and signs.
set -e
V=${1:-0.1.0.0}
D=/c/Users/GamerDad/XboxEmu/XemuUWP; SRC=${XEMU_EXE:-/c/Users/GamerDad/XboxEmu/xemu-src/build-uwp/qemu-system-i386w.exe}
cd $D
find pkg -maxdepth 1 -name "*.dll" -delete; rm -f pkg/xemu.exe
cp $SRC pkg/xemu.exe
# function names for readable crash reports (ui/xemu.c, uwp_where): "<rva> <name>" for every function, sorted
BASE=$(/c/msys64/ucrt64/bin/objdump.exe -p "$SRC" | sed -n 's/^ImageBase\s*//p')
/c/msys64/ucrt64/bin/nm.exe --defined-only "$SRC" |
  awk -v base=$((16#$BASE)) '$2 ~ /^[tT]$/ { printf "%08x %s\n", strtonum("0x" $1) - base, substr($3, 1, 120) }' |
  sort -k1,1 > pkg/xemu.sym
/c/msys64/ucrt64/bin/strip.exe pkg/xemu.exe
# recursively copy DLL dependencies that live in /ucrt64/bin
todo=(pkg/xemu.exe); seen=" "
while [ ${#todo[@]} -gt 0 ]; do
  f=${todo[0]}; todo=("${todo[@]:1}")
  for dll in $(/c/msys64/ucrt64/bin/objdump.exe -p "$f" | sed -n 's/^\s*DLL Name: //p'); do
    lc=$(echo "$dll" | tr 'A-Z' 'a-z'); case "$seen" in *" $lc "*) continue;; esac; seen="$seen$lc "
    if [ -f "/c/msys64/ucrt64/bin/$dll" ]; then cp "/c/msys64/ucrt64/bin/$dll" pkg/; todo+=("pkg/$dll"); fi
  done
done
cp ../sdl3-uwp/build-uwp/RelWithDebInfo/SDL3.dll ../deps/mesa-26/x/bin/{opengl32,libgallium_wgl,z-1}.dll ../deps/ra_mesa/dxil.dll pkg/
cp xemu.toml pkg/xemu.default.toml
# free BIOS used when the player has none of their own (GPL-2.0, unmodified release files + licence + source note)
rm -rf pkg/spiritboot; mkdir -p pkg/spiritboot
for f in SpiritBoot-v1.0.0-64MB.bin SpiritBoot-v1.0.0-128MB.bin; do
  [ -f spiritboot/$f ] || curl -sfL -o spiritboot/$f https://github.com/Mainkill1/SpiritBoot/releases/download/v1.0.0/$f
done
(cd spiritboot && grep -E '(64MB|128MB)\.bin$' SHA256SUMS.txt | grep -v game-memory | sha256sum -c --quiet)
# blank hard disk xemu copies when the player has none (xemu project's copyright-free image, release 1.0)
if [ ! -f blank-hdd/xbox_hdd_blank.qcow2 ]; then
  mkdir -p blank-hdd
  curl -sfL -o blank-hdd/xbox_hdd.qcow2.zip https://github.com/xemu-project/xemu-hdd-image/releases/download/1.0/xbox_hdd.qcow2.zip
  bsdtar -xOf blank-hdd/xbox_hdd.qcow2.zip xbox_hdd.qcow2 > blank-hdd/xbox_hdd_blank.qcow2
  rm blank-hdd/xbox_hdd.qcow2.zip
fi
echo "eb35d069715dfc0d37cfac086a0b73a89a02e8f12519cd8eda82ad479d1a4eed  blank-hdd/xbox_hdd_blank.qcow2" | sha256sum -c --quiet
cp blank-hdd/xbox_hdd_blank.qcow2 pkg/
cp spiritboot/SpiritBoot-v1.0.0-64MB.bin spiritboot/SpiritBoot-v1.0.0-128MB.bin spiritboot/LICENSE spiritboot/README.txt spiritboot/SHA256SUMS.txt pkg/spiritboot/
EB=$(ls -d "/c/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/"*/bin/Hostx64/x64)
"$EB/editbin.exe" //nologo //APPCONTAINER pkg/xemu.exe
sed -i "s/ Version=\"[0-9.]*\" ProcessorArchitecture/ Version=\"$V\" ProcessorArchitecture/" pkg/AppxManifest.xml
SDK="/c/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64"
mkdir -p dist; rm -f dist/Xemu_x64.appx
"$SDK/makeappx.exe" pack //o //d pkg //p dist/Xemu_x64.appx >/dev/null
# signing: your own certificate at GameVault/cert/GameVault.pfx, its password in PFX_PASSWORD
PFX_PASSWORD=${PFX_PASSWORD:?set PFX_PASSWORD to your signing certificate\'s password}
"$SDK/signtool.exe" sign //fd SHA256 //a //f ../GameVault/cert/GameVault.pfx //p "$PFX_PASSWORD" dist/Xemu_x64.appx >/dev/null
ls pkg/*.dll | wc -l; ls -la dist/Xemu_x64.appx
