# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Shares a games folder on this PC with Game Vault on the Xbox (network games, LT in Game Vault).
# It makes a separate account that can only READ that folder (and write its "Game Vault saves" folder, for save sync),
# so your own Windows account and password are never
# used: Windows does not let an account without a password sign in over the network, and your own account can do
# far more than read games. You choose the account's password here; it is typed on your phone once and kept on
# the Xbox. Run from Game Vault Setup.exe (it asks for administrator rights once).
# Game Vault Setup.exe passes the answers: -Folder, -KeepPassword or the password in the environment (GV_SHARE_PASSWORD,
# never on the command line), -SetPrivate, -NoPause; it reads the last line, "@@result|<ip>|<share>|<account>|<kept>".
param([string]$Folder, [switch]$KeepPassword, [switch]$SetPrivate, [switch]$NoPause)
$ErrorActionPreference = 'Stop'
$Account = 'xboxgames'
$Share = 'XboxGames'

function Pause-End($code) { if (-not $NoPause) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }; exit $code }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

try {
Write-Host 'Game Vault - share games with your Xbox' -ForegroundColor Green
Write-Host ''

# 1. the folder
if (-not $Folder) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose the folder with your games (its subfolders are included)'
    $dlg.ShowNewFolderButton = $false
    $top = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}
    if ($dlg.ShowDialog($top) -ne 'OK') { Write-Host 'No folder chosen.'; Pause-End 1 }
    $Folder = $dlg.SelectedPath
}
if ($Folder.Length -le 3) {
    Write-Host "Please choose a folder, not a whole drive ($Folder): only your games should be shared." -ForegroundColor Yellow
    Pause-End 1
}
Write-Host "Folder: $Folder"

# 2. the account and its password (typed here, never shown or saved by this script). Run again (to share another
# folder, or for save sync), the account keeps its password unless a new one is typed: the Xbox already has it.
$user = Get-LocalUser -Name $Account -ErrorAction SilentlyContinue
$keep = $false
Write-Host ''
$given = $env:GV_SHARE_PASSWORD
$env:GV_SHARE_PASSWORD = $null
if ($user -and $KeepPassword) {
    $keep = $true
} elseif ($given) {
    if ($given.Length -lt 8) { throw 'The password must have 8 characters or more.' }
    $p1 = ConvertTo-SecureString $given -AsPlainText -Force
} elseif ($user) {
    Write-Host "The '$Account' account is already set up, and your Xbox knows its password."
    Write-Host 'Press Enter to keep that password (nothing to type on your phone), or type a new one.'
    $p1 = Read-Host -AsSecureString 'New password (Enter keeps the current one)'
    $keep = $p1.Length -eq 0
}
if (-not $keep -and -not $given) {
    if (-not $user) {
        Write-Host "Choose a password for the '$Account' account (8 characters or more)."
        Write-Host 'You type it once on your phone when Game Vault asks; it is kept on the Xbox.'
    }
    do {
        if (-not $p1 -or $p1.Length -eq 0) { $p1 = Read-Host -AsSecureString 'Password' }
        $p2 = Read-Host -AsSecureString 'Same password again'
        $s1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        $s2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
        $ok = $s1.Length -ge 8 -and $s1 -ceq $s2
        if (-not $ok) { Write-Host 'They do not match, or it is shorter than 8 characters. Again:' -ForegroundColor Yellow; $p1 = $null }
    } until ($ok)
    $s1 = $null; $s2 = $null
}

if ($user) {
    if (-not $keep) { Set-LocalUser -Name $Account -Password $p1 -PasswordNeverExpires $true }
    Enable-LocalUser -Name $Account
} else {
    New-LocalUser -Name $Account -Password $p1 -PasswordNeverExpires -UserMayNotChangePassword `
        -Description 'Game Vault (Xbox): reads games, writes saves' | Out-Null   # New-LocalUser takes 48 at most
}
# not a member of Users: no sign-in on this PC, only network access to the share
Remove-LocalGroupMember -Group 'Users' -Member $Account -ErrorAction SilentlyContinue
$hide = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
New-Item -Force $hide | Out-Null
New-ItemProperty -Force $hide -Name $Account -Value 0 -PropertyType DWord | Out-Null

# 3. read-only access to the games and the share. The one folder the Xbox may write is "Game Vault saves" (save
# sync in Game Vault's Options): the share allows changes, the folder permissions keep everything else read-only.
icacls "$Folder" /grant "${Account}:(OI)(CI)RX" | Out-Null
$saves = Join-Path $Folder 'Game Vault saves'
New-Item -ItemType Directory -Force $saves | Out-Null
icacls "$saves" /grant "${Account}:(OI)(CI)M" | Out-Null
$existing = Get-SmbShare -Name $Share -ErrorAction SilentlyContinue
if ($existing -and $existing.Path -ne $Folder) { Remove-SmbShare -Name $Share -Force }
if (-not (Get-SmbShare -Name $Share -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $Share -Path "$Folder" -ChangeAccess $Account | Out-Null
} else {
    Grant-SmbShareAccess -Name $Share -AccountName $Account -AccessRight Change -Force | Out-Null
}

# the home network must be Private for Windows to allow sharing on it (a Public one is for cafes and hotels)
$net = Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq 'Internet' } | Select-Object -First 1
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $net.InterfaceIndex -ErrorAction SilentlyContinue |
       Select-Object -First 1).IPAddress
Write-Host ''
if ($net -and $net.NetworkCategory -eq 'Public') {
    Write-Host "Your network '$($net.Name)' is set as Public." -ForegroundColor Yellow
    $a = if ($SetPrivate) { 'y' } elseif ($NoPause) { 'n' } else { Read-Host 'Is this your home network? Set it to Private so the Xbox can reach the share (y/n)' }
    if ($a -match '^[yY]') { Set-NetConnectionProfile -InterfaceIndex $net.InterfaceIndex -NetworkCategory Private; Write-Host 'Set to Private.' }
}

Write-Host ''
if ($keep) {
    # same account, same password, same share name: the Xbox's saved network place goes on working
    Write-Host 'Done. Your Xbox already knows this share and its password: nothing to type on your phone.' -ForegroundColor Green
    Write-Host "Save sync can now keep your saves in '$saves' (Options in Game Vault: Save sync)."
} else {
    Write-Host 'Done. On your phone (Game Vault, LT on the Xbox), type:' -ForegroundColor Green
    Write-Host "   Computer:   \\$ip\$Share      (or \\$env:COMPUTERNAME\$Share)"
    Write-Host "   User name:  $Account"
    Write-Host '   Password:   the one you just chose'
}
Write-Host ''
Write-Host "To stop sharing later: run this again and close it, or remove the share '$Share' in Computer Management."
Write-Host "@@result|$ip|$Share|$Account|$keep|$env:COMPUTERNAME"
Pause-End 0
} catch {
    # the window stays open with what went wrong (no password is ever part of it)
    Write-Host ''
    Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
    "$(Get-Date) $($_.Exception.Message) | $($_.InvocationInfo.PositionMessage)" | Out-File -Append "$env:PUBLIC\Game Vault share error.txt"
    Write-Host "(also written to $env:PUBLIC\Game Vault share error.txt)"
    Pause-End 1
}
