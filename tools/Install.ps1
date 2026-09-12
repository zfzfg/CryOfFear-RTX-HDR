<#
.SYNOPSIS
    Installs the Cry of Fear HDR & 1440p Enhancement Mod (portable).
#>
[CmdletBinding()]
param(
    [string] $GamePath,
    [double] $Fov = 1.15,
    [int]    $Width = 0,
    [int]    $Height = 0,
    [switch] $Windowed,
    [switch] $Shader,
    [switch] $SkipProfile,
    [switch] $Indicator,
    [switch] $ProfileOnly,
    $RawMouse = $true,
    $LowLatencyVsync = $true,
    $EngineRates = $true
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$pkgRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'Common.ps1')

$RawMouse = ConvertTo-FlexibleBool $RawMouse $true
$LowLatencyVsync = ConvertTo-FlexibleBool $LowLatencyVsync $true
$EngineRates = ConvertTo-FlexibleBool $EngineRates $true

function Write-Step { param($m) Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "   [ok]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "   [warn] $m" -ForegroundColor Yellow }

function Get-QualityNip {
    if ($Indicator) { return Join-Path $pkgRoot 'profiles\CryOfFear-HDR-Indicator.nip' }
    return Join-Path $pkgRoot 'profiles\CryOfFear-HDR-Quality.nip'
}

if ($ProfileOnly) {
    Write-Step 'Importing NVIDIA driver profile'
    $inspector = Join-Path $scriptRoot 'nvidiaProfileInspector\nvidiaProfileInspector.exe'
    $nip = Get-QualityNip
    $ok = Import-NvidiaProfile -InspectorPath $inspector -NipPath $nip
    if ($ok) {
        Write-Host '[PROFILE] imported'
        exit 0
    }
    Write-Host '[PROFILE] failed'
    exit 1
}

$installFailed = $false

Write-Step 'Locating Cry of Fear'
if (-not $GamePath) { $GamePath = Find-CryOfFear }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath 'cof.exe'))) {
    throw "Cry of Fear could not be located automatically. Please provide -GamePath '<path to Cry of Fear folder>'."
}
$exe    = Join-Path $GamePath 'cof.exe'
$modDir = Join-Path $GamePath 'cryoffear'
Write-Ok "Found game at: $GamePath"

Write-Step 'Backing up game files'
$backupDir = Get-BackupDir -PkgRoot $pkgRoot -Create
Write-Ok "Backup folder: $backupDir"

function Backup-IfMissing {
    param([string] $Relative, [switch] $Recurse)
    $src = Join-Path $modDir $Relative
    $dst = Join-Path $backupDir $Relative
    if (-not (Test-Path $src)) { return }
    if (Test-Path $dst) { return }
    $parent = Split-Path -Parent $dst
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item $src -Destination $dst -Recurse:$Recurse -Force
    Write-Ok "Backed up $Relative"
}

Backup-IfMissing 'autoexec.cfg'
Backup-IfMissing 'config.cfg'
Backup-IfMissing 'scriptsettings.dat'
Backup-IfMissing 'SAVE' -Recurse
Backup-IfMissing 'cgshaders\black_fp.cg'

Write-Step 'Deploying autoexec.cfg'
$srcCfg = Join-Path $pkgRoot 'files\autoexec.cfg'
$dstCfg = Join-Path $modDir 'autoexec.cfg'
if (-not (Test-Path $srcCfg)) { throw "Missing template: $srcCfg" }
$how = Merge-Autoexec -TemplatePath $srcCfg -DestinationPath $dstCfg -Fov $Fov -RawMouse $RawMouse -LowLatencyVsync $LowLatencyVsync -EngineRates $EngineRates
Write-Ok "autoexec.cfg $how (FOV $('{0:F2}' -f $Fov))"

Write-Step 'Setting High-DPI override for cof.exe'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
if (-not (Test-Path $layers)) { New-Item -Path $layers -Force | Out-Null }
$existing = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
if ($existing -and $existing -notmatch 'HIGHDPIAWARE') {
    Set-ItemProperty -Path $layers -Name $exe -Value "$existing HIGHDPIAWARE"
} elseif (-not $existing) {
    Set-ItemProperty -Path $layers -Name $exe -Value '~ HIGHDPIAWARE'
}
Write-Ok 'Application-controlled DPI scaling enabled'

Write-Step 'Configuring display resolution & mode in registry'
if ($Width -le 0 -or $Height -le 0) {
    $mode = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1
    if ($mode) {
        $Width  = [int]$mode.CurrentHorizontalResolution
        $Height = [int]$mode.CurrentVerticalResolution
    } else {
        $Width  = 2560
        $Height = 1440
    }
}

$regKey = 'HKCU:\Software\Valve\Cry of Fear\Settings'
if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
Set-ItemProperty -Path $regKey -Name 'ScreenWidth' -Value $Width
Set-ItemProperty -Path $regKey -Name 'ScreenHeight' -Value $Height
Set-ItemProperty -Path $regKey -Name 'SCREENWINDOWED' -Value $(if ($Windowed) { 1 } else { 0 })
Write-Ok "Resolution set to: ${Width}x${Height} ($(if ($Windowed) { 'Windowed' } else { 'Fullscreen' }))"

