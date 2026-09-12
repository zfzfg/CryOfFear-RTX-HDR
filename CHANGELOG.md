# Changelog

## 1.1.1 — 2026-09-12

Regression fixes from the first real 1440p run.

### Fixed

- **The game crashed on launch after 1.1.0.** Three changes had gone in at once -
  forced MSAA, scaled menu fonts, and new cvars - which is exactly the mistake
  that makes a crash hard to attribute. The file timestamps placed it: the game
  ran and exited cleanly at 16:09, the changes landed at 16:34-16:39, and the
  16:47 run wrote level-transition saves but never rewrote config.cfg, so it
  reached map load and died there. The forced MSAA is the prime suspect - the
  one interaction flagged as undocumented from the start - so the profile is now
  the `-noaa` variant. Anisotropic filtering, texture quality and HDR are kept.
- **"Enhance pointer precision" switched itself back on after every launch.**
  GoldSrc rewrites the Windows mouse parameters through `SystemParametersInfo`
  at startup. The launch options now carry `-noforcemparms -noforcemaccel
  -noforcemspd`, all three confirmed present in `hw.dll` by string search before
  being recommended. This build predates `m_rawinput`, so there is no in-game
  alternative.
- `r_detailtextures 1` removed again. The game ships no `_detail.txt` at all, so
  the engine just logs "No detail texture mapping file" and continues - the line
  could not help and was still a crash suspect. A change with no upside does not
  belong in a config.

### Note

The crash cause is inferred from timestamps and from which change carried known
risk, not proven. If the game still crashes with MSAA off, revert the fonts with
`Set-CofFontScale.ps1 -Revert` - that is the next suspect, and the two can be
separated in one further launch each.


## 1.1.0 — 2026-09-12

Resolution, menu fonts and driver-level image quality for 1440p.

### Added

- `tools/Set-CofFontScale.ps1` — scales the menu fonts by adding `yres`-guarded
  blocks to `trackerscheme.res` and `clientscheme.res`. Behaviour below 1200 px
  stays byte-for-byte identical, and a marker line makes repeated runs a no-op
  instead of compounding the sizes. Edits the player's own files rather than
  shipping modified game content.
- Image quality forced through the NVIDIA profile, which GoldSrc cannot do
  itself: 16x anisotropic filtering, true 8x MSAA (`0x25`, not the weaker 8x
  CSAA), 4x sparse-grid transparency supersampling, high-quality texture
  filtering with the optimisations off, negative LOD bias clamped.
- `-Quality`, `-NoAA` and `-Fonts` switches on `Install-CofHdr.ps1`.
- `Test-CofHdr.ps1` now reads the driver profile's actual settings out of
  `nvdrsdb0.bin` and reports which are active, rather than only checking that
  the profile exists.
- `autoexec.cfg`: `r_detailtextures 1`, `cl_fovmultiplier`, and commented-out
  test entries for `gl_overbright` and `gl_contrast`.

### Fixed

- **`fps_override` was a no-op and the advice to use it was wrong.** This engine
  build has no such cvar - a byte search of `hw.dll`/`sw.dll` finds only
  `fps_max` and `fps_modem` - and the 100 fps ceiling is compiled in. The line
  is gone, `fps_max` is 100, and the diagnostic now reports `fps_override` in a
  config as an error.
- **A `.nip` import replaces the profile, it does not merge.** Importing a
  quality-only profile silently removed the RTX HDR and present-method settings
  from the driver. Every shipped profile now describes one complete state, and
  the combinations are generated rather than layered.
- `Set-CofFontScale.ps1` attributed `Legacy_CreditsFont`'s block to the previous
  font, because the font name carries a trailing comment and the pattern was
  anchored at end of line - which defeated the skip list for the one font the
  game explicitly marks as "should not scale".
- Scheme files keep their exact newline convention; writing them back with
  `WriteAllLines` had been adding a byte at EOF.
- `Uninstall-CofHdr.ps1` restores the scheme files.

### Verified

- All 18 settings of the combined profile read back correctly from the driver
  database after import.
- Scheme edits confined to the `Fonts` section: text before and after it is
  byte-identical, braces balanced, CRLF preserved.
- Repeated runs of the font tool change nothing.
- All five scripts parse; the diagnostic reports no `[FAIL]`.

### Not verified

