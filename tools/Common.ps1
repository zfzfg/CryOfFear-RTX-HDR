<#
.SYNOPSIS
    Shared helpers for the Cry of Fear HDR portable installer.
#>

function Get-SteamPath {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }
    return ($steam -replace '/', '\')
}

function Get-ModDataRoot {
    return Join-Path $env:LOCALAPPDATA 'CryOfFearHDR'
}

function Get-BackupDir {
    param(
        [string] $PkgRoot,
        [switch] $Create
    )
    $preferred = Join-Path (Get-ModDataRoot) 'backup\original'
    $legacy = Join-Path $PkgRoot 'backup\original'
    if (Test-Path $preferred) { return $preferred }
    if (Test-Path $legacy) { return $legacy }
    if ($Create) {
        New-Item -ItemType Directory -Path $preferred -Force | Out-Null
        return $preferred
    }
    return $preferred
}

function Find-CryOfFear {
    $steam = Get-SteamPath
    if (-not $steam) { return $null }

    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
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

function ConvertTo-FlexibleBool {
    param($Value, [bool] $Default = $true)
    if ($null -eq $Value -or $Value -eq '') { return $Default }
    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [byte] -or $Value -is [double]) {
        return [bool][int]$Value
    }
    $s = "$Value".Trim()
    if ($s.StartsWith('$')) { $s = $s.Substring(1) }
    switch -Regex ($s) {
        '^(1|true|yes)$'  { return $true }
        '^(0|false|no)$' { return $false }
        default { return $Default }
    }
}

function Get-LaunchOptions {
    param(
        [int] $Width,
        [int] $Height,
        [switch] $Windowed
    )
    $mode = if ($Windowed) { "-window -w $Width -h $Height" } else { "-fullscreen -w $Width -h $Height" }
    return "$mode -noforcemparms -noforcemaccel -noforcemspd"
}

function Import-NvidiaProfile {
    param(
        [string] $InspectorPath,
        [string] $NipPath
    )

    if (-not (Test-Path $InspectorPath)) {
        Write-Host "   [warn] NVIDIA Profile Inspector not found: $InspectorPath" -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path $NipPath)) {
        Write-Host "   [warn] Profile missing: $NipPath" -ForegroundColor Yellow
        return $false
    }

    try {
        $proc = Start-Process -FilePath $InspectorPath -ArgumentList @('-silentImport', $NipPath) -Verb RunAs -PassThru -Wait
        if (-not $proc) {
            Write-Host '   [warn] UAC cancelled or inspector did not start - driver profile not imported.' -ForegroundColor Yellow
            return $false
        }
        if ($proc.ExitCode -ne 0) {
            Write-Host "   [warn] Profile Inspector exited with code $($proc.ExitCode)." -ForegroundColor Yellow
            return $false
        }
        Write-Host '   [ok]   NVIDIA driver profile imported' -ForegroundColor Green
        return $true
    } catch {
        Write-Host "   [warn] Profile import failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Set-PerAppAutoHdrOff {
    param([string] $ExePath)

    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }

    $existing = (Get-ItemProperty -Path $key -Name $ExePath -ErrorAction SilentlyContinue).$ExePath
    $parts = @()
    if ($existing) {
        $parts = @($existing -split ';' | Where-Object { $_ -and ($_ -notmatch '^\s*AutoHDREnable\s*=') })
    }
    $parts += 'AutoHDREnable=0'
    $value = (($parts | Where-Object { $_ }) -join ';').Trim(';') + ';'
    Set-ItemProperty -Path $key -Name $ExePath -Value $value
    return $value
}

function Reset-PerAppAutoHdr {
    param([string] $ExePath)

    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $existing = (Get-ItemProperty -Path $key -Name $ExePath -ErrorAction SilentlyContinue).$ExePath
    if (-not $existing) { return $null }

    $parts = @($existing -split ';' | Where-Object { $_ -and ($_ -notmatch '^\s*AutoHDREnable\s*=') })
    if ($parts.Count -eq 0) {
        Remove-ItemProperty -Path $key -Name $ExePath -Force
        return ''
    }
    $value = ($parts -join ';').Trim(';') + ';'
    Set-ItemProperty -Path $key -Name $ExePath -Value $value
    return $value
}

