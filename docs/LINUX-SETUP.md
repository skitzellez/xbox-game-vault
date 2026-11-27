# Setting up Game Vault from Linux

The Linux setup does the same job as the Windows and Mac setups. It runs on your Linux PC and sends Game Vault, xemu
and the other emulators to your Xbox over your home network, through the Xbox's own **Device Portal**. It also includes
a helper to share a games folder from your Linux PC with your Xbox over Samba (for network games and save sync).

---

## What you need

- An **Xbox Series X or Series S** (or Xbox One) that is already in **Developer Mode**.
  See Microsoft's guide: [Xbox Developer Mode activation](https://learn.microsoft.com/windows/uwp/xbox-apps/devkit-activation).
- A **Linux PC** on the **same home network** as the Xbox (the same Wi-Fi or router), with `bash`, `curl` and
  `python3` (or `node`), which come pre-installed on almost all desktop Linux distributions.
- About **2 GB of free space** on the PC for the downloads, and 15-30 minutes. RetroArch alone is close to 600 MB.

---

## Step 1: Turn on Device Portal on the Xbox

1. Start the Xbox in Developer Mode. **Dev Home** opens.
2. In Dev Home, open **Remote Access Settings**. On some versions this is under **Home → Remote Access**.
3. Tick **Enable Xbox Device Portal**.
4. Under **Authentication**, set a **user name** and **password**. Write them down, because the setup asks for them.
5. Note the Xbox's **address**. Dev Home shows it at the top left, for example `192.168.0.25`. You only need
   the numbers, not `https://` or `:11443`.
6. Make sure a **profile is signed in** on the Xbox.

Leave the Xbox on, in Dev Home.

---

## Step 2: Download the setup

