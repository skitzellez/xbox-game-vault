# Game Vault: details for developers and testers

The front page ([README.md](../README.md)) is the short version. This page has the manual install, the
status of each part, what was learned about UWP on the Xbox, and how to build everything.

## What it does

1. You put your game files on a USB drive, in any folders, with any names, and plug it into the console.
2. Game Vault scans the drive (a progress screen shows it is working), reads each file to find out which
   system it belongs to, and shows a grid with box art.
3. **A** starts the game in the emulator that suits it best; **X** shows details (system, format, which
   emulator it plays in, and what that emulator still needs from you, such as a BIOS).
4. Quitting the emulator brings you back to Game Vault (for the emulators that support a return link).

Game Vault does not emulate anything itself. It starts emulators that are installed next to it:

| System | Emulator it starts |
| --- | --- |
| Original Xbox | xemu (our Dev Mode build, see below) |
| PlayStation, Game Boy / Color / Advance, NES, SNES, N64, DS, Genesis, Saturn, Sega CD and other cartridge and CD systems, ScummVM | RetroArch (XboxEmulationHub build) |
| GameCube, Wii | Dolphin for UWP |
| PlayStation 2 | XBSX2 |
| PSP | PPSSPP |
| Dreamcast | Flycast |

## Setup

### The easy way: all-in-one setup from a Windows PC

1. Put the console in **Dev Mode**, and in Dev Home turn on the **Device Portal** with a user name and
   password (Remote Access Settings). Sign a profile in.
2. On a Windows PC on the same network, download **GameVault-Setup.zip** from the
   [releases page](https://github.com/skitzellez/xbox-game-vault/releases), unzip it and double-click
   **Install Game Vault.bat**.
3. Type the console's address, user name and password when asked. The setup then:
   - installs or updates **Game Vault** and **xemu**, and the emulators Game Vault starts (RetroArch, Dolphin,
     XBSX2, PPSSPP, Flycast), each downloaded from its own project's release page;
   - installs the free PlayStation BIOS (OpenBIOS), so PlayStation games need nothing from you;
   - asks for a folder or drive with **BIOS files of your own** (PlayStation 2, Saturn, Sega CD, original
     Xbox ...) and puts each one where its emulator looks. They are found by the usual file names
     (`sega_101.bin`, `bios_CD_U.bin`, a 4 MB `scph*.bin` for PS2, and so on);
   - tells Game Vault what it installed. Where a BIOS is missing, Game Vault starts the game in an emulator
     that needs none if there is one (Saturn, PlayStation: fewer games work that way), or tells you what to
     add (PS2, Sega CD).
4. Do the two things it prints at the end: set each app's **App type** to **Game** in Dev Home (that cannot
   be done from a PC), and prepare the games USB drive (step 3 below).
5. Start Game Vault and plug the drive in. Original Xbox games just start (step 4 below).

Run the setup again at any time: it only installs what is new, and it is also how to add BIOS files later.
It downloads no games and no console BIOS files. The source is `installer/GameVault-Setup.ps1`.

### By hand

The steps below are what the setup does for you, and what the console needs.

