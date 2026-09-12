# Cry of Fear: RTX HDR, 1440p & Ultra-Low Latency Enhancement Suite

Real HDR output, high-resolution rendering, and ultra-low latency reaction times for *Cry of Fear* on NVIDIA RTX GPUs and HDR displays — crash-safe, without ReShade, and without replacing game binaries.

**Author:** Collin Lerche (zfzfg) | STERRA ([https://sterra.online](https://sterra.online))  
**License:** [MIT License](LICENSE)

---

### 📦 Portable Release Ready Out-of-the-Box!
Looking for the fastest way to install and configure everything?  
Check out the **[CryOfFear-HDR-Portable](portable/CryOfFear-HDR-Portable/)** folder or grab the ready-to-run ZIP from [`dist/CryOfFear-HDR-Portable-v1.0.0.zip`](dist/CryOfFear-HDR-Portable-v1.0.0.zip)!
- **Modern WPF GUI Configurator:** `CryOfFearHDRConfig.exe`
- **1-Click Automated Batch Installers:** `INSTALL.bat`, `DIAGNOSE.bat`, `UNINSTALL.bat`
- **100% in English** with zero dependencies.

---

| Feature | Details |
|---|---|
| **Target GPU** | NVIDIA GeForce RTX (20, 30, 40, 50-series), Windows 10/11 HDR |
| **Game** | Cry of Fear 1.6 (Steam App 223710), GoldSrc build 5936 / Paranoia renderer |
| **Visuals** | NVIDIA RTX HDR, 16x Anisotropic Filtering, High Quality Textures, Softened Nightmare Shader |
| **Responsiveness** | Raw mouse input (`m_filter 0`), V-Sync buffer lag kill (`gl_vsync 0`), 101 tickrate command sync |
| **Field of View** | Adjustable widescreen FOV multiplier (`cl_fovmultiplier 1.15`) |

Full technical report and reasoning: [HDRmodCOF.md](HDRmodCOF.md).  
German quick-start for legacy profiles: [install/KURZANLEITUNG.md](install/KURZANLEITUNG.md).


---

## What this actually is

Cry of Fear's engine cannot render HDR and never will: OpenGL 1.x, 8-bit textures
and lightmaps, no floating-point framebuffer, no full-screen tone-mapping pass.
(It does have a small Cg shader path — see artifact 4 — but nothing that could
carry an HDR pipeline.) So there is nothing to "patch into" the engine. What produces HDR is **NVIDIA RTX HDR converting the game's
SDR frames**, and the only thing standing between a stock install and that working is
configuration — most of it outside the game folder entirely.

That shapes what this project ships. It is a **configuration package**, not a code mod:

```
cof-hdr/
├─ README.md                          this file (English, for distribution)
├─ CHANGELOG.md                       what shipped, what is verified, what is not
├─ LICENSE                            MIT, with a scope note on game content
├─ HDRmodCOF.md                       the technical report: why, and what was rejected
├─ install/
│  ├─ KURZANLEITUNG.md                German end-user quick start
│  ├─ autoexec.cfg                    game config, merged onto the stock 1.6 file
│  ├─ cof-hdr-nvidia-*.nip            NVIDIA profiles — one per complete state
│  └─ cgshaders/black_fp.cg           softened B/W nightmare effect (opt-in)
└─ tools/
   ├─ Install-CofHdr.ps1              backup + config + DPI flag + profile import
   ├─ Set-CofFontScale.ps1            menu font scaling for high-res displays
   ├─ Uninstall-CofHdr.ps1            full revert
   ├─ Test-CofHdr.ps1                 read-only diagnosis of every precondition
   └─ Build-Release.ps1               packs the release zip from an allow-list
```

## The artifacts, and why each exists

### 1. `install/*.nip` — the NVIDIA profile (the real "installer")

This is the piece that does the actual work. A `.nip` is a NVIDIA Profile Inspector
export: XML, one profile keyed to `cof.exe`, decimal setting IDs. Importing it sets
in one step what would otherwise be two separate manual detours:

| Setting | ID | Value | Why |
|---|---|---|---|
| Vulkan/OpenGL Present Method | `0x20D690F8` | `1` — layered on DXGI Swapchain | **The critical one.** OpenGL frames otherwise present through a legacy path Windows treats as SDR-only. Without it, no HDR reaches the game at all. |
| RTX HDR — Enable | `0x00DD48FB` | `1` | Turns the feature on for this program. |
| RTX HDR — Driver Flags | `0x00432F84` | `0` (app route) / `2` (driver route) | `0` runs RTX HDR through NVOverlay so the four tuning sliders stay adjustable. Any non-zero value runs it in the driver with **no** brightness/contrast/saturation control; `2` is very-high debanding, chosen deliberately because GoldSrc's 8-bit lightmaps band badly under tone expansion. |
| Game Filters | `0x00980896` | `1` | The NVOverlay route needs Freestyle filters enabled. |

Import: `nvidiaProfileInspector.exe -silentImport install\cof-hdr-nvidia-driver-quality.nip`

**Importing replaces the profile, it does not merge into it.** Each file therefore
describes one complete state — HDR alone, or HDR plus forced 16x anisotropic
filtering and 8x MSAA, which GoldSrc cannot do itself. Layering two imports drops
whatever the first one set; that is how the RTX HDR settings were lost once.

Target `cof.exe`, not `CoFLaunchApp.exe` — Steam starts the launcher, but `cof.exe`
is the process that creates the GL context.

### 2. `install/autoexec.cfg` — a neutral SDR frame to expand

Its job is not to make the game look better; it is to hand RTX HDR a clean, stable,
unmodified-gamma image. Pinning `brightness`/`gamma` to their stock values matters
because those go through the hardware gamma ramp, which Windows **ignores** while HDR
is on — so leaving them anywhere but neutral skews the input for no visible benefit.

It is a **merge**, not a replacement. Cry of Fear 1.6 ships its own `autoexec.cfg`
carrying gameplay lines (`sv_maxspeed`, `cl_sidespeed`, `sv_voicecodec`, …); those are
preserved verbatim at the top of the file. The installer refuses to overwrite an
existing `autoexec.cfg` and writes `autoexec.hdr.cfg` alongside it instead.

### 3. `tools/Install-CofHdr.ps1` — the parts that can honestly be automated

Locates the game through the Steam library, backs up `SAVE/` and the configs to a
timestamped folder, installs the config, sets the high-DPI override for `cof.exe`,
and optionally imports the `.nip`.

It deliberately does **not** touch Windows HDR, Auto HDR, or Steam launch options.
Those are user-facing OS settings; an install script silently changing them is worse
than a checklist. It prints the checklist instead. Supports `-WhatIf`.

### 4. `install/cgshaders/black_fp.cg` — the one edit that reaches into the renderer

The Paranoia renderer is not purely fixed-function: `cg.dll` / `cgGL.dll` ship with
the game and `cryoffear/cgshaders/` holds six plain-text Cg shaders compiled at load.
`black_fp.cg` is the black-and-white nightmare effect, and it resolves to

```
rgb = 1.2 - 4.0 * (r + g + b)
```

— a steep inverted ramp that clips hard at both ends. That is the worst possible
input for a tone expander: everything near 1.0 gets pushed to the panel's peak
brightness, in an otherwise pitch-dark scene. The shipped version flattens the slope
and caps output below white, so the effect survives as an artistic device instead of
being switched off wholesale with `gl_posteffects 0`.

Opt-in (`-Shader`), because unlike everything else in this package it overwrites a
file the game ships — Steam's file verification reverts it, and the installer backs
up the original first.

### 5. `tools/Test-CofHdr.ps1` — diagnosis, because there are many failure points

Read-only. Walks the chain — GPU, Windows build, display HDR state, game install,
`opengl32.dll` presence, config contents, Cg shaders, DPI override, Steam launch
options, NVIDIA app presence — and reports `[ok] / [FAIL] / [warn] / [?]`.

Anything it cannot determine reliably is reported as `[?]`, never as a pass. When
"HDR doesn't work", this tells you which link broke instead of leaving you guessing
between eight candidates.

---

## Install

```powershell
.\tools\Install-CofHdr.ps1 -WhatIf                    # dry run: changes nothing
.\tools\Install-CofHdr.ps1 -InspectorPath C:\Tools\nvidiaProfileInspector.exe
.\tools\Install-CofHdr.ps1 -DriverPath -Quality -Fonts   # the usual full run
.\tools\Install-CofHdr.ps1 -Shader                       # + softened B/W effect
.\tools\Install-CofHdr.ps1 -DriverPath -Quality -NoAA    # if forcing MSAA misbehaves
.\tools\Test-CofHdr.ps1                               # verify
.\tools\Uninstall-CofHdr.ps1                          # revert everything
```

`-Quality` forces 16x anisotropic filtering and 8x MSAA; `-Fonts` scales the menu
text for displays taller than 1200 px. The in-game HUD cannot be scaled — its
sizes are compiled into `client.dll`.

Without `-InspectorPath` the script tells you which `.nip` to import by hand.
Every run backs up saves and configs to `backup/<timestamp>/` first.

Then the manual checklist the installer prints: Windows HDR on, Auto HDR **off**,
run Windows HDR Calibration, set Steam launch options
(`-window -noborder -w <w> -h <h> -console -noforcemparms -noforcemaccel -noforcemspd`), and enable
RTX HDR in the NVIDIA app. The `-noforce*` flags stop the engine from re-enabling
Windows' mouse acceleration on every launch.

Tuning the four sliders afterwards is section 4 of [HDRmodCOF.md](HDRmodCOF.md) —
the short version is that **Middle Grey goes up**, contrast and saturation go down,
and peak sits slightly below your panel's real capability.

---

## Going further: what else is genuinely moddable

Found by inspecting an actual 1.6 install, documented in
[HDRmodCOF.md](HDRmodCOF.md) section 9:

- **The other Cg shaders.** `water_fp.cg` and its vertex program are editable by the
  same method as `black_fp.cg`. Water is a highlight-bearing surface, so there is
  room here, though less than in the post-effect.
- **`liblist.gam`.** Its `commandargs` field could carry the window-mode flags as a
  mod file rather than a manual Steam step — at the cost of editing a shipped file
  that Steam verification reverts.
- **Lightmaps.** Recompiling maps with wider lit/unlit range gives the tone expander
  unambiguous highlights to lift. Highest-value asset change, and by far the largest
  effort.

## What is never shipped

`cof.exe`, `hw.dll`, Paranoia's `opengl32.dll`, stock WADs/BSPs/MDLs, or any patched
binary. The package references the user's own Steam install. Everything here is local
configuration and driver settings, which keeps it clear of both the Steam Subscriber
Agreement and the VAC complications that custom `opengl32.dll` files have historically
caused in other GoldSrc games.

## Status

**v1.1.0 — complete and packaged.** `tools/Build-Release.ps1` produces
`dist/cof-hdr-1.1.0.zip` from an explicit allow-list.

Verified: NVIDIA setting IDs and values against NVIDIA's published setting database;
the `.nip` schema against a real Profile Inspector export; install layout, stock
config contents, the Cg shader path and `liblist.gam` against a real Cry of Fear 1.6
install; all scripts parse, and the diagnostic and both dry-run paths execute clean.

Not verified: **the end-to-end visual result on hardware** — in particular whether
the layered-DXGI present path cooperates with Paranoia's `opengl32.dll`, and whether
the softened shader compiles under the profile this build selects. See
[CHANGELOG.md](CHANGELOG.md) and section 12 of [HDRmodCOF.md](HDRmodCOF.md).
