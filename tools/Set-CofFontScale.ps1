<#
.SYNOPSIS
    Scales Cry of Fear's menu fonts for high-resolution displays.

.DESCRIPTION
    At 2560x1440 the menu and dialog text is tiny, because clientscheme.res and
    trackerscheme.res declare fixed pixel sizes (16 / 13 / 12 px) with no
    resolution scaling.

    The engine does support resolution-dependent fonts: trackerscheme.res
    already uses "yres" range blocks for EngineFont, and one font even carries
    the comment "This version should not scale". So rather than overwriting the
    sizes - which would make the game look wrong for everyone on 1080p - this
    adds a new block guarded by "yres", leaving behaviour below the threshold
    byte-for-byte identical.

    It edits YOUR copy of the game's files in place rather than shipping
    modified ones: those are game content, and a script also survives a game
    version whose schemes differ from the one this was written against.

    The in-game HUD is NOT affected and cannot be: Cry of Fear's client.dll
    uses VGUI1 with font sizes compiled in, and the build has no hud_scale
    cvar. The *_textscheme.txt files in the game folder look relevant but are
    dead - no binary in the game references them.

.PARAMETER Scale
    Font size multiplier above the threshold. Default 1.55, tuned for 1440p.

.PARAMETER MinYres
    Vertical resolution at which the larger fonts start. Default 1200.

.PARAMETER Revert
    Restore the scheme files from backup\original\resource and exit.

.EXAMPLE
    .\Set-CofFontScale.ps1 -WhatIf
    .\Set-CofFontScale.ps1
    .\Set-CofFontScale.ps1 -Scale 1.8
    .\Set-CofFontScale.ps1 -Revert
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $GamePath,
    [double] $Scale = 1.55,
    [int]    $MinYres = 1200,
    [switch] $Revert
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "   [ok]   $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "   [warn] $m" -ForegroundColor Yellow }

# Fonts that must keep their size. The scheme file says so itself.
$skipFonts = @('Legacy_CreditsFont')

# Written into the file so a second run cannot scale an already-scaled font
# again. Without it the sizes compound silently on every invocation.
$marker = '// cof-hdr: menu fonts scaled - revert with Set-CofFontScale.ps1 -Revert'

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
Write-Ok $GamePath

$resDir    = Join-Path $GamePath 'cryoffear\resource'
$backupRes = Join-Path $root 'backup\original\resource'
$schemes   = @('trackerscheme.res', 'clientscheme.res')

# --- Revert -----------------------------------------------------------------
if ($Revert) {
    Write-Step 'Restoring original scheme files'
    if (-not (Test-Path $backupRes)) { throw "No backup at $backupRes" }
    foreach ($s in $schemes) {
        $src = Join-Path $backupRes $s
        if (Test-Path $src) {
            if ($PSCmdlet.ShouldProcess((Join-Path $resDir $s), 'Restore')) {
                Copy-Item $src (Join-Path $resDir $s) -Force
                Write-Ok $s
            }
        } else { Write-Warn "$s not in backup" }
    }
    return
}

# --- Back up (once) ---------------------------------------------------------
Write-Step 'Backing up scheme files'
if (-not (Test-Path $backupRes)) {
    if ($PSCmdlet.ShouldProcess($backupRes, 'Create pristine backup')) {
        New-Item -ItemType Directory -Path $backupRes -Force | Out-Null
    }
}
foreach ($s in $schemes) {
    $src = Join-Path $resDir $s
    $dst = Join-Path $backupRes $s
    if ((Test-Path $src) -and -not (Test-Path $dst)) {
        if ($PSCmdlet.ShouldProcess($dst, 'Back up')) {
            Copy-Item $src $dst -Force; Write-Ok $s
        }
    } elseif (Test-Path $dst) {
        Write-Ok "$s already backed up (kept - it is the pristine copy)"
    }
}

# --- Parse one scheme file into font blocks ---------------------------------
function Get-FontBlocks {
    param([string[]] $Lines)

    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim().Trim('"') -eq 'Fonts') { $start = $i; break }
    }
    if ($start -lt 0) { return $null }

    # consume up to and including the opening brace of the Fonts section
    $i = $start
    while ($i -lt $Lines.Count -and $Lines[$i] -notmatch '\{') { $i++ }
    $i++

    $depth = 1              # 1 = inside Fonts, 2 = inside a font, 3 = inside a block
    $fonts = @()
    $font = $null
    $block = $null
    $pendingName = $null

    for (; $i -lt $Lines.Count; $i++) {
        $t = $Lines[$i].Trim()
        if ($t -match '^//') { continue }

        if ($t -match '^\{') {
            $depth++
            if ($depth -eq 2) {
                $font = [pscustomobject]@{ Name = $pendingName; NameLine = $pendingLine; Blocks = @() }
                $fonts += $font
            } elseif ($depth -eq 3) {
                $block = [pscustomobject]@{ Label = $pendingName; LabelLine = $pendingLine
                                            Open = $i; Close = -1; Props = @() }
                $font.Blocks += $block
            }
            continue
        }
        if ($t -match '^\}') {
            if ($depth -eq 3) { $block.Close = $i }
            $depth--
            if ($depth -eq 0) { break }
            continue
        }

        if ($depth -eq 1 -or $depth -eq 2) {
            # The name may carry a trailing comment - Legacy_CreditsFont does,
            # and anchoring at end of line silently attributed its block to the
            # previous font, which then defeated the skip list.
            if ($t -match '^"([^"]+)"\s*(//.*)?$') { $pendingName = $Matches[1]; $pendingLine = $i }
        } elseif ($depth -eq 3) {
            $block.Props += $i
        }
    }
    return $fonts
}