- The visual result of MSAA alongside RTX HDR and the layered-DXGI present
  path. Fall back to `cof-hdr-nvidia-driver-quality-noaa.nip` if it misbehaves.
- Whether the enlarged menu fonts overflow the fixed-size dialog panels.


## 1.0.0 — 2026-09-12

First complete release. HDR output for Cry of Fear on RTX GPUs without ReShade
and without replacing any game binary.

### Added

- `install/cof-hdr-nvidia-app.nip` — NVIDIA profile for the NVOverlay route
  (RTX HDR tuning sliders remain available). Sets the Vulkan/OpenGL present
  method to *layered on DXGI Swapchain*, which is what makes HDR reach an
  OpenGL game at all.
- `install/cof-hdr-nvidia-driver.nip` — same, for the driver route, for users
  without the NVIDIA app. Very-high debanding, chosen because GoldSrc's 8-bit
  lightmaps band under tone expansion.
- `install/cof-hdr-nvidia-driver-indicator.nip` — the driver profile with flags
  `3`, which makes the driver draw an on-screen marker while RTX HDR runs. Without
  the NVIDIA app there is no overlay to ask, so this is the only way to confirm the
  filter is actually active.
- `install/cof-hdr-nvidia-reset.nip` — reverts all of them.
- `install/autoexec.cfg` — merged onto the stock Cry of Fear 1.6 config, whose
  gameplay lines are preserved verbatim.
- `install/cgshaders/black_fp.cg` — softened black-and-white nightmare effect.
  The stock shader resolves to `1.2 - 4.0 * (r+g+b)`: a hard-clipping inverted
  ramp that a tone expander pushes to panel peak brightness in an otherwise
  dark scene. This version flattens the slope and caps output below white.
  Opt-in via `-Shader`.
- `tools/Install-CofHdr.ps1` — locate, back up, install, set the DPI override,
  optionally import the profile. Supports `-WhatIf`.
- `tools/Uninstall-CofHdr.ps1` — full revert. Deliberately does not roll back
  saves, which are newer than the backup.
- `tools/Test-CofHdr.ps1` — read-only diagnosis of every link in the chain.
  Reports what it cannot verify as `[?]`, never as a pass.
- `HDRmodCOF.md` — technical report: the pipeline, tuning, troubleshooting, and
  the routes that were evaluated and rejected.
- `install/KURZANLEITUNG.md` — German quick start.

### Fixed during first real deployment

- `Install-CofHdr.ps1` now keeps a single pristine backup at `backup/original`
  and never overwrites it. A second install run previously backed up files the
  first run had already modified, so `Uninstall-CofHdr.ps1` would have
  "restored" the modified state. The uninstaller prefers `backup/original`.
- `Test-CofHdr.ps1` reads the HDR state through the DisplayConfig API instead
  of the graphics-driver registry key, which is ACL'd for normal users. The
  first attempt returned garbage: `DISPLAYCONFIG_PATH_SOURCE_INFO` ends with a
  `statusFlags` field, making `DISPLAYCONFIG_PATH_INFO` 72 bytes rather than
  68 - omitting it shifts every later field and every call fails with
  ERROR_INVALID_PARAMETER while still looking plausible. It now reports
  per display path: connection type, HDR capable, HDR on, bits per channel.
- `Test-CofHdr.ps1` detects whether the `.nip` import reached the driver, by
  searching the profile database for the profile name (stored as plain UTF-16).
- `Test-CofHdr.ps1` checks the per-app Auto HDR override rather than assuming
  Auto HDR must be off globally.
- `Install-CofHdr.ps1` matches `fps_max` to the display's refresh rate,
  capped at 300.
- `Uninstall-CofHdr.ps1` removes the per-app Auto HDR override it set.

### Verified

- NVIDIA setting IDs and values against NVIDIA's published setting database.
- `.nip` schema against a real Profile Inspector export.
- Install layout, stock config contents, Cg shader path and `liblist.gam`
  against a real Cry of Fear 1.6 install.
- All three scripts parse; `Test-CofHdr.ps1` and both `-WhatIf` paths run clean.

### Not verified

- The end-to-end visual result on hardware. In particular whether the
  layered-DXGI present path cooperates with Paranoia's `opengl32.dll`.
  See `HDRmodCOF.md` section 12.
