# Copyright (c) 2026 Skitzelles - part of Game Vault, https://github.com/skitzellez/xbox-game-vault
# PolyForm Noncommercial License 1.0.0: not for sale, and this notice stays in every copy.
# Game Vault all-in-one setup for an Xbox Series X|S or Xbox One in Dev Mode. Run it on a Windows PC that is
# on the same network as the console (double-click "Install Game Vault.bat").
#
# What it does, through the console's Device Portal:
#   1. installs or updates Game Vault and xemu (from their GitHub releases) and the emulators Game Vault starts:
#      RetroArch, Dolphin, XBSX2, PPSSPP, Flycast, (Series X|S) Xenia for Game Vault, and Moonlight for streaming
#      games from your PC. On a Series X|S, RetroArch and XBSX2 are our own builds
#      ("RetroArch for Game Vault", "XBSX2 for Game Vault": any USB drive works, saves live on it), and what the
#      original RetroArch / XBSX2 apps held (settings, saves, states, BIOS files, memory cards) is copied over;
#      the others come from their own projects;
#   2. puts the free PlayStation BIOS (OpenBIOS) in place, and any BIOS files of your own that it finds in a
#      folder or drive you point it at;
#   3. tells Game Vault which BIOS files are there, so it can pick the right emulator for each system.
# Nothing copyrighted is downloaded or included: no games and no console BIOS files.
#
# Options (all optional; without them the script asks):
#   -Console <address>   -User <name>   -Password <password>
#   -BiosFolder <path>   a folder or drive letter to search for your own BIOS files ("none" to skip)
#   -Skip <names>        components to leave out, e.g. -Skip RetroArch,Dolphin
#   -Force <names>       install these again even when the console already has that version
#   -Yes                 do not ask for confirmation
param(
    [string]$Console, [string]$User, [string]$Password, [string]$BiosFolder,
    [string[]]$Skip = @(), [string[]]$Force = @(), [switch]$Yes
)
$ErrorActionPreference = "Stop"
# started through the .bat file, "-Skip A,B" arrives as one piece of text
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Force = @($Force | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path $env:LOCALAPPDATA "GameVaultSetup"
$cache = Join-Path $work "downloads"
New-Item -ItemType Directory -Force $cache | Out-Null
$jar = Join-Path $work "portal_cookies.txt"
Remove-Item -LiteralPath $jar -ErrorAction SilentlyContinue      # a stale cookie file makes the console answer 403

function Json($text) { if ($text) { (($text | Out-String) | ConvertFrom-Json) } }
function Say($text, $color = "Gray") { Write-Host $text -ForegroundColor $color }
function Head($text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }

Say ""
Say "Game Vault setup, by Skitzelles" "White"
Say "Installs Game Vault, xemu and the emulators it uses on an Xbox in Dev Mode."
Say "No games and no console BIOS files are downloaded or included."

# ---------------------------------------------------------------------------------------------------
Head "1. The console"
if (-not $Console) {
    Say "On the Xbox: Dev Home > Remote Access Settings > enable Xbox Device Portal, and set a user name and"
    Say "password there. Dev Home shows the console's address at the top left (for example 192.168.0.25)."
    $Console = Read-Host "Console address"
}
$Console = ($Console -replace '^https?://', '') -replace '[:/].*$', ''
if (-not $User) { $User = Read-Host "Device Portal user name" }
if (-not $Password) {
    $sec = Read-Host "Device Portal password" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$B = "https://${Console}:11443"
$cred = "${User}:${Password}"

function Portal { curl.exe -sk -u $cred -b $jar -c $jar @args }
function Token {
    Portal "$B/api/os/info" | Out-Null
    $t = ""
    if (Test-Path -LiteralPath $jar) {
        foreach ($line in Get-Content -LiteralPath $jar) {
            $p = $line -split "`t"
            if ($p.Count -ge 7 -and $p[5] -eq "CSRF-Token") { $t = $p[6] }
        }
    }
    return $t
}

$info = $null
try { $info = Json (Portal -m 15 "$B/api/os/info") } catch { }
if (-not $info -or -not $info.Platform) {
    Say "Could not reach the console's Device Portal at $B." "Red"
    Say "Check: the console is on and in Dev Mode, the address is right, Device Portal is enabled in Dev Home,"
    Say "and the user name and password are the ones set there. Then run this again."
    exit 1
}
Say "Connected: $($info.Platform) `"$($info.ComputerName)`"" "Green"
$series = $info.Platform -match "Series"

# Dev Home's "treat UWP apps as games by default" (Device Portal setting DefaultUWPContentTypeToGame): apps
# installed after it is on (and the console restarted) start as type Game with full memory, instead of the
# player changing App type by hand for each. Nothing else on the console changes.
try {
    $st = Json (Portal -m 15 "$B/ext/settings")
    $gameType = $st.Settings | Where-Object { $_.Name -eq "DefaultUWPContentTypeToGame" } | Select-Object -First 1
    if ($gameType -and $gameType.Value -ne "true") {
        # the body from a file: Windows PowerShell 5.1 drops the quotes inside an argument passed to curl
        $body = Join-Path $env:TEMP "gamevault-setting.json"
        [IO.File]::WriteAllText($body, '{"Value":"true"}')
        $tok = Token
        Portal -m 15 -X PUT -H "X-CSRF-Token: $tok" -H "Content-Type: application/json" --data-binary "@$body" "$B/ext/settings/DefaultUWPContentTypeToGame" -o NUL
        Remove-Item -LiteralPath $body -ErrorAction SilentlyContinue
        Say "   new apps will start as type Game (takes effect after the console restarts)" "DarkGray"
    }
} catch { }

function Packages { (Json (Portal "$B/api/app/packagemanager/packages")).InstalledPackages }
function Installed($prefix) { Packages | Where-Object { $_.PackageFullName -like "$prefix*" } | Select-Object -First 1 }

# ---------------------------------------------------------------------------------------------------
# Downloads. A finished download leaves a ".ok" file next to it, so an interrupted one is fetched again.
function Fetch($url, $name) {
    $file = Join-Path $cache $name
    if ((Test-Path -LiteralPath "$file.ok") -and (Test-Path -LiteralPath $file)) { return $file }
    Remove-Item -LiteralPath $file, "$file.ok" -ErrorAction SilentlyContinue
    Say "   downloading $name"
    curl.exe -L --fail --retry 3 -# -o $file $url
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $file)) { throw "download failed: $url" }
    Set-Content -LiteralPath "$file.ok" -Value $url
    return $file
}
function Releases($repo, $count = 5) {   # $count: a shared download repository holds many projects
    $json = curl.exe -sL -m 30 -H "User-Agent: GameVaultSetup" "https://api.github.com/repos/$repo/releases?per_page=$count"
    $r = Json $json
    if (-not $r -or ($r -isnot [array] -and $r.message -and -not $r.tag_name)) { throw "could not read the release list of $repo (GitHub may be limiting requests; try again in an hour)" }
    # newest first by publishing time: GitHub's own order follows the date of the release's commit, which
    # is the same for releases made from an unchanged branch
    return @($r | Sort-Object { $_.published_at } -Descending)
}
# Newest release of a GitHub project that has a file matching $pattern: its version text and download address.
function FromGitHub($repo, $pattern, $count = 5) {
    foreach ($rel in (Releases $repo $count)) {
        $a = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
        if ($a) {
            $ver = if ($a.name -match '(\d+(\.\d+)+)') { $Matches[1] } else { $rel.tag_name -replace '^[^\d]*', '' }
            return @{ Url = $a.browser_download_url; Name = $a.name; Version = $ver; Size = [int]($a.size / 1MB) }
        }
    }
    throw "no file matching $pattern in the releases of $repo"
}

$components = @(
    @{ Key = "GameVault"; Title = "Game Vault (the launcher)"; Prefix = "GamerDad.GameVault"; Game = $true
       Get = { FromGitHub "skitzellez/xbox-game-vault" '^GameVault_.*x64\.appx$' } },
    @{ Key = "xemu"; Title = "xemu (original Xbox)"; Prefix = "GamerDad.Xemu"; Game = $true
       Get = { FromGitHub "skitzellez/xemu-uwp" '^Xemu_.*x64\.appx$' } },
    # Xbox 360: Xenia for Game Vault (Series X|S only): our build of DanP's Xenia Canary port. It reads 360 games
    # from any USB drive through Game Vault and makes its own profile.
    @{ Key = "Xenia"; Title = "Xenia for Game Vault (Xbox 360)"; Prefix = "GamerDad.XeniaForGameVault"; Game = $true
       SeriesOnly = $true
       Get = { FromGitHub "skitzellez/Xenia-GameVault" '^XeniaForGameVault_.*_x64\.appx$' } },
    # Series X|S: our builds (any USB drive, saves on it). Xbox One: the original ones, built for its older CPU.
    @{ Key = "RetroArch"; Title = "RetroArch (PlayStation, cartridge and CD systems)"; Game = $true
       Prefix = $(if ($series) { "GamerDad.RetroArchForGameVault" } else { "1e4cf179-f3c2-404f-b9f3-cb2070a5aad8" })
       Get = { if ($series) { FromGitHub "skitzellez/RetroArch-GameVault" '^RetroArch-for-GameVault_.*x64\.appx$' }
               else { $r = FromGitHub "XboxEmulationHub/RetroArch" '^RetroArch-XboxOne-AllCores\.appx$'; $r.Version = ""; $r } } },
    # Dolphin for Game Vault: the Xbox Dolphin 1.1.9 with Game Vault's fix (games started from Game Vault no longer
    # crash back to Dev Home); its own link, so an original Dolphin installed by hand stays as it is.
    @{ Key = "Dolphin"; Title = "Dolphin for Game Vault (GameCube, Wii)"; Prefix = "GamerDad.DolphinForGameVault"; Game = $true
       Get = { FromGitHub "skitzellez/Dolphin-GameVault" '^DolphinForGameVault_.*_x64\.appx$' } },
    @{ Key = "XBSX2"; Title = "XBSX2 (PlayStation 2)"; Game = $true
       Prefix = $(if ($series) { "GamerDad.XBSX2ForGameVault" } else { "595c25f0-b370-4d7a-9b14-3027fbd69ecf" })
       Get = { if ($series) { FromGitHub "skitzellez/XBSX2-GameVault" '^XBSX2-for-GameVault_.*\.msixbundle$' }
               else { FromGitHub "XboxEmulationHub/XBSX2" 'SSE4\.msixbundle$' } } },
    @{ Key = "PPSSPP"; Title = "PPSSPP (PSP)"; Prefix = "0ad29e1a-1069-4cf5-8c97-620892505f0c"; Game = $true
       Get = { $tag = ((Releases "hrydgard/ppsspp") | Where-Object { -not $_.prerelease } | Select-Object -First 1).tag_name -replace '^v', ''
               @{ Url = "https://www.ppsspp.org/files/$($tag -replace '\.', '_')/ppsspp_uwp.zip"; Name = "ppsspp_uwp_$tag.zip"; Version = $tag; Size = 28; Zip = $true } } },
    @{ Key = "Flycast"; Title = "Flycast (Dreamcast)"; Prefix = "AF75D068-D5AC-3D3C-B52A-2791C2F3491A"; Game = $true
       Get = { FromGitHub "flyinghead/flycast" '^flycast-.*\.appx$' } },
    # Moonlight (TheElixZammuto/moonlight-xbox, GPL-3.0, not ours): streams games from a PC running Sunshine or
    # GeForce Experience. Its Dev Mode build also needs Microsoft's XAML runtime, which comes in the same release.
    @{ Key = "Moonlight"; Title = "Moonlight (stream games from your PC)"; Prefix = "50497EliaZammuto.MoonlightUWP"
       Get = { $pkg = '^moonlight-xbox-dx_.*_x64\.msixbundle$'; $xaml = '^Microsoft\.UI\.Xaml\..*\.appx$'
               $rel = Releases "TheElixZammuto/moonlight-xbox" | Where-Object { ($_.assets.name -match $pkg) -and ($_.assets.name -match $xaml) } |
                      Select-Object -First 1
               if (-not $rel) { throw "no Dev Mode build in the releases of TheElixZammuto/moonlight-xbox" }
               $a = $rel.assets | Where-Object { $_.name -match $pkg } | Select-Object -First 1
               $x = $rel.assets | Where-Object { $_.name -match $xaml } | Select-Object -First 1
               $ver = if ($a.name -match '(\d+(\.\d+)+)') { $Matches[1] } else { $rel.tag_name }
               @{ Url = $a.browser_download_url; Name = $a.name; Version = $ver; Size = [int]($a.size / 1MB)
                  Extra = @{ Url = $x.browser_download_url; Name = $x.name } } } }
)

# ---------------------------------------------------------------------------------------------------
Head "2. What will be installed"
$plan = @()
foreach ($c in $components) {
    if ($Skip -contains $c.Key) { Say ("   {0,-52} left out (-Skip)" -f $c.Title); continue }
    if ($c.SeriesOnly -and -not $series) { Say ("   {0,-52} needs an Xbox Series X|S" -f $c.Title) "DarkGray"; continue }
    try { $src = & $c.Get } catch { Say ("   {0,-52} cannot be checked: {1}" -f $c.Title, $_.Exception.Message) "Yellow"; continue }
    $have = Installed $c.Prefix
    $haveVer = if ($have) { "{0}.{1}.{2}.{3}" -f $have.Version.Major, $have.Version.Minor, $have.Version.Build, $have.Version.Revision } else { "" }
    # "2.7" on the download page and "2.7.1.0" on the console are the same release
    $same = $have -and (($src.Version -eq "") -or $haveVer.StartsWith($src.Version))
    if ($same -and ($Force -notcontains $c.Key)) {
        Say ("   {0,-52} already installed ({1})" -f $c.Title, $haveVer) "DarkGray"
    } else {
        $what = if ($have) { "update $haveVer -> $($src.Version)" } else { "install $($src.Version)" }
        Say ("   {0,-52} {1}, {2} MB" -f $c.Title, $what, $src.Size) "White"
        $plan += @{ C = $c; Src = $src; New = -not $have }
    }
}
if ($plan.Count -and -not $Yes) {
    $a = Read-Host "Download and install these now? [Y/n]"
    if ($a -match '^[nN]') { $plan = @() }
}

# The Visual C++ runtime package every one of these apps depends on. It comes inside PPSSPP's official
# download (signed by Microsoft); the console keeps one copy for all apps.
$vclibs = $null
function VcLibs {
    if ($script:vclibs) { return $script:vclibs }
    $pp = & ($components | Where-Object { $_.Key -eq "PPSSPP" }).Get
    $dir = Unpack (Fetch $pp.Url $pp.Name)
    $script:vclibs = (Get-ChildItem -LiteralPath $dir -Recurse -Filter "Microsoft.VCLibs.x64*.appx" | Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1).FullName
    return $script:vclibs
}
function Unpack($zip) {
    $dir = "$zip.files"
    if (-not (Test-Path -LiteralPath $dir)) { Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force }
    return $dir
}

function InstallPackage($file, [string[]]$dependencies) {   # the runtime packages it needs go with it
    $tok = Token
    $form = @("-F", "f=@$file")
    $i = 0
    foreach ($d in $dependencies) { if ($d) { $form += @("-F", "dep$(if ($i) { $i })=@$d"); $i++ } }
    $name = [uri]::EscapeDataString((Split-Path -Leaf $file))
    Portal -m 1800 -H "X-CSRF-Token: $tok" -H "Expect:" @form "$B/api/app/packagemanager/package?package=$name" -o NUL
    for ($i = 0; $i -lt 300; $i++) {
        Start-Sleep -Seconds 2
        $s = Portal "$B/api/app/packagemanager/state"
        if (-not $s -or $s -match 'in progress') { continue }
        try { return (Json $s) } catch { return @{ Success = $false; Reason = "$s" } }
    }
    return @{ Success = $false; Reason = "the console did not finish within ten minutes" }
}

Head "3. Installing"
$failed = @()
if (-not $plan.Count) { Say "   nothing to install" "DarkGray" }
$firstStart = @()   # new installs to start once (below)
$fresh = @()        # apps this run installed for the first time
foreach ($p in $plan) {
    $c = $p.C; $src = $p.Src
    Say " - $($c.Title)" "White"
    try {
        $file = Fetch $src.Url $src.Name
        if ($src.Zip) {
            # the package inside the download, not the runtime packages in its Dependencies folder
            $file = (Get-ChildItem -LiteralPath (Unpack $file) -Recurse -File |
                     Where-Object { $_.Extension -match '^\.(msix|msixbundle|appx)$' -and $_.FullName -notmatch 'Dependencies' } |
                     Select-Object -First 1).FullName
            if (-not $file) { throw "no package found inside the download" }
        }
        Say "   sending to the console and installing (large ones take a few minutes)"
        $deps = @(VcLibs)
        if ($src.Extra) { $deps += Fetch $src.Extra.Url $src.Extra.Name }   # Moonlight: the XAML runtime
        $r = InstallPackage $file $deps
        # believe the console's package list, not only its answer
        if ($r.Success -and (Installed $c.Prefix)) {
            Say "   done" "Green"
            # every emulator Game Vault starts (Game Vault itself is started at the end)
            if ($c.Game -and $c.Key -ne "GameVault") { $firstStart += $c }
            if ($p.New) { $fresh += $c.Key }
        }
        else { Say "   FAILED: $($r.Reason) $($r.CodeText)" "Red"; $failed += $c.Title }
    } catch { Say "   FAILED: $($_.Exception.Message)" "Red"; $failed += $c.Title }
}

# ---------------------------------------------------------------------------------------------------
# Files into an app's own folder on the console.
function Enc($path) { ($path -split '\\' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '%5C' }
$script:made = @{}
function MakeDir($pfn, $path) {      # \LocalState\a\b, one level at a time
    $parts = $path.TrimStart('\') -split '\\'
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $parent = '\' + ($parts[0..($i - 1)] -join '\'); $key = "$pfn|$parent\$($parts[$i])"
        if ($script:made[$key]) { continue }
        $tok = Token
        Portal -X POST -H "X-CSRF-Token: $tok" -H "Content-Length: 0" "$B/api/filesystem/apps/folder?knownfolderid=LocalAppData&packagefullname=$pfn&path=$(Enc $parent)&newfoldername=$([uri]::EscapeDataString($parts[$i]))" -o NUL
        $script:made[$key] = $true
    }
}
function PutFile($pfn, $dir, $file, $as) {
    MakeDir $pfn $dir
    $tmp = Join-Path $work "upload"; New-Item -ItemType Directory -Force $tmp | Out-Null
    $copy = Join-Path $tmp $as; Copy-Item -LiteralPath $file $copy -Force
    $tok = Token
    # quoted: a comma or semicolon in the name would cut it up
    $code = Portal -m 600 -H "X-CSRF-Token: $tok" -H "Expect:" -F "f=@`"$($copy -replace '\\', '/')`"" "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$pfn&path=$(Enc $dir)" -o NUL -w "%{http_code}"
    Remove-Item -LiteralPath $copy
    return $code -eq "200"
}
function Md5($file) { (Get-FileHash -LiteralPath $file -Algorithm MD5).Hash.ToLower() }

function StartApp($p) {
    $tok = Token
    Portal -X POST -H "X-CSRF-Token: $tok" -H "Content-Length: 0" "$B/api/taskmanager/app?appid=$(B64 $p.PackageRelativeId)&package=$(B64 $p.PackageFullName)" -o NUL
}
function StopApp($p) {
    $tok = Token
    Portal -X DELETE -H "X-CSRF-Token: $tok" "$B/api/taskmanager/app?package=$(B64 $p.PackageFullName)" -o NUL
}
function B64($s) { [uri]::EscapeDataString([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))) }

