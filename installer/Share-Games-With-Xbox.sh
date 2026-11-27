#!/bin/bash
# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Shares a games folder on this Linux PC with Game Vault on the Xbox (network games, LT in Game Vault, and save sync).
# Mirrors Share-Games-With-Xbox.ps1 (Windows): creates a separate 'xboxgames' system account that can only READ that
# folder (and write its "Game Vault saves" folder, for save sync), so your own Linux account and password are never
# used. You choose the account's password here; it is typed on your phone once and kept on the Xbox.
# Options: --folder <path>   --keep-password   --set-private   --no-pause   (or GV_SHARE_PASSWORD in the environment)
# Prints "@@result|<ip>|<share>|<account>|<kept>|<hostname>" on the last line.

Account="xboxgames"
Share="XboxGames"
Folder=""
KeepPassword=""
SetPrivate=""
NoPause=""

if [ -z "${GV_SHARE_LIB_ONLY:-}" ]; then
    while [ $# -gt 0 ]; do
        case "$1" in
            --folder|-Folder) Folder="$2"; shift ;;
            --keep-password|-KeepPassword) KeepPassword=1 ;;
            --set-private|-SetPrivate) SetPrivate=1 ;;
            --no-pause|-NoPause) NoPause=1 ;;
            *) echo "unknown option: $1"; exit 1 ;;
        esac
        shift
    done
fi

say() {
    local c="0"
    case "${2:-}" in Red) c="31";; Green) c="32";; Yellow) c="33";; White) c="1";; DarkGray) c="90";; Cyan) c="36";; esac
    printf '\033[%sm%s\033[0m\n' "$c" "$1"
}
pause_end() {
    if [ -z "$NoPause" ] && [ -t 0 ]; then
        echo ""
        read -r -p "Press Enter to close" _
    fi
    exit "$1"
}
fail() {
    echo ""
    say "Something went wrong: $1" Red
    # a new private file each time: this part can run as root, so never write to a fixed name in /tmp
    local err_file; err_file="$(mktemp "${TMPDIR:-/tmp}/gamevault-share-error.XXXXXX" 2>/dev/null)"
    if [ -n "$err_file" ] && printf '%s %s\n' "$(date)" "$1" > "$err_file" 2>/dev/null; then
        say "(also written to $err_file)"
    fi
    pause_end 1
}

clean_folder_path() {
    local p="$1"
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    case "$p" in
        \'*\'|\"*\") p="${p:1:${#p}-2}" ;;
        *) p="$(printf '%s' "$p" | sed 's/\\\(.\)/\1/g')" ;;
    esac
    case "$p" in
        file://localhost/*) p="/${p#file://localhost/}"; p="${p//\\/\\\\}"; p="$(printf '%b' "${p//%/\\x}")" ;;
        file:///*) p="/${p#file:///}"; p="${p//\\/\\\\}"; p="$(printf '%b' "${p//%/\\x}")" ;;
    esac
    printf '%s' "$p"
}

validate_share_folder() {
    local raw; raw="$(clean_folder_path "$1")"
    [ -z "$raw" ] && { say "No folder chosen." Yellow; return 1; }
    [ ! -d "$raw" ] && { say "Folder does not exist: $raw" Yellow; return 1; }
    local real; real="$(cd "$raw" 2>/dev/null && pwd -P)" || return 1
    case "$real" in
        /|/home|/root|/usr|/etc|/var|/bin|/sbin|/lib|/lib64|/opt|/tmp|/proc|/sys|/dev|/run|/boot|/mnt|/media)
            say "Please choose a games folder, not a whole drive or system folder ($real): only your games should be shared." Yellow
            return 1
            ;;
    esac
    return 0
}

