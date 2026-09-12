# Cry of Fear: RTX HDR, 1440p & Ultra-Low Latency Enhancement Mod (Portable Edition)

**Created by:** Collin Lerche (zfzfg) | STERRA ([https://sterra.online](https://sterra.online))  
**License:** MIT License (see [LICENSE](LICENSE))  
**Version:** 1.3.0

---

## Overview

This package is a **fully portable, standalone enhancement suite** for *Cry of Fear* (Steam). It upgrades the game's visuals and performance to modern high-definition standards while strictly avoiding engine crashes:

- **AI-Powered True HDR (NVIDIA RTX HDR, Route 3B):** Driver-level RTX HDR with VeryHigh debanding and layered DXGI present. No overlay sliders, no NVIDIA App required.
- **Fullscreen at 2560x1440 (QHD) / 4K / custom:** Registry + Steam launch options. GoldSrc in this build has no `-noborder` flag; fullscreen is the supported path.
- **Ultra-Low Latency & Instant Input:** Disables GoldSrc engine mouse smoothing (`m_filter 0`), disables V-Sync buffering lag (`gl_vsync 0`), and unlocks 101 tickrate engine updates (`cl_updaterate 101`, `cl_cmdrate 101`, `rate 100000`).
- **Custom Field of View (FOV):** Enhanced perspective (`cl_fovmultiplier 1.15`) for natural widescreen view distances on 16:9 and 16:10 displays.
- **Crash-Proof High Quality Driver Profile:**
  - **16x High-Quality Anisotropic Filtering**
  - **Negative LOD Bias Clamped** with High Quality Texture Filtering
  - **MSAA Forced OFF:** Anti-aliasing causes fatal GoldSrc engine vertex buffer crashes.
- **Auto HDR off for Cry of Fear only:** The installer checks Windows HDR and writes a per-app override (`AutoHDREnable=0` for `cof.exe`) so Auto HDR cannot stack with RTX HDR. Other games are unchanged.
- **Softened Nightmare Post-Processing (optional):** Replaces the stock `black_fp.cg` nightmare shader with a balanced vignette.

---

## Quick Start

### Option 1: GUI Configurator (Recommended)
1. Double-click **`CryOfFearHDRConfig.exe`**.
2. Check the header chips (game path, Windows HDR, Auto HDR for CoF).
3. Customize resolution (desktop native, listed modes, or custom), FOV, and latency options. Steam launch options update live — Copy is next to the field.
4. Click **Install**. Confirm the UAC prompt for the driver profile.
5. If Steam is closed, launch options are written automatically. If Steam is running, they are copied — paste them, or close Steam and click Install again:
   ```text
   -fullscreen -w 2560 -h 1440 -noforcemparms -noforcemaccel -noforcemspd
   ```
6. Turn **Windows HDR ON** (`Win + Alt + B` or **HDR settings** in the header). Auto HDR for this game is already disabled.
7. Launch the game. Optional: **HDR indicator** draws an on-screen marker while RTX HDR is active; click Install afterwards to hide it.

### Option 2: 1-Click Automated Batch Scripts
- **`INSTALL.bat`**: Detects Steam, merges config, sets DPI, disables Auto HDR for `cof.exe`, imports the driver profile.
- **`DIAGNOSE.bat`**: HDR display state, Auto HDR override, GPU driver settings, file integrity.
- **`UNINSTALL.bat`**: Restores original shaders/config and resets the driver profile. **Saves are never rolled back.**

---

## Requirements

- **OS:** Windows 10 (Build 19041+) or Windows 11.
- **Display:** HDR-capable monitor with Windows HDR turned ON.
- **GPU:** NVIDIA GeForce RTX 20-series or newer (Driver 551.23 or newer).
- **Game:** Cry of Fear on Steam.

---

## Package Structure

```text
CryOfFear-HDR-Portable/
├── CryOfFearHDRConfig.exe            # WPF graphical configurator
├── INSTALL.bat                       # 1-click installer
├── UNINSTALL.bat                     # uninstaller (saves untouched)
├── DIAGNOSE.bat                      # diagnostics
├── LICENSE
├── README.md
├── QUICKSTART.txt
├── CHANGELOG.md
├── files/
│   ├── autoexec.cfg                  # template; merged into an existing autoexec
│   └── cgshaders/black_fp.cg
├── profiles/
│   ├── CryOfFear-HDR-Quality.nip     # RTX HDR Route 3B + 16x AF, MSAA off
│   ├── CryOfFear-HDR-Indicator.nip   # same, driver flags 3 (on-screen marker)
│   └── CryOfFear-HDR-Reset.nip
├── src/Program.cs
└── tools/
    ├── Common.ps1
    ├── Install.ps1
    ├── Uninstall.ps1
    ├── Test.ps1
    ├── Build-Config.ps1
    ├── Build-Portable.ps1
    └── nvidiaProfileInspector/
```

---

## Troubleshooting

### The game starts in 1080p instead of 1440p
Close Steam and click **Install** again so launch options can be written, or paste: `-fullscreen -w 2560 -h 1440 -noforcemparms -noforcemaccel -noforcemspd`.

### Windows HDR is off
Diagnostics will `[FAIL]` this. RTX HDR cannot produce HDR output until Windows HDR is on. The installer does **not** flip that OS switch.

### Washed-out greys / two tone mappers
Auto HDR must not run on Cry of Fear together with RTX HDR. Re-run the installer — it sets `AutoHDREnable=0` for `cof.exe` only.

### The main menu font is too large or truncated
This mod keeps stock menu font sizes so inventory and keybind dialogs stay intact at any resolution.

### Is RTX HDR working?
Click **HDR indicator**, launch the game, and look for the driver marker. Then click **Install** to return to the Quality profile (no marker). `DIAGNOSE.bat` also reads Windows HDR via DisplayConfig and the `Cry of Fear (HDR)` settings out of the NVIDIA driver database.

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.  
Copyright (c) 2026 Collin Lerche (zfzfg) | STERRA.  
Website: [https://sterra.online](https://sterra.online)

This package does not redistribute Cry of Fear or GoldSrc binaries. `files/cgshaders/black_fp.cg` is a source edit you apply to your own copy of the game.