# A Device Portal install is ready only for the console's own account until the app is started once; until then
# Game Vault cannot start it for the player (the console says 0x80070002). One start through the portal does it.
foreach ($c in $firstStart) {
    $p = Installed $c.Prefix
    if (-not $p) { continue }
    Say "   starting $($c.Title) once so the console makes it ready for you" "DarkGray"
    StartApp $p
    Start-Sleep -Seconds 10
    StopApp $p
}
function Items($pfn, $dir) {
    $j = Json (Portal -m 60 "$B/api/filesystem/apps/files?knownfolderid=LocalAppData&packagefullname=$pfn&path=$(Enc $dir)")
    if ($j -and $j.Items) { return @($j.Items) }
    return @()
}
# Copies folders and files of an app's LocalState into another app's, leaving alone what the new one has.
# Settings files get the old package's folder names replaced by the new one's.
function CopyAppData($from, $to, [string[]]$names) {
    $tmp = Join-Path $work "move"; New-Item -ItemType Directory -Force $tmp | Out-Null
    $oldFam = $from.PackageFamilyName; $newFam = $to.PackageFamilyName
    $count = 0
    $queue = New-Object System.Collections.Queue
    foreach ($i in (Items $from.PackageFullName '\LocalState')) {
        if ($names -contains $i.Name) { $queue.Enqueue(@('\LocalState', $i)) }
    }
    $have = @{}
    while ($queue.Count) {
        $dir, $i = $queue.Dequeue()
        $path = "$dir\$($i.Name)"
        if ($i.Type -band 16) {
            MakeDir $to.PackageFullName $path
            foreach ($c in (Items $from.PackageFullName $path)) { $queue.Enqueue(@($path, $c)) }
            continue
        }
        if (-not $have.ContainsKey($dir)) { $have[$dir] = @((Items $to.PackageFullName $dir) | ForEach-Object { $_.Name.ToLower() }) }
        if ($have[$dir] -contains $i.Name.ToLower()) { continue }
        $f = Join-Path $tmp $i.Name
        Portal -m 1800 "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$($from.PackageFullName)&filename=$([uri]::EscapeDataString($i.Name))&path=$(Enc $dir)" -o $f
        if ($i.Name -match '\.(cfg|ini|opt|lpl|rmp)$' -and $oldFam -and $newFam) {
            $t = [IO.File]::ReadAllText($f); [IO.File]::WriteAllText($f, $t.Replace($oldFam, $newFam), (New-Object Text.UTF8Encoding $false))
        }
        $tok = Token
        $code = Portal -m 1800 -H "X-CSRF-Token: $tok" -H "Expect:" -F "f=@`"$($f -replace '\\', '/')`"" "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$($to.PackageFullName)&path=$(Enc $dir)" -o NUL -w "%{http_code}"
        Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue
        if ($code -eq "200") { $count++ } else { Say "   could not copy $path" "Yellow" }
    }
    return $count
}
# Only into a new app this run installed for the first time: one already in use keeps its own settings (they
# would be replaced by the old app's). A mark in the new app's own storage says it was done, so a second
# computer or a cleared cache never does it again. The new app's storage exists once it has run; its first
# settings file makes way for the old one.
function MoveOver($key, $oldPrefix, $newPrefix, $title, $settingsDir, $settingsFile, [string[]]$names) {
    if ($fresh -notcontains $key) { return }
    $old = Installed $oldPrefix; $new = Installed $newPrefix
    if (-not $old -or -not $new) { return }
    $done = Join-Path $work "moved-$newPrefix.txt"
    if (Test-Path -LiteralPath $done) { return }
    if (Items $new.PackageFullName '\LocalState' | Where-Object { $_.Name -eq "gamevault-moved.txt" }) { return }
    Say " - $title"
    if (-not (Items $new.PackageFullName '\LocalState').Count) {
        StartApp $new; Start-Sleep -Seconds 12; StopApp $new; Start-Sleep -Seconds 2
    }
    $tok = Token
    Portal -X DELETE -H "X-CSRF-Token: $tok" "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$($new.PackageFullName)&filename=$settingsFile&path=$(Enc $settingsDir)" -o NUL
    $n = CopyAppData $old $new $names
    Say "   $n files copied from the original app (it stays installed; you can remove it in Dev Home)" "Green"
    Set-Content -LiteralPath $done -Value (Get-Date)
    PutFile $new.PackageFullName '\LocalState' $done "gamevault-moved.txt" | Out-Null
}
if ($series) {
    Head "3b. Moving over what the original apps had"
    MoveOver "RetroArch" "1e4cf179-f3c2-404f-b9f3-cb2070a5aad8" "GamerDad.RetroArchForGameVault" "RetroArch: settings, saves, states, BIOS files" '\LocalState' "retroarch.cfg" @("retroarch.cfg", "config", "saves", "states", "system", "playlists")
    MoveOver "XBSX2" "595c25f0-b370-4d7a-9b14-3027fbd69ecf" "GamerDad.XBSX2ForGameVault" "XBSX2: settings, BIOS files, memory cards, states" '\LocalState\inis' "PCSX2.ini" @("inis", "bios", "memcards", "sstates", "gamesettings", "inputprofiles")
}
# every console: Dolphin for Game Vault takes the place of the original Dolphin (memory cards, Wii saves, states)
MoveOver "Dolphin" "3143e227-cbe5-41c4-aaa9-cf40132a1b22" "GamerDad.DolphinForGameVault" "Dolphin: settings, memory cards, Wii saves, states" '\LocalState\Config' "Dolphin.ini" @("Config", "GC", "Wii", "StateSaves", "GameSettings")

Head "4. BIOS files"
$ra = (Installed $(if ($series) { "GamerDad.RetroArchForGameVault" } else { "1e4cf179-f3c2-404f-b9f3-cb2070a5aad8" })).PackageFullName
$xbsx2 = (Installed $(if ($series) { "GamerDad.XBSX2ForGameVault" } else { "595c25f0-b370-4d7a-9b14-3027fbd69ecf" })).PackageFullName
$flycast = (Installed "AF75D068-D5AC-3D3C-B52A-2791C2F3491A").PackageFullName
$xemu = (Installed "GamerDad.Xemu").PackageFullName
$vault = (Installed "GamerDad.GameVault").PackageFullName
$sys = '\LocalState\system'
$status = @{}       # what Game Vault is told: system -> what is there

if (-not $BiosFolder) {
    Say "Some systems need BIOS files that are copyrighted and must come from consoles you own: PlayStation 2,"
    Say "Saturn and Sega CD. PlayStation and the original Xbox get free replacements (Xbox: offline play only;"
    Say "your own Xbox boot ROM and BIOS add online play)."
    Say "If you have such files, type the folder or drive they are in (a USB stick, for example E:)."
    $BiosFolder = Read-Host "Folder or drive to search, or just Enter to skip"
}
if ($BiosFolder -match '^[A-Za-z]:?$') { $BiosFolder = $BiosFolder.Substring(0, 1) + ":\" }

# name on your drive (lower case) -> where it goes. Names are the ones the emulators look for.
$byName = @{
    "scph1001.bin" = @("ps1"); "scph5500.bin" = @("ps1"); "scph5501.bin" = @("ps1"); "scph5502.bin" = @("ps1"); "scph7001.bin" = @("ps1")
    "sega_101.bin" = @("saturn"); "mpr-17933.bin" = @("saturn"); "saturn_bios.bin" = @("saturn")
    "bios_cd_u.bin" = @("segacd"); "bios_cd_e.bin" = @("segacd"); "bios_cd_j.bin" = @("segacd")
    "32x_g_bios.bin" = @("32x"); "32x_m_bios.bin" = @("32x"); "32x_s_bios.bin" = @("32x")
    "gba_bios.bin" = @("gba"); "gbc_bios.bin" = @("gbc"); "gb_bios.bin" = @("gb"); "bios.gg" = @("gamegear")
    "bios7.bin" = @("ds"); "bios9.bin" = @("ds"); "firmware.bin" = @("ds")
    "5200.rom" = @("atari5200"); "7800 bios (u).rom" = @("atari7800"); "lynxboot.img" = @("lynx"); "syscard3.pce" = @("pcenginecd")
    "dc_boot.bin" = @("dreamcast"); "dc_flash.bin" = @("dreamcast")
}
$found = 0
if ($BiosFolder -and $BiosFolder -ne "none" -and (Test-Path -LiteralPath $BiosFolder)) {
    Say "   searching $BiosFolder"
    $files = Get-ChildItem -LiteralPath $BiosFolder -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -le 16MB }
    foreach ($f in $files) {
        $low = $f.Name.ToLower(); $ok = $null; $what = $null
        if ($byName.ContainsKey($low) -and $ra) {
            $system = $byName[$low][0]; $what = "$($f.Name)  ->  RetroArch ($system)"
            $dir = if ($system -eq "dreamcast") { "$sys\dc" } else { $sys }
            $ok = PutFile $ra $dir $f.FullName $f.Name
            if ($system -eq "dreamcast" -and $flycast) { PutFile $flycast '\LocalState\data' $f.FullName $f.Name | Out-Null }
            if ($ok) { $status[$system] = "yes" }
        } elseif ($f.Length -eq 4194304 -and $low -match 'scph|ps2' -and $low -match '\.bin$' -and $xbsx2) {
            $what = "$($f.Name)  ->  XBSX2 (PlayStation 2)"; $ok = PutFile $xbsx2 '\LocalState\bios' $f.FullName $f.Name
            if ($ok) { $status["ps2"] = "yes" }
        } elseif ($f.Length -eq 512 -and $xemu -and (Md5 $f.FullName) -eq "d49c52a4102f6df7bcf8d0617ac475ed") {
            $what = "$($f.Name)  ->  xemu (Xbox boot ROM)"; $ok = PutFile $xemu '\LocalState\xemu\xemu' $f.FullName "mcpx_1.0.bin"
            if ($ok) { $status["xboxmcpx"] = "yes" }
        } elseif (@(262144, 524288, 1048576) -contains $f.Length -and $low -match '\.(bin|rom)$' -and $xemu -and
                  ($low -match 'complex|cromwell|evox|xbox|4627|4034|4817|5101|5530|5713|5838|xecuter' -or $f.DirectoryName -match 'xbox|xemu') -and
                  $low -notmatch '^(scph|sega|mpr-|saturn|bios_cd|dc_)|spiritboot' -and -not $status["xboxbios"]) {
            $what = "$($f.Name)  ->  xemu (Xbox BIOS)"; $ok = PutFile $xemu '\LocalState\xemu\xemu' $f.FullName "bios.bin"
            if ($ok) { $status["xboxbios"] = "yes" }
        }
        if ($what) { $found++; if ($ok) { Say "   $what" "Green" } else { Say "   $what  FAILED" "Red" } }
    }
    if (-not $found) { Say "   no BIOS files recognised there (they are found by the names the emulators expect)" "Yellow" }
} elseif ($BiosFolder -and $BiosFolder -ne "none") {
    Say "   $BiosFolder does not exist; skipped" "Yellow"
}

# PlayStation: the free OpenBIOS (PCSX-Redux project, MIT licence) unless a real BIOS was just installed.
if ($ra -and -not $status["ps1"]) {
    $ob = Join-Path $here "files\openbios.bin"; $opt = Join-Path $here "files\SwanStation.opt"
    if ((Test-Path -LiteralPath $ob) -and (PutFile $ra $sys $ob "openbios.bin") -and (PutFile $ra '\LocalState\config\SwanStation' $opt "SwanStation.opt")) {
        Say "   PlayStation: free OpenBIOS installed (no file of yours needed)" "Green"
        $status["ps1"] = "openbios"
    } else { Say "   PlayStation: the free OpenBIOS could not be installed" "Yellow" }
}
# ScummVM: the engine data files and themes the libretro ScummVM core needs (free, from libretro's own server).
# Without them some games stop at "Unable to locate the ... engine data file". The marker file says which
# pack is installed, so it is uploaded once.
$scummUrl = "https://buildbot.libretro.com/assets/system/ScummVM.zip"
if ($ra) {
    $mark = Join-Path $work "scummvm-mark.tmp"; Remove-Item -LiteralPath $mark -ErrorAction SilentlyContinue
    $code = Portal -m 60 "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$ra&filename=gamevault-scummvm.txt&path=$(Enc "$sys\scummvm")" -o $mark -w "%{http_code}"
    if ($code -ne "200") {
        try {
            $dir = Unpack (Fetch $scummUrl "ScummVM.zip")
            $files = Get-ChildItem -LiteralPath (Join-Path $dir "scummvm") -Recurse -File
            $ok = 0
            foreach ($f in $files) {
                $rel = $f.DirectoryName.Substring((Join-Path $dir "scummvm").Length)
                if (PutFile $ra "$sys\scummvm$rel" $f.FullName $f.Name) { $ok++ }
            }
            $note = Join-Path $work "gamevault-scummvm.txt"; Set-Content -LiteralPath $note -Value $scummUrl
            if ($ok -eq $files.Count -and (PutFile $ra "$sys\scummvm" $note "gamevault-scummvm.txt")) {
                Say "   ScummVM: engine data installed ($ok files)" "Green"
            } else { Say "   ScummVM: only $ok of $($files.Count) engine data files could be installed" "Yellow" }
        } catch { Say "   ScummVM: engine data could not be downloaded ($_)" "Yellow" }
    }
}
if ($xemu -and -not $status["xboxmcpx"]) {
    Say "   Original Xbox: games play with the free BIOS that comes with xemu (offline only). For online play,"
    Say "   put your own boot ROM and BIOS on the games USB drive; Game Vault picks them up by itself."
}

# Tell Game Vault. Lines of system=value; a system that is not listed keeps what an earlier run said.
if ($vault) {
    $old = @{}
    $tmpOld = Join-Path $work "bios_old.txt"
    Portal "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$vault&filename=bios.txt&path=%5CLocalState" -o $tmpOld
    if (Test-Path -LiteralPath $tmpOld) {
        foreach ($l in Get-Content -LiteralPath $tmpOld) { if ($l -match '^([a-z0-9]+)=([a-z]+)$') { $old[$Matches[1]] = $Matches[2] } }
    }
    foreach ($k in $status.Keys) { $old[$k] = $status[$k] }
    $bios = Join-Path $work "bios.txt"
    Set-Content -LiteralPath $bios -Value (($old.Keys | Sort-Object | ForEach-Object { "$_=$($old[$_])" }) -join "`n") -Encoding ascii
    if (PutFile $vault '\LocalState' $bios "bios.txt") { Say "   Game Vault told what is installed" "DarkGray" }
}

# ---------------------------------------------------------------------------------------------------
Head "5. Controllers"
# XBSX2 (PlayStation 2) writes its first settings file with no buttons assigned (seen with 2.0.9.1): nothing
# on the controller does anything in a game. Its settings file gets the usual layout for two controllers
# here: A = Cross, B = Circle, X = Square, Y = Triangle, Menu = Start, View = Select. (Pressing both sticks
# in opens XBSX2's own menu; that one it sets up by itself.)
function GetText($pfn, $dir, $name) {
    $f = Join-Path $work "fetched.tmp"
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f }
    $code = Portal -m 60 "$B/api/filesystem/apps/file?knownfolderid=LocalAppData&packagefullname=$pfn&filename=$([uri]::EscapeDataString($name))&path=$(Enc $dir)" -o $f -w "%{http_code}"
    if ($code -ne "200" -or -not (Test-Path -LiteralPath $f)) { return $null }
    return [IO.File]::ReadAllText($f)
}
function PadButtons($n) {
    $names = "Up=DPadUp", "Right=DPadRight", "Down=DPadDown", "Left=DPadLeft", "Triangle=FaceNorth", "Circle=FaceEast",
             "Cross=FaceSouth", "Square=FaceWest", "Select=Back", "Start=Start", "L1=LeftShoulder", "L2=+LeftTrigger",
             "R1=RightShoulder", "R2=+RightTrigger", "L3=LeftStick", "R3=RightStick", "LUp=-LeftY", "LRight=+LeftX",
             "LDown=+LeftY", "LLeft=-LeftX", "RUp=-RightY", "RRight=+RightX", "RDown=+RightY", "RLeft=-RightX",
             "LargeMotor=LargeMotor", "SmallMotor=SmallMotor"
    $names | ForEach-Object { $kv = $_ -split '=', 2; "$($kv[0]) = SDL-$n/$($kv[1])" }
}
# The settings text with buttons added to controller ports 1 and 2, where a port has none. $null: nothing to add.
function AddPadButtons($text) {
    $nl = "`n"; if ($text.Contains("`r`n")) { $nl = "`r`n" }
    $changed = $false
    foreach ($n in 0, 1) {
        $m = [regex]::Match($text, "(?ms)^\[Pad$($n + 1)\]\r?\n(.*?)(?=^\[|\z)")
        if (-not $m.Success) { continue }
        $lines = @($m.Groups[1].Value -split '\r?\n' | Where-Object { $_.Trim() })
        if ($lines | Where-Object { $_ -match '^Cross\s*=' }) { continue }           # has buttons already
        $type = ($lines | Where-Object { $_ -match '^Type\s*=' } | Select-Object -First 1) -replace '^Type\s*=\s*', ''
        if ($n -eq 1 -and $type -eq "None") {
            # a second controller: the same kind and settings as the first
            $first = [regex]::Match($text, "(?ms)^\[Pad1\]\r?\n(.*?)(?=^\[|\z)").Groups[1].Value
            $lines = @($first -split '\r?\n' | Where-Object { $_.Trim() -and $_ -notmatch 'SDL-' })
            $type = "DualShock2"
        }
        if ($type -ne "DualShock2") { continue }
        $section = (@("[Pad$($n + 1)]") + $lines + (PadButtons $n) + @("", "", "")) -join $nl
        $text = $text.Substring(0, $m.Index) + $section + $text.Substring($m.Index + $m.Length)
        $changed = $true
    }
    if ($changed) { return $text }
    return $null
}

