<#
.SYNOPSIS
    Compiles src/Program.cs into CryOfFearHDRConfig.exe (WPF, .NET Framework).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pkgRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $pkgRoot 'src\Program.cs'
$out = Join-Path $pkgRoot 'CryOfFearHDRConfig.exe'

if (-not (Test-Path $src)) { throw "Missing $src" }

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path $csc)) { throw 'csc.exe not found. Install .NET Framework 4.x Developer Pack / Windows.' }

$fw = Split-Path -Parent $csc
function Resolve-Ref([string]$name) {
    foreach ($candidate in @(
        (Join-Path $fw "WPF\$name"),
        (Join-Path $fw $name)
    )) {
        if (Test-Path $candidate) { return $candidate }
    }
    throw "Missing WPF assembly: $name (looked in $fw and $fw\WPF)"
}
$refs = @(
    (Resolve-Ref 'PresentationFramework.dll'),
    (Resolve-Ref 'PresentationCore.dll'),
    (Resolve-Ref 'WindowsBase.dll'),
    (Resolve-Ref 'System.Xaml.dll')
)

$argList = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    "/out:$out"
)
foreach ($r in $refs) { $argList += "/r:$r" }
$core = Join-Path $fw 'System.Core.dll'
if (Test-Path $core) { $argList += "/r:$core" }
$argList += $src

Write-Host "Compiling with $csc"
& $csc @argList
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit $LASTEXITCODE" }
Write-Host "Built $out" -ForegroundColor Green