1. Download **GameVault-Setup.zip** from the [latest release](https://github.com/skitzellez/xbox-game-vault/releases/latest)
   and unzip it into a folder.

Inside the **Game Vault Setup** folder you will see:

- `Install Game Vault (Linux).sh`: starts the setup
- `Share Games With Xbox (Linux).sh`: shares a games folder on your Linux PC with your Xbox
- a **Setup Files** folder with everything the starters use (`GameVault-Setup.sh`, `Share-Games-With-Xbox.sh`,
  `setup-helper.js` and a `files` folder)

The Windows and Mac starters are there too; you can ignore them. Keep everything together and don't move files out
of **Setup Files**.

---

## Step 3: Start the setup

### Way A: through a terminal (recommended)

1. Open your terminal app in the unzipped **Game Vault Setup** folder (or right-click inside the folder and choose
   **Open in Terminal**).
2. Run:
   ```bash
   bash "./Install Game Vault (Linux).sh"
   ```

### Way B: double-click

1. Double-click **Install Game Vault (Linux).sh** (if your file manager asks whether to display or run it, choose
   **Run in Terminal** or **Execute**). A terminal window opens and the setup starts.

---

## Step 4: Answer the setup's questions

The setup asks a few questions in the terminal window. Type the answer and press **Enter**.

1. **Console address:** the address from step 1, e.g. `192.168.0.25`.
2. **Device Portal user name:** the user name you set in step 1.
3. **Device Portal password:** the password you set in step 1. **Nothing appears while you type it.**
   Type it and press Enter.

If it worked, you see **Connected: Xbox Series X** (or your model) in green.

4. The setup lists what it will install or update, with sizes. It asks
   **Download and install these now? [Y/n]**. Press **Enter** (or type `y`) to go ahead.
5. Each app is downloaded and then sent to the Xbox. Large ones (RetroArch) take a few minutes each. Leave the
   terminal window open and the Xbox on.
6. **BIOS files.** The setup asks for a folder or drive with BIOS files from consoles you own. These are only
   needed for PlayStation 2, Saturn and Sega CD. PlayStation and the original Xbox get free replacements.
   - **No BIOS files?** Just press **Enter** to skip.
   - **Have some?** Type or drag their folder or USB drive from your file manager into the terminal window (or type the
     USB drive's label, e.g. `MYUSB`) and press **Enter**.
     You can also add BIOS files later by putting them in the `Game Vault/bios` folder on your games USB drive.

When it ends you see **Finished. Start Game Vault on the console and plug in your games.** in green.

---

## Step 5: On the Xbox

1. In **Dev Home**, go to **Games and apps**.
2. For **each** new app the setup listed (Game Vault, xemu, RetroArch, XBSX2, and the rest): highlight it, press
   the **Menu** button (☰), choose **View details**, and set **App type** to **Game**.
   This matters: as an *App*, the Xbox gives it too little memory to emulate anything.
   If it already says *Game*, there is nothing to do.
3. Put your games on **any USB drive** (FAT32, exFAT or NTFS, any folders and file names) and plug it into the
   Xbox.
4. Start **Game Vault**. Your games show up with their box art. Press **A** to play.

---

## Optional: Share games from your Linux PC over the network (and Save Sync)

Instead of (or as well as) a USB drive, you can share a games folder directly from your Linux PC over your home
network, and keep your saves synced with `Game Vault saves` (see [docs/SAVE-SYNC.md](SAVE-SYNC.md)):

1. Run:
   ```bash
   bash "./Share Games With Xbox (Linux).sh"
   ```
   (or double-click **Share Games With Xbox (Linux).sh**).
2. Choose the folder that holds your games.
3. The script asks for administrator (`sudo`) permission once. If **Samba** is not installed yet, it offers to install
   it through your distro's package manager (`apt`, `dnf`, `pacman`, or `zypper`).
4. Choose a password (8 characters or more) for the dedicated `xboxgames` account. Your own Linux account and password
   are never used; `xboxgames` is a restricted system account hidden from the login screen that can only read your
   games folder and write to `Game Vault saves`.
5. If `ufw` or `firewalld` is active, the script offers to open the Samba port so the Xbox can reach the share.
6. On the Xbox, press **LT** in Game Vault and enter the computer address (`\\<ip>\XboxGames`), user name (`xboxgames`)
   and password shown in the terminal.

If the games folder is on a drive without Linux permissions (exFAT or NTFS), the share is read-only: network games
work, but Save Sync needs the folder on a Linux drive (ext4) or on the PC's own disk.

---

## Updating later

Run `bash "./Install Game Vault (Linux).sh"` again. It only downloads what has a newer version and leaves your saves and settings
alone. Game Vault itself also shows an **RT Update** badge when a new version is out, which you can install with your
phone (see the main README).

---

## Troubleshooting

| What you see | What to do |
|---|---|
| **Could not reach the console's Device Portal** | Check that the Xbox is on and in Dev Home, the address is right (numbers only), Device Portal is ticked, and the user name and password match. Your Linux PC and Xbox must be on the same network: not a guest Wi-Fi, not a VPN. |
| **curl is not installed** | Install `curl` with your package manager (`sudo apt install curl`, `sudo dnf install curl`, or `sudo pacman -S curl`) and run the setup again. |
| **cannot be checked: ... GitHub may be limiting requests** | GitHub allows only a few checks per hour from one address. Wait an hour and run it again. |
| An app shows **FAILED** | Run the setup again. It retries only what is missing. |
| Xbox cannot connect to the `XboxGames` network share | Check that your firewall allows Samba (`sudo ufw allow Samba` or `sudo firewall-cmd --permanent --add-service=samba && sudo firewall-cmd --reload`) and that `smbd` (`smb` on Fedora/Arch) is running. |
| Save Sync does not save to a shared exFAT or NTFS drive | Those drives have no Linux permissions, so the share is read-only to keep your games safe. Put the games folder on an ext4 drive or on the PC's own disk, and run `Share Games With Xbox (Linux).sh` again. |
| Xbox One: **needs an NTFS drive with read access for apps** | Linux cannot set the Windows `ALL APPLICATION PACKAGES` NTFS security descriptor. Prepare that USB drive once on a Windows PC (see the main README). On a Series X\|S this is not needed. |