function Initialize-HdrProbeType {
    if ('CofHdrProbe' -as [type]) { return $true }
    try {
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
            case 11: return "internal";
            case 0x80000000: return "internal";
            default: return "type " + t;
        }
    }

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
'@
        return $true
    } catch {
        return $false
    }
}

function Get-DisplayHdrStatus {
    $result = [pscustomobject]@{
        Queried = $false
        AnyOn   = $false
        Rows    = @()
    }
    if (-not (Initialize-HdrProbeType)) { return $result }
    try {
        $probe = [CofHdrProbe]::Probe()
        if (-not $probe -or $probe.Count -eq 0) { return $result }
        $result.Queried = $true
        foreach ($row in $probe) {
            $f = $row -split '\|'
            $on = $f.Count -gt 2 -and $f[2] -eq 'True'
            $sup = $f.Count -gt 1 -and $f[1] -eq 'True'
            $item = [pscustomobject]@{
                Tech      = $f[0]
                Supported = $sup
                On        = $on
                Bpc       = if ($f.Count -gt 3) { $f[3] } else { '?' }
            }
            $result.Rows += $item
            if ($on) { $result.AnyOn = $true }
        }
    } catch {}
    return $result
}

function Set-CvarInText {
    param(
        [string] $Text,
        [string] $Name,
        [string] $Value
    )
    $escaped = [regex]::Escape($Name)
    $pattern = "(?m)^(\s*)$escaped(\s+)\S+.*$"
    if ([regex]::IsMatch($Text, "(?m)^\s*$escaped\s+\S+")) {
        return [regex]::Replace($Text, $pattern, "`${1}$Name`${2}$Value", 1)
    }
    $nl = if ($Text -match "`r`n") { "`r`n" } else { "`n" }
    return $Text.TrimEnd() + "$nl$Name $Value$nl"
}

function Remove-CvarFromText {
    param(
        [string] $Text,
        [string] $Name
    )
    $escaped = [regex]::Escape($Name)
    return [regex]::Replace($Text, "(?m)^\s*$escaped\s+\S+.*\r?\n?", '')
}

function Merge-Autoexec {
    param(
        [string] $TemplatePath,
        [string] $DestinationPath,
        [double] $Fov,
        [bool] $RawMouse,
        [bool] $LowLatencyVsync,
        [bool] $EngineRates
    )

    $template = Get-Content -Path $TemplatePath -Raw
    $template = $template -replace '(?m)^cl_fovmultiplier\s+[0-9.]+', ("cl_fovmultiplier {0:F2}" -f $Fov)

    $cvars = [ordered]@{
        'gl_renderer'      = '1'
        'gl_twopassdyn'    = '1'
        'brightness'       = '1'
        'gamma'            = '2.5'
        'gl_brightness'    = '0'
        'gl_gamma'         = '1'
        'gl_posteffects'   = '1'
        'gl_texturemode'   = 'gl_linear_mipmap_linear'
        'cl_fovmultiplier' = ('{0:F2}' -f $Fov)
        'fps_max'          = '100'
        'developer'        = '0'
    }
    if ($RawMouse) { $cvars['m_filter'] = '0' }
    else { $cvars['m_filter'] = '1' }
    if ($LowLatencyVsync) { $cvars['gl_vsync'] = '0' }
    else { $cvars['gl_vsync'] = '1' }
    if ($EngineRates) {
        $cvars['cl_cmdrate'] = '101'
        $cvars['cl_updaterate'] = '101'
        $cvars['rate'] = '100000'
    }

    if (-not (Test-Path $DestinationPath)) {
        $out = $template
        if (-not $RawMouse) {
            $out = [regex]::Replace($out, '(?m)^\s*m_filter\s+\S+.*\r?\n?', '')
            $nl = if ($out -match "`r`n") { "`r`n" } else { "`n" }
            $out = $out.TrimEnd() + "${nl}m_filter        1$nl"
        }
        if (-not $LowLatencyVsync) {
            $out = [regex]::Replace($out, '(?m)^\s*gl_vsync\s+\S+.*\r?\n?', '')
            $nl = if ($out -match "`r`n") { "`r`n" } else { "`n" }
            $out = $out.TrimEnd() + "${nl}gl_vsync        1$nl"
        }
        if (-not $EngineRates) {
            $out = [regex]::Replace($out, '(?m)^\s*cl_cmdrate\s+\S+.*\r?\n?', '')
            $out = [regex]::Replace($out, '(?m)^\s*cl_updaterate\s+\S+.*\r?\n?', '')
            $out = [regex]::Replace($out, '(?m)^\s*rate\s+\S+.*\r?\n?', '')
        }
        Set-Content -Path $DestinationPath -Value $out -Encoding ASCII -NoNewline
        return 'created'
    }

    $existing = Get-Content -Path $DestinationPath -Raw
    foreach ($name in $cvars.Keys) {
        $existing = Set-CvarInText -Text $existing -Name $name -Value $cvars[$name]
    }
    if (-not $EngineRates) {
        foreach ($name in @('cl_cmdrate', 'cl_updaterate', 'rate')) {
            $existing = Remove-CvarFromText -Text $existing -Name $name
        }
    }
    Set-Content -Path $DestinationPath -Value $existing -Encoding ASCII -NoNewline
    return 'merged'
}

