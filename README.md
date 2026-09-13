# Cry of Fear: RTX HDR, 1440p & Ultra-Low Latency (Portable Edition)

**Version 1.3.0** · by Collin Lerche (zfzfg) | [STERRA](https://sterra.online) · MIT License

This installer upgrades *your* Steam copy of Cry of Fear: true HDR, a modern resolution, snappier input, and sharper textures — without the anti-aliasing settings that crash this engine.

Keep the whole folder together. `CryOfFearHDRConfig.exe` is only the menu; it will not work if you copy that one file somewhere else.

---

## What you get

- **NVIDIA RTX HDR** — driver-level HDR with strong debanding. You do not need the NVIDIA App or overlay sliders.
- **Fullscreen at 2560×1440, 4K, or a custom size** — written into Steam launch options. This build of the game has no borderless-window flag, so fullscreen is the supported path.
- **Lower input lag** — mouse smoothing and V-Sync buffering are turned off (`m_filter 0`, `gl_vsync 0`), and the engine update rate is raised (`cl_updaterate 101`, `cl_cmdrate 101`, `rate 100000`).
- **Wider FOV** — `cl_fovmultiplier` for 16:9 and 16:10.
- **A crash-safe quality profile on your NVIDIA driver**
  - 16× high-quality anisotropic filtering
  - Negative LOD bias clamped, High Quality texture filtering
  - **MSAA forced off** — forced anti-aliasing crashes Cry of Fear. Do not turn it back on in the driver.
- **Auto HDR off for this game only** — so Windows Auto HDR cannot stack with RTX HDR. Your other games stay as they are.
- **Optional softer nightmare look** — replaces the stock `black_fp.cg` vignette if you tick that box.

Your saves are never reverted.

---

## What you need

- Windows 10 (build 19041+) or Windows 11
- An HDR monitor, with **Windows HDR turned on**
- An NVIDIA GeForce RTX 20-series or newer (driver **551.23** or newer)
- Cry of Fear installed through Steam

---

## Install

### Option 1: GUI (recommended)

1. Extract the **entire** zip. Leave every file in that folder.
2. Double-click **`CryOfFearHDRConfig.exe`**.
3. Check the header chips: game path, Windows HDR, Auto HDR for Cry of Fear. Browse to `cof.exe` if the path is empty.
4. Pick your resolution (desktop native, a listed mode, or custom), FOV, and latency options. Steam launch options update as you change them — use **Copy** if you need the line.
5. Click **Install**. Accept the UAC prompt so the NVIDIA profile can be imported.
6. If Steam is **closed**, launch options are written for you. If Steam is **open**, they are only copied — paste them under Steam → Cry of Fear → Properties → Launch Options, or close Steam and click Install again. Example:

   ```text
   -fullscreen -w 2560 -h 1440 -noforcemparms -noforcemaccel -noforcemspd
   ```

7. Turn **Windows HDR on** (`Win + Alt + B`, or **HDR settings** in the header). Auto HDR for this game is already disabled.
8. Start Cry of Fear from Steam.

To confirm RTX HDR: click **HDR indicator**, launch the game, and look for the on-screen marker. Click **Install** afterwards to hide it again.

### Option 2: batch files

- **`INSTALL.bat`** — finds Steam, merges your config, sets DPI, disables Auto HDR for `cof.exe`, imports the driver profile. Accept UAC.
- **`DIAGNOSE.bat`** — checks Windows HDR, the Auto HDR override, GPU settings, and game files.
- **`UNINSTALL.bat`** — puts shaders, config, and the driver profile back. **Your saves are not touched.**

---

## If something looks wrong

**The game starts in 1080p**  
Close Steam completely and click **Install** again, or paste this into launch options:

`-fullscreen -w 2560 -h 1440 -noforcemparms -noforcemaccel -noforcemspd`

**Windows HDR is off**  
`DIAGNOSE.bat` will report `[FAIL]`. RTX HDR cannot output HDR until you turn Windows HDR on. The installer will not flip that switch for you.

**Washed-out greys / two different tone maps**  
Auto HDR is still running on Cry of Fear. Run Install again — it turns Auto HDR off for `cof.exe` only.

**Menu text looks huge or cut off**  
That is not this mod. Stock menu fonts are left alone so inventory and keybind dialogs stay readable at any resolution.

**You are not sure RTX HDR is on**  
Click **HDR indicator**, launch the game, look for the marker, then click **Install** to go back to the normal quality profile. `DIAGNOSE.bat` also reads Windows HDR and the `Cry of Fear (HDR)` driver settings.

---

## Uninstall

Double-click **`UNINSTALL.bat`**, or use **Revert** in the GUI. Shaders, config, and the NVIDIA profile go back to stock. Saves stay where they are.

---

## License

MIT License — see [LICENSE](LICENSE).  
Copyright (c) 2026 Collin Lerche (zfzfg) | STERRA · [https://sterra.online](https://sterra.online)

This download does not include Cry of Fear or GoldSrc. You must already own the game. The optional nightmare shader is applied to **your** copy.
