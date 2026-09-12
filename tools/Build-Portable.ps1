<#
.SYNOPSIS
    Packs CryOfFear-HDR-Portable into dist/ from an explicit allow-list.
#>
[CmdletBinding()]
param([string] $Version)

$ErrorActionPreference = 'Stop'
$pkgRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $pkgRoot)

if (-not $Version) {
    $line = Select-String -Path (Join-Path $pkgRoot 'CHANGELOG.md') -Pattern '^##\s+([0-9]+\.[0-9]+\.[0-9]+)' |
            Select-Object -First 1
    $Version = if ($line) { $line.Matches[0].Groups[1].Value } else { '0.0.0' }
}

$include = @(
    'CryOfFearHDRConfig.exe'
    'INSTALL.bat'
    'UNINSTALL.bat'
    'DIAGNOSE.bat'
    'LICENSE'
    'README.md'
    'QUICKSTART.txt'
    'CHANGELOG.md'
    'files\autoexec.cfg'
    'files\cgshaders\black_fp.cg'
    'profiles\CryOfFear-HDR-Quality.nip'
    'profiles\CryOfFear-HDR-Indicator.nip'
    'profiles\CryOfFear-HDR-Reset.nip'
    'src\Program.cs'
    'tools\Common.ps1'
    'tools\Install.ps1'
    'tools\Uninstall.ps1'
    'tools\Test.ps1'
    'tools\Build-Config.ps1'
    'tools\Build-Portable.ps1'
    'tools\nvidiaProfileInspector\nvidiaProfileInspector.exe'
    'tools\nvidiaProfileInspector\nvidiaProfileInspector.exe.config'
    'tools\nvidiaProfileInspector\Reference.xml'
)

$exe = Join-Path $pkgRoot 'CryOfFearHDRConfig.exe'
if (-not (Test-Path $exe)) {
    Write-Host 'CryOfFearHDRConfig.exe missing - compiling...' -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'Build-Config.ps1')
}

$staging = Join-Path ([System.IO.Path]::GetTempPath()) "CryOfFear-HDR-Portable-$Version"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$missing = @()
foreach ($rel in $include) {
    $src = Join-Path $pkgRoot $rel
    if (-not (Test-Path $src)) { $missing += $rel; continue }
    $dst = Join-Path $staging $rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
    Copy-Item $src $dst -Force
}

if ($missing.Count) {
    Remove-Item $staging -Recurse -Force
    throw "Release is incomplete, missing:`n  $($missing -join "`n  ")"
}

$outDir = Join-Path $repoRoot 'dist'
if (-not (Test-Path $outDir)) { $outDir = Join-Path $pkgRoot '..\..\dist' }
$outDir = [IO.Path]::GetFullPath($outDir)
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$zip = Join-Path $outDir "CryOfFear-HDR-Portable-v$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip
Remove-Item $staging -Recurse -Force

# Guard against leaking saves / inspector junk (allow-list should already prevent this).
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $leaks = @($archive.Entries | Where-Object {
        $_.FullName -match '(?i)SAVE[/\\]|\.pdb$|CustomProfiles_|^backup[/\\]'
    })
    if ($leaks.Count) {
        $archive.Dispose()
        Remove-Item $zip -Force
        throw "Zip leaked excluded files:`n  $($leaks.FullName -join "`n  ")"
    }
} finally {
    $archive.Dispose()
}

$size = [math]::Round((Get-Item $zip).Length / 1KB, 1)
Write-Host "Built $zip ($size KB, $($include.Count) files)" -ForegroundColor Green