update_smb_conf_file() {
    local conf="$1" folder="$2" force_user="${3:-}"
    local tmp="${conf}.gamevault.tmp"
    if [ -f "$conf" ] && [ ! -f "${conf}.gamevault.bak" ]; then
        cp -p "$conf" "${conf}.gamevault.bak" 2>/dev/null || true
    fi
    if [ -f "$conf" ]; then
        awk '
            /^# --- Game Vault XboxGames start ---$/ { skip = 1; next }
            /^# --- Game Vault XboxGames end ---$/   { skip = 0; next }
            !skip { print }
        ' "$conf" > "$tmp"
    else
        printf '[global]\n   workgroup = WORKGROUP\n' > "$tmp"
    fi
    {
        printf '\n# --- Game Vault XboxGames start ---\n'
        printf '[%s]\n' "$Share"
        printf '   comment = Game Vault games and saves\n'
        printf '   path = %s\n' "$folder"
        printf '   valid users = %s\n' "$Account"
        [ -n "$force_user" ] && printf '   force user = %s\n' "$force_user"
        printf '   browseable = yes\n'
        # without ACLs the share runs as the folder's owner: keep it read-only then, so the Xbox can never change games
        if [ -n "$force_user" ]; then printf '   read only = yes\n'; else printf '   read only = no\n'; fi
        printf '   guest ok = no\n'
        printf '   create mask = 0664\n'
        printf '   directory mask = 0775\n'
        printf '# --- Game Vault XboxGames end ---\n'
    } >> "$tmp"
    mv -f "$tmp" "$conf"
}

apply_share_permissions() {
    local folder="$1" saves="$1/Game Vault saves"
    mkdir -p "$saves" || return 1
    FORCE_USER=""
    if command -v setfacl >/dev/null 2>&1; then
        # Grant traverse (--x) on parent folders up to / so a folder inside /home/<user> or /run/media/<user> is reachable
        local cur="$folder" parent
        while [ "$cur" != "/" ] && [ -n "$cur" ]; do
            parent="$(dirname "$cur")"
            [ "$parent" = "$cur" ] && break
            [ "$parent" != "/" ] && setfacl -m "u:${Account}:x" "$parent" 2>/dev/null || true
            cur="$parent"
        done
        if setfacl -R -m "u:${Account}:rx" -m "d:u:${Account}:rx" "$folder" 2>/dev/null &&
           setfacl -R -m "u:${Account}:rwx" -m "d:u:${Account}:rwx" "$saves" 2>/dev/null; then
            return 0
        fi
    fi
    # Fallback for filesystems without POSIX ACLs (e.g. exFAT/NTFS USB drives mounted by a desktop user)
    chmod -R a+rX "$folder" 2>/dev/null || true
    chmod -R a+rwX "$saves" 2>/dev/null || true
    if ! GV_CHK_FOLDER="$folder" GV_CHK_SAVES="$saves" su -s /bin/sh "$Account" -c 'test -r "$GV_CHK_FOLDER" && test -w "$GV_CHK_SAVES"' 2>/dev/null; then
        FORCE_USER="$(stat -c '%U' "$folder" 2>/dev/null || ls -ld "$folder" | awk '{print $3}')"
        [ "$FORCE_USER" = "UNKNOWN" ] && FORCE_USER=""
    fi
    return 0
}

if [ -n "${GV_SHARE_LIB_ONLY:-}" ]; then return 0 2>/dev/null || exit 0; fi

say "Game Vault - share games with your Xbox" Green
echo ""

# 1. the folder (chosen before sudo so GUI folder dialogs run in the user's desktop session)
if [ -z "$Folder" ]; then
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        if command -v zenity >/dev/null 2>&1; then
            Folder="$(zenity --file-selection --directory --title="Choose the folder with your games (its subfolders are included)" 2>/dev/null || true)"
        elif command -v kdialog >/dev/null 2>&1; then
            Folder="$(kdialog --getexistingdirectory "${HOME:-/}" --title "Choose the folder with your games (its subfolders are included)" 2>/dev/null || true)"
        fi
    fi
    if [ -z "$Folder" ]; then
        read -r -e -p "Choose the folder with your games (its subfolders are included): " Folder
    fi
fi
Folder="$(clean_folder_path "$Folder")"
if ! validate_share_folder "$Folder"; then
    pause_end 1
fi
Folder="$(cd "$Folder" && pwd -P)"
echo "Folder: $Folder"

# Elevate to root if needed, preserving the chosen folder and flags
if [ "$(id -u)" -ne 0 ]; then
    args=(--folder "$Folder")
    [ -n "$KeepPassword" ] && args+=(--keep-password)
    [ -n "$SetPrivate" ] && args+=(--set-private)
    [ -n "$NoPause" ] && args+=(--no-pause)
    echo ""
    say "Administrator rights (sudo) are needed to configure the Samba share and the '$Account' account." DarkGray
    if [ -n "${GV_SHARE_PASSWORD:-}" ]; then
        exec sudo --preserve-env=GV_SHARE_PASSWORD bash "$0" "${args[@]}"
    else
        exec sudo bash "$0" "${args[@]}"
    fi
