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

out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "GameVault-Setup.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name, executable in FILES:
        data = open(os.path.join(here, name), "rb").read()
        if name.endswith(MAC):
            data = data.replace(b"\r\n", b"\n")
        info = zipfile.ZipInfo("GameVault-Setup/" + name, date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3                                  # Unix, so the mode below counts
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)
print("wrote", out)
