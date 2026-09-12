<#
.SYNOPSIS
    Diagnostics & Health Check for Cry of Fear HDR & 1440p Mod (portable).
#>
[CmdletBinding()]
param(
    [string] $GamePath
)

$scriptRoot = $PSScriptRoot
. (Join-Path $scriptRoot 'Common.ps1')

function Head { param($m) Write-Host "`n--- $m" -ForegroundColor Cyan }
function Pass { param($m) Write-Host "   [PASS] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "   [WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "   [FAIL] $m" -ForegroundColor Red }
function Info { param($m) Write-Host "   [INFO] $m" -ForegroundColor Gray }
function Unk  { param($m) Write-Host "   [?]    $m" -ForegroundColor DarkGray }

Head 'GPU and OS'
$gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like '*NVIDIA*' } | Select-Object -First 1
if ($gpu) {
    Pass "$($gpu.Name), driver $($gpu.DriverVersion)"
    $branch = ConvertTo-NvidiaBranch -WmiVersion $gpu.DriverVersion
    if ($branch) {
        if ($branch -ge [version]'551.23') { Pass "NVIDIA driver branch $branch (>= 551.23)" }
        else { Warn "NVIDIA driver branch $branch is older than 551.23 - update the driver for RTX HDR" }
    }
    if ($gpu.Name -match 'RTX') { Pass 'NVIDIA RTX hardware detected (supports RTX HDR)' }
    else { Warn 'Non-RTX GPU detected. RTX HDR requires an RTX series card.' }
} else { Fail 'No NVIDIA GPU detected.' }

$os = [System.Environment]::OSVersion
Pass "Windows build $($os.Version.Build)"

Head 'Display HDR'
$mode = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1
if ($mode) {
    Pass "Desktop Resolution: $($mode.CurrentHorizontalResolution)x$($mode.CurrentVerticalResolution) @ $($mode.CurrentRefreshRate) Hz"
}

$hdr = Get-DisplayHdrStatus
if (-not $hdr.Queried) {
    Unk 'Could not query display config - check Settings > System > Display > HDR by hand.'
} else {
    foreach ($row in $hdr.Rows) {
        if ($row.On) {
            Pass "$($row.Tech) - HDR on, $($row.Bpc) bit per channel"
            if ($row.Bpc -match '^\d+$' -and [int]$row.Bpc -lt 10) {
                Warn "  only $($row.Bpc) bit - expect banding"
            }
        } elseif ($row.Supported) {
            Warn "$($row.Tech) - HDR capable but OFF"
        } else {
            Unk "$($row.Tech) - not HDR capable"
        }
    }
    if (-not $hdr.AnyOn) { Fail 'No display has Windows HDR enabled. Settings > System > Display > HDR.' }
}

Head 'Game Install'
if (-not $GamePath) { $GamePath = Find-CryOfFear }
if ($GamePath -and (Test-Path (Join-Path $GamePath 'cof.exe'))) {
    Pass "Game executable found at: $GamePath"
    $opengl = Join-Path $GamePath 'opengl32.dll'
    if (Test-Path $opengl) {
        Pass 'Paranoia custom OpenGL renderer is present (opengl32.dll)'
    } else {
        Fail 'Missing opengl32.dll! Game will fall back to software rendering without HDR highlights.'
    }
} else {
    Fail 'Cry of Fear was not found on this system.'
    Write-Host "`nDiagnostic complete.`n" -ForegroundColor Cyan
    return
}

$exe = Join-Path $GamePath 'cof.exe'

