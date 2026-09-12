<#
.SYNOPSIS
    Reverts everything Install-CofHdr.ps1 changed.

.DESCRIPTION
    Restores the game files from a backup taken by the installer, removes the
    files the installer added, drops the high-DPI override, and optionally
    resets the NVIDIA profile.

    Like the installer, it does not touch Windows HDR, Auto HDR or Steam launch
    options - it prints them as a checklist instead.

.PARAMETER BackupPath
    A specific backup folder under .\backup\. Defaults to backup\original,
    the pristine copy taken before the first install.

.EXAMPLE
    .\Uninstall-CofHdr.ps1 -WhatIf
    .\Uninstall-CofHdr.ps1 -InspectorPath C:\Tools\nvidiaProfileInspector.exe
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $GamePath,
    [string] $BackupPath,
    [string] $InspectorPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "   [ok]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "   [warn] $m" -ForegroundColor Yellow }

# --- Locate the game --------------------------------------------------------
function Find-CryOfFear {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }
    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches |
            ForEach-Object { $_.Matches } |
            ForEach-Object { $libraries += $_.Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in ($libraries | Select-Object -Unique)) {
        $c = Join-Path $lib 'steamapps\common\Cry of Fear'
        if (Test-Path (Join-Path $c 'cof.exe')) { return $c }
    }
    return $null
}

Write-Step 'Locating Cry of Fear'
if (-not $GamePath) { $GamePath = Find-CryOfFear }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath 'cof.exe'))) {
    throw "Cry of Fear not found. Pass -GamePath '<folder containing cof.exe>'."
}
$exe    = Join-Path $GamePath 'cof.exe'
$modDir = Join-Path $GamePath 'cryoffear'
Write-Ok $GamePath

# --- Pick a backup ----------------------------------------------------------
Write-Step 'Selecting backup'
if (-not $BackupPath) {
    # Prefer backup\original: it is the only copy guaranteed to predate any
    # change this package made. Dated folders may contain already-modified
    # files from a repeated install run.
    $pristine = Join-Path $root 'backup\original'
    if (Test-Path $pristine) {
        $BackupPath = $pristine
    } else {
        $backupRoot = Join-Path $root 'backup'
        if (Test-Path $backupRoot) {
            $BackupPath = (Get-ChildItem $backupRoot -Directory |
                           Sort-Object Name |
                           Select-Object -First 1).FullName
            if ($BackupPath) { Write-Warn 'No backup\original - using the OLDEST dated backup instead.' }
        }
    }
}
if ($BackupPath -and (Test-Path $BackupPath)) {
    Write-Ok $BackupPath
} else {
    Write-Warn 'No backup found. Added files will still be removed, but the stock'
    Write-Warn 'autoexec.cfg and black_fp.cg cannot be restored from here.'
    Write-Warn 'Steam > Cry of Fear > Properties > Installed Files > Verify will restore them.'
    $BackupPath = $null
}

# --- Remove files the installer added ---------------------------------------
Write-Step 'Removing installed files'
$sideCfg = Join-Path $modDir 'autoexec.hdr.cfg'
if (Test-Path $sideCfg) {
    if ($PSCmdlet.ShouldProcess($sideCfg, 'Remove')) {
        Remove-Item $sideCfg -Force; Write-Ok 'autoexec.hdr.cfg'
    }
}

# --- Restore from backup ----------------------------------------------------
if ($BackupPath) {
    Write-Step 'Restoring from backup'
    foreach ($item in @('autoexec.cfg', 'config.cfg', 'scriptsettings.dat')) {
        $src = Join-Path $BackupPath $item
        if (Test-Path $src) {
            if ($PSCmdlet.ShouldProcess((Join-Path $modDir $item), 'Restore')) {
                Copy-Item $src -Destination $modDir -Force; Write-Ok $item
            }
        }
    }
    # scheme files live in a sub-folder of the backup
    $resBak = Join-Path $BackupPath 'resource'
    if (Test-Path $resBak) {
        foreach ($sf in @('trackerscheme.res', 'clientscheme.res')) {
            $src = Join-Path $resBak $sf
            if (Test-Path $src) {
                $dst = Join-Path $modDir ('resource' + [char]92 + $sf)
                if ($PSCmdlet.ShouldProcess($dst, 'Restore scheme')) {
                    Copy-Item $src $dst -Force; Write-Ok "resource/$sf"
                }
            }
        }
    }

    $shaderBak = Join-Path $BackupPath 'black_fp.cg'
    if (Test-Path $shaderBak) {
        $dst = Join-Path $modDir 'cgshaders\black_fp.cg'
        if ($PSCmdlet.ShouldProcess($dst, 'Restore shader')) {
            Copy-Item $shaderBak -Destination $dst -Force; Write-Ok 'cgshaders\black_fp.cg'
        }
    }
    # SAVE is intentionally NOT restored: the player's progress since the
    # install is newer than the backup, and silently rolling it back would
    # destroy real playthrough data. The backup stays on disk either way.
    if (Test-Path (Join-Path $BackupPath 'SAVE')) {
        Write-Warn "Saves were NOT rolled back (yours are newer). Backup kept at:"
        Write-Warn "  $(Join-Path $BackupPath 'SAVE')"
    }
}

# --- Per-app Auto HDR override -----------------------------------------------
Write-Step 'Removing per-app Auto HDR override'
$gpuPrefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$appPref = (Get-ItemProperty -Path $gpuPrefKey -Name $exe -ErrorAction SilentlyContinue).$exe
if ($appPref) {
    if ($PSCmdlet.ShouldProcess($exe, 'Remove Auto HDR override')) {
        Remove-ItemProperty -Path $gpuPrefKey -Name $exe -Force
        Write-Ok "removed ($appPref) - the game falls back to the global Auto HDR setting"
    }
} else {
    Write-Ok 'nothing to remove'
}

# --- High-DPI override ------------------------------------------------------
Write-Step 'Removing high-DPI override'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$existing = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
if ($existing) {
    if ($PSCmdlet.ShouldProcess($exe, 'Remove HIGHDPIAWARE')) {
        $remaining = ($existing -split '\s+' | Where-Object { $_ -and $_ -ne 'HIGHDPIAWARE' -and $_ -ne '~' }) -join ' '
        if ($remaining) {
            Set-ItemProperty -Path $layers -Name $exe -Value "~ $remaining"
            Write-Ok "kept other compatibility flags: $remaining"
        } else {
            Remove-ItemProperty -Path $layers -Name $exe -Force
            Write-Ok 'removed'
        }
    }
} else {
    Write-Ok 'nothing to remove'
}

# --- NVIDIA profile ---------------------------------------------------------
Write-Step 'NVIDIA profile'
$reset = Join-Path $root 'install\cof-hdr-nvidia-reset.nip'
if ($InspectorPath -and (Test-Path $InspectorPath)) {
    if ($PSCmdlet.ShouldProcess($reset, 'Import reset profile')) {
        & $InspectorPath -silentImport $reset
        Write-Ok 'present method back to Auto, RTX HDR off'
    }
} else {
    Write-Warn 'No -InspectorPath given. Import this by hand to undo the profile:'
    Write-Warn "  $reset"
    Write-Warn 'Or delete the "Cry of Fear (HDR)" profile in NVIDIA Profile Inspector.'
}

@"

Remaining manual steps:

  [ ] Steam > Cry of Fear > Properties > Launch Options: clear them
  [ ] NVIDIA app: turn RTX HDR off for Cry of Fear (if you used route 3A)
  [ ] Windows HDR: back to whatever you prefer

Run tools\Test-CofHdr.ps1 to confirm the state.
"@ | Write-Host
