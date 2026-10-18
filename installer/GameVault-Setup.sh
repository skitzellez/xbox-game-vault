#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Game Vault all-in-one setup for an Xbox Series X|S or Xbox One in Dev Mode, for a Mac that is on the same
# network as the console (double-click "Install Game Vault (Mac).command"). Does the same as the Windows setup
# (GameVault-Setup.ps1); written for the bash 3.2 that comes with macOS, with only the Mac's own tools.
#
# What it does, through the console's Device Portal:
#   1. installs or updates Game Vault and xemu (from their GitHub releases) and the emulators Game Vault starts:
#      RetroArch, Dolphin, XBSX2, PPSSPP, Flycast and (Series X|S) Xenia for Game Vault. On a Series X|S, RetroArch
#      and XBSX2 are our own builds, and what the original RetroArch / XBSX2 apps held is copied over;
#   2. puts the free PlayStation BIOS (OpenBIOS) in place, and any BIOS files of your own that it finds in a
#      folder or drive you point it at;
#   3. tells Game Vault which BIOS files are there, so it can pick the right emulator for each system.
# Nothing copyrighted is downloaded or included: no games and no console BIOS files.
#
# Options (all optional; without them the script asks):
#   --console <address>   --user <name>   --password <password>
#   --bios-folder <path>  a folder or drive to search for your own BIOS files ("none" to skip)
#   --skip <names>        components to leave out, e.g. --skip RetroArch,Dolphin
#   --force <names>       install these again even when the console already has that version
#   --yes                 do not ask for confirmation

Console=""; User=""; Password=""; BiosFolder=""; Skip=""; Force=""; Yes=""
while [ $# -gt 0 ]; do
    case "$1" in
        --console|-Console) Console="$2"; shift ;;
        --user|-User) User="$2"; shift ;;
        --password|-Password) Password="$2"; shift ;;
        --bios-folder|-BiosFolder) BiosFolder="$2"; shift ;;
        --skip|-Skip) Skip="$2"; shift ;;
        --force|-Force) Force="$2"; shift ;;
        --yes|-Yes|-y) Yes=1 ;;
        *) echo "unknown option: $1"; exit 1 ;;
    esac
    shift
done

here="$(cd "$(dirname "$0")" && pwd)"
if [ "$(uname)" = "Darwin" ]; then work="$HOME/Library/Caches/GameVaultSetup"; else work="${XDG_CACHE_HOME:-$HOME/.cache}/GameVaultSetup"; fi
cache="$work/downloads"
mkdir -p "$cache"
jar="$work/portal_cookies.txt"
rm -f "$jar"                         # a stale cookie file makes the console answer 403
login="$work/portal_login.txt"       # the user name and password for curl: in a file only this user can read,
trap 'rm -f "$login"' EXIT           # so they never show in the list of running programs

# colours as in the Windows setup
say()  { local c="0"; case "${2:-}" in Red) c="31";; Green) c="32";; Yellow) c="33";; White) c="1";; DarkGray) c="90";; Cyan) c="36";; esac
         printf '\033[%sm%s\033[0m\n' "$c" "$1"; }
head_() { echo ""; say "== $1" Cyan; }
ask()  { local a; read -r -p "$1" a; printf '%s' "$a"; }

# JSON and text helper (setup-helper.js): the Mac's own JavaScript, else Node.js
helper="$here/setup-helper.js"
if command -v osascript >/dev/null 2>&1; then js() { osascript -l JavaScript "$helper" "$@" 2>/dev/null; }
elif command -v node >/dev/null 2>&1; then js() { node "$helper" "$@" 2>/dev/null; }
else say "This setup needs a Mac (or Node.js on other systems)." Red; exit 1; fi
if [ ! -f "$helper" ]; then say "setup-helper.js is missing: unzip the whole GameVault-Setup.zip and run this again." Red; exit 1; fi

# a file for curl -F, quoted: a comma or semicolon in its name would otherwise cut it up
form_file() { printf '%s=@"%s"' "$1" "$(printf '%s' "$2" | sed 's/[\\"]/\\&/g')"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
in_list() { case ",$(lower "$2")," in *",$(lower "$1"),"*) return 0;; esac; return 1; }   # in_list item "a,b,c"
urlenc() {
    local LC_ALL=C s="$1" o="" c i
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in [a-zA-Z0-9.~_-]) o="$o$c" ;; *) o="$o$(printf '%%%02X' "'$c")" ;; esac
    done
    printf '%s' "$o"
}
b64() { urlenc "$(printf '%s' "$1" | base64 | tr -d '\n')"; }
# a console path like \LocalState\a b -> %5CLocalState%5Ca%20b
enc() {
    local out="" part first=1 parts
    IFS='\' read -r -a parts <<< "$1"
    for part in "${parts[@]}"; do
        if [ $first = 1 ]; then out="$(urlenc "$part")"; first=0; else out="$out%5C$(urlenc "$part")"; fi
    done
    printf '%s' "$out"
}
md5of() { if command -v md5 >/dev/null 2>&1; then md5 -q "$1"; else md5sum "$1" | cut -d' ' -f1; fi; }
sizeof() { wc -c < "$1" | tr -d ' '; }
unpack() {                           # a zip -> the folder it was unpacked into
    local dir="$1.files"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        if command -v ditto >/dev/null 2>&1; then ditto -x -k "$1" "$dir"; else unzip -q -o "$1" -d "$dir"; fi
    fi
    printf '%s' "$dir"
}

