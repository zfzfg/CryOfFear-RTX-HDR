<#
.SYNOPSIS
    Installs the local, file-based part of the Cry of Fear HDR setup.

.DESCRIPTION
    Handles only what can honestly be automated:
      1. locates the Cry of Fear install,
      2. backs up saves and configs,
      3. installs autoexec.cfg (never silently overwriting an existing one),
      4. sets the high-DPI override for cof.exe,
      5. optionally imports the NVIDIA profile (.nip) via NVIDIA Profile Inspector.

    Windows HDR, Auto HDR and the Steam launch options are NOT touched: they are
    user-facing OS settings, and silently changing them is exactly the kind of
    thing an install script should not do. The script prints them as a checklist.

.PARAMETER GamePath
    Path to the "Cry of Fear" folder (the one containing cof.exe).
    Auto-detected from the Steam library if omitted.

.PARAMETER InspectorPath
    Path to nvidiaProfileInspector.exe. If given, the .nip is imported silently.

.PARAMETER DriverPath
    Import the driver-level profile (no NVIDIA app) instead of the NVOverlay one.
    See HDRmodCOF.md Step 3 for why the app route is recommended.

.PARAMETER Shader
    Also install the softened black_fp.cg (the black-and-white nightmare effect).
    Opt-in, because unlike autoexec.cfg this overwrites a file Cry of Fear ships,
    which Steam's file verification will revert. See HDRmodCOF.md section 9.2.

.PARAMETER Quality
    Also import the image-quality profile: 16x anisotropic filtering, 8x MSAA,
    transparency supersampling. GoldSrc offers none of this itself.

.PARAMETER NoAA
    With -Quality, import the variant without MSAA and transparency
    supersampling. Use it if forcing MSAA misbehaves alongside RTX HDR.

.PARAMETER Fonts
    Also scale the menu fonts for displays taller than 1200 px, by calling
    Set-CofFontScale.ps1. Does not affect the in-game HUD, which cannot be
    scaled - see that script's help.

.EXAMPLE
    .\Install-CofHdr.ps1 -WhatIf
    .\Install-CofHdr.ps1 -InspectorPath C:\Tools\nvidiaProfileInspector.exe
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $GamePath,
    [string] $InspectorPath,
    [switch] $DriverPath,
    [switch] $Shader,
    [switch] $Quality,
    [switch] $NoAA,
    [switch] $Fonts
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "   [ok]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "   [warn] $m" -ForegroundColor Yellow }

# --- 1. Locate the game -----------------------------------------------------
function Find-CryOfFear {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }

    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        # Each library root appears as a quoted "path" value in the VDF.
        Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches |
            ForEach-Object { $_.Matches } |
            ForEach-Object { $libraries += $_.Groups[1].Value -replace '\\\\', '\' }
    }

    foreach ($lib in ($libraries | Select-Object -Unique)) {
        $candidate = Join-Path $lib 'steamapps\common\Cry of Fear'
        if (Test-Path (Join-Path $candidate 'cof.exe')) { return $candidate }
    }
    return $null
}

Write-Step 'Locating Cry of Fear'
if (-not $GamePath) { $GamePath = Find-CryOfFear }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath 'cof.exe'))) {
    throw "Cry of Fear not found. Pass -GamePath '<folder containing cof.exe>'."
}
$exe     = Join-Path $GamePath 'cof.exe'
$modDir  = Join-Path $GamePath 'cryoffear'
Write-Ok $GamePath

if (-not (Test-Path (Join-Path $GamePath 'opengl32.dll'))) {
    Write-Warn "opengl32.dll missing from the game root. That is the Paranoia renderer; without it the game falls back to software rendering and there are no highlights for HDR to expand."
}