fi

given="${GV_SHARE_PASSWORD:-}"
unset GV_SHARE_PASSWORD

# Ensure Samba (smbd, smbpasswd) and setfacl are installed
have_samba=""
if { command -v smbd >/dev/null 2>&1 || [ -x /usr/sbin/smbd ]; } && command -v smbpasswd >/dev/null 2>&1; then
    have_samba=1
fi
if [ -z "$have_samba" ]; then
    echo ""
    say "Samba (the Windows file-sharing service for Linux) is not installed yet." Yellow
    ans="y"
    if [ -z "$SetPrivate" ] && [ -z "$NoPause" ] && [ -t 0 ]; then
        read -r -p "Install Samba now using your package manager? (y/n) " ans
    fi
    case "$ans" in
        [yY]*|"")
            if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get install -y samba acl
            elif command -v dnf >/dev/null 2>&1; then dnf install -y samba acl
            elif command -v pacman >/dev/null 2>&1; then pacman -S --needed --noconfirm samba acl
            elif command -v zypper >/dev/null 2>&1; then zypper --non-interactive install samba acl
            else fail "Could not find apt-get, dnf, pacman or zypper. Install 'samba' and 'acl' and run this again."; fi
            ;;
        *) fail "Samba is required to share games with your Xbox." ;;
    esac
    if ! { command -v smbd >/dev/null 2>&1 || [ -x /usr/sbin/smbd ]; } || ! command -v smbpasswd >/dev/null 2>&1; then
        fail "Samba installation did not complete. Install 'samba' and run this again."
    fi
fi

# 2. the account and its password
have_user=""
if id -u "$Account" >/dev/null 2>&1; then have_user=1; fi
have_smb_user=""
if command -v pdbedit >/dev/null 2>&1 && pdbedit -L 2>/dev/null | grep -q "^${Account}:"; then have_smb_user=1; fi

keep="false"
p1=""
echo ""
if [ -n "$have_smb_user" ] && [ -n "$KeepPassword" ]; then
    keep="true"
elif [ -n "$given" ]; then
    [ "${#given}" -lt 8 ] && fail "The password must have 8 characters or more."
    p1="$given"
elif [ -n "$have_smb_user" ]; then
    echo "The '$Account' account is already set up, and your Xbox knows its password."
    echo "Press Enter to keep that password (nothing to type on your phone), or type a new one."
    read -r -s -p "New password (Enter keeps the current one): " p1; echo ""
    [ -z "$p1" ] && keep="true"
fi

if [ "$keep" != "true" ] && [ -z "$given" ]; then
    if [ -z "$have_smb_user" ]; then
        echo "Choose a password for the '$Account' account (8 characters or more)."
        echo "You type it once on your phone when Game Vault asks; it is kept on the Xbox."
    fi
    while :; do
        if [ -z "$p1" ]; then read -r -s -p "Password: " p1; echo ""; fi
        read -r -s -p "Same password again: " p2; echo ""
        if [ "${#p1}" -ge 8 ] && [ "$p1" = "$p2" ]; then
            unset p2
            break
        fi
        say "They do not match, or it is shorter than 8 characters. Again:" Yellow
        p1=""
    done
fi

nologin_shell="/usr/sbin/nologin"
[ ! -x "$nologin_shell" ] && [ -x /sbin/nologin ] && nologin_shell="/sbin/nologin"
[ ! -x "$nologin_shell" ] && nologin_shell="/bin/false"

if [ -z "$have_user" ]; then
    useradd -r -M -d /nonexistent -s "$nologin_shell" -c "Game Vault (Xbox): reads games, writes saves" "$Account" ||
        fail "Could not create the '$Account' system account."
fi
# Hide from desktop login screens (AccountsService: GDM, LightDM, Cinnamon, MATE)
if [ -d /var/lib/AccountsService/users ]; then
    printf '[User]\nSystemAccount=true\n' > "/var/lib/AccountsService/users/$Account" 2>/dev/null || true
fi

if [ "$keep" != "true" ]; then
    printf '%s\n%s\n' "$p1" "$p1" | smbpasswd -s -a "$Account" >/dev/null || fail "Could not set the Samba password for '$Account'."