say ""
say "Game Vault setup, by Skitzelles" White
say "Installs Game Vault, xemu and the emulators it uses on an Xbox in Dev Mode."
say "No games and no console BIOS files are downloaded or included."

# ---------------------------------------------------------------------------------------------------
head_ "1. The console"
if [ -z "$Console" ]; then
    say "On the Xbox: Dev Home > Remote Access Settings > enable Xbox Device Portal, and set a user name and"
    say "password there. Dev Home shows the console's address at the top left (for example 192.168.0.25)."
    Console="$(ask "Console address: ")"
fi
Console="$(printf '%s' "$Console" | sed -E 's#^https?://##; s#[:/].*$##' | tr -d ' ')"
[ -z "$User" ] && User="$(ask "Device Portal user name: ")"
if [ -z "$Password" ]; then read -r -s -p "Device Portal password: " Password; echo; fi
B="https://$Console:11443"
( umask 077; esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  printf 'user = "%s:%s"\n' "$(esc "$User")" "$(esc "$Password")" > "$login" )

portal() { curl -sk -K "$login" -b "$jar" -c "$jar" "$@"; }
token() {
    portal "$B/api/os/info" -o /dev/null
    [ -f "$jar" ] && awk -F'\t' 'NF >= 7 && $6 == "CSRF-Token" { t = $7 } END { printf "%s", t }' "$jar"
}

rm -f "$work/info.json"; portal -m 15 "$B/api/os/info" -o "$work/info.json"
platform="$(js "$work/info.json" get Platform)"
if [ -z "$platform" ]; then
    say "Could not reach the console's Device Portal at $B." Red
    say "Check: the console is on and in Dev Mode, the address is right, Device Portal is enabled in Dev Home,"
    say "and the user name and password are the ones set there. Then run this again."
    exit 1
fi
say "Connected: $platform \"$(js "$work/info.json" get ComputerName)\"" Green
series=""; case "$platform" in *Series*) series=1 ;; esac

# Dev Home's "treat UWP apps as games by default" (Device Portal setting DefaultUWPContentTypeToGame): apps
# installed after it is on (and the console restarted) start as type Game with full memory.
rm -f "$work/settings.json"; portal -m 15 "$B/ext/settings" -o "$work/settings.json"
gt="$(js "$work/settings.json" setting DefaultUWPContentTypeToGame)"
if [ -n "$gt" ] && [ "$gt" != "true" ]; then
    tok="$(token)"
    portal -m 15 -X PUT -H "X-CSRF-Token: $tok" -H "Content-Type: application/json" --data-binary '{"Value":"true"}' \
        "$B/ext/settings/DefaultUWPContentTypeToGame" -o /dev/null
    say "   new apps will start as type Game (takes effect after the console restarts)" DarkGray
fi

# installed <prefix>: sets P_FULL, P_FAMILY, P_RELID, P_VER of the first package whose name starts with it
installed() {
    P_FULL=""; P_FAMILY=""; P_RELID=""; P_VER=""
    rm -f "$work/packages.json"; portal "$B/api/app/packagemanager/packages" -o "$work/packages.json"
    local line; line="$(js "$work/packages.json" package "$1")"
    [ -z "$line" ] && return 1
    IFS=$'\t' read -r P_FULL P_FAMILY P_RELID P_VER <<EOF
$line
EOF
    return 0
}

# ---------------------------------------------------------------------------------------------------
# Downloads. A finished download leaves a ".ok" file next to it, so an interrupted one is fetched again.
fetch() {                            # fetch <url> <name> -> the file
    local file="$cache/$2"
    if [ -f "$file.ok" ] && [ -f "$file" ]; then printf '%s' "$file"; return 0; fi
    rm -f "$file" "$file.ok"
    say "   downloading $2" >&2
    if ! curl -L --fail --retry 3 -# -o "$file" "$1" || [ ! -f "$file" ]; then return 1; fi
    printf '%s' "$1" > "$file.ok"
    printf '%s' "$file"
}
# Newest release of a GitHub project that has a file matching a pattern: sets S_URL, S_NAME, S_VER, S_SIZE.
releases() { rm -f "$work/releases.json"; curl -sL -m 30 -H "User-Agent: GameVaultSetup" "https://api.github.com/repos/$1/releases?per_page=${2:-5}" -o "$work/releases.json"; }
from_github() {                      # from_github <repo> <pattern> [count]
    releases "$1" "${3:-5}"
    local line; line="$(js "$work/releases.json" release "$2")"
    if [ "$line" = "ERROR" ] || [ ! -s "$work/releases.json" ]; then S_ERR="could not read the release list of $1 (GitHub may be limiting requests; try again in an hour)"; return 1; fi
    if [ -z "$line" ]; then S_ERR="no file matching $2 in the releases of $1"; return 1; fi
    IFS=$'\t' read -r S_URL S_NAME S_VER S_SIZE <<EOF
$line
EOF
    return 0
}

