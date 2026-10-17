# Save sync: the same saves on your Xbox, your PC and your handheld

Game Vault can keep your saves and memory cards the same as a folder on your PC (or NAS). From there, a free app
called **Syncthing** keeps that folder the same on an Android handheld or phone. Play on the Xbox, pick up on the
handheld, and the other way round.

## What is synced

| On the Xbox (in `Game Vault` on your games drive) | Used by | Same files on Android |
|---|---|---|
| `memory cards` | XBSX2 for Game Vault (PlayStation 2) | ARMSX2, AetherSX2 and other PCSX2-based apps (`.ps2` memory cards) |
| `saves` | RetroArch for Game Vault (older systems) | RetroArch (`.srm` and other save files) |

Only **in-game saves and memory cards** travel. **Save states** do not: they belong to one emulator build and can
break in another, so they stay on each device.

GameCube and Wii saves are not synced yet (Dolphin for Game Vault keeps them in its own app folder).

## How it decides

Game Vault syncs when it opens, after every game, and when you switch it on.

- A save changed on one side only: the newer copy goes to the other side.
- A save changed on **both** sides since the last sync (you played offline on both): the newer one is kept, and the
  other is **not lost**. It goes to `Game Vault\older saves` on the Xbox, or `Game Vault saves\.older` on the PC.
- Nothing is ever deleted. A save deleted on one side comes back from the other.

## Set it up

### 1. Share a folder from your PC (once)

Run **Share games with Xbox** from `GameVault-Setup.zip` on your PC (you may already have done this for network
games). It makes a `Game Vault saves` folder inside the shared folder; that is the only place the Xbox may write.
Your games stay read-only.

Already set up from an older version? Run it again and pick the same folder. When it asks for a password,
**press Enter**: the password stays the same and there is nothing to type on the Xbox.

### 2. Switch it on in Game Vault

Menu button → **Options** → **Save sync** → pick your PC with ◀ ▶. Game Vault syncs at once and shows
"Saves synced."

### 3. Your handheld (Android)

1. Install **Syncthing** on the PC and the handheld (free; on Android it may be called *Syncthing-Fork*).
2. On the PC, add the folder `Game Vault saves\memory cards` (and `Game Vault saves\saves` for RetroArch) to
   Syncthing, and share it with the handheld.
3. On the handheld, accept each folder and point it at the emulator's own folder:
   - PCSX2-based apps (ARMSX2 ...): the **memory card folder** shown in the app's settings.
   - RetroArch: the **save files** folder (Settings → Directory → Save Files).
4. Use the same memory card file names on both: the Xbox uses `Mcd001.ps2` and `Mcd002.ps2` by default.

Play on one device at a time and give it a moment to sync before switching. If you do play the same game on both
before they sync, nothing is lost: see "How it decides".

## If something goes wrong

- **"The shared folder does not let Game Vault save there"**: run Share games with Xbox on the PC again (step 1).
- **A save looks old**: the copy that was not kept is in `Game Vault\older saves` (Xbox) or
  `Game Vault saves\.older` (PC). Copy it back with any file manager.
- Problem reports (Options) include a line about every sync, so a report shows what happened.