# --- Transform --------------------------------------------------------------
Write-Step "Scaling menu fonts (x$Scale above ${MinYres}p)"

foreach ($s in $schemes) {
    $path = Join-Path $resDir $s
    if (-not (Test-Path $path)) { Write-Warn "$s missing - skipped"; continue }

    # Read twice: lines for parsing, raw for the exact newline convention. Writing
    # with WriteAllLines would otherwise add or drop the final newline, leaving a
    # one-byte difference in a game file for no reason.
    $raw   = [System.IO.File]::ReadAllText($path)
    $nl    = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $endNl = $raw.EndsWith("`n")
    if ($raw.Contains($marker)) {
        Write-Warn "$s is already scaled - skipped. Use -Revert first to change the factor."
        continue
    }

    $lines = [System.IO.File]::ReadAllLines($path)
    $fonts = Get-FontBlocks -Lines $lines
    if (-not $fonts) { Write-Warn "$s has no Fonts section - skipped"; continue }

    # Collect edits, then apply bottom-up so earlier indices stay valid.
    $inserts  = @()   # @{ At = <line>; Lines = @() }
    $replaces = @{}   # line -> new text
    $changed  = 0

    foreach ($f in $fonts) {
        if ($skipFonts -contains $f.Name) { continue }
        if ($f.Blocks.Count -eq 0) { continue }

        $hasYres = $false
        foreach ($b in $f.Blocks) {
            foreach ($p in $b.Props) { if ($lines[$p] -match '"yres"') { $hasYres = $true } }
        }

        if (-not $hasYres) {
            # Build a new highest-priority block from block 1, guarded by yres,
            # and renumber the existing blocks so ours is evaluated first.
            $src = $f.Blocks[0]
            $new = @()
            $new += $lines[$src.LabelLine] -replace '"[^"]+"', '"1"'
            $new += $lines[$src.Open]
            $indent = ''
            foreach ($p in $src.Props) {
                $line = $lines[$p]
                if ($line -match '^(\s*)') { $indent = $Matches[1] }
                if ($line -match '"tall"\s*"?(\d+)"?') {
                    $big = [int][Math]::Round([int]$Matches[1] * $Scale)
                    $line = $line -replace '("tall"\s*)"?\d+"?', ('$1"' + $big + '"')
                }
                $new += $line
            }
            $new += ($indent + '"yres"' + "`t" + '"' + $MinYres + ' 6000"')
            $new += $lines[$src.Close]

            $inserts += @{ At = $src.LabelLine; Lines = $new }

            for ($k = 0; $k -lt $f.Blocks.Count; $k++) {
                $b = $f.Blocks[$k]
                $replaces[$b.LabelLine] = ($lines[$b.LabelLine] -replace '"[^"]+"', ('"' + ($k + 2) + '"'))
            }
            $changed++
        } else {
            # The font already scales by resolution (EngineFont does). Then no
            # new block is needed or wanted - just enlarge the one block that
            # covers the open-ended top range. Blocks for lower resolutions are
            # left exactly as they are, so 768p and 1024p users see no change.
            $top = $null
            foreach ($b in $f.Blocks) {
                foreach ($p in $b.Props) {
                    if ($lines[$p] -match '"yres"\s*"(\d+)\s+(\d+)"' -and
                        [int]$Matches[2] -ge 6000 -and [int]$Matches[1] -le $MinYres) { $top = $b }
                }
            }
            if (-not $top) { continue }

            foreach ($p in $top.Props) {
                if ($lines[$p] -match '"tall"\s*"?(\d+)"?') {
                    $big = [int][Math]::Round([int]$Matches[1] * $Scale)
                    $replaces[$p] = ($lines[$p] -replace '("tall"\s*)"?\d+"?', ('$1"' + $big + '"'))
                    $changed++
                }
            }
        }
    }

    $markerAt = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().Trim('"') -eq 'Fonts') { $markerAt = $i; break }
    }

    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -eq $markerAt -and $changed -gt 0) { $out.Add($marker) }
        foreach ($ins in $inserts) { if ($ins.At -eq $i) { $ins.Lines | ForEach-Object { $out.Add($_) } } }
        if ($replaces.ContainsKey($i)) { $out.Add($replaces[$i]) } else { $out.Add($lines[$i]) }
    }
    foreach ($ins in $inserts) { if ($ins.At -ge $lines.Count) { $ins.Lines | ForEach-Object { $out.Add($_) } } }

    if ($PSCmdlet.ShouldProcess($path, "Scale $changed font(s)")) {
        $text = ($out.ToArray() -join $nl)
        if ($endNl) { $text += $nl }
        [System.IO.File]::WriteAllText($path, $text)
        Write-Ok "$s - $changed font(s) scaled, $($out.Count - $lines.Count) lines added"
    } else {
        Write-Ok "$s - would scale $changed font(s)"
    }
}

@"

The in-game HUD is deliberately untouched - its sizes are compiled into
client.dll and there is no cvar for them.

If menu text now overflows its buttons, the dialog .res files use fixed pixel
sizes and would need scaling too. Report it rather than guessing: run
  .\tools\Set-CofFontScale.ps1 -Revert
to go back, or lower -Scale.
"@ | Write-Host