Ready-made packages are on the release pages: **[Game Vault](https://github.com/skitzellez/xbox-game-vault/releases)**
and **[xemu for Dev Mode](https://github.com/skitzellez/xemu-uwp/releases)**. They are early test builds.
You can also build both yourself (see "Building").

### 1. The console

1. Put the Xbox Series X|S in **Dev Mode** (the "Xbox Dev Mode" app from the Store and a Microsoft Partner
   Center developer account).
2. In Dev Home, turn on the **Device Portal** and set a user name and password. Note the console's address;
   the portal is at `https://<address>:11443`.
3. Sign a profile in on the console. Without one, apps refuse to start (error 0x8004090a).

### 2. Install the apps

In the Device Portal ("Add" on the home page), or with `XemuUWP/tools/xb.py install <file>`:

1. `GameVault_x64.appx`. If the console reports a missing framework, add `Microsoft.VCLibs.x64.14.00.appx`
   as a dependency (it comes with the Windows SDK and with most UWP emulator downloads; consoles that
   already have a UWP emulator installed usually have it).
2. `Xemu_x64.appx` if you want original Xbox games.
3. The emulators you want Game Vault to start: RetroArch (the XboxEmulationHub UWP build), Dolphin for UWP,
   XBSX2, PPSSPP, Flycast. Get them from their own projects.
4. In Dev Home, open each app's details and set **App type** to **Game**. As "App" they get too little memory
   (xemu will not run games; Game Vault unpacks archives on one thread).

### 3. The USB drive

Any USB drive works as it is: FAT32, exFAT or NTFS. Game Vault, xemu, and our builds of RetroArch and XBSX2
("RetroArch for Game Vault", "XBSX2 for Game Vault") open files through the file broker, which honours the
file system permission every Dev Mode app is given. The original RetroArch and XBSX2 builds and the other
emulators cannot; with those, the drive has to be NTFS and readable by app packages. On a PC, with the drive
as `X:` (formatting erases it):

```
format X: /FS:NTFS /Q
icacls X:\ /grant "*S-1-15-2-1:(OI)(CI)F"
```

Then copy your games on. Folders up to six levels deep are searched. Extras:
- A cue sheet next to each PlayStation / Saturn / Sega CD `.bin`.
- ScummVM games as folders inside a folder named `ScummVM`.
- Xbox games may stay packed as `.7z` or `.rar`; they are unpacked to the console's storage on first play.

### 4. Original Xbox: nothing to set up

Start an Xbox game in Game Vault. That is all.

- The first time, Game Vault spends a few seconds looking on your drives for your own Xbox **boot ROM**
  (MCPX 1.0, a 512-byte file) and **BIOS** (a 256 KB, 512 KB or 1 MB `.bin`). If it finds them, it sets them
  up without asking. The boot ROM is recognised by its contents, whatever it is called; a BIOS is easiest to
  find in a folder named `Xbox` or with "xbox" or "bios" in its name.
- If it finds none, the game starts with the **free SpiritBoot BIOS** that comes with xemu. Games play
  offline. Online play (Insignia) needs your own files from an Xbox you own; they are copyrighted and are
  not included ([what they are](https://xemu.app/docs/required-files/)).
- Add your own files later by just putting them on the USB drive: the next Xbox game finds them.
- The hard disk: a `.qcow2` image of yours on the drive is copied; otherwise xemu makes a blank one by
  itself (the xemu project's copyright-free image). The free BIOS and your own BIOS each get their own hard
  disk, because their saves cannot read each other. An installed hard disk is never replaced.
- A game's details (**X**) say which BIOS it plays with; **Y** there opens the setup screen to choose another
  BIOS file.

Advanced: an `xemu.toml` of your own in xemu's `LocalState\xemu\xemu` folder still wins wherever the file
it names exists (`flashrom_path = 'spiritboot'` picks the free BIOS); in the setup screen press **X** ("I set
xemu up myself") and Game Vault stops looking.

Other emulators need their own BIOS files in their own folders; Game Vault's details screen says which.

### 5. Play

Start Game Vault, plug the drive in, wait for the scan, pick a game.

## Status

### Game Vault (0.14.22.0)

Seen working on the console:
- USB scan with a progress screen, box art, grid and details screen, controller input.
- **Copy a disc in the console's drive to the USB drive** (View button). Apps in Dev Mode are refused every file
  and volume route to the disc drive; what works is opening the drive's device interface through
  `Windows.Devices.Custom` (the package declares the CD-ROM interface class as a DeviceCapability) and reading
  sectors with SCSI READ(10) through `IOCTL_SCSI_PASS_THROUGH` (`GameVault/src/disccopy.cpp`). Done once with a
  PlayStation 2 DVD: 898 MB in 4 min 41 s, and the copy plays. PlayStation 1 discs are refused for now (they
  need raw 2352-byte sectors); original Xbox discs have not been tried. The probe that found this route is in
  `XboxProbe/`.
- ScummVM games: the PC setup installs ScummVM's engine data, so they start without extra steps.
- PlayStation and Game Boy Advance through RetroArch; original Xbox through our xemu build, including full
  disc dumps and images inside `.7z` / `.rar` (unpacked once, on first play, then kept).
- Systems are told apart by content, not by file name: PS1 / PS2 (SYSTEM.CNF), PSP, Saturn, Sega CD,
  Dreamcast, GameCube / Wii (ISO, GCM, CISO, GCZ, WIA, RVZ, NKit, WBFS), Xbox (XISO and full dumps), and the
  same checks inside `.chd` (own CHD v5 reader in `src/chd.cpp`).
- Cartridge ROMs inside `.zip` / `.7z` (handed to RetroArch as they are), ScummVM game folders.
- 4K: asks for the best 60 Hz HDMI mode at start-up.
- Original Xbox games start with no setup: your own boot ROM and BIOS are found on the drive, otherwise
  the free SpiritBoot BIOS is used (offline only). The all-in-one
  setup program for a PC (tested against one console: installs, updates, places BIOS files).
- Picks an emulator that needs no BIOS when the setup reported none (Saturn, PlayStation). The Saturn
  fallback has not been tried with a game.

Written but not tried with a real game: launching Dolphin, XBSX2, PPSSPP and Flycast (the links start each
emulator; no game was played), and most of the cartridge systems added by file extension.

Not done: arcade sets, disc games of non-Xbox systems inside archives, `.zip` with an Xbox image.

Known defects (from a code review): a failed download can leave a partial file that is then trusted as cache;
old scan threads are detached rather than stopped.

### xemu on the console

Version 0.9.30.0. Retail games boot and play with sound and the controller, many at full speed; heavy scenes
can still drop below it. Quick save states, quit from the controller, no settings file, a free BIOS when you
have none, and a smooth start-up animation. Results are not listed per game.

See [README-UWP.md](https://github.com/skitzellez/xemu-uwp/blob/uwp/README-UWP.md) in the `xemu-uwp` fork for
the controls, what works, what was changed, the performance findings and the open problems.

## Things we learned about UWP on the Xbox that may save you time

- `VirtualAlloc` will not give executable memory; `VirtualAllocFromApp` + `VirtualProtectFromApp` will (with
  the `codeGeneration` capability). A JIT can run.
- No Win32 windows (`RegisterClassExW` / `CreateWindowExW` fail). Everything goes through a CoreWindow.
- A MinGW-built exe runs in the AppContainer after `editbin /APPCONTAINER`.
- Of the 779 functions desktop xemu imports, 775 exist on the console (`XboxProbe/probe_xemu_uwp.txt`).
- Plain `fopen` cannot read a FAT32 USB stick; the `*FromApp` file functions can. Emulator cores that use
  `fopen` need the stick to be NTFS with full control granted to ALL APPLICATION PACKAGES.
- `GetLogicalDrives` is safe on the UI thread; probing drive roots there can hang for good.
- App type "App" gets very little memory (about 145 MB for xemu, 1 GB for the launcher); "Game" gets several GB.
- OpenGL works through Mesa on D3D12 (use the 26.2.2 UWP build; `dxil.dll` must be in the package).
- SDL: set `SDL_HINT_JOYSTICK_WGI=1` or no controller appears. `patches/sdl3-uwp.patch` holds our fixes on
  top of XboxEmulationHub/SDL3-uwp `uwp-3.4.16` (OpenGL and library loading for Windows Store builds, launch
  links, 4K detection on Series X: an HRESULT was tested as a BOOL). SDL does not accept AI-written
  contributions, so the patch stays here and is not offered upstream.
- The Device Portal REST API can install, start, stop, screenshot and fetch files and crash dumps
  (`XemuUWP/tools/xb.py`).

## Building

Windows 11, Visual Studio 2022 Build Tools with the UWP workload, Windows SDK 10.0.26100.

Game Vault: its source code is not published (from version 0.15.14 on); the app comes from the releases.

xemu: build the `uwp` branch as described in its `README-UWP.md`, then `XemuUWP/package.sh <version>`. The
scripts contain paths from the author's PC (`C:\Users\GamerDad\XboxEmu`, `C:\msys64`); adjust them.

The emulator builds' complete source is public: [xemu-uwp](https://github.com/skitzellez/xemu-uwp) (branch
`uwp`), [RetroArch-GameVault](https://github.com/skitzellez/RetroArch-GameVault) and
[XBSX2-GameVault](https://github.com/skitzellez/XBSX2-GameVault) (branch `gamevault`), plus the build and
packaging scripts in `XemuUWP/`.

## Third-party pieces and credits

- [xemu](https://xemu.app) and QEMU (GPL-2.0).
- [XboxEmulationHub](https://github.com/XboxEmulationHub): SDL3-uwp, mesa-uwp and the RetroArch build this relies on.
- LZMA SDK (public domain), UnRAR (freeware licence: may be used to extract, not to build a RAR compressor).
- Title data from GameTDB, box art from the libretro thumbnail server (fetched at run time).
- Launch link format for standalone emulators as used by the RetroPass frontend.

## Licence

**Game Vault and everything in this repository: Copyright (c) 2026 Skitzelles**, under the PolyForm
Noncommercial License 1.0.0 (`LICENSE`). In plain words:

- You may use it, change it and share it, for free, for noncommercial purposes.
- You may **not** sell it or use it commercially.
- Every copy, changed or not, must keep the line
  `Required Notice: Copyright (c) 2026 Skitzelles (https://github.com/skitzellez/xbox-game-vault)`.
  Do not remove the credit or present the work as your own.

The xemu fork is different: xemu is GPL version 2, so our changes to it are GPL version 2 as well. That
licence requires copyright notices to be kept and changed versions to be marked as changed, but it does not
forbid selling. UnRAR and the LZMA SDK keep their own terms and are not included here.