fi
unset p1 given
smbpasswd -e "$Account" >/dev/null || fail "Could not enable the '$Account' Samba account."

# 3. read-only access to the games and writable 'Game Vault saves'
saves="$Folder/Game Vault saves"
apply_share_permissions "$Folder" || fail "Could not set permissions on '$Folder'."
mkdir -p /etc/samba
update_smb_conf_file /etc/samba/smb.conf "$Folder" "$FORCE_USER" || fail "Could not update /etc/samba/smb.conf."

# Restart and enable Samba
restarted=""
if command -v systemctl >/dev/null 2>&1; then
    for svc in smbd smb; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 || systemctl status "${svc}.service" >/dev/null 2>&1; then
            systemctl enable "$svc" >/dev/null 2>&1 || true
            if systemctl restart "$svc" >/dev/null 2>&1; then restarted=1; fi
        fi
    done
    for nsvc in nmbd nmb; do
        if systemctl list-unit-files "${nsvc}.service" >/dev/null 2>&1; then
            systemctl enable "$nsvc" >/dev/null 2>&1 || true
            systemctl restart "$nsvc" >/dev/null 2>&1 || true
        fi
    done
fi
if [ -z "$restarted" ] && command -v service >/dev/null 2>&1; then
    service smbd restart >/dev/null 2>&1 || service smb restart >/dev/null 2>&1 || true
fi

# 4. Firewall check (ufw or firewalld)
echo ""
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "^Status: active"; then
    if ! ufw status 2>/dev/null | grep -qiE "Samba|445/tcp"; then
        say "Your firewall (ufw) is active and blocking file sharing." Yellow
        a="n"
        if [ -n "$SetPrivate" ]; then a="y"
        elif [ -z "$NoPause" ] && [ -t 0 ]; then read -r -p "Allow Samba through the firewall so the Xbox can reach the share? (y/n) " a; fi
        if [[ "$a" =~ ^[yY] ]]; then ufw allow Samba >/dev/null 2>&1 || ufw allow 445/tcp >/dev/null 2>&1; echo "Allowed in ufw."; fi
    fi
elif command -v firewall-cmd >/dev/null 2>&1 && [ "$(firewall-cmd --state 2>/dev/null)" = "running" ]; then
    if ! firewall-cmd --query-service=samba >/dev/null 2>&1; then
        say "Your firewall (firewalld) is active and blocking file sharing." Yellow
        a="n"
        if [ -n "$SetPrivate" ]; then a="y"
        elif [ -z "$NoPause" ] && [ -t 0 ]; then read -r -p "Allow Samba through the firewall so the Xbox can reach the share? (y/n) " a; fi
        if [[ "$a" =~ ^[yY] ]]; then
            firewall-cmd --permanent --add-service=samba >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
            echo "Allowed in firewalld."
        fi
    fi
fi

ip=""
if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
fi
[ -z "$ip" ] && command -v hostname >/dev/null 2>&1 && ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
host_name="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "LINUXPC")"
if [ -z "$ip" ]; then
    say "Could not find this PC's network address: check that it is on the same network as the Xbox." Yellow
    ip="$host_name"
fi
keep_out="$([ "$keep" = "true" ] && echo "True" || echo "False")"

echo ""
if [ "$keep" = "true" ]; then
    say "Done. Your Xbox already knows this share and its password: nothing to type on your phone." Green
    echo "Save sync can now keep your saves in '$saves' (Options in Game Vault: Save sync)."
else
    say "Done. On your phone (Game Vault, LT on the Xbox), type:" Green
    if [ "$ip" = "$host_name" ]; then
        echo "   Computer:   \\\\$host_name\\$Share"
    else
        echo "   Computer:   \\\\$ip\\$Share      (or \\\\$host_name\\$Share)"
    fi
    echo "   User name:  $Account"
    echo "   Password:   the one you just chose"
fi
if [ -n "$FORCE_USER" ]; then
    echo ""
    say "This drive has no Linux permissions (for example exFAT or NTFS), so the games are shared read-only." Yellow
    say "Network games work. Save sync needs the folder on a Linux drive (ext4) or on this PC's own disk." Yellow
fi
echo ""
echo "To stop sharing later: remove the [$Share] section in /etc/samba/smb.conf and restart smbd."
echo "@@result|$ip|$Share|$Account|$keep_out|$host_name"
pause_end 0
