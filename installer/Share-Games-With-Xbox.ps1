# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Shares a games folder on this PC with Game Vault on the Xbox (network games, LT in Game Vault).
# It makes a separate account that can only READ that folder, so your own Windows account and password are never
# used: Windows does not let an account without a password sign in over the network, and your own account can do
# far more than read games. You choose the account's password here; it is typed on your phone once and kept on
# the Xbox. Run "Share games with Xbox.bat" (it asks for administrator rights once).
$ErrorActionPreference = 'Stop'
$Account = 'xboxgames'
$Share = 'XboxGames'

function Pause-End($code) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null; exit $code }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

try {
Write-Host 'Game Vault - share games with your Xbox' -ForegroundColor Green
Write-Host ''

# 1. the folder
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
$dlg.Description = 'Choose the folder with your games (its subfolders are included)'
$dlg.ShowNewFolderButton = $false
$top = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}
if ($dlg.ShowDialog($top) -ne 'OK') { Write-Host 'No folder chosen.'; Pause-End 1 }
$Folder = $dlg.SelectedPath
if ($Folder.Length -le 3) {
    Write-Host "Please choose a folder, not a whole drive ($Folder): only your games should be shared." -ForegroundColor Yellow
    Pause-End 1
}
Write-Host "Folder: $Folder"

# 2. the account and its password (typed here, never shown or saved by this script)
Write-Host ''
Write-Host "Choose a password for the '$Account' account (8 characters or more)."
Write-Host 'You type it once on your phone when Game Vault asks; it is kept on the Xbox.'
do {
    $p1 = Read-Host -AsSecureString 'Password'
    $p2 = Read-Host -AsSecureString 'Same password again'
    $s1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
    $s2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
    $ok = $s1.Length -ge 8 -and $s1 -ceq $s2
    if (-not $ok) { Write-Host 'They do not match, or it is shorter than 8 characters. Again:' -ForegroundColor Yellow }
} until ($ok)
$s1 = $null; $s2 = $null

$user = Get-LocalUser -Name $Account -ErrorAction SilentlyContinue
if ($user) {
    Set-LocalUser -Name $Account -Password $p1 -PasswordNeverExpires $true
    Enable-LocalUser -Name $Account
} else {
    New-LocalUser -Name $Account -Password $p1 -PasswordNeverExpires -UserMayNotChangePassword `
        -Description 'Game Vault (Xbox): reads shared games only' | Out-Null
}
# not a member of Users: no sign-in on this PC, only network access to the share
Remove-LocalGroupMember -Group 'Users' -Member $Account -ErrorAction SilentlyContinue
$hide = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
New-Item -Force $hide | Out-Null
New-ItemProperty -Force $hide -Name $Account -Value 0 -PropertyType DWord | Out-Null

# 3. read-only access and the share
icacls "$Folder" /grant "${Account}:(OI)(CI)RX" | Out-Null
$existing = Get-SmbShare -Name $Share -ErrorAction SilentlyContinue
if ($existing -and $existing.Path -ne $Folder) { Remove-SmbShare -Name $Share -Force }
if (-not (Get-SmbShare -Name $Share -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $Share -Path "$Folder" -ReadAccess $Account | Out-Null
} else {
    Grant-SmbShareAccess -Name $Share -AccountName $Account -AccessRight Read -Force | Out-Null
}

# the home network must be Private for Windows to allow sharing on it (a Public one is for cafes and hotels)
$net = Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq 'Internet' } | Select-Object -First 1
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $net.InterfaceIndex -ErrorAction SilentlyContinue |
       Select-Object -First 1).IPAddress
Write-Host ''
if ($net -and $net.NetworkCategory -eq 'Public') {
    Write-Host "Your network '$($net.Name)' is set as Public." -ForegroundColor Yellow
    $a = Read-Host 'Is this your home network? Set it to Private so the Xbox can reach the share (y/n)'
    if ($a -match '^[yY]') { Set-NetConnectionProfile -InterfaceIndex $net.InterfaceIndex -NetworkCategory Private; Write-Host 'Set to Private.' }
}

Write-Host ''
Write-Host 'Done. On your phone (Game Vault, LT on the Xbox), type:' -ForegroundColor Green
Write-Host "   Computer:   \\$ip\$Share      (or \\$env:COMPUTERNAME\$Share)"
Write-Host "   User name:  $Account"
Write-Host '   Password:   the one you just chose'
Write-Host ''
Write-Host "To stop sharing later: run this again and close it, or remove the share '$Share' in Computer Management."
Pause-End 0
} catch {
    # the window stays open with what went wrong (no password is ever part of it)
    Write-Host ''
    Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
    "$(Get-Date) $($_.Exception.Message) | $($_.InvocationInfo.PositionMessage)" | Out-File -Append "$env:PUBLIC\Game Vault share error.txt"
    Write-Host "(also written to $env:PUBLIC\Game Vault share error.txt)"
    Pause-End 1
}