$xp = Installed $(if ($series) { "GamerDad.XBSX2ForGameVault" } else { "595c25f0-b370-4d7a-9b14-3027fbd69ecf" })
if (-not $xp) { Say "   XBSX2 is not installed: nothing to do" "DarkGray" }
else {
    $inis = '\LocalState\inis'
    $ini = GetText $xp.PackageFullName $inis "PCSX2.ini"
    if (-not $ini -or $ini -notmatch '(?m)^\[Pad1\]') {
        # XBSX2 writes its settings the first time it runs
        Say "   starting XBSX2 for a moment so that it writes its settings"
        StartApp $xp
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep -Seconds 3
            $ini = GetText $xp.PackageFullName $inis "PCSX2.ini"
            if ($ini -and $ini -match '(?m)^\[Pad1\]') { Start-Sleep -Seconds 2; $ini = GetText $xp.PackageFullName $inis "PCSX2.ini"; break }
        }
        StopApp $xp; Start-Sleep -Seconds 2
    }
    if (-not $ini -or $ini -notmatch '(?m)^\[Pad1\]') {
        Say "   XBSX2's settings could not be read. Start XBSX2 once on the console, close it, and run this again." "Yellow"
    } else {
        $new = AddPadButtons $ini
        if (-not $new) { Say "   XBSX2 (PlayStation 2): buttons are set up already" "DarkGray" }
        else {
            StopApp $xp; Start-Sleep -Seconds 2      # a running XBSX2 would write its old settings back
            $f = Join-Path $work "PCSX2.ini"
            [IO.File]::WriteAllText($f, $new, (New-Object Text.UTF8Encoding $false))
            if (PutFile $xp.PackageFullName $inis $f "PCSX2.ini") { Say "   XBSX2 (PlayStation 2): buttons set up for two controllers" "Green" }
            else { Say "   XBSX2 (PlayStation 2): the settings could not be written" "Yellow" }
        }
    }
}

