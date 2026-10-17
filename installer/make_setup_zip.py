# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Builds GameVault-Setup.zip (Windows and Mac setup) from this folder:  python make_setup_zip.py <out.zip>
# The Mac files get plain line endings and the "executable" mark, so they run after unzipping on a Mac.
import os
import sys
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
FILES = [
    ("Install Game Vault.bat", False),
    ("GameVault-Setup.ps1", False),
    ("Install Game Vault (Mac).command", True),
    ("GameVault-Setup.sh", True),
    ("setup-helper.js", False),
    ("files/openbios.bin", False),
    ("files/SwanStation.opt", False),
    ("files/OpenBIOS-copyright.txt", False),
]
MAC = (".sh", ".command", ".js")
# --mac: the Mac setup alone (the beta download), with a short note on top
MAC_NOTE = (
    "Game Vault setup for Mac - BETA\n"
    "\n"
    "This is new and not yet tested on a real Mac. Nothing on your Mac or Xbox is erased if it goes wrong.\n"
    "\n"
    "Step-by-step guide: https://github.com/skitzellez/xbox-game-vault/blob/main/docs/MAC-SETUP.md\n"
    "\n"
    "Short version: open Terminal, type  bash  and a space, drag GameVault-Setup.sh from this folder into the\n"
    "Terminal window, press Return, and answer the questions.\n"
    "\n"
    "Problems: https://github.com/skitzellez/xbox-game-vault/issues\n"
)

args = [a for a in sys.argv[1:] if a != "--mac"]
mac_only = "--mac" in sys.argv[1:]
out = args[0] if args else os.path.join(here, "GameVault-Setup-Mac-BETA.zip" if mac_only else "GameVault-Setup.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    if mac_only:
        info = zipfile.ZipInfo("GameVault-Setup/READ ME FIRST (BETA).txt", date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, MAC_NOTE)
    for name, executable in FILES:
        if mac_only and name.endswith((".bat", ".ps1")):
            continue
        data = open(os.path.join(here, name), "rb").read()
        if name.endswith(MAC):
            data = data.replace(b"\r\n", b"\n")
        info = zipfile.ZipInfo("GameVault-Setup/" + name, date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3                                  # Unix, so the mode below counts
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)
print("wrote", out)