KEYS="GameVault xemu Xenia RetroArch Dolphin XBSX2 PPSSPP Flycast Moonlight"
# comp <key>: sets C_TITLE, C_PREFIX, C_SERIESONLY
comp() {
    C_SERIESONLY=""
    case "$1" in
        GameVault) C_TITLE="Game Vault (the launcher)"; C_PREFIX="GamerDad.GameVault" ;;
        xemu) C_TITLE="xemu (original Xbox)"; C_PREFIX="GamerDad.Xemu" ;;
        # Xbox 360: Xenia for Game Vault (Series X|S only).
        Xenia) C_TITLE="Xenia for Game Vault (Xbox 360)"; C_PREFIX="GamerDad.XeniaForGameVault"; C_SERIESONLY=1 ;;
        # Series X|S: our builds (any USB drive, saves on it). Xbox One: the original ones, built for its older CPU.
        RetroArch) C_TITLE="RetroArch (PlayStation, cartridge and CD systems)"
                   if [ -n "$series" ]; then C_PREFIX="GamerDad.RetroArchForGameVault"; else C_PREFIX="1e4cf179-f3c2-404f-b9f3-cb2070a5aad8"; fi ;;
        Dolphin) C_TITLE="Dolphin for Game Vault (GameCube, Wii)"; C_PREFIX="GamerDad.DolphinForGameVault" ;;
        XBSX2) C_TITLE="XBSX2 (PlayStation 2)"
               if [ -n "$series" ]; then C_PREFIX="GamerDad.XBSX2ForGameVault"; else C_PREFIX="595c25f0-b370-4d7a-9b14-3027fbd69ecf"; fi ;;
        PPSSPP) C_TITLE="PPSSPP (PSP)"; C_PREFIX="0ad29e1a-1069-4cf5-8c97-620892505f0c" ;;
        Flycast) C_TITLE="Flycast (Dreamcast)"; C_PREFIX="AF75D068-D5AC-3D3C-B52A-2791C2F3491A" ;;
        # Moonlight (TheElixZammuto/moonlight-xbox, GPL-3.0, not ours): streams games from a PC running Sunshine or
        # GeForce Experience. Its Dev Mode build also needs Microsoft's XAML runtime (S_EXTRA_*, same release).
        Moonlight) C_TITLE="Moonlight (stream games from your PC)"; C_PREFIX="50497EliaZammuto.MoonlightUWP" ;;
    esac
}
# comp_get <key>: where to download it; sets S_URL, S_NAME, S_VER, S_SIZE, S_ZIP, S_EXTRA_URL, S_EXTRA_NAME
# (a second runtime package it needs; S_ERR on failure)
comp_get() {
    S_ZIP=""; S_ERR=""; S_EXTRA_URL=""; S_EXTRA_NAME=""
    case "$1" in
        GameVault) from_github "skitzellez/xbox-game-vault" '^GameVault_.*x64\.appx$' ;;
        xemu) from_github "skitzellez/xemu-uwp" '^Xemu_.*x64\.appx$' ;;
        Xenia) from_github "skitzellez/Xenia-GameVault" '^XeniaForGameVault_.*_x64\.appx$' ;;
        RetroArch) if [ -n "$series" ]; then from_github "skitzellez/RetroArch-GameVault" '^RetroArch-for-GameVault_.*x64\.appx$'
                   else from_github "XboxEmulationHub/RetroArch" '^RetroArch-XboxOne-AllCores\.appx$' && S_VER=""; fi ;;
        Dolphin) from_github "skitzellez/Dolphin-GameVault" '^DolphinForGameVault_.*_x64\.appx$' ;;
        XBSX2) if [ -n "$series" ]; then from_github "skitzellez/XBSX2-GameVault" '^XBSX2-for-GameVault_.*\.msixbundle$'
               else from_github "XboxEmulationHub/XBSX2" 'SSE4\.msixbundle$'; fi ;;
        PPSSPP) releases "hrydgard/ppsspp"
                local tag; tag="$(js "$work/releases.json" stabletag)"
                if [ -z "$tag" ] || [ "$tag" = "ERROR" ]; then S_ERR="could not read the release list of hrydgard/ppsspp"; return 1; fi
                S_URL="https://www.ppsspp.org/files/$(printf '%s' "$tag" | tr . _)/ppsspp_uwp.zip"; S_NAME="ppsspp_uwp_$tag.zip"
                S_VER="$tag"; S_SIZE=28; S_ZIP=1 ;;
        Flycast) from_github "flyinghead/flycast" '^flycast-.*\.appx$' ;;
        Moonlight) from_github "TheElixZammuto/moonlight-xbox" '^Microsoft\.UI\.Xaml\..*\.appx$' || return 1
                   S_EXTRA_URL="$S_URL"; S_EXTRA_NAME="$S_NAME"
                   from_github "TheElixZammuto/moonlight-xbox" '^moonlight-xbox-dx_.*_x64\.msixbundle$' ;;
    esac
}