# --- 2. Back up -------------------------------------------------------------
Write-Step 'Backing up saves and configs'
# The FIRST backup is the only one that holds pristine game files. A second
# install run would otherwise back up files this script already modified, and
# the uninstaller would then "restore" the modded state. So the pristine copy
# lives at backup\original and is written exactly once; later runs add a dated
# copy for reference only.
$pristine  = Join-Path $root 'backup\original'
$isFirst   = -not (Test-Path $pristine)
$backupDir = if ($isFirst) { $pristine }
             else { Join-Path $root ('backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }

if (-not $isFirst) {
    Write-Warn "Pristine backup already exists at $pristine - keeping it."
    Write-Warn 'This run only adds a dated reference copy.'
}

if ($PSCmdlet.ShouldProcess($backupDir, 'Create backup')) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    foreach ($item in @('SAVE', 'autoexec.cfg', 'config.cfg', 'scriptsettings.dat')) {
        $src = Join-Path $modDir $item
        if (Test-Path $src) {
            Copy-Item $src -Destination $backupDir -Recurse -Force
            Write-Ok "$item"
        }
    }
    # The shader is only touched with -Shader, but back it up unconditionally:
    # a backup of a file you did not change costs nothing, a missing one costs
    # a Steam verification.
    $shaderSrc = Join-Path $modDir ('cgshaders' + [char]92 + 'black_fp.cg')
    if (Test-Path $shaderSrc) {
        Copy-Item $shaderSrc -Destination $backupDir -Force
        Write-Ok 'cgshaders/black_fp.cg'
    }
    Write-Ok "backup at $backupDir"
}

# --- 3. Install autoexec.cfg ------------------------------------------------
Write-Step 'Installing autoexec.cfg'
$srcCfg = Join-Path $root 'install\autoexec.cfg'
$dstCfg = Join-Path $modDir 'autoexec.cfg'

if (-not (Test-Path $srcCfg)) { throw "Missing $srcCfg" }

# Match fps_max to the refresh rate, but never above 100: this engine build
# has no fps_override cvar at all (a byte search of hw.dll/sw.dll finds only
# fps_max and fps_modem), and clamps fps_max to 100 internally. Writing a
# higher number would just look like a setting that does not work.
$cfgText = Get-Content $srcCfg -Raw
$refresh = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.CurrentRefreshRate } |
            Select-Object -First 1).CurrentRefreshRate
if ($refresh) {
    $target = [Math]::Min([int]$refresh, 100)
    $cfgText = $cfgText -replace '(?m)^(fps_max\s+)\d+', "`${1}$target"
    if ([int]$refresh -gt 100) {
        Write-Ok "fps_max set to $target (display runs at $refresh Hz, but the engine caps at 100)"
    } else {
        Write-Ok "fps_max matched to display: $target"
    }
}

if (Test-Path $dstCfg) {
    # An existing autoexec may carry gameplay-relevant lines. Never clobber it:
    # install alongside and let the user merge.
    $side = Join-Path $modDir 'autoexec.hdr.cfg'
    if ($PSCmdlet.ShouldProcess($side, 'Write config for manual merge')) {
        Set-Content -Path $side -Value $cfgText -Encoding ASCII -NoNewline
        Write-Warn "An autoexec.cfg already exists. Wrote '$side' instead - merge it by hand."
        Write-Warn "The original is backed up in $backupDir."
    }
} else {
    if ($PSCmdlet.ShouldProcess($dstCfg, 'Install config')) {
        Set-Content -Path $dstCfg -Value $cfgText -Encoding ASCII -NoNewline
        Write-Ok $dstCfg
    }
}

# --- 4. High-DPI override ---------------------------------------------------
Write-Step 'Setting high-DPI override for cof.exe'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
if ($PSCmdlet.ShouldProcess($exe, 'Set HIGHDPIAWARE')) {
    if (-not (Test-Path $layers)) { New-Item -Path $layers -Force | Out-Null }
    $existing = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
    if ($existing -and $existing -notmatch 'HIGHDPIAWARE') {
        Set-ItemProperty -Path $layers -Name $exe -Value "$existing HIGHDPIAWARE"
    } elseif (-not $existing) {
        Set-ItemProperty -Path $layers -Name $exe -Value '~ HIGHDPIAWARE'
    }
    Write-Ok 'application-controlled DPI scaling'
}

