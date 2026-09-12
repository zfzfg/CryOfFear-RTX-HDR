<#
.SYNOPSIS
    Packs the distributable release archive.

.DESCRIPTION
    Collects exactly the files that belong in a release - no backups, no git
    metadata, nothing from the user's game folder - and writes a versioned zip.

.PARAMETER Version
    Version string for the archive name. Read from CHANGELOG.md if omitted.

.EXAMPLE
    .\Build-Release.ps1
#>
[CmdletBinding()]
param([string] $Version)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $Version) {
    $line = Select-String -Path (Join-Path $root 'CHANGELOG.md') -Pattern '^##\s+([0-9]+\.[0-9]+\.[0-9]+)' |
            Select-Object -First 1
    $Version = if ($line) { $line.Matches[0].Groups[1].Value } else { '0.0.0' }
}

# Explicit allow-list. A release should never be "everything except what I
# remembered to exclude" - backups and stray game files must not leak out.
$include = @(
    'README.md'
    'CHANGELOG.md'
    'LICENSE'
    'HDRmodCOF.md'
    'install\KURZANLEITUNG.md'
    'install\autoexec.cfg'
    'install\cof-hdr-nvidia-app.nip'
    'install\cof-hdr-nvidia-app-quality.nip'
    'install\cof-hdr-nvidia-driver.nip'
    'install\cof-hdr-nvidia-driver-quality.nip'
    'install\cof-hdr-nvidia-driver-quality-noaa.nip'
    'install\cof-hdr-nvidia-driver-indicator.nip'
    'install\cof-hdr-nvidia-reset.nip'
    'install\cgshaders\black_fp.cg'
    'tools\Install-CofHdr.ps1'
    'tools\Uninstall-CofHdr.ps1'
    'tools\Test-CofHdr.ps1'
    'tools\Set-CofFontScale.ps1'
    'tools\Import-Profile.bat'
)

$staging = Join-Path ([System.IO.Path]::GetTempPath()) "cof-hdr-$Version"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

$missing = @()
foreach ($rel in $include) {
    $src = Join-Path $root $rel
    if (-not (Test-Path $src)) { $missing += $rel; continue }
    $dst = Join-Path $staging $rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
    Copy-Item $src $dst -Force
}

if ($missing.Count) {
    Remove-Item $staging -Recurse -Force
    throw "Release is incomplete, missing:`n  $($missing -join "`n  ")"
}

$outDir = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$zip = Join-Path $outDir "cof-hdr-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip
Remove-Item $staging -Recurse -Force

$size = [math]::Round((Get-Item $zip).Length / 1KB, 1)
Write-Host "Built $zip ($size KB, $($include.Count) files)" -ForegroundColor Green