# ---------------------------------------------------------------------------------------------------
head_ "2. What will be installed"
PKEY=(); PNEW=(); PURL=(); PNAME=(); PZIP=(); PXURL=(); PXNAME=(); n=0
for k in $KEYS; do
    comp "$k"
    if in_list "$k" "$Skip"; then say "$(printf '   %-52s left out (--skip)' "$C_TITLE")"; continue; fi
    if [ -n "$C_SERIESONLY" ] && [ -z "$series" ]; then say "$(printf '   %-52s needs an Xbox Series X|S' "$C_TITLE")" DarkGray; continue; fi
    if ! comp_get "$k"; then say "$(printf '   %-52s cannot be checked: %s' "$C_TITLE" "$S_ERR")" Yellow; continue; fi
    have=""; installed "$C_PREFIX" && have=1
    # "2.7" on the download page and "2.7.1.0" on the console are the same release
    same=""
    if [ -n "$have" ]; then case "$P_VER" in "$S_VER"*) same=1 ;; esac; fi
    if [ -n "$same" ] && ! in_list "$k" "$Force"; then
        say "$(printf '   %-52s already installed (%s)' "$C_TITLE" "$P_VER")" DarkGray
    else
        if [ -n "$have" ]; then what="update $P_VER -> $S_VER"; else what="install $S_VER"; fi
        say "$(printf '   %-52s %s, %s MB' "$C_TITLE" "$what" "$S_SIZE")" White
        PKEY[$n]="$k"; PNEW[$n]="$([ -z "$have" ] && echo 1)"; PURL[$n]="$S_URL"; PNAME[$n]="$S_NAME"; PZIP[$n]="$S_ZIP"
        PXURL[$n]="$S_EXTRA_URL"; PXNAME[$n]="$S_EXTRA_NAME"; n=$((n + 1))
    fi
done
if [ "$n" -gt 0 ] && [ -z "$Yes" ]; then
    case "$(ask "Download and install these now? [Y/n] ")" in [nN]*) n=0 ;; esac
fi

# The Visual C++ runtime package every one of these apps depends on. It comes inside PPSSPP's official
# download (signed by Microsoft); the console keeps one copy for all apps.
VCLIBS=""
vclibs() {
    if [ -z "$VCLIBS" ]; then
        comp_get PPSSPP || return 1
        local zip; zip="$(fetch "$S_URL" "$S_NAME")" || return 1
        VCLIBS="$(find "$(unpack "$zip")" -type f -path '*/x64/*' -name 'Microsoft.VCLibs.x64*.appx' | head -n 1)"
    fi
    printf '%s' "$VCLIBS"
}

# install_package <file> [dependency] [second dependency]: prints "ok" or why it failed
install_package() {
    local tok name s i
    local form=(-F "$(form_file f "$1")")
    [ -n "$2" ] && form+=(-F "$(form_file dep "$2")")
    [ -n "$3" ] && form+=(-F "$(form_file dep1 "$3")")
    tok="$(token)"
    name="$(urlenc "$(basename "$1")")"
    portal -m 1800 -H "X-CSRF-Token: $tok" -H "Expect:" "${form[@]}" "$B/api/app/packagemanager/package?package=$name" -o /dev/null
    for ((i = 0; i < 300; i++)); do
        sleep 2
        rm -f "$work/state.json"; portal "$B/api/app/packagemanager/state" -o "$work/state.json"
        s="$(cat "$work/state.json" 2>/dev/null)"
        case "$s" in ""|*"in progress"*) continue ;; esac
        js "$work/state.json" state
        return 0
    done
    printf '%s' "the console did not finish within ten minutes"
}

head_ "3. Installing"
FAILED=""; FIRSTSTART=""; FRESH=""  # FRESH: apps this run installed for the first time
[ "$n" = 0 ] && say "   nothing to install" DarkGray
for ((i = 0; i < n; i++)); do
    k="${PKEY[$i]}"; comp_name="${PNAME[$i]}"; url="${PURL[$i]}"; zip="${PZIP[$i]}"
    comp "$k"
    say " - $C_TITLE" White
    if ! file="$(fetch "$url" "$comp_name")"; then say "   FAILED: download failed: $url" Red; FAILED="$FAILED, $C_TITLE"; continue; fi
    if [ -n "$zip" ]; then
        # the package inside the download, not the runtime packages in its Dependencies folder
        file="$(find "$(unpack "$file")" -type f \( -iname '*.msix' -o -iname '*.msixbundle' -o -iname '*.appx' \) ! -path '*Dependencies*' | head -n 1)"
        if [ -z "$file" ]; then say "   FAILED: no package found inside the download" Red; FAILED="$FAILED, $C_TITLE"; continue; fi
    fi
    say "   sending to the console and installing (large ones take a few minutes)"
    extra=""
    if [ -n "${PXURL[$i]}" ] && ! extra="$(fetch "${PXURL[$i]}" "${PXNAME[$i]}")"; then   # Moonlight: the XAML runtime
        say "   FAILED: download failed: ${PXURL[$i]}" Red; FAILED="$FAILED, $C_TITLE"; continue
    fi
    r="$(install_package "$file" "$(vclibs)" "$extra")"
    # believe the console's package list, not only its answer
    if [ "$r" = "ok" ] && installed "$C_PREFIX"; then
        say "   done" Green
        # every emulator Game Vault starts (Game Vault itself is started at the end; Moonlight is not one)
        [ "$k" != GameVault ] && [ "$k" != Moonlight ] && FIRSTSTART="$FIRSTSTART $k"
        [ -n "${PNEW[$i]}" ] && FRESH="$FRESH $k"
    else
        say "   FAILED: $r" Red; FAILED="$FAILED, $C_TITLE"
    fi
done

