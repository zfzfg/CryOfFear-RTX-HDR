<#
.SYNOPSIS
    Diagnoses a Cry of Fear HDR setup and reports which preconditions are met.

.DESCRIPTION
    Read-only. Changes nothing. Checks each link in the chain described in
    HDRmodCOF.md section 3, so that when HDR "does not work" you can see which
    step actually failed instead of guessing.

    Anything this script cannot determine reliably is reported as [?], not as a
    failure - a wrong "all good" is worse than an honest unknown.

.EXAMPLE
    .\Test-CofHdr.ps1
#>
[CmdletBinding()]
param([string] $GamePath)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

function Pass  { param($m) Write-Host "[ok]   $m" -ForegroundColor Green }
function Fail  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Warn  { param($m) Write-Host "[warn] $m" -ForegroundColor Yellow }
function Unk   { param($m) Write-Host "[?]    $m" -ForegroundColor DarkGray }
function Head  { param($m) Write-Host "`n--- $m" -ForegroundColor Cyan }

# --- GPU and OS -------------------------------------------------------------
Head 'GPU and OS'
$gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
if ($gpu) {
    Pass "$($gpu.Name), driver $($gpu.DriverVersion)"
    if ($gpu.Name -notmatch 'RTX') { Warn 'RTX HDR requires a GeForce RTX GPU.' }
} else {
    Fail 'No NVIDIA GPU found - the RTX HDR route does not apply.'
}

$os = [Environment]::OSVersion.Version
if ($os.Build -ge 22000) { Pass "Windows build $($os.Build)" }
else { Warn "Windows build $($os.Build) - Windows 11 recommended; driver-level RTX HDR needs WDDM 3.1." }

# --- HDR state --------------------------------------------------------------
Head 'Display HDR'
# The graphics-driver registry key is ACL'd and unreliable, so ask the
# DisplayConfig API instead: per active display path, is advanced colour
# supported and is it currently on. Read-only.
#
# Note DISPLAYCONFIG_PATH_SOURCE_INFO ends with a statusFlags field, making
# DISPLAYCONFIG_PATH_INFO 72 bytes, not 68. Omitting it shifts every later
# field and every call returns ERROR_INVALID_PARAMETER.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CofHdrProbe
{
    [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint Low; public int High; }
    [StructLayout(LayoutKind.Sequential)] public struct SOURCE { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] public struct RATIONAL { public uint num; public uint den; }
    [StructLayout(LayoutKind.Sequential)] public struct TARGET {
        public LUID adapterId; public uint id; public uint modeInfoIdx;
        public uint outputTechnology; public uint rotation; public uint scaling;
        public RATIONAL refreshRate; public uint scanLineOrdering;
        public int targetAvailable; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] public struct PATH { public SOURCE sourceInfo; public TARGET targetInfo; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] public struct MODE { public uint infoType; public uint id; public LUID adapterId;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 48)] public byte[] blob; }
    [StructLayout(LayoutKind.Sequential)] public struct HEADER { public uint type; public uint size; public LUID adapterId; public uint id; }
    [StructLayout(LayoutKind.Sequential)] public struct GET_COLOR { public HEADER header; public uint value; public uint colorEncoding; public uint bitsPerColorChannel; }

    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPath, out uint numMode);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint numPath, [Out] PATH[] paths, ref uint numMode, [Out] MODE[] modes, IntPtr topo);
    [DllImport("user32.dll")] static extern int DisplayConfigGetDeviceInfo(ref GET_COLOR info);

    static string Tech(uint t)
    {
        switch (t) {
            case 4:  return "DVI";
            case 5:  return "HDMI";
            case 10: return "DisplayPort";
            case 11: return "intern";
            case 0x80000000: return "intern";
            default: return "Typ " + t;
        }
    }

    // one line per active path: "<tech>|<supported>|<enabled>|<bpc>"
    public static string[] Probe()
    {
        uint np, nm;
        if (GetDisplayConfigBufferSizes(2, out np, out nm) != 0) return new string[0];
        PATH[] paths = new PATH[np]; MODE[] modes = new MODE[nm];
        if (QueryDisplayConfig(2, ref np, paths, ref nm, modes, IntPtr.Zero) != 0) return new string[0];
        string[] outp = new string[np];
        for (int i = 0; i < np; i++) {
            var t = paths[i].targetInfo;
            GET_COLOR g = new GET_COLOR();
            g.header.type = 9;
            g.header.size = (uint)Marshal.SizeOf(typeof(GET_COLOR));
            g.header.adapterId = t.adapterId;
            g.header.id = t.id;
            if (DisplayConfigGetDeviceInfo(ref g) != 0) { outp[i] = Tech(t.outputTechnology) + "|?|?|?"; continue; }
            outp[i] = Tech(t.outputTechnology) + "|" + ((g.value & 1) != 0) + "|" + ((g.value & 2) != 0) + "|" + g.bitsPerColorChannel;
        }
        return outp;
    }
}
'@ -ErrorAction SilentlyContinue