Write-Step 'Windows HDR & Auto HDR'
$hdr = Get-DisplayHdrStatus
if (-not $hdr.Queried) {
    Write-Warn 'Could not query display HDR state. Check Settings > System > Display > HDR by hand.'
} elseif ($hdr.AnyOn) {
    foreach ($row in $hdr.Rows) {
        if ($row.On) { Write-Ok "$($row.Tech) - Windows HDR on, $($row.Bpc) bit" }
    }
} else {
    foreach ($row in $hdr.Rows) {
        if ($row.Supported) { Write-Warn "$($row.Tech) - HDR capable but OFF" }
    }
    Write-Warn 'Windows HDR is off. RTX HDR needs it: Settings > System > Display > HDR.'
}

$autoHdrValue = Set-PerAppAutoHdrOff -ExePath $exe
Write-Ok "Auto HDR disabled for cof.exe only ($autoHdrValue)"
if ($hdr.AnyOn) {
    Write-Ok 'Windows HDR is on, so the per-app Auto HDR override is required to keep RTX HDR from stacking two tone mappers.'
}

$shaderDst = Join-Path $modDir 'cgshaders\black_fp.cg'
$shaderBak = Join-Path $backupDir 'cgshaders\black_fp.cg'
if ($Shader) {
    Write-Step 'Installing softened black_fp.cg shader'
    $shaderSrc = Join-Path $pkgRoot 'files\cgshaders\black_fp.cg'
    if (Test-Path $shaderSrc) {
        if ((Test-Path $shaderDst) -and -not (Test-Path $shaderBak)) {
            $bakParent = Split-Path -Parent $shaderBak
            if (-not (Test-Path $bakParent)) { New-Item -ItemType Directory -Path $bakParent -Force | Out-Null }
            Copy-Item $shaderDst $shaderBak -Force
            Write-Ok 'Backed up stock black_fp.cg'
        }
        Copy-Item -Path $shaderSrc -Destination $shaderDst -Force
        Write-Ok "Installed $shaderDst"
        Write-Warn 'This overwrites a shipped game file. Steam file verification reverts it.'
    } else {
        Write-Warn "Missing $shaderSrc - skipped."
    }
} elseif ((Test-SoftenedShader -Path $shaderDst) -and (Test-Path $shaderBak)) {
    Write-Step 'Restoring stock black_fp.cg (soften shader off)'
    Copy-Item $shaderBak $shaderDst -Force
    Write-Ok 'Stock nightmare shader restored'
}

if ($SkipProfile) {
    Write-Host '[PROFILE] skipped'
} else {
    Write-Step 'Importing NVIDIA driver quality profile (Route 3B)'
    $inspector = Join-Path $scriptRoot 'nvidiaProfileInspector\nvidiaProfileInspector.exe'
    $nip = Get-QualityNip
    $imported = Import-NvidiaProfile -InspectorPath $inspector -NipPath $nip
    if ($imported) {
        Write-Host '[PROFILE] imported'
    } else {
        Write-Host '[PROFILE] failed'
        Write-Warn 'Driver profile was not imported. RTX HDR will not apply until you re-run and accept UAC.'
        $installFailed = $true
    }
}

Write-Step 'Steam launch options'
$steamArgs = Get-LaunchOptions -Width $Width -Height $Height -Windowed:$Windowed
$steamWrite = Set-SteamLaunchOptions -LaunchOptions $steamArgs -BackupDir $backupDir
if ($steamWrite.Written) {
    Write-Ok "Wrote launch options for $($steamWrite.Paths.Count) Steam account(s)"
    Write-Host "[STEAM] written"
} elseif ($steamWrite.Reason -eq 'steam-running') {
    Write-Warn 'Steam is running - launch options were NOT written (Steam would overwrite the file on exit).'
    Write-Warn 'Close Steam and click Install again, or paste the line below into Steam Properties.'
    Write-Host '[STEAM] not-written'
} elseif ($steamWrite.Reason -eq 'no-app-entry' -or $steamWrite.Reason -eq 'no-localconfig') {
    Write-Warn 'Cry of Fear has no Steam launch-options slot yet (launch it once from Steam, then re-run Install).'
    Write-Host '[STEAM] not-written'
} else {
    Write-Warn "Could not write Steam launch options ($($steamWrite.Reason)). Paste them manually."
    Write-Host '[STEAM] not-written'
}

if ($installFailed) {
    Write-Step 'Install finished with errors'
} else {
    Write-Step 'Installation Complete!'
}

$steamHint = if ($steamWrite.Written) {
    "Launch options were written to Steam. Close Steam if it is open so it reloads them, then start Cry of Fear."
} else {
    @"
Paste this into Steam > Cry of Fear > Properties > Launch Options:
  $steamArgs
"@
}

Write-Host @"

$steamHint

Checklist:
  [ ] Windows HDR ON     Settings > System > Display > HDR
  [ ] Auto HDR for Cry of Fear is already off (per-app override)
  [ ] Run Windows HDR Calibration from the Microsoft Store if you have not
  [ ] Steam launch options as above

Saves were backed up under $backupDir\SAVE and will not be reverted on uninstall.

"@ -ForegroundColor $(if ($installFailed) { 'Yellow' } else { 'Green' })

if ($installFailed) { exit 1 }
exit 0