# ---------------------------------------------------------------------------------------------------
# Files into an app's own folder on the console.
MADE=" "
make_dir() {                         # make_dir <package> <\LocalState\a\b>, one level at a time
    local pfn="$1" parent="" part key tok parts
    IFS='\' read -r -a parts <<< "$2"
    for part in "${parts[@]}"; do
        [ -z "$part" ] && continue
        if [ -z "$parent" ]; then parent="\\$part"; continue; fi
        key="$pfn|$parent\\$part"
        case "$MADE" in *" $key "*) parent="$parent\\$part"; continue ;; esac
        tok="$(token)"
        portal -X POST -H "X-CSRF-Token: $tok" -H "Content-Length: 0" \
            "$B/api/filesystem/apps/folder?knownfolderid=LocalAppData&packagefullname=$pfn&path=$(enc "$parent")&newfoldername=$(urlenc "$part")" -o /dev/null
        MADE="$MADE$key "
        parent="$parent\\$part"
    done
}
put_file() {                         # put_file <package> <dir> <local file> <name on the console>
    make_dir "$1" "$2"
    local tmp="$work/upload" tok code
    mkdir -p "$tmp"; cp -f "$3" "$tmp/$4"
    tok="$(token)"
    code="$(portal -m 600 -H "X-CSRF-Token: $tok" -H "Expect:" -F "$(form_file f "$tmp/$4")" \
        "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$1&path=$(enc "$2")" -o /dev/null -w "%{http_code}")"
    rm -f "$tmp/$4"
    [ "$code" = "200" ]
}
get_file() {                         # get_file <package> <dir> <name> <local file>: true when it was there
    rm -f "$4"
    local code; code="$(portal -m 1800 "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$1&filename=$(urlenc "$3")&path=$(enc "$2")" -o "$4" -w "%{http_code}")"
    [ "$code" = "200" ] && [ -f "$4" ]
}
start_app() {                        # uses P_FULL and P_RELID from installed
    local tok; tok="$(token)"
    portal -X POST -H "X-CSRF-Token: $tok" -H "Content-Length: 0" "$B/api/taskmanager/app?appid=$(b64 "$P_RELID")&package=$(b64 "$P_FULL")" -o /dev/null
}
stop_app() {
    local tok; tok="$(token)"
    portal -X DELETE -H "X-CSRF-Token: $tok" "$B/api/taskmanager/app?package=$(b64 "$P_FULL")" -o /dev/null
}

# A Device Portal install is ready only for the console's own account until the app is started once; until then
# Game Vault cannot start it for the player (the console says 0x80070002). One start through the portal does it.
for k in $FIRSTSTART; do
    comp "$k"
    installed "$C_PREFIX" || continue
    say "   starting $C_TITLE once so the console makes it ready for you" DarkGray
    start_app; sleep 10; stop_app
done

items() {                            # items <package> <dir>: "dir|file<TAB>name" lines
    rm -f "$work/items.json"; portal -m 60 "$B/api/filesystem/apps/files?knownfolderid=LocalAppData&packagefullname=$1&path=$(enc "$2")" -o "$work/items.json"
    js "$work/items.json" items
}
# Copies folders and files of an app's LocalState into another app's, leaving alone what the new one has.
# Settings files get the old package's folder names replaced by the new one's.
copy_app_data() {                    # copy_app_data <from pkg> <from family> <to pkg> <to family> <names...>
    local from="$1" oldfam="$2" to="$3" newfam="$4"; shift 4
    local tmp="$work/move" count=0 qd=() qn=() qt=() h=0 t=0 type name dir path have_dir="" have="" f code tok
    mkdir -p "$tmp"
    while IFS=$'\t' read -r type name; do
        [ -z "$name" ] && continue
        for want in "$@"; do if [ "$want" = "$name" ]; then qd[$t]='\LocalState'; qn[$t]="$name"; qt[$t]="$type"; t=$((t + 1)); fi; done
    done <<EOF
$(items "$from" '\LocalState')
EOF
    while [ "$h" -lt "$t" ]; do
        dir="${qd[$h]}"; name="${qn[$h]}"; type="${qt[$h]}"; h=$((h + 1))
        path="$dir\\$name"
        if [ "$type" = "dir" ]; then
            make_dir "$to" "$path"
            while IFS=$'\t' read -r type name; do
                [ -z "$name" ] && continue
                qd[$t]="$path"; qn[$t]="$name"; qt[$t]="$type"; t=$((t + 1))
            done <<EOF
$(items "$from" "$path")
EOF
            continue
        fi
        if [ "$have_dir" != "$dir" ]; then have_dir="$dir"; have="$(items "$to" "$dir" | cut -f2 | tr '[:upper:]' '[:lower:]')"; fi
        if printf '%s\n' "$have" | grep -qxF "$(lower "$name")"; then continue; fi
        f="$tmp/$name"
        get_file "$from" "$dir" "$name" "$f"
        case "$(lower "$name")" in *.cfg|*.ini|*.opt|*.lpl|*.rmp)
            if [ -n "$oldfam" ] && [ -n "$newfam" ]; then
                sed "s/$(printf '%s' "$oldfam" | sed 's/[.[\*^$/]/\\&/g')/$newfam/g" "$f" > "$f.new" && mv -f "$f.new" "$f"
            fi ;;
        esac
        tok="$(token)"
        code="$(portal -m 1800 -H "X-CSRF-Token: $tok" -H "Expect:" -F "$(form_file f "$f")" \
            "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$to&path=$(enc "$dir")" -o /dev/null -w "%{http_code}")"
        rm -f "$f"
        if [ "$code" = "200" ]; then count=$((count + 1)); else say "   could not copy $path" Yellow >&2; fi
    done
    printf '%s' "$count"
}
# Only into a new app this run installed for the first time: one already in use keeps its own settings (they
# would be replaced by the old app's). A mark in the new app's own storage says it was done, so a second
# computer or a cleared cache never does it again. The new app's storage exists once it has run; its first
# settings file makes way for the old one.
move_over() {                        # move_over <key> <old prefix> <new prefix> <title> <settings dir> <settings file> <names...>
    local key="$1" oldp="$2" newp="$3" title="$4" sdir="$5" sfile="$6"; shift 6
    case " $FRESH " in *" $key "*) ;; *) return 0 ;; esac
    installed "$oldp" || return 0
    local ofull="$P_FULL" ofam="$P_FAMILY"
    installed "$newp" || return 0
    local tok c
    get_file "$P_FULL" '\LocalState' "gamevault-moved.txt" "$work/moved.tmp" && return 0
    say " - $title"
    if [ -z "$(items "$P_FULL" '\LocalState')" ]; then start_app; sleep 12; stop_app; sleep 2; fi
    tok="$(token)"
    portal -X DELETE -H "X-CSRF-Token: $tok" "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$P_FULL&filename=$sfile&path=$(enc "$sdir")" -o /dev/null
    c="$(copy_app_data "$ofull" "$ofam" "$P_FULL" "$P_FAMILY" "$@")"
    say "   $c files copied from the original app (it stays installed; you can remove it in Dev Home)" Green
    date > "$work/gamevault-moved.txt"
    put_file "$P_FULL" '\LocalState' "$work/gamevault-moved.txt" "gamevault-moved.txt"
}
if [ -n "$series" ]; then
    head_ "3b. Moving over what the original apps had"
    move_over RetroArch "1e4cf179-f3c2-404f-b9f3-cb2070a5aad8" "GamerDad.RetroArchForGameVault" "RetroArch: settings, saves, states, BIOS files" '\LocalState' "retroarch.cfg" retroarch.cfg config saves states system playlists
    move_over XBSX2 "595c25f0-b370-4d7a-9b14-3027fbd69ecf" "GamerDad.XBSX2ForGameVault" "XBSX2: settings, BIOS files, memory cards, states" '\LocalState\inis' "PCSX2.ini" inis bios memcards sstates gamesettings inputprofiles