function Test-SoftenedShader {
    param([string] $Path)
    if (-not (Test-Path $Path)) { return $false }
    $text = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    return [bool]($text -match 'EFFECT_CEILING')
}

function ConvertTo-NvidiaBranch {
    param([string] $WmiVersion)
    if (-not $WmiVersion) { return $null }
    $p = $WmiVersion.Split('.')
    if ($p.Count -lt 4) { return $null }
    $blob = $p[2] + $p[3].PadLeft(4, '0')
    if ($blob.Length -lt 5) { return $null }
    $n = $blob.Substring($blob.Length - 5)
    $s = $n.Substring(0, 3) + '.' + $n.Substring(3)
    try { return [version]$s } catch { return $null }
}

function Test-SteamRunning {
    return [bool](Get-Process -Name 'steam' -ErrorAction SilentlyContinue)
}

function Get-SteamLocalConfigPaths {
    $steam = Get-SteamPath
    if (-not $steam) { return @() }
    $root = Join-Path $steam 'userdata'
    if (-not (Test-Path $root)) { return @() }
    @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Join-Path $_.FullName 'config\localconfig.vdf'
        if (Test-Path $p) { $p }
    })
}

function Read-VdfFile {
    param([string] $Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [pscustomobject]@{
            Text = [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
            Enc  = 'utf16'
        }
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [pscustomobject]@{
            Text = [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
            Enc  = 'utf8bom'
        }
    }
    return [pscustomobject]@{
        Text = [Text.Encoding]::UTF8.GetString($bytes)
        Enc  = 'utf8'
    }
}

function Write-VdfFile {
    param(
        [string] $Path,
        [string] $Text,
        [string] $Enc
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    if ($Enc -eq 'utf16') {
        $bytes = [Text.Encoding]::Unicode.GetPreamble() + [Text.Encoding]::Unicode.GetBytes($Text)
        [IO.File]::WriteAllBytes($Path, $bytes)
        return
    }
    if ($Enc -eq 'utf8bom') {
        $utf8bom = New-Object System.Text.UTF8Encoding $true
        [IO.File]::WriteAllText($Path, $Text, $utf8bom)
        return
    }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Find-VdfObjectSpan {
    param(
        [string] $Text,
        [string] $Key,
        [int] $StartAt = 0
    )
    $needle = '"' + $Key + '"'
    $idx = $Text.IndexOf($needle, $StartAt)
    if ($idx -lt 0) { return $null }
    $open = $Text.IndexOf([char]'{', $idx + $needle.Length)
    if ($open -lt 0) { return $null }
    $gap = $Text.Substring($idx + $needle.Length, $open - ($idx + $needle.Length))
    if ($gap -match '"') { return $null }
    $depth = 0
    for ($i = $open; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return @{ KeyStart = $idx; Open = $open; Close = $i }
            }
        }
    }
    return $null
}

function Get-VdfLaunchOptionsFromText {
    param([string] $Text)
    $span = Find-VdfObjectSpan -Text $Text -Key '223710'
    if (-not $span) { return $null }
    $inner = $Text.Substring($span.Open + 1, $span.Close - $span.Open - 1)
    $m = [regex]::Match($inner, '"LaunchOptions"\s+"([^"]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Test-ModLaunchOptions {
    param([string] $Options)
    if ([string]::IsNullOrWhiteSpace($Options)) { return $false }
    $mode = ($Options -match '-fullscreen') -or ($Options -match '(^|\s)-window(\s|$)')
    $res = ($Options -match '-w\s+\d+') -and ($Options -match '-h\s+\d+')
    $mouse = ($Options -match '-noforcemparms') -and ($Options -match '-noforcemaccel') -and ($Options -match '-noforcemspd')
    return $mode -and $res -and $mouse
}

function Get-SteamLaunchOptions {
    $rows = @()
    foreach ($path in (Get-SteamLocalConfigPaths)) {
        try {
            $vdf = Read-VdfFile -Path $path
            $opt = Get-VdfLaunchOptionsFromText -Text $vdf.Text
            $user = Split-Path -Parent (Split-Path -Parent $path)
            $rows += [pscustomobject]@{
                Path    = $path
                UserId  = Split-Path $user -Leaf
                Found   = $null -ne $opt
                Options = $opt
                Ok      = Test-ModLaunchOptions -Options $opt
            }
        } catch { }
    }
    return $rows
}

function Set-VdfLaunchOptionsInText {
    param(
        [string] $Text,
        [string] $LaunchOptions
    )
    $span = Find-VdfObjectSpan -Text $Text -Key '223710'
    if (-not $span) { return $null }
    $inner = $Text.Substring($span.Open + 1, $span.Close - $span.Open - 1)
    $quoted = '"' + $LaunchOptions.Replace('\', '\\').Replace('"', '\"') + '"'
    if ($inner -match '"LaunchOptions"\s+"[^"]*"') {
        $inner2 = [regex]::Replace($inner, '"LaunchOptions"\s+"[^"]*"', ('"LaunchOptions"' + "`t`t" + $quoted), 1)
    } else {
        $nl = if ($Text -match "`r`n") { "`r`n" } else { "`n" }
        $indent = "`t`t`t`t`t"
        $m = [regex]::Match($inner, '(?m)^([ \t]+)"')
        if ($m.Success) { $indent = $m.Groups[1].Value }
        $inner2 = $nl + $indent + '"LaunchOptions"' + "`t`t" + $quoted + $inner
    }
    return $Text.Substring(0, $span.Open + 1) + $inner2 + $Text.Substring($span.Close)
}

function Set-SteamLaunchOptions {
    param(
        [string] $LaunchOptions,
        [string] $BackupDir
    )

    $result = [pscustomobject]@{
        Written = $false
        Reason  = ''
        Paths   = @()
        Options = $LaunchOptions
    }

    if (Test-SteamRunning) {
        $result.Reason = 'steam-running'
        return $result
    }

    $targets = @()
    foreach ($row in (Get-SteamLaunchOptions)) {
        if ($row.Found) { $targets += $row }
    }
    if ($targets.Count -eq 0) {
        $all = @(Get-SteamLocalConfigPaths)
        if ($all.Count -eq 0) {
            $result.Reason = 'no-localconfig'
            return $result
        }
        $result.Reason = 'no-app-entry'
        return $result
    }

    $steamBackup = $null
    if ($BackupDir) {
        $steamBackup = Join-Path (Split-Path -Parent $BackupDir) 'steam'
        if (-not (Test-Path $steamBackup)) {
            New-Item -ItemType Directory -Path $steamBackup -Force | Out-Null
        }
    }

    $written = 0
    foreach ($row in $targets) {
        try {
            $vdf = Read-VdfFile -Path $row.Path
            $updated = Set-VdfLaunchOptionsInText -Text $vdf.Text -LaunchOptions $LaunchOptions
            if (-not $updated) { continue }
            if ($steamBackup) {
                Copy-Item $row.Path (Join-Path $steamBackup ("localconfig-" + $row.UserId + ".vdf")) -Force
            }
            Write-VdfFile -Path $row.Path -Text $updated -Enc $vdf.Enc
            $result.Paths += $row.Path
            $written++
        } catch {
            $result.Reason = $_.Exception.Message
        }
    }

    if ($written -gt 0) {
        $result.Written = $true
        $result.Reason = 'ok'
    } elseif (-not $result.Reason) {
        $result.Reason = 'write-failed'
    }
    return $result
}