$probe = @()
try { $probe = [CofHdrProbe]::Probe() } catch { }

if ($probe.Count -eq 0) {
    Unk 'Could not query display config - check Settings > System > Display > HDR by hand.'
} else {
    $anyOn = $false
    foreach ($row in $probe) {
        $f = $row -split '\|'
        $tech = $f[0]; $sup = $f[1] -eq 'True'; $on = $f[2] -eq 'True'; $bpc = $f[3]
        if ($on) {
            Pass "$tech - HDR on, $bpc bit per channel"
            $anyOn = $true
            if ($bpc -lt 10) { Warn "  only $bpc bit - expect banding; check the driver's output colour depth." }
        } elseif ($sup) {
            Warn "$tech - HDR capable but OFF"
        } else {
            Unk "$tech - not HDR capable"
        }
    }
    if (-not $anyOn) { Fail 'No display has HDR enabled. Settings > System > Display > HDR.' }
}

# Auto HDR must not run alongside RTX HDR, but only for THIS game - a global
# "on" is fine as long as cof.exe carries a per-app override.
$gpuPrefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$globalPref = (Get-ItemProperty -Path $gpuPrefKey -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
if ($globalPref -match 'AutoHDREnable=1') {
    Unk 'Auto HDR is on globally - harmless if this game has a per-app override (checked below).'
}

# --- Game install -----------------------------------------------------------
Head 'Game install'
if (-not $GamePath) {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    $libraries = @($steam)
    $vdf = if ($steam) { Join-Path $steam 'steamapps\libraryfolders.vdf' } else { $null }
    if ($vdf -and (Test-Path $vdf)) {
        Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches |
            ForEach-Object { $_.Matches } |
            ForEach-Object { $libraries += $_.Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in ($libraries | Where-Object { $_ } | Select-Object -Unique)) {
        $c = Join-Path $lib 'steamapps\common\Cry of Fear'
        if (Test-Path (Join-Path $c 'cof.exe')) { $GamePath = $c; break }
    }
}

if (-not $GamePath) { Fail 'Cry of Fear not found. Re-run with -GamePath.'; return }
Pass $GamePath

$exe = Join-Path $GamePath 'cof.exe'
if (Test-Path (Join-Path $GamePath 'CoFLaunchApp.exe')) {
    Unk 'CoFLaunchApp.exe is what Steam starts; cof.exe is what renders. The NVIDIA profile must target cof.exe.'
}
$appPref = (Get-ItemProperty -Path $gpuPrefKey -Name $exe -ErrorAction SilentlyContinue).$exe
if ($appPref -match 'AutoHDREnable=0') { Pass 'Auto HDR disabled for this game specifically.' }
elseif ($appPref) { Warn "Per-app GPU preference exists but does not disable Auto HDR: $appPref" }
else { Warn 'No per-app Auto HDR override for cof.exe - it may run alongside RTX HDR.' }

$gl  = Join-Path $GamePath 'opengl32.dll'
if (Test-Path $gl) {
    $h = (Get-FileHash $gl -Algorithm SHA256).Hash.Substring(0, 16)
    Pass "Paranoia renderer present (opengl32.dll, sha256 $h...)"
} else {
    Fail 'opengl32.dll missing - the Paranoia renderer is what draws the highlights HDR expands.'
}

# --- Config -----------------------------------------------------------------
Head 'Game config'
$cfgFile = Join-Path $GamePath 'cryoffear\autoexec.cfg'
if (Test-Path $cfgFile) {
    $text = Get-Content $cfgFile -Raw
    if ($text -match '(?m)^\s*gl_renderer\s+1') { Pass 'autoexec.cfg sets gl_renderer 1' }
    else { Fail 'autoexec.cfg does not set gl_renderer 1 - no flashlight, nothing for HDR to work with.' }
    if ($text -match '(?m)^\s*fps_max\s+0') { Warn 'fps_max 0 - uncapped GoldSrc destabilises physics and frame pacing.' }
    if ($text -match '(?m)^\s*fps_override') {
        Fail 'autoexec.cfg sets fps_override - this engine build has no such cvar; it does nothing.'
        Fail 'The 100 fps cap is built into the engine and cannot be lifted. Remove the line.'
    }
    if ($text -match '(?m)^\s*fps_max\s+(\d+)' -and [int]$Matches[1] -gt 100) {
        Warn "fps_max $($Matches[1]) - the engine clamps to 100 regardless."
    }
} else {
    Fail "No autoexec.cfg at $cfgFile"
}

$side = Join-Path $GamePath 'cryoffear\autoexec.hdr.cfg'
if (Test-Path $side) { Warn "autoexec.hdr.cfg is present - the installer left it for you to merge by hand." }

# --- Paranoia Cg shaders ----------------------------------------------------
Head 'Paranoia Cg shaders'
$cgDir = Join-Path $GamePath 'cryoffear\cgshaders'
if (Test-Path $cgDir) {
    $cgFiles = @(Get-ChildItem $cgDir -Filter *.cg -ErrorAction SilentlyContinue)
    Pass "$($cgFiles.Count) editable Cg shaders found - the renderer is not purely fixed-function."
    $black = Join-Path $cgDir 'black_fp.cg'
    if (Test-Path $black) {
        $mod = (Get-Item $black).LastWriteTime
        Pass "black_fp.cg (the B/W post-effect) present, modified $mod"
    }
} else {
    Unk 'No cgshaders folder - this build may differ from the one this was written against.'
}

# --- Menu font scaling ------------------------------------------------------
Head 'Menu fonts'
$schemeDir = Join-Path $GamePath 'cryoffear\resource'
$scaled = 0
foreach ($sf in @('trackerscheme.res', 'clientscheme.res')) {
    $sp = Join-Path $schemeDir $sf
    if (Test-Path $sp) {
        if ((Get-Content $sp -Raw) -match 'cof-hdr: menu fonts scaled') { $scaled++ }
    }
}
if ($scaled -eq 2) { Pass 'both scheme files carry the scaled menu fonts' }
elseif ($scaled -eq 1) { Warn 'only one scheme file is scaled - re-run Set-CofFontScale.ps1' }
else { Unk 'menu fonts not scaled (run tools\Set-CofFontScale.ps1 on a high-resolution display)' }

Unk 'The in-game HUD cannot be scaled: sizes are compiled into client.dll.'

# --- DPI override -----------------------------------------------------------
Head 'High-DPI override'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$dpi = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
if ($dpi -match 'HIGHDPIAWARE') { Pass 'application-controlled DPI scaling' }
else { Warn 'Not set. Expect a small window or wrong resolution.' }

# --- Steam launch options ---------------------------------------------------
Head 'Steam launch options'
$steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
$found = $false
if ($steam) {
    Get-ChildItem (Join-Path $steam 'userdata') -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $lc = Join-Path $_.FullName 'config\localconfig.vdf'
        if (Test-Path $lc) {
            $m = Select-String -Path $lc -Pattern '"LaunchOptions"\s+"([^"]*)"' -AllMatches
            foreach ($match in ($m | ForEach-Object { $_.Matches })) {
                $opt = $match.Groups[1].Value
                if ($opt -match 'noborder|-window') { Pass "Found launch options: $opt"; $script:found = $true }
            }
        }
    }
}
if (-not $found) { Unk 'No borderless launch options found (Steam stores these per user; a running Steam may also cache them).' }

# --- NVIDIA driver profile --------------------------------------------------
Head 'NVIDIA driver profile'
# The driver keeps its profiles in a binary database. It has no documented
# format, but the profile NAME is stored as plain UTF-16, so searching for it
# is enough to answer the only question that matters here: did the .nip import
# actually land? Read-only, and a miss proves nothing beyond "name not found".
$profileFound = $false
$drs = Join-Path $env:ProgramData 'NVIDIA Corporation\Drs\nvdrsdb0.bin'
if (Test-Path $drs) {
    try {
        $bytes    = [System.IO.File]::ReadAllBytes($drs)
        $haystack = [System.Text.Encoding]::Unicode.GetString($bytes)
        if ($haystack.Contains('Cry of Fear (HDR)')) {
            Pass 'Profile "Cry of Fear (HDR)" found in the driver database - the .nip imported.'
            $profileFound = $true

            # Settings sit immediately before the profile name as 16-byte records:
            # [A4 00 10 00][id:4][02 10 00 00][value:4]. Walking them backwards is
            # the only way to see what is really active - and it catches the trap
            # that importing one .nip replaces the profile rather than merging,
            # which silently drops whatever the previous file had set.
            $nameBytes = [System.Text.Encoding]::Unicode.GetBytes('Cry of Fear (HDR)')
            $at = -1
            for ($i = 0; $i -lt $bytes.Length - $nameBytes.Length; $i++) {
                $hit = $true
                for ($j = 0; $j -lt $nameBytes.Length; $j++) {
                    if ($bytes[$i + $j] -ne $nameBytes[$j]) { $hit = $false; break }
                }
                if ($hit) { $at = $i; break }
            }
            $settings = @{}
            if ($at -gt 0) {
                $r = $at - 16
                while ($r -ge 0 -and $bytes[$r] -eq 0xA4 -and $bytes[$r+1] -eq 0x00 -and
                       $bytes[$r+2] -eq 0x10 -and $bytes[$r+3] -eq 0x00) {
                    $id  = [BitConverter]::ToUInt32($bytes, $r + 4)
                    $val = [BitConverter]::ToUInt32($bytes, $r + 12)
                    $settings[$id] = $val
                    $r -= 16
                }
            }
            Pass "$($settings.Count) setting(s) active in the profile"

            if ($settings[[uint32]0x20D690F8] -eq 1) { Pass 'present method = layered on DXGI swapchain' }
            else { Fail 'present method is NOT layered on DXGI - HDR cannot reach the game.' }

            if ($settings[[uint32]0x00DD48FB] -eq 1) { Pass "RTX HDR on (driver flags = $($settings[[uint32]0x00432F84]))" }
            else { Fail 'RTX HDR is not enabled in the profile.' }

            if ($settings[[uint32]0x101E61A9]) { Pass "anisotropic filtering = $($settings[[uint32]0x101E61A9])x" }
            else { Unk 'no anisotropic filtering forced (import a *-quality.nip for it)' }

            if ($settings[[uint32]0x107EFC5B] -eq 1) { Pass "MSAA override on (setting 0x$('{0:X}' -f $settings[[uint32]0x10D773D2]))" }
            else { Unk 'no MSAA override (expected if you use the -noaa profile)' }
        } else {
            Warn 'Profile "Cry of Fear (HDR)" not in the driver database.'
            Warn 'Import it:  nvidiaProfileInspector.exe -silentImport install\cof-hdr-nvidia-*.nip'
        }
    } catch {
        Unk 'Could not read the driver profile database.'
    }
} else {
    Unk "No driver profile database at $drs"
}

# --- NVIDIA app -------------------------------------------------------------
Head 'NVIDIA app'
$appPaths = @(
    "$env:ProgramFiles\NVIDIA Corporation\NVIDIA app",
    "${env:ProgramFiles(x86)}\NVIDIA Corporation\NVIDIA app"
)
if ($appPaths | Where-Object { Test-Path $_ }) {
    Pass 'NVIDIA app installed - the four RTX HDR sliders are available (route 3A).'
} elseif ($profileFound) {
    Pass 'No NVIDIA app, but the driver profile is in place - route 3B is set up as intended.'
    Unk 'No tuning sliders on this route. Adjust gl_brightness in autoexec.cfg instead.'
} else {
    Warn 'NVIDIA app not found and no driver profile imported - RTX HDR is not configured.'
    Warn 'Import a .nip with NVIDIA Profile Inspector (route 3B), or install the app (route 3A).'
}

Unk 'Whether RTX HDR is actually ACTIVE in-game cannot be read from here.'
Unk 'Verify in-game: the flashlight core must be clearly brighter than the pause-menu white.'

Write-Host "`nSee HDRmodCOF.md section 6 for what to do about each failure.`n"