# ---------------------------------------------------------------------------------------------------
# Games drives plugged into this PC. Our own builds read any drive through Game Vault, but other emulators
# (Xenia for Xbox 360) open game files directly: on a drive that does not let apps read it, the console asks a
# permission question it never shows and the emulator waits on a black screen. Read access for apps
# ("ALL APPLICATION PACKAGES", S-1-15-2-1) fixes that for good. Nothing is erased; only NTFS drives have it.
Head "6. Games drives on this PC"
# needed on an Xbox One (the original emulators) or with the original Xenia Canary app only; on a Series X|S our
# builds read every drive through Game Vault
$needDrives = (-not $series) -or (-not (Installed "GamerDad.XeniaForGameVault") -and (Installed "27d6ba69-e4f1-4b69-b391-8238bab5a431"))
$usb = @()
if (-not $needDrives) {
    Say "   not needed: Game Vault and its emulators read games from any USB drive" "DarkGray"
} else {
    try {
        $usb = @(Get-Disk | Where-Object { $_.BusType -eq 'USB' } | Get-Partition | Get-Volume |
                 Where-Object { $_.DriveLetter } | Sort-Object DriveLetter)
    } catch { }
    if (-not $usb.Count) {
        Say "   No USB drive is plugged into this PC. To make a games drive ready, plug it in here and run the setup"
        Say "   again (it only needs this once per drive)." "DarkGray"
    }
}
foreach ($v in $usb) {
    $root = "$($v.DriveLetter):\"
    $label = if ($v.FileSystemLabel) { " `"$($v.FileSystemLabel)`"" } else { "" }
    $size = "{0:N0} GB" -f ($v.Size / 1GB)
    if ($v.FileSystem -ne 'NTFS') {
        Say "   $root$label ($($v.FileSystem), $size): Xbox 360 games need an NTFS drive; the other systems play from it as it is." "DarkGray"
        continue
    }
    $acl = (icacls $root 2>$null) -join "`n"
    if ($acl -match 'ALL APPLICATION PACKAGES:\(OI\)\(CI\)') { Say "   $root$label ($size): ready" "DarkGray"; continue }
    $ok = $Yes
    if (-not $Yes) { $ok = (Read-Host "   $root$label ($size): let the Xbox apps read games on it? Nothing is erased. [Y/n]") -notmatch '^[nN]' }
    if (-not $ok) { Say "   $root left as it is" "DarkGray"; continue }
    Say "   $root giving apps read access (on a big drive this takes a minute)"
    icacls $root /grant "*S-1-15-2-1:(OI)(CI)RX" /T /C /Q 2>$null | Out-Null
    if (-not (((icacls $root 2>$null) -join "`n") -match 'ALL APPLICATION PACKAGES:\(OI\)\(CI\)')) {
        # a drive's top folder usually belongs to the administrators: ask Windows once (its usual Yes/No window)
        Say "   Windows asks for permission to change the drive: choose Yes in its window"
        try {
            Start-Process -FilePath "icacls.exe" -ArgumentList "$root /grant *S-1-15-2-1:(OI)(CI)RX /T /C /Q" `
                -Verb RunAs -Wait -WindowStyle Hidden
        } catch { }
    }
    if (((icacls $root 2>$null) -join "`n") -match 'ALL APPLICATION PACKAGES:\(OI\)\(CI\)') { Say "   $root ready" "Green" }
    else { Say "   $root could not be changed (Windows said no, or the drive is read-only)" "Yellow" }
}

# ---------------------------------------------------------------------------------------------------
Head "7. What to do on the console"
Say "a) Give the apps full memory. In Dev Home > Games and apps, for each of these: select it, View details,"
Say "   and change App type from App to Game:"
foreach ($c in $components) { if (Installed $c.Prefix) { Say "      $($c.Title)" "White" } }
Say "   (A new install starts as type App, which is too little memory for most of them. If it already says Game,"
Say "   there is nothing to do: this setup turns on Dev Home's 'treat apps as games' setting for new installs.)"
if ($series) {
    Say "b) Put your games on any USB drive (FAT32, exFAT or NTFS) and plug it in. Game Vault makes a Game Vault"
    Say "   folder on it for your saves and BIOS files; new BIOS files go in Game Vault\bios."
    if (-not (Installed "GamerDad.XeniaForGameVault") -and (Installed "27d6ba69-e4f1-4b69-b391-8238bab5a431")) {
        # the original Xenia Canary port (installed by hand): it opens games itself and asks for a profile
        Say "   With the original Xenia Canary app, Xbox 360 games need an NTFS drive that step 6 has prepared; open"
        Say "   it once from Dev Home and choose Create Profile. Xenia for Game Vault (this setup) needs neither."
    }
} else {
    Say "b) Games go on a USB drive formatted NTFS, with access for apps. On this PC, with the drive as X: (the"
    Say "   first command erases the drive):"
    Say "      format X: /FS:NTFS /Q" "White"
    Say "      icacls X:\ /grant `"*S-1-15-2-1:(OI)(CI)F`"" "White"
}
Say ""
if ($failed.Count) { Say "Finished, but these did not install: $($failed -join ', '). Run the setup again to retry." "Yellow"; exit 2 }
Say "Finished. Start Game Vault on the console and plug in your games." "Green"