# --- 5. Optional: softened post-effect shader -------------------------------
if ($Shader) {
    Write-Step 'Installing softened black_fp.cg'
    $srcShader = Join-Path $root ('install' + [char]92 + 'cgshaders' + [char]92 + 'black_fp.cg')
    $dstShader = Join-Path $modDir ('cgshaders' + [char]92 + 'black_fp.cg')
    if (-not (Test-Path $srcShader)) {
        Write-Warn "Missing $srcShader - skipped."
    } elseif (-not (Test-Path (Split-Path -Parent $dstShader))) {
        Write-Warn 'No cgshaders folder in this install - skipped.'
    } else {
        if ($PSCmdlet.ShouldProcess($dstShader, 'Overwrite shipped shader')) {
            Copy-Item $srcShader $dstShader -Force
            Write-Ok $dstShader
            Write-Warn 'This overwrites a shipped game file. Steam file verification reverts it.'
        }
    }
}

# --- 6. Optional: menu font scaling ----------------------------------------
if ($Fonts) {
    $fontTool = Join-Path $PSScriptRoot 'Set-CofFontScale.ps1'
    if (Test-Path $fontTool) {
        & $fontTool -GamePath $GamePath -WhatIf:$WhatIfPreference
    } else {
        Write-Warn "Missing $fontTool - skipped."
    }
}

# --- 7. NVIDIA profile ------------------------------------------------------
Write-Step 'NVIDIA profile'
# Each .nip describes the COMPLETE profile - importing one replaces the
# previous. Importing a quality-only file would silently drop the RTX HDR
# settings, which is exactly what happened the first time this was tried. So
# pick one combined file instead of layering imports.
$nip = if ($DriverPath -and $Quality -and $NoAA) { 'cof-hdr-nvidia-driver-quality-noaa.nip' }
       elseif ($DriverPath -and $Quality)        { 'cof-hdr-nvidia-driver-quality.nip' }
       elseif ($DriverPath)                      { 'cof-hdr-nvidia-driver.nip' }
       elseif ($Quality)                         { 'cof-hdr-nvidia-app-quality.nip' }
       else                                      { 'cof-hdr-nvidia-app.nip' }
$nip = Join-Path $root (Join-Path 'install' $nip)

if ($InspectorPath -and (Test-Path $InspectorPath)) {
    if ($PSCmdlet.ShouldProcess($nip, 'Import via NVIDIA Profile Inspector')) {
        & $InspectorPath -silentImport $nip
        Write-Ok "imported $(Split-Path -Leaf $nip)"
    }
} else {
    Write-Warn 'No -InspectorPath given. Import this by hand with NVIDIA Profile Inspector:'
    Write-Warn "  $nip"
}

# --- 8. What the script deliberately does not do ----------------------------
$mode = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1
$res = if ($mode) { "-w $($mode.CurrentHorizontalResolution) -h $($mode.CurrentVerticalResolution)" }
       else { '-w <width> -h <height>' }

@"

Remaining manual steps (these are OS/Steam settings - do them yourself):

  [ ] Windows HDR ON:  Settings > System > Display > HDR
  [ ] Auto HDR OFF     (same page - it must not run alongside RTX HDR)
  [ ] Run 'Windows HDR Calibration' from the Microsoft Store
  [ ] Steam > Cry of Fear > Properties > Launch Options (the -noforce*
      flags stop the engine re-enabling Windows mouse acceleration):
          -window -noborder $res -console -noforcemparms -noforcemaccel -noforcemspd
  [ ] Enable RTX HDR for Cry of Fear in the NVIDIA app (unless using -DriverPath)

Then run tools\Test-CofHdr.ps1 to verify, and see HDRmodCOF.md section 4 for tuning.
"@ | Write-Host
