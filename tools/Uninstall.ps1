<#
.SYNOPSIS
    Reverts Cry of Fear HDR & 1440p Mod back to stock (portable).
#>
[CmdletBinding()]
param(
    [string] $GamePath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$pkgRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'Common.ps1')

function Write-Step { param($m) Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "   [ok]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "   [warn] $m" -ForegroundColor Yellow }

Write-Step 'Locating Cry of Fear'
if (-not $GamePath) { $GamePath = Find-CryOfFear }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath 'cof.exe'))) {
    throw "Cry of Fear could not be located automatically."
}
$exe    = Join-Path $GamePath 'cof.exe'
$modDir = Join-Path $GamePath 'cryoffear'
Write-Ok "Found game at: $GamePath"

Write-Step 'Restoring files from pristine backup'
$backupDir = Get-BackupDir -PkgRoot $pkgRoot
if (Test-Path $backupDir) {
    foreach ($item in @('autoexec.cfg', 'config.cfg', 'scriptsettings.dat')) {
        $src = Join-Path $backupDir $item
        if (Test-Path $src) {
            Copy-Item $src -Destination $modDir -Force
            Write-Ok "Restored $item"
        }
    }
    $shaderBak = Join-Path $backupDir 'cgshaders\black_fp.cg'
    if (Test-Path $shaderBak) {
        Copy-Item $shaderBak -Destination (Join-Path $modDir 'cgshaders\black_fp.cg') -Force
        Write-Ok "Restored cgshaders/black_fp.cg"
    }
    if (Test-Path (Join-Path $backupDir 'SAVE')) {
        Write-Warn 'Saves were NOT rolled back (yours are newer than the backup).'
        Write-Warn "  Backup kept at: $(Join-Path $backupDir 'SAVE')"
    }
} else {
    Write-Warn "No backup folder found. Verifying files via Steam will restore stock state."
}

Write-Step 'Removing per-app Auto HDR override'
$removed = Reset-PerAppAutoHdr -ExePath $exe
if ($null -eq $removed) {
    Write-Ok 'nothing to remove'
} elseif ($removed -eq '') {
    Write-Ok 'Auto HDR override removed - game follows the global Auto HDR setting again'
} else {
    Write-Ok "Auto HDR override removed, kept other GPU prefs: $removed"
}

Write-Step 'Removing High-DPI override'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$existing = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
if ($existing) {
    $remaining = ($existing -split '\s+' | Where-Object { $_ -and $_ -ne 'HIGHDPIAWARE' -and $_ -ne '~' }) -join ' '
    if ($remaining) {
        Set-ItemProperty -Path $layers -Name $exe -Value "~ $remaining"
        Write-Ok "Kept other flags: $remaining"
    } else {
        Remove-ItemProperty -Path $layers -Name $exe -Force
        Write-Ok 'High-DPI override removed'
    }
} else {
    Write-Ok 'nothing to remove'
}

Write-Step 'Resetting NVIDIA driver profile'
$inspector = Join-Path $scriptRoot 'nvidiaProfileInspector\nvidiaProfileInspector.exe'
$resetNip = Join-Path $pkgRoot 'profiles\CryOfFear-HDR-Reset.nip'
$resetOk = Import-NvidiaProfile -InspectorPath $inspector -NipPath $resetNip
if ($resetOk) {
    Write-Host '[PROFILE] imported'
} else {
    Write-Host '[PROFILE] failed'
    Write-Warn 'Driver profile was not reset. Re-run Uninstall and accept UAC, or import profiles\CryOfFear-HDR-Reset.nip by hand.'
}

if ($resetOk) {
    Write-Step 'Uninstallation Complete!'
    Write-Host "`nCry of Fear has been restored back to its vanilla state (saves were not touched).`n" -ForegroundColor Green
    exit 0
}

Write-Step 'Uninstall finished with errors'
Write-Host "`nGame files were restored, but the NVIDIA profile reset did not complete.`n" -ForegroundColor Yellow
exit 1