Head 'Auto HDR (must not stack with RTX HDR)'
$gpuPrefKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$globalPref = (Get-ItemProperty -Path $gpuPrefKey -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
if ($globalPref -match 'AutoHDREnable=1') {
    Info 'Auto HDR is on globally - fine if cof.exe has a per-app override (checked next).'
}
$appPref = (Get-ItemProperty -Path $gpuPrefKey -Name $exe -ErrorAction SilentlyContinue).$exe
if ($appPref -match 'AutoHDREnable=0') {
    Pass 'Auto HDR disabled for Cry of Fear specifically'
} elseif ($appPref) {
    Warn "Per-app GPU preference exists but does not disable Auto HDR: $appPref"
} else {
    Warn 'No per-app Auto HDR override for cof.exe - run INSTALL.bat to set AutoHDREnable=0.'
}

Head 'Game Configuration (autoexec.cfg)'
$cfg = Join-Path $GamePath 'cryoffear\autoexec.cfg'
if (Test-Path $cfg) {
    $text = Get-Content $cfg -Raw
    if ($text -match '(?m)^\s*gl_renderer\s+1') { Pass 'Paranoia dynamic lighting renderer enabled (gl_renderer 1)' }
    else { Fail 'gl_renderer 1 missing in autoexec.cfg' }

    if ($text -match '(?m)^\s*cl_fovmultiplier\s+([0-9.]+)') { Pass "Field of View multiplier set to $($Matches[1])" }
    if ($text -match '(?m)^\s*m_filter\s+0') { Pass 'Direct raw mouse input active (m_filter 0)' }
    if ($text -match '(?m)^\s*gl_vsync\s+0') { Pass 'VSync off (gl_vsync 0)' }
    if ($text -match '(?m)^\s*fps_max\s+100') { Pass 'Engine framerate capped at 100 FPS (engine limit)' }
    if ($text -match '(?m)^\s*fps_override') {
        Fail 'autoexec.cfg sets fps_override - this engine build has no such cvar'
    }
    if ($text -match '(?m)^\s*fps_max\s+(\d+)' -and [int]$Matches[1] -gt 100) {
        Warn "fps_max $($Matches[1]) - the engine clamps to 100 regardless"
    }
} else {
    Warn 'autoexec.cfg not found in game directory.'
}

Head 'Nightmare shader (black_fp.cg)'
$shader = Join-Path $GamePath 'cryoffear\cgshaders\black_fp.cg'
if (Test-Path $shader) {
    if (Test-SoftenedShader -Path $shader) { Pass 'softened black_fp.cg is installed (EFFECT_CEILING)' }
    else { Info 'stock black_fp.cg (nightmare effect not softened)' }
} else {
    Unk 'cgshaders/black_fp.cg not found'
}

Head 'High-DPI Override'
$layers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$dpi = (Get-ItemProperty -Path $layers -Name $exe -ErrorAction SilentlyContinue).$exe
if ($dpi -match 'HIGHDPIAWARE') { Pass 'Application-controlled DPI scaling active (HIGHDPIAWARE)' }
else { Warn 'HIGHDPIAWARE not active for cof.exe.' }

Head 'Game Registry Settings'
$reg = Get-ItemProperty -Path 'HKCU:\Software\Valve\Cry of Fear\Settings' -ErrorAction SilentlyContinue
if ($reg) {
    Pass "Configured Resolution: $($reg.ScreenWidth)x$($reg.ScreenHeight)"
    Pass "Display Mode: $(if ($reg.SCREENWINDOWED -eq 1) { 'Windowed' } else { 'Fullscreen' })"
} else {
    Unk 'No Cry of Fear Settings registry key yet.'
}

Head 'Steam launch options'
$steamRows = @(Get-SteamLaunchOptions)
$anyOk = $false
$anyFound = $false
foreach ($row in $steamRows) {
    if (-not $row.Found) { continue }
    $anyFound = $true
    if ($row.Ok) {
        Pass "account $($row.UserId): $($row.Options)"
        $anyOk = $true
    } elseif ($row.Options) {
        Warn "account $($row.UserId) has launch options, but they are missing -fullscreen/-window, -w/-h, or the -noforce* flags: $($row.Options)"
    } else {
        Warn "account $($row.UserId) has Cry of Fear in Steam but LaunchOptions is empty"
    }
}
if (-not $anyFound) {
    Unk 'No Cry of Fear LaunchOptions in Steam localconfig.vdf. Run INSTALL (with Steam closed) or paste them in Steam Properties.'
} elseif (-not $anyOk) {
    Warn 'Launch options are present but do not match this package (need -fullscreen or -window, -w, -h, -noforcemparms -noforcemaccel -noforcemspd).'
}
if (Test-SteamRunning) {
    Info 'Steam is running - if you just installed, close Steam once so it reloads launch options from disk.'
}

Head 'NVIDIA Driver Profile'
$drs = Join-Path $env:ProgramData 'NVIDIA Corporation\Drs\nvdrsdb0.bin'
if (Test-Path $drs) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($drs)
        $haystack = [System.Text.Encoding]::Unicode.GetString($bytes)
        if ($haystack.Contains('Cry of Fear (HDR)')) {
            Pass 'Profile "Cry of Fear (HDR)" found in NVIDIA driver database'

            $nameBytes = [Text.Encoding]::Unicode.GetBytes("Cry of Fear (HDR)`0")
            $at = -1
            for ($i = 0; $i -le $bytes.Length - $nameBytes.Length; $i++) {
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
            Pass "$($settings.Count) settings active in driver profile"
            if ($settings[[uint32]0x20D690F8] -eq 1) { Pass 'Present method = Layered on DXGI swapchain' }
            else { Warn 'Present method is not layered DXGI - RTX HDR will not reach OpenGL.' }
            if ($settings[[uint32]0x00DD48FB] -eq 1) { Pass 'RTX HDR = Enabled' }
            else { Warn 'RTX HDR enable flag not set in the profile.' }
            if ($settings[[uint32]0x00432F84] -eq 2) { Pass 'RTX HDR driver flags = 2 (Route 3B, VeryHigh debanding)' }
            elseif ($settings[[uint32]0x00432F84] -eq 3) { Pass 'RTX HDR driver flags = 3 (on-screen indicator is ON - import the Quality profile to hide it)' }
            elseif ($settings.Contains([uint32]0x00432F84)) { Info "RTX HDR driver flags = $($settings[[uint32]0x00432F84])" }
            if ($settings[[uint32]0x101E61A9]) { Pass "Anisotropic filtering = $($settings[[uint32]0x101E61A9])x" }
            if ($settings[[uint32]0x107EFC5B] -eq 0) { Pass 'MSAA driver override = Off (crash-safe)' }
            $tex = $settings[[uint32]0x00CE2691]
            if ($tex -eq [uint32]4294967286) { Pass 'Texture filtering quality = High quality' }
            elseif ($tex) { Warn "Texture filtering quality = $tex (expected 4294967286 / High quality)" }
        } else {
            Warn 'Profile "Cry of Fear (HDR)" not found in driver database. Please run the installer.'
        }
    } catch {
        Warn 'Could not read driver database.'
    }
} else {
    Unk 'NVIDIA driver database not found.'
}

Write-Host "`nDiagnostic complete.`n" -ForegroundColor Cyan