fi
# every console: Dolphin for Game Vault takes the place of the original Dolphin (memory cards, Wii saves, states)
move_over Dolphin "3143e227-cbe5-41c4-aaa9-cf40132a1b22" "GamerDad.DolphinForGameVault" "Dolphin: settings, memory cards, Wii saves, states" '\LocalState\Config' "Dolphin.ini" Config GC Wii StateSaves GameSettings

head_ "4. BIOS files"
comp RetroArch; ra="";      installed "$C_PREFIX" && ra="$P_FULL"
comp XBSX2;     xbsx2="";   installed "$C_PREFIX" && xbsx2="$P_FULL"
flycast=""; installed "AF75D068-D5AC-3D3C-B52A-2791C2F3491A" && flycast="$P_FULL"
xemu="";    installed "GamerDad.Xemu" && xemu="$P_FULL"
vault="";   installed "GamerDad.GameVault" && vault="$P_FULL"
sys='\LocalState\system'
STATUS=""                            # what Game Vault is told: "system=value" lines
set_status() { STATUS="$STATUS$1=$2
"; }
has_status() { printf '%s' "$STATUS" | grep -q "^$1="; }

if [ -z "$BiosFolder" ]; then
    say "Some systems need BIOS files that are copyrighted and must come from consoles you own: PlayStation 2,"
    say "Saturn and Sega CD. PlayStation and the original Xbox get free replacements (Xbox: offline play only;"
    say "your own Xbox boot ROM and BIOS add online play)."
    say "If you have such files, drag their folder or USB drive into this window (or type its name)."
    BiosFolder="$(ask "Folder or drive to search, or just Enter to skip: ")"
fi
# a folder dragged into Terminal arrives quoted or with \ before spaces
BiosFolder="${BiosFolder#"${BiosFolder%%[![:space:]]*}"}"; BiosFolder="${BiosFolder%"${BiosFolder##*[![:space:]]}"}"
case "$BiosFolder" in
    \'*\'|\"*\") BiosFolder="${BiosFolder:1:${#BiosFolder}-2}" ;;
    *) BiosFolder="$(printf '%s' "$BiosFolder" | sed 's/\\\(.\)/\1/g')" ;;
esac
# a drive's name alone, e.g. MYUSB -> /Volumes/MYUSB
if [ -n "$BiosFolder" ] && [ "$BiosFolder" != "none" ] && [ ! -e "$BiosFolder" ] && [ -d "/Volumes/$BiosFolder" ]; then BiosFolder="/Volumes/$BiosFolder"; fi

# name on your drive (lower case) -> the system. Names are the ones the emulators look for.
bios_system() {
    case "$1" in
        scph1001.bin|scph5500.bin|scph5501.bin|scph5502.bin|scph7001.bin) echo ps1 ;;
        sega_101.bin|mpr-17933.bin|saturn_bios.bin) echo saturn ;;
        bios_cd_u.bin|bios_cd_e.bin|bios_cd_j.bin) echo segacd ;;
        32x_g_bios.bin|32x_m_bios.bin|32x_s_bios.bin) echo 32x ;;
        gba_bios.bin) echo gba ;; gbc_bios.bin) echo gbc ;; gb_bios.bin) echo gb ;; bios.gg) echo gamegear ;;
        bios7.bin|bios9.bin|firmware.bin) echo ds ;;
        5200.rom) echo atari5200 ;; "7800 bios (u).rom") echo atari7800 ;; lynxboot.img) echo lynx ;; syscard3.pce) echo pcenginecd ;;
        dc_boot.bin|dc_flash.bin) echo dreamcast ;;
    esac
}
found=0
if [ -n "$BiosFolder" ] && [ "$BiosFolder" != "none" ] && [ -d "$BiosFolder" ]; then
    say "   searching $BiosFolder"
    while IFS= read -r -d '' f; do
        base="$(basename "$f")"; low="$(lower "$base")"; size="$(sizeof "$f")"; ok=""; what=""
        system="$(bios_system "$low")"
        if [ -n "$system" ] && [ -n "$ra" ]; then
            what="$base  ->  RetroArch ($system)"
            dir="$sys"; [ "$system" = "dreamcast" ] && dir="$sys\\dc"
            put_file "$ra" "$dir" "$f" "$base" && ok=1
            if [ "$system" = "dreamcast" ] && [ -n "$flycast" ]; then put_file "$flycast" '\LocalState\data' "$f" "$base"; fi
            [ -n "$ok" ] && set_status "$system" yes
        elif [ "$size" = "4194304" ] && [ -n "$xbsx2" ] && printf '%s' "$low" | grep -qE 'scph|ps2' && printf '%s' "$low" | grep -qE '\.bin$'; then
            what="$base  ->  XBSX2 (PlayStation 2)"
            put_file "$xbsx2" '\LocalState\bios' "$f" "$base" && { ok=1; set_status ps2 yes; }
        elif [ "$size" = "512" ] && [ -n "$xemu" ] && [ "$(md5of "$f")" = "d49c52a4102f6df7bcf8d0617ac475ed" ]; then
            what="$base  ->  xemu (Xbox boot ROM)"
            put_file "$xemu" '\LocalState\xemu\xemu' "$f" "mcpx_1.0.bin" && { ok=1; set_status xboxmcpx yes; }
        elif { [ "$size" = "262144" ] || [ "$size" = "524288" ] || [ "$size" = "1048576" ]; } && [ -n "$xemu" ] &&
             printf '%s' "$low" | grep -qE '\.(bin|rom)$' &&
             { printf '%s' "$low" | grep -qE 'complex|cromwell|evox|xbox|4627|4034|4817|5101|5530|5713|5838|xecuter' ||
               lower "$(dirname "$f")" | grep -qE 'xbox|xemu'; } &&
             ! printf '%s' "$low" | grep -qE '^(scph|sega|mpr-|saturn|bios_cd|dc_)|spiritboot' && ! has_status xboxbios; then
            what="$base  ->  xemu (Xbox BIOS)"
            put_file "$xemu" '\LocalState\xemu\xemu' "$f" "bios.bin" && { ok=1; set_status xboxbios yes; }
        fi
        if [ -n "$what" ]; then found=$((found + 1)); if [ -n "$ok" ]; then say "   $what" Green; else say "   $what  FAILED" Red; fi; fi
    done < <(find "$BiosFolder" -type f -size -16777217c ! -name '._*' -print0 2>/dev/null)
    [ "$found" = 0 ] && say "   no BIOS files recognised there (they are found by the names the emulators expect)" Yellow
