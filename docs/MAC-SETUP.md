# Setting up Game Vault from a Mac (BETA)

> ⚠️ **BETA: new and not yet tested on a real Mac.** The Mac setup does the same job as the Windows setup and
> has been tested against an Xbox Series X, but not yet run on a Mac. If something goes wrong, nothing on your
> Mac or your Xbox is erased. You can run it again, or use a Windows PC instead. Please tell us how it went
> (see [Reporting a problem](#reporting-a-problem)).

The setup runs once on your Mac. It sends Game Vault, xemu and the other emulators to your Xbox over your home
network, through the Xbox's own **Device Portal**. You do not need to install anything on the Mac.

---

## What you need

- An **Xbox Series X or Series S** (or Xbox One) that is already in **Developer Mode**.
  See Microsoft's guide: [Xbox Developer Mode activation](https://learn.microsoft.com/windows/uwp/xbox-apps/devkit-activation).
- A **Mac** on the **same home network** as the Xbox (the same Wi-Fi or router).
- About **2 GB of free space** on the Mac for the downloads, and 15-30 minutes. RetroArch alone is close to 600 MB.

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

## Step 2: Download the Mac setup

1. On the Mac, open the release page:
   **[Mac setup (BETA)](https://github.com/skitzellez/xbox-game-vault/releases/tag/mac-setup-beta-1)**
2. Under **Assets**, click **GameVault-Setup-Mac-BETA.zip**.
3. Open your **Downloads** folder in Finder. Safari usually unzips it by itself into a folder named
   **GameVault-Setup**. If you only see the `.zip`, double-click it to unzip it.

Inside the **GameVault-Setup** folder you should see:

- `GameVault-Setup.sh`: the setup itself
- `Install Game Vault (Mac).command`: a double-click starter
- `setup-helper.js`
- a `files` folder

Keep these together in the same folder.

---

## Step 3: Start the setup

There are two ways to start it. **Way A always works**; way B is quicker but macOS may block it.

### Way A: through Terminal (recommended)

1. Open **Terminal**. Press **⌘ Command + Space**, type `Terminal` and press **Return**. Or find it in Finder
   under **Applications → Utilities → Terminal**.
2. In the Terminal window, type `bash` followed by **one space**. Do **not** press Return yet.
3. Drag **GameVault-Setup.sh** from the Finder window into the Terminal window and let go. Its full path appears
   after `bash `, for example:
   ```
   bash /Users/yourname/Downloads/GameVault-Setup/GameVault-Setup.sh
   ```
4. Press **Return**.

### Way B: double-click

1. Double-click **Install Game Vault (Mac).command**. A Terminal window opens and the setup starts.
2. If macOS says it **cannot be opened** or **could not be verified**, click **Done** (not *Move to Trash*).
   Then open **System Settings → Privacy & Security**, scroll down, click **Open Anyway** next to
   *"Install Game Vault (Mac).command" was blocked*, and confirm. Or simply use way A instead.

---

## Step 4: Answer the setup's questions

The setup asks a few questions in the Terminal window. Type the answer and press **Return**.

1. **Console address:** the address from step 1, e.g. `192.168.0.25`.
2. **Device Portal user name:** the user name you set in step 1.
3. **Device Portal password:** the password you set in step 1. **Nothing appears while you type it.**
   That is normal on a Mac. Type it and press Return.

> **macOS may ask: "Terminal would like to find and connect to devices on your local network."**
> Click **Allow**. Without it the Mac cannot reach the Xbox.

If it worked, you see **Connected: Xbox Series X** (or your model) in green.

4. The setup lists what it will install or update, with sizes. It asks
   **Download and install these now? [Y/n]**. Press **Return** (or type `y`) to go ahead.
5. Each app is downloaded and then sent to the Xbox. Large ones (RetroArch) take a few minutes each. Leave the
   Terminal window open and the Xbox on.
6. **BIOS files.** The setup asks for a folder or drive with BIOS files from consoles you own. These are only
   needed for PlayStation 2, Saturn and Sega CD. PlayStation and the original Xbox get free replacements.
   - **No BIOS files?** Just press **Return** to skip.
   - **Have some?** Drag their folder or USB drive from Finder into the Terminal window and press **Return**.
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

## Updating later

Run the Mac setup again the same way (step 3). It only downloads what has a newer version and leaves your saves
and settings alone. Game Vault itself also shows an **RT Update** badge when a new version is out, which you can
install with your phone (see the main README).

---

## Troubleshooting

| What you see | What to do |
|---|---|
| **Could not reach the console's Device Portal** | Check that the Xbox is on and in Dev Home, the address is right (numbers only), Device Portal is ticked, and the user name and password match. The Mac and Xbox must be on the same network: not a guest Wi-Fi, not a VPN. |
| It still cannot reach the Xbox | **System Settings → Privacy & Security → Local Network**: turn **Terminal** on, then run the setup again. |
| **"cannot be opened" / "could not be verified"** | Use way A (Terminal) in step 3, or **Open Anyway** as described in way B. |
| **Permission denied** when starting | Use way A: typing `bash` in front starts it whatever the file's settings are. |
| **cannot be checked: ... GitHub may be limiting requests** | GitHub allows only a few checks per hour from one address. Wait an hour and run it again. |
| **setup-helper.js is missing** | Unzip the whole download and keep all files in the same folder. Don't move `GameVault-Setup.sh` out on its own. |
| An app shows **FAILED** | Run the setup again. It retries only what is missing. If it fails again, report it (below). |
| Xbox One: **needs an NTFS drive with read access for apps** | A Mac cannot set that up. Prepare that USB drive once on a Windows PC (see the main README). On a Series X\|S this is not needed. |

---

## Reporting a problem

Because this is a beta, every report helps. Please open an issue at
[github.com/skitzellez/xbox-game-vault/issues](https://github.com/skitzellez/xbox-game-vault/issues) with:

- your **Mac model** and **macOS version** ( → **About This Mac**),
- your **Xbox model**,
- the **text from the Terminal window**. Select it all with **⌘ Command + A**, copy with **⌘ Command + C** and
  paste it into the issue. Your password is never shown there.

Nothing is sent anywhere by the setup itself except to your own Xbox and to GitHub for the downloads.
