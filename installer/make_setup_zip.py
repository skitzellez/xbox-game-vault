# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Builds GameVault-Setup.zip (Windows, Mac and Linux setup) from this folder:  python make_setup_zip.py <out.zip>
# The Mac and Linux files get plain line endings and the "executable" mark, so they run after unzipping.
import os
import sys
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
FILES = [
    ("Install Game Vault.bat", False),
    ("GameVault-Setup.ps1", False),
    ("Share games with Xbox.bat", False),
    ("Share-Games-With-Xbox.ps1", False),
    ("Install Game Vault (Mac).command", True),
    ("Install Game Vault (Linux).sh", True),
    ("GameVault-Setup.sh", True),
    ("Share-Games-With-Xbox.sh", True),
    ("Share games with Xbox (Linux).sh", True),
    ("setup-helper.js", False),
    ("files/openbios.bin", False),
    ("files/SwanStation.opt", False),
    ("files/OpenBIOS-copyright.txt", False),
]
UNIX = (".sh", ".command", ".js")
LINUX_ONLY = ("Install Game Vault (Linux).sh", "Share-Games-With-Xbox.sh", "Share games with Xbox (Linux).sh")
# What the player sees after unzipping: only the starters on top, everything they never touch in "Setup Files"
# (the scripts find their files next to themselves, so nothing else changes).
ROOT = "Game Vault Setup/"
STARTERS = {"Install Game Vault.bat": "Install Game Vault.bat",
            "Install Game Vault (Mac).command": "Install Game Vault (Mac).command",
            "Share games with Xbox.bat": "Share Games With Xbox.bat",
            "Install Game Vault (Linux).sh": "Install Game Vault (Linux).sh",
            "Share games with Xbox (Linux).sh": "Share Games With Xbox (Linux).sh"}


def zip_name(name):
    return STARTERS.get(name) or "Setup Files/" + name


# --mac: the Mac setup alone (the beta download), with a short note on top
MAC_NOTE = (
    "Game Vault setup for Mac - BETA\n"
    "\n"
    "This is new and not yet tested on a real Mac. Nothing on your Mac or Xbox is erased if it goes wrong.\n"
    "\n"
    "Step-by-step guide: https://github.com/skitzellez/xbox-game-vault/blob/main/docs/MAC-SETUP.md\n"
    "\n"
    "Short version: open Terminal, type  bash  and a space, drag GameVault-Setup.sh from the Setup Files folder into the\n"
    "Terminal window, press Return, and answer the questions.\n"
    "\n"
    "Problems: https://github.com/skitzellez/xbox-game-vault/issues\n"
)
# --linux: the Linux setup alone, with a short note on top
LINUX_NOTE = (
    "Game Vault setup for Linux\n"
    "\n"
    "Step-by-step guide: https://github.com/skitzellez/xbox-game-vault/blob/main/docs/LINUX-SETUP.md\n"
    "\n"
    "Short version: open a terminal in this folder and run:\n"
    "   bash \"./Install Game Vault (Linux).sh\"\n"
    "\n"
    "To share a games folder on this Linux PC with your Xbox (for network games and save sync):\n"
    "   bash \"./Share Games With Xbox (Linux).sh\"\n"
    "\n"
    "Problems: https://github.com/skitzellez/xbox-game-vault/issues\n"
)

args = [a for a in sys.argv[1:] if a not in ("--mac", "--linux")]
mac_only = "--mac" in sys.argv[1:]
linux_only = "--linux" in sys.argv[1:]
default_name = "GameVault-Setup-Mac-BETA.zip" if mac_only else ("GameVault-Setup-Linux.zip" if linux_only else "GameVault-Setup.zip")
out = args[0] if args else os.path.join(here, default_name)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    if mac_only:
        info = zipfile.ZipInfo(ROOT + "READ ME FIRST (BETA).txt", date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, MAC_NOTE)
    elif linux_only:
        info = zipfile.ZipInfo(ROOT + "READ ME FIRST.txt", date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        info.external_attr = 0o100644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, LINUX_NOTE)
    for name, executable in FILES:
        if mac_only and (name.endswith((".bat", ".ps1")) or name in LINUX_ONLY):
            continue
        if linux_only and name.endswith((".bat", ".ps1", ".command")):
            continue
        with open(os.path.join(here, name), "rb") as f:
            data = f.read()
        if name.endswith(UNIX):
            data = data.replace(b"\r\n", b"\n")
        info = zipfile.ZipInfo(ROOT + zip_name(name), date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3                                  # Unix, so the mode below counts
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)
print("wrote", out)