elif [ -n "$BiosFolder" ] && [ "$BiosFolder" != "none" ]; then
    say "   $BiosFolder does not exist; skipped" Yellow
fi

# PlayStation: the free OpenBIOS (PCSX-Redux project, MIT licence) unless a real BIOS was just installed.
if [ -n "$ra" ] && ! has_status ps1; then
    ob="$here/files/openbios.bin"; opt="$here/files/SwanStation.opt"
    if [ -f "$ob" ] && put_file "$ra" "$sys" "$ob" "openbios.bin" && put_file "$ra" '\LocalState\config\SwanStation' "$opt" "SwanStation.opt"; then
        say "   PlayStation: free OpenBIOS installed (no file of yours needed)" Green
        set_status ps1 openbios
    else say "   PlayStation: the free OpenBIOS could not be installed" Yellow; fi
fi
# ScummVM: the engine data files and themes the libretro ScummVM core needs (free, from libretro's own server).
# The marker file says which pack is installed, so it is uploaded once.
scumm_url="https://buildbot.libretro.com/assets/system/ScummVM.zip"
if [ -n "$ra" ] && ! get_file "$ra" "$sys\\scummvm" "gamevault-scummvm.txt" "$work/scummvm-mark.tmp"; then
    if zip="$(fetch "$scumm_url" "ScummVM.zip")"; then
        root="$(unpack "$zip")/scummvm"; ok=0; total=0
        while IFS= read -r -d '' f; do
            total=$((total + 1))
            rel="$(dirname "${f#"$root"}")"; [ "$rel" = "/" ] || [ "$rel" = "." ] && rel=""
            put_file "$ra" "$sys\\scummvm$(printf '%s' "$rel" | tr / '\\')" "$f" "$(basename "$f")" && ok=$((ok + 1))
        done < <(find "$root" -type f -print0)
        printf '%s' "$scumm_url" > "$work/gamevault-scummvm.txt"
        if [ "$ok" = "$total" ] && put_file "$ra" "$sys\\scummvm" "$work/gamevault-scummvm.txt" "gamevault-scummvm.txt"; then
            say "   ScummVM: engine data installed ($ok files)" Green
        else say "   ScummVM: only $ok of $total engine data files could be installed" Yellow; fi
    else say "   ScummVM: engine data could not be downloaded" Yellow; fi
fi
if [ -n "$xemu" ] && ! has_status xboxmcpx; then
    say "   Original Xbox: games play with the free BIOS that comes with xemu (offline only). For online play,"
    say "   put your own boot ROM and BIOS on the games USB drive; Game Vault picks them up by itself."
fi

# Tell Game Vault. Lines of system=value; a system that is not listed keeps what an earlier run said.
if [ -n "$vault" ]; then
    get_file "$vault" '\LocalState' "bios.txt" "$work/bios_old.txt" || : > "$work/bios_old.txt"
    { tr -d '\r' < "$work/bios_old.txt" | grep -E '^[a-z0-9]+=[a-z]+$'; printf '%s' "$STATUS"; } |
        awk -F= 'NF == 2 { v[$1] = $2 } END { for (k in v) print k "=" v[k] }' | sort > "$work/bios.txt"
    put_file "$vault" '\LocalState' "$work/bios.txt" "bios.txt" && say "   Game Vault told what is installed" DarkGray
fi

# ---------------------------------------------------------------------------------------------------
head_ "5. Controllers"
# XBSX2 (PlayStation 2) writes its first settings file with no buttons assigned: nothing on the controller does
# anything in a game. Its settings file gets the usual layout for two controllers here.
comp XBSX2
if ! installed "$C_PREFIX"; then say "   XBSX2 is not installed: nothing to do" DarkGray
else
    inis='\LocalState\inis'; ini="$work/PCSX2.ini"
    has_pad() { get_file "$P_FULL" "$inis" "PCSX2.ini" "$ini" && [ "$(js "$ini" hasPad1)" = "yes" ]; }
    if ! has_pad; then
        # XBSX2 writes its settings the first time it runs
        say "   starting XBSX2 for a moment so that it writes its settings"
        start_app
        for ((i = 0; i < 10; i++)); do
            sleep 3
            if has_pad; then sleep 2; has_pad; break; fi
        done
        stop_app; sleep 2
    fi
    if [ "$(js "$ini" hasPad1)" != "yes" ]; then
        say "   XBSX2's settings could not be read. Start XBSX2 once on the console, close it, and run this again." Yellow
    elif [ "$(js "$ini" padfix "$work/PCSX2.new.ini")" != "changed" ]; then
        say "   XBSX2 (PlayStation 2): buttons are set up already" DarkGray
    else
        stop_app; sleep 2              # a running XBSX2 would write its old settings back
        if put_file "$P_FULL" "$inis" "$work/PCSX2.new.ini" "PCSX2.ini"; then say "   XBSX2 (PlayStation 2): buttons set up for two controllers" Green
        else say "   XBSX2 (PlayStation 2): the settings could not be written" Yellow; fi
    fi
fi

# ---------------------------------------------------------------------------------------------------
# On a Series X|S, Game Vault and our builds read games from any USB drive as it is. Only an Xbox One (the
# original emulators) or the original Xenia Canary app need an NTFS drive with read access for apps, and a Mac
# cannot set that.
head_ "6. Games drives"
need_drives=""
if [ -z "$series" ]; then need_drives=1
elif ! installed "GamerDad.XeniaForGameVault" && installed "27d6ba69-e4f1-4b69-b391-8238bab5a431"; then need_drives=1; fi
if [ -z "$need_drives" ]; then
    say "   not needed: Game Vault and its emulators read games from any USB drive" DarkGray
else
    say "   This console's emulators need an NTFS drive with read access for apps. A Mac cannot set that up:" Yellow
    say "   prepare the drive once on a Windows PC (see step 7)." Yellow
fi

# ---------------------------------------------------------------------------------------------------
head_ "7. What to do on the console"
say "a) Give the apps full memory. In Dev Home > Games and apps, for each of these: select it, View details,"
say "   and change App type from App to Game:"
for k in $KEYS; do comp "$k"; installed "$C_PREFIX" && say "      $C_TITLE" White; done
say "   (A new install starts as type App, which is too little memory for most of them. If it already says Game,"
say "   there is nothing to do: this setup turns on Dev Home's 'treat apps as games' setting for new installs.)"
if [ -n "$series" ]; then
    say "b) Put your games on any USB drive (FAT32, exFAT or NTFS) and plug it in. Game Vault makes a Game Vault"
    say "   folder on it for your saves and BIOS files; new BIOS files go in Game Vault/bios."
    if ! installed "GamerDad.XeniaForGameVault" && installed "27d6ba69-e4f1-4b69-b391-8238bab5a431"; then
        say "   With the original Xenia Canary app, Xbox 360 games need an NTFS drive prepared on a Windows PC; open"
        say "   it once from Dev Home and choose Create Profile. Xenia for Game Vault (this setup) needs neither."
    fi
else
    say "b) Games go on a USB drive formatted NTFS, with access for apps. On a Windows PC, with the drive as X: (the"
    say "   first command erases the drive):"
    say "      format X: /FS:NTFS /Q" White
    say "      icacls X:\\ /grant \"*S-1-15-2-1:(OI)(CI)F\"" White
fi
say ""
if [ -n "$FAILED" ]; then say "Finished, but these did not install: ${FAILED#, }. Run the setup again to retry." Yellow; exit 2; fi
say "Finished. Start Game Vault on the console and plug in your games." Green
