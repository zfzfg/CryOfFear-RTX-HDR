# Changelog

## 1.3.0 — 2026-09-12

Installer correctness, Steam launch options, HDR indicator, settings persistence.

### Added

- Steam launch options are written to `localconfig.vdf` when Steam is **closed**. If Steam is running, they are copied instead (Steam would overwrite the file on exit). Close Steam and click Install again to write them.
- HDR indicator profile (`CryOfFear-HDR-Indicator.nip`, driver flags `3`) and a GUI button. Confirms RTX HDR is running; Install puts the Quality profile back.
- GUI remembers path, resolution, FOV, and checkboxes in `CryOfFearHDRConfig.json`.
- Header button opens Windows display settings (`ms-settings:display`).
- Diagnose reads Steam launch options, whether `black_fp.cg` is the softened shader, NVIDIA driver branch vs 551.23, and driver flags `2` vs `3`.

### Fixed

- Install / Uninstall no longer report success when the NVIDIA profile import fails (UAC cancel or non-zero inspector exit).
- Re-install with Raw mouse / VSync / engine rates unchecked now reverts those cvars instead of leaving the previous values. Unchecking the nightmare shader restores stock `black_fp.cg` from backup.
- First-run backup lives under `%LOCALAPPDATA%\CryOfFearHDR\backup\` (legacy `backup\original` in the package folder is still found on uninstall). Saves stay out of the portable zip.
- Reset profile is reviewable UTF-16 XML and turns RTX HDR / AF overrides back off.
- Clipboard copy no longer crashes the GUI if the clipboard is locked.
- GUI install no longer dies on `RawMouse` / `LowLatencyVsync` / `EngineRates`: `powershell -File` cannot bind `$true` to `[bool]`. Arguments are `1`/`0`, and Install.ps1 accepts `$true`, `true`, or `1`.

### Not changed

- Fullscreen, Route 3B (driver flags `2`, no NVIDIA App sliders), MSAA off, `fps_max 100`, stock menu fonts.


## 1.2.0 — 2026-09-12

Installer GUI: status, live launch options, no frozen window.

### Added

- Header chips for game path, Windows HDR, and Auto HDR (`cof.exe` override), with Refresh.
- Live Steam launch-options field (copy in place). Resolution combo lists desktop native plus `EnumDisplaySettings` modes, then Custom.
- After a successful install, an in-window checklist (HDR chips + launch line + Steam paste hint). Launch options are copied automatically.
- Colour-coded log (`[PASS]` / `[WARN]` / `[FAIL]`).

### Fixed

- Install / Diagnose / Revert no longer block the UI thread. Action buttons disable while a script runs.
- “Desktop native” no longer copies `2560×1440` when the fields were `0×0`. It uses the current display mode in pixels.
- Disabled MSAA checkbox removed; MSAA-off is a caption, not a fake control.

### Not changed

- Fullscreen, Route 3B, MSAA off, `fps_max 100`, Auto HDR off only for `cof.exe`.


## 1.1.0 — 2026-09-12

Portable-only release. Fullscreen and RTX HDR Route 3B are unchanged.

### Fixed

- Texture filtering quality in `CryOfFear-HDR-Quality.nip` was `20`; High Quality is `4294967286` (`0xFFFFFFF6`).
- GUI and `INSTALL.bat` no longer invent a second `autoexec.cfg`. Both call `tools/Install.ps1`, which merges cvars into an existing file and keeps Cry of Fear 1.6 gameplay lines.
- GUI labelled fullscreen as "Borderless / DirectFlip". The label now matches `-fullscreen`. This build has no `-noborder` flag.
- NVIDIA Profile Inspector success was logged even if UAC was cancelled (`Process.Start` null) or the inspector exited non-zero.
- Double UAC: `INSTALL.bat` / `UNINSTALL.bat` no longer elevate the whole script. Only the inspector import requests admin.
- Independent AF checkbox did nothing (same NIP either way). 16x AF is part of the one quality profile.
- README promised Custom resolution; the GUI now has width/height fields plus Desktop native.

### Added

- Windows HDR is queried through DisplayConfig during install and diagnose. If HDR is off, install warns; diagnose `[FAIL]`s.
- Auto HDR is turned **off for `cof.exe` only** (`HKCU\...\UserGpuPreferences`, `AutoHDREnable=0`). Global Auto HDR and other games stay as they are. Uninstall removes that override.
- First-run backup of `SAVE/`, configs, and `black_fp.cg` under `backup/original`. Later installs never overwrite it. Uninstall does not restore saves.
- `tools/Common.ps1`, `Build-Config.ps1`, `Build-Portable.ps1`. Release zip is an allow-list (no `backup/`, no `.pdb`, no inspector profile dumps).

### Not changed

- Fullscreen launch options, Route 3B driver flags (`2`), MSAA off, `fps_max 100`, stock menu fonts.
