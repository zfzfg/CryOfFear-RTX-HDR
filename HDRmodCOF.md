# HDR for Cry of Fear on an RTX 50-Series GPU and an HDR1000 Display

**Target configuration for this document:** NVIDIA GeForce RTX 50-series (Blackwell), Windows 11, a display capable of ~1000 nits peak HDR, Cry of Fear from Steam (App 223710). **Constraint: no ReShade.** **Goal: an installation a normal player can complete in about 15 minutes.**

---

## TL;DR — The Recommended Setup

Cry of Fear's engine will never output HDR by itself. It is a pre-SteamPipe GoldSrc branch with the Paranoia OpenGL renderer: fixed-function OpenGL 1.x, 8-bit textures and lightmaps, no floating-point framebuffer.[^1][^2][^4][^5] Every realistic HDR path therefore converts the game's SDR frames to HDR *outside* the engine. On an RTX 50-series card the best converter available is **NVIDIA RTX HDR**, and it requires **zero files in the game folder** — which makes it both the highest-quality and the easiest-to-install option.

The complete recipe:

| Step | What | Where | Time |
|---|---|---|---|
| 1 | Turn on Windows HDR, run **Windows HDR Calibration** | Windows Settings / Microsoft Store | 5 min |
| 2 | Set **Vulkan/OpenGL present method → Prefer layered on DXGI Swapchain** | NVIDIA Control Panel, per-app profile for `cof.exe` | 1 min |
| 3 | Enable **RTX HDR** for Cry of Fear | NVIDIA app → Graphics → Cry of Fear | 1 min |
| 4 | Force **borderless windowed at native resolution** | Steam launch options | 1 min |
| 5 | Drop in the tuned **`autoexec.cfg`** (Section 5) | `Cry of Fear\cryoffear\` | 1 min |
| 6 | Tune the four RTX HDR sliders against two reference scenes | In-game overlay | 5 min |

Step 2 is the one most guides omit, and it is the step that makes HDR work on an OpenGL game at all.[^51][^52]

**What you get:** real HDR10/scRGB output to the panel, with highlights (flashlight cone, phone screen, fire, muzzle flash, fluorescent tubes) lifted well above SDR white while blacks stay black. On an HDR1000 panel this is a substantial, not subtle, change.

**What you do not get:** physically-based light values. The engine still renders 8-bit SDR internally; RTX HDR infers the expanded range. This is an *HDR conversion*, not native engine HDR. Section 8 explains why native HDR is not realistically achievable here; Section 9 covers what can still be modded inside the game, Section 10 what the package consists of.

---

## 1. Prerequisites

### 1.1 Required

- **GPU:** any GeForce RTX GPU; an RTX 50-series is far more than sufficient. RTX HDR costs a few percent of GPU time, which on a GoldSrc title is irrelevant. Cap the framerate anyway (Section 5) — an uncapped GoldSrc game burns power and produces erratic frame pacing.
- **OS:** 64-bit Windows 11 (Windows 10 works, but its HDR management is weaker). RTX Video/HDR features require a 64-bit *operating system*; this is not a constraint on the *game*, so Cry of Fear's 32-bit `cof.exe` is fine.[^56]
- **Display:** HDR10-capable, over DisplayPort 1.4+ or HDMI 2.1, with HDR enabled in the monitor's own OSD.[^31][^32]
- **Driver:** 526.61 or newer for the present-method option; current is recommended.[^51]
- **NVIDIA app** (successor to GeForce Experience) — RTX HDR is configured there, and it is not in the classic NVIDIA Control Panel. There is an app-free route, but it costs you the tuning sliders; see Step 3.[^55][^64]

### 1.2 Display mode choice on an HDR1000 panel

If your panel exposes several HDR modes, the choice matters more for Cry of Fear than for most games, because the game is overwhelmingly dark:

- **LCD with full-array local dimming:** use the full "HDR1000"/peak mode. You need the headroom for flashlight and fire highlights; the dimming zones handle the dark scenes.
- **OLED:** "True Black 400" gives better near-black handling and less risk of raised blacks in dark corridors, at the cost of highlight punch. "Peak 1000" is the better choice if your tuning (Section 4) keeps mid-grey low. Try both against the same reference scene.
- Disable any monitor-side "dynamic tone mapping", "smart HDR" or vendor auto-brightness. It will fight RTX HDR's tone mapper and make the flashlight cone pump in brightness as you turn.

Run the **Windows HDR Calibration** app (free, Microsoft Store) before anything else. It writes your display's real peak-luminance metadata into Windows, which is what RTX HDR's tone mapper targets; skipping it is the single most common cause of "HDR looks washed out".[^31][^32][^40]

---

## 2. Step-by-Step Installation

### Step 1 — Windows HDR

1. `Settings → System → Display → HDR` → turn **Use HDR** on.
2. Same page: **turn Auto HDR OFF.** Auto HDR and RTX HDR must never both be active on the same game; they stack two tone mappers and give you crushed or washed-out output.[^23][^39]
3. Install and run **Windows HDR Calibration** from the Microsoft Store. Complete all three patterns, save the profile.
4. Set **SDR content brightness** to taste — this affects the desktop only, not the game once RTX HDR is active.

### Step 2 — The critical NVIDIA setting: DXGI swapchain

This is what makes an OpenGL game HDR-capable at all.

By default the NVIDIA driver presents OpenGL frames through a legacy native/GDI copy path, which Windows treats as SDR-only and which the HDR pipeline cannot touch. Setting the present method to **"Prefer layered on DXGI Swapchain"** routes the OpenGL swap through a DXGI flip-model swapchain instead, and that is what enables HDR — and RTX HDR — for OpenGL and Vulkan titles.[^51][^52][^61]

1. Open **NVIDIA Control Panel → Manage 3D settings → Program Settings**.
2. Click **Add**, browse to `…\steamapps\common\Cry of Fear\cof.exe`. **`cof.exe`, not `CoFLaunchApp.exe`** — Steam starts the launcher, but `cof.exe` (a ~90 KB GoldSrc stub that loads `hw.dll`) is the process that creates the GL context. Verified against a 1.6 install.
3. Set **Vulkan/OpenGL present method** = **Prefer layered on DXGI Swapchain**.
4. Optional in the same profile: **Max Frame Rate** 120–240, **Vertical sync** On or Fast.
5. Apply.

Set this **per-program, never globally.** The layered path costs performance in some OpenGL/Vulkan titles (Minecraft is the usual example), so you do not want it system-wide.[^59]

### Step 3 — Enable RTX HDR

RTX HDR is a driver feature, but it is *configured* from the NVIDIA app — it has no entry in the classic NVIDIA Control Panel, and it never will: the Control Panel is legacy and NVIDIA has been retiring it in favour of the app. Step 2 above is the last piece of this guide that lives in the Control Panel.

There are therefore two ways to do this step. **Route 3A is strongly recommended for this particular game**, for a reason specific to Cry of Fear that is explained below.

#### Route 3A — With the NVIDIA app (recommended)

If you do not have the NVIDIA app, install it from nvidia.com. It is a free, separate download from the driver; it does not require reinstalling or changing your driver, it imports your existing Control Panel per-program profiles, and the Control Panel keeps working alongside it. It also carries the Vulkan/OpenGL present method setting from Step 2, so afterwards both steps live in one place.

1. Open the **NVIDIA app → Graphics**.
2. Find **Cry of Fear** in the program list. If it is not detected, use **Add program / Browse** and point it at `cof.exe`.
3. Enable **RTX HDR** for that program.
4. Leave the sliders at defaults for now; Section 4 covers tuning.

#### Route 3B — Without the NVIDIA app: driver-level RTX HDR

RTX HDR can also be switched on purely through the driver's per-application profile, with no app and no overlay, by writing a handful of undocumented NVAPI profile settings. Two ways to do that:

- **`NvTrueHDR`** — a small community tool that writes exactly these settings for a chosen executable. It is a profile writer, not an injector: nothing is placed in the game folder. Requires driver 531.18+ and WDDM 3.1 (Windows 11).[^62][^63]
- **NVIDIA Profile Inspector** — manual, using a build that exposes the RTX HDR flags (mainline does not name them yet; import them from a `.nip` or use a fork that does).[^64]

On the profile for `cof.exe`, set:

| Setting ID | Name | Value |
|---|---|---|
| `0x20D690F8` | Vulkan/OpenGL Present Method | `1` = layered on DXGI Swapchain (Step 2, same profile) |
| `0x00DD48FB` | RTX HDR — Enable | `1` |
| `0x00432F84` | RTX HDR — Driver Flags | `2` = via driver, **VeryHigh debanding** |
| `0x00980896` | Game Filters | `1` |
| `0x1077A11A` | undocumented, reported as required by NvTrueHDR | `1` |

Two things about `0x00432F84` that community write-ups usually get wrong, and that NVIDIA's own setting database states plainly: the value is a **debanding strength**, not a quality level — and *any* non-zero value switches RTX HDR from the NVOverlay path to the driver path, which is precisely what costs you the sliders.[^64] For this game `2` (VeryHigh debanding) is the right pick: GoldSrc's 8-bit lightmaps band badly under tone expansion, so the strongest debanding available is worth having.

Ready-made profiles for both routes ship with this project as `install/cof-hdr-nvidia-app.nip` and `install/cof-hdr-nvidia-driver.nip`; import with `nvidiaProfileInspector.exe -silentImport <file>`. A third, `install/cof-hdr-nvidia-driver-indicator.nip`, is the same driver profile with flags `3` instead of `2`: the driver then draws an on-screen marker while the filter runs, which is the only way to confirm RTX HDR is active without the app’s overlay. Import it once, check, then import the normal driver profile to switch the marker off.

Note that NVIDIA Profile Inspector is a portable executable — no installer, no service, no shell integration. For anyone avoiding the NVIDIA app specifically because of its system footprint, that distinction is the point of this route.

Driver-level RTX HDR has genuine advantages — it works across multiple monitors, needs no overlay, and the quality level is selectable, which lets you trade quality for performance.[^62][^64]

#### Why 3A matters more than usual here

**The four tuning sliders — Peak Brightness, Middle Grey, Contrast, Saturation — only do anything on the NVOverlay path.** Their profile settings (`0x00DD48FC` through `0x00DD48FF`) exist and can be written by Profile Inspector, but NVIDIA's setting database is explicit that once any driver flag is set, “HDR will be applied via driver instead of through NVOverlay (driver doesn't support customizing brightness/contrast/saturation)”.[^64] The choice is therefore binary: NVOverlay path (needs the app installed) with tuning, or driver path without it.

For most games that is a minor loss. For Cry of Fear it is not, and the reason is Section 3: under Windows HDR, the game's own gamma ramp is inert, so the base image arrives *darker than the tone mapper expects*, and **Middle Grey is the slider that fixes it.** Reports of driver-level RTX HDR producing noticeably darker output than Auto HDR are consistent with exactly this.[^63] Without the app you are left correcting a dark game with monitor-side brightness, which raises black level along with everything else — precisely what HDR is supposed to avoid.

**If you decline the app deliberately** — a reasonable position, given how much of the system it takes over — the recommendation chain changes rather than collapsing. Start with Route 3B: ten minutes, one portable executable, nothing installed. If the result is too dark or too flat to enjoy, the next step is not to reconsider the app but to go to Option B (Section 7): Special K gives you a full, controllable tone mapper, and its entire footprint is one game folder that you can delete. Judged by *system* footprint rather than by file count, it is arguably the tidier of the two.

Either way there are two partial escapes worth trying first. `TrueHDRTweaks` is a plugin that restores some of the missing tuning[^62] — but it is an injected DLL in the game folder, forfeiting the "no files in the game directory" advantage that made this route attractive, at which point Option B (Section 7) deserves the comparison instead. The second costs nothing and is game-side: **`gl_brightness` and `gl_gamma`** (Section 5) belong to the Paranoia renderer rather than to the gamma ramp, so they plausibly still work under HDR and can lift the base image before RTX HDR ever sees it. Untested, but the cheapest thing to try on Route 3B.

RTX HDR works with DX9 through DX12, Vulkan and — with Step 2 applied — OpenGL, in exclusive fullscreen or borderless windowed mode.[^51][^6][^40] Note that OpenGL support is the least-documented case for the driver-level route specifically; if Route 3B produces no visible change on Cry of Fear even with Step 2 correctly applied, that is the most likely explanation, and Route 3A is the answer.[^62]

### Step 4 — Window mode and resolution

Cry of Fear's exclusive fullscreen is unreliable on modern Windows; the long-standing "tiny borderless square" bug is well documented.[^45][^46] Borderless windowed at native desktop resolution avoids it entirely, and RTX HDR supports borderless.

In Steam: **right-click Cry of Fear → Properties → Launch Options**, and enter (substituting your resolution):

```
-window -noborder -w 2560 -h 1440 -console -noforcemparms -noforcemaccel -noforcemspd
```

The three `-noforce*` flags are not optional. Without them GoldSrc rewrites the Windows mouse settings through `SystemParametersInfo` at every launch, switching *Enhance pointer precision* back on each time - a per-launch annoyance with no in-game cure, since this build predates `m_rawinput`. All three flags were confirmed present in `hw.dll` by string search before being recommended.

Also set high-DPI behaviour explicitly, or Windows scaling will letterbox the window: right-click `cof.exe` → **Properties → Compatibility → Change high DPI settings → Override high DPI scaling behavior → Application**.

### Step 5 — Drop in `autoexec.cfg`

Copy the file from Section 5 to `…\steamapps\common\Cry of Fear\cryoffear\autoexec.cfg`. If one already exists, **merge rather than overwrite** — some installs ship gameplay-relevant lines there. Back up the original first.

### Step 6 — Verify

Launch and check, in order:

1. **Route 3A:** the NVIDIA app overlay (`Alt+Z` by default) reports RTX HDR as **active** for this game, not merely enabled. **Route 3B:** there is no overlay to ask, so set `0x00432F84` to `3` (“Enabled + Indicator”) temporarily — the driver draws an on-screen indicator when the filter is running — then set it back to `2` once confirmed.[^64]
2. Alt-tab out: the desktop should look visibly different in brightness while the game runs — a sign HDR is being driven.
3. In-game: point the flashlight at a near wall. The centre of the cone should be clearly brighter than the white of the pause-menu text. If they look equally bright, HDR is not actually being applied — go back to Step 2.

---

## 3. Why This Pipeline Works (and What It Actually Does)

```
GoldSrc / Paranoia renderer
  → fixed-function OpenGL 1.x, 8-bit RGBA framebuffer     [SDR, unchanged]
      ↓  wglSwapBuffers
NVIDIA driver, present method = layered on DXGI swapchain
  → frame now lives in a DXGI flip-model swapchain        [HDR-capable surface]
      ↓
RTX HDR (driver-level AI tone-expansion filter)
  → inverse tone-maps SDR → scRGB/HDR10
    applies Peak / Middle Grey / Contrast / Saturation
      ↓
Windows HDR composition → display, using calibrated peak-luminance metadata
```

Two consequences follow, and they explain most of the tuning problems later:

1. **The game's own gamma and brightness controls stop working.** GoldSrc applies brightness/gamma through the hardware gamma ramp, which Windows ignores while HDR is enabled and which does nothing in windowed mode regardless.[^58][^2] Expect the base image to be darker than you remember. **Do not try to fix this in-game** — correct it with RTX HDR's Middle Grey slider, which operates in the right colour space.
2. **The engine's post-effects are applied before the expansion.** Cry of Fear's scripted desaturation and black-and-white nightmare sequences, vignette and grain all reach RTX HDR as baked-in SDR pixels. Hard tone expansion exaggerates them — grain in particular turns sparkly in dark scenes. Section 5's config offers a `gl_posteffects` switch if that bothers you — though Section 9.2 has a better answer: the effect is a plain-text Cg shader that can be softened instead of switched off.[^13]

---

## 4. Tuning RTX HDR for Cry of Fear on an HDR1000 Panel

The NVIDIA app exposes four RTX HDR sliders: **Peak Brightness**, **Middle Grey**, **Contrast**, **Saturation**.[^55] The defaults are tuned for bright, colourful modern games — close to the opposite of Cry of Fear.

> **This whole section requires Route 3A.** The four sliders are app/Freestyle-only; driver-level RTX HDR (Route 3B) applies a fixed default curve. If you are on 3B, skip to Section 6.[^64]

### 4.1 Method: tune against two fixed reference scenes

Do not tune while walking around. Pick two scenes and keep returning to them:

- **Reference A (highlights):** an early subway or street scene, flashlight on, aimed at a near wall. Tells you whether Peak is right.
- **Reference B (shadows):** an unlit apartment corridor or stairwell, flashlight off. Tells you whether Middle Grey and Contrast are right.

Change one slider at a time, then re-check both scenes. Tuning only on A gives you an unplayably black game; tuning only on B gives you a milky grey one.

### 4.2 Starting values for a ~1000-nit display

| Slider | Suggested start | Rationale |
|---|---|---|
| **Peak Brightness** | ~800 nits, i.e. slightly **below** your panel's measured peak | Almost no HDR1000 monitor sustains 1000 nits outside a small window. Setting peak above what the panel delivers just clips the flashlight core into a flat white disc. Start below the rating, raise until the highlight stops gaining detail. |
| **Middle Grey** | **above default** | The most important slider here, and it moves the opposite way from most games. The game is dark to start with, and Step 1 removed the gamma ramp it used to lean on. Raise until Reference B is readable-but-menacing, then stop. |
| **Contrast** | at or slightly **below** default (default is around 25 as shipped) | The engine's lightmaps are already high-contrast and low-bit-depth. Extra contrast produces visible banding on lightmap gradients — GoldSrc lightmaps have nowhere near the precision to survive aggressive stretching.[^1][^17] |
| **Saturation** | at or slightly **below** default | Cry of Fear's palette is deliberately desaturated grey-green. Pushing saturation makes skin tones and blood look cartoonish and breaks the intended look. |

Write your final values down — you will lose them the next time the NVIDIA app refreshes its profile database.

### 4.3 Acceptance checks

- **Banding:** stare at a lit wall gradient in Reference A. Stepped rings → reduce Contrast first, then Peak.
- **Black floor:** in Reference B, blacks should be black — not dark grey, and not so crushed that doorways vanish. Adjust Middle Grey.
- **UI and subtitles:** HUD, subtitles and inventory are drawn into the same SDR frame and get expanded with everything else. Painfully bright HUD means Peak is too high — the HUD is near-white in SDR and goes wherever you put peak.
- **Nightmare/black-and-white sequences:** check one deliberately. These are the worst case for any tone expander.

---

## 5. The `autoexec.cfg`

Path: `…\steamapps\common\Cry of Fear\cryoffear\autoexec.cfg`. The finished file ships as `install/autoexec.cfg`.

This config's only job is to hand RTX HDR a **clean, neutral, stable SDR image** to expand. It is not a "make the game look better" config.

### 5.1 It is a merge, not a replacement

Cry of Fear 1.6 already ships an `autoexec.cfg`, and it carries gameplay-relevant lines. Verified contents on a stock install:

```
sv_maxspeed 300          cl_sidespeed 200         sv_voicecodec voice_speex
sv_cheats 0              cl_backspeed 200         sv_voicequality 5
r_dynamiclight 0         gl_max_size 1024         sv_lan 0
cl_noiseeffect 1         gl_texturemode gl_linear_mipmap_linear
```

Overwriting this breaks movement speed and voice chat. Keep these lines and append the HDR block below them — which is what `install/autoexec.cfg` does, and why `Install-CofHdr.ps1` refuses to overwrite an existing file and writes `autoexec.hdr.cfg` alongside instead.

Two observations on the stock values:

- **`gl_renderer` is not set at all** in the stock file. The Paranoia renderer is therefore relying on a default, which is exactly the setting community bug reports keep having to repair. Set it explicitly.
- **`r_dynamiclight 0`** is the developers' choice, presumably for performance or for a conflict with the Paranoia renderer. Dynamic lights are a highlight source and therefore interesting for HDR, so `1` is worth *testing* — but the shipped config leaves it alone, because overriding a deliberate developer setting on a guess is how mods acquire mystery bugs.

### 5.2 The gamma cvars, and why there are four of them

A stock `config.cfg` contains all four:

```
brightness "1"        gamma "2.5"        gl_brightness "0.000000"        gl_gamma "1"
```

`brightness` and `gamma` are the standard GoldSrc pair and go through the **hardware gamma ramp** — which Windows ignores while HDR is enabled, and which does nothing in windowed mode regardless.[^58][^2] The config pins them to their stock values so they cannot skew the frame RTX HDR receives.

`gl_brightness` and `gl_gamma` are **Paranoia renderer cvars**, and the distinction matters: a renderer-side cvar is most likely applied during rendering rather than through the ramp, in which case it keeps working under HDR. That makes them the one game-side lever for lifting the base image — and the only such lever at all on Route 3B, where there is no Middle Grey slider. This is inference from where the cvars live, not something documented; test in small steps (`gl_brightness 0.05`–`0.15`) and revert if nothing changes.

### 5.3 The HDR block

```
gl_renderer     1      // Paranoia renderer ON. With 0 the game loses the
                       // flashlight/phone light entirely - i.e. exactly the
                       // highlights HDR exists to show.
gl_twopassdyn   1      // Two-pass dynamic lighting. 0 if you see z-fighting.

brightness      1      // Stock. Gamma-ramp based, inert under HDR - pinned
gamma           2.5    // so it cannot skew RTX HDR's input.
gl_brightness   0      // Stock. Renderer-side; see 5.2 before touching.
gl_gamma        1      // Stock.

gl_posteffects  1      // Keep the intended B/W and nightmare effects.
                       // Prefer editing black_fp.cg (Section 9.2) over
                       // switching these off wholesale.

gl_texturemode  gl_linear_mipmap_linear   // As stock. Trilinear reduces mip
                       // shimmer, which a tone expander turns into sparkle.

fps_max         100    // The cap is the engine's, not a preference. See 5.4.
gl_vsync        1      // 0 only with working VRR.

developer       0      // Dev spam is drawn into the frame and tone-expanded
                       // along with it.
```

**Verifying a cvar exists on your build.** Open the console (Step 4 added `-console`) and type `find gl_` or `find gamma` to list what this build actually has. A cvar that does not exist is silently ignored rather than reported as an error, so a typo fails quietly — check rather than assume.[^57][^13]

### 5.4 The 100 fps cap, and why it cannot be lifted

Earlier revisions of this document recommended `fps_override 1` to unlock framerates above 100. **That was wrong for this engine build.** A byte search of `hw.dll` and `sw.dll` finds only `fps_max` and `fps_modem` — there is no `fps_override` cvar at all, so the line was silently swallowed, which is exactly the failure mode the paragraph above warns about. The 100 fps ceiling is compiled into this pre-SteamPipe engine and no configuration reaches it.

This costs less than it sounds. GoldSrc's movement and jump physics are tuned around 100 fps and misbehave above it, so even an engine that allowed more would not be worth pushing. On a variable-refresh display a locked 100 is smooth.

### 5.5 Settings for high-resolution displays

Three additions earn their place at 1440p:

| Cvar | Stock | Set to | Why |
|---|---|---|---|
| `r_detailtextures` | `0` | `1` | `gl_detailtex` already ships as `1` while this one is `0`. Detail textures pay off at high resolution; if the install carries none, the line simply does nothing. |
| `cl_fovmultiplier` | — | `1.0` | Cry of Fear's own FOV control. GoldSrc's field of view comes from 4:3 and feels cramped on 16:9; `1.1`–`1.15` opens it up, beyond that the weapon models distort at the edges. |
| `gl_texturemode` | trilinear | unchanged | Anisotropic filtering is not something the engine can do — it is forced through the NVIDIA profile instead (Section 10.1). |

A stock `config.cfg` also exposes two Paranoia renderer cvars worth experimenting with, shipped commented out because both visibly change the game's look: `gl_overbright` (stock `0`) lets lit surfaces exceed white, which is precisely the headroom a tone expander wants — at the cost of some of the game's oppressive darkness; and `gl_contrast` (stock `1.4`) bakes contrast in before RTX HDR ever sees the frame, so lowering it to about `1.15` gives the tone mapper more to work with. Change one at a time and compare the same scene.

## 6. Troubleshooting

| Symptom | Most likely cause | Fix |
|---|---|---|
| RTX HDR shows as enabled but nothing changes | Present method still on Auto | Step 2 — `cof.exe` needs "Prefer layered on DXGI Swapchain"[^51][^52] |
| RTX HDR option missing for the game | NVIDIA app did not detect a legacy 32-bit executable | Add the program manually; if that fails, use NvTrueHDR to write the profile (Route 3B) |
| No RTX HDR anywhere in the NVIDIA Control Panel | It is not there and will not be — Control Panel is legacy | Install the NVIDIA app (Route 3A), or use Route 3B[^64] |
| Route 3B applied, Step 2 correct, still no visible change | Driver-level RTX HDR on OpenGL is the least-documented path | Switch to Route 3A and re-test before concluding anything[^62] |
| HDR works but the game is flatly too dark and there is nothing to adjust | Route 3B has no Middle Grey slider | Route 3A — this is the reason it is recommended (Step 3) |
| Washed out, grey blacks | Auto HDR and RTX HDR both active, or display calibration never run | Turn Auto HDR off; run Windows HDR Calibration[^23][^31] |
| Everything far too dark | The gamma ramp the game relied on is inert under HDR | Raise RTX HDR **Middle Grey**, not the in-game slider (Section 3) |
| Tiny window in the corner of the screen | Known CoF fullscreen/DPI bug | Borderless + explicit `-w/-h` + DPI override (Step 4)[^45][^46] |
| Banding on lit walls | Contrast/Peak stretching 8-bit lightmaps too hard | Lower Contrast, then Peak (Section 4.3) |
| No flashlight, broken shading | `gl_renderer 0`, or Paranoia renderer fell back to software | `gl_renderer 1`; verify `opengl32.dll` is present and intact in the game root[^4][^43][^10] |
| Blinding HUD/subtitles | Peak too high — UI is near-white SDR | Lower Peak Brightness |
| "Enhance pointer precision" turns itself back on | The engine forces the Windows mouse parameters at launch | Add the three `-noforce*` flags (Step 4) |
| Crash at launch or on map load | Most likely the forced MSAA against the layered-DXGI present path | Import `cof-hdr-nvidia-driver-quality-noaa.nip`; if it persists, `Set-CofFontScale.ps1 -Revert` |
| Flashlight brightness pumps as you turn | Monitor-side dynamic tone mapping fighting RTX HDR | Disable the monitor's own dynamic/smart HDR in its OSD |
| Overlay conflicts, flicker, crash on launch | Multiple overlays contending for the swapchain | One overlay at a time; disable the Steam overlay for this game while testing |
| Stutter appeared after Step 2 | Layered DXGI path costing performance | Confirm it is set per-program, not globally[^59] |
| Crash between the first levels | Long-standing CoF bug on 64-bit Windows, unrelated to HDR | Apply the community crash patch before blaming your HDR setup[^15] |

**Co-op caution.** Cry of Fear's co-op is sensitive to renderer state differing between peers, and inconsistent renderer cvars or GL drivers have been linked to freezes.[^44][^16] Everything in this guide is local and driver-side and changes no game binary, so it is far safer than an injector — but if you hit co-op instability, test with RTX HDR off before blaming the netcode.

---

## 7. Option B — Special K's OpenGL HDR Retrofit (still not ReShade)

If RTX HDR's result is not good enough — its weakness is that it cannot tell an intentionally dark scene from an under-exposed one — the next step up, still without ReShade, is **Special K**.

Special K is an injector, but a fundamentally different class of tool from ReShade: it promotes OpenGL applications to what it calls **OpenGL-IK**, an interop path where DirectX 11 handles final presentation, and that path brings flip-model presentation and its **HDR Retrofit** feature — a user-configurable tone mapper that can undo the game's SDR compression rather than merely stretching the output.[^53][^54][^60]

Trade-offs against RTX HDR for this specific game:

- **Better:** a real, controllable tone mapper with per-game profiles, HDR-aware UI handling, and inverse tone mapping instead of AI inference.
- **Worse for install simplicity:** it is a DLL in the game folder, which forfeits the main advantage of the RTX HDR route.
- **Unverified:** Special K's own documentation notes that its deeper *remastering* options frequently do not work under OpenGL, and none of it is documented against a fixed-function OpenGL 1.x renderer that is itself wrapped by a third-party `opengl32.dll`. Cry of Fear is a genuinely awkward case — two things both want to be `opengl32.dll`.[^53][^4]

**Recommendation:** treat Option B as an experiment on a *copy* of the game folder, after the RTX HDR route works and you have a baseline to compare against. Do not make it the default install path of a mod.

---

## 8. Routes Considered and Rejected

For completeness, so the recommendation above is not taken on faith.

| Route | HDR type | Effort | Verdict for this hardware |
|---|---|---|---|
| **RTX HDR + DXGI present method** | True HDR10/scRGB output, inferred range | Very low | **Recommended.** Best quality-per-effort on RTX 50; no files in the game folder.[^51][^6][^40] |
| **Special K OpenGL-IK HDR Retrofit** | True HDR output, inverse-tonemapped | Low–medium | Option B (Section 7). Better tone mapping, worse install story, unverified against Paranoia.[^53][^54] |
| **ReShade HDR shaders** | SDR-space emulation; output still needs OS HDR | Low | **Excluded by requirement.** Also strictly worse here: its shaders work on an already-clipped 8-bit frame, and its `opengl32.dll` collides with Paranoia's.[^8][^4] |
| **Windows Auto HDR** | True HDR output | Very low | Not recommended. DirectX-oriented, unreliable for OpenGL, far less control, and must not run alongside RTX HDR.[^23][^39] |
| **Custom `opengl32.dll` HDR renderer** | Genuinely native HDR | Very high | Not realistic. Would mean emulating fixed-function GL into an `RGBA16F` target and shipping an HDR swapchain — and Paranoia already occupies that DLL slot. No public implementation exists.[^33][^34][^4] |
| **Xash3D FWGS port** | Native HDR if the renderer were extended | Very high | Blocked. Cry of Fear's gamecode is closed-source and FWGS maintainers state it cannot be properly ported.[^7][^38] |
| **Asset-side "fake HDR"** | Perceptual only | Medium–high | Not an HDR route on its own, but the best *complement* to RTX HDR — Section 9.4.[^17][^1] |

The two "native HDR" routes are research projects, not mods. Both founder on the same facts: the engine is closed-source, the renderer DLL slot is already taken by Paranoia, and the content is authored 8-bit SDR throughout.[^7][^17]

---

## 9. Going Further: What Is Genuinely Moddable Inside the Game

All optional; none required for the Section 2 install. This is what turns a settings guide into a mod. It matters because RTX HDR can only expand contrast that exists in the SDR frame — give it a better frame and you get a better result.

### 9.1 Correction to Section 8: the renderer is not purely fixed-function

Inspecting a real 1.6 install turns up something the engine-level analysis missed. The game root ships `cg.dll` and `cgGL.dll` — **NVIDIA's Cg toolkit** — and `cryoffear/cgshaders/` contains six *plain-text shader sources* compiled at runtime:

```
black_fp.cg   black_vp.cg   fp20_black_fp.cg
water_fp.cg   water_vp.cg   fp20_water_fp.cg
```

(`fp20_` are fallback-profile variants for older hardware.)

This does **not** change Section 8's conclusion — there is no full-screen tone-mapping pass here, and no floating-point framebuffer to write one into, so native HDR remains out of reach. But it does mean the Paranoia renderer has a programmable path with **editable, shippable source files**, which is a meaningfully different situation from "fixed-function, take it or leave it".

### 9.2 The highest-value shader: `black_fp.cg`

`black_fp.cg` is the black-and-white post-effect — the nightmare and desaturation sequences. Its fragment program is short and legible: it sums the sampled RGB, rescales, and writes `0.2 - flColor1` to all three channels.

That is exactly the effect Section 3 flagged as the worst case for tone expansion, and Section 6 offered only a blunt remedy for (`gl_posteffects 0`, which throws away an intentional artistic effect). With the shader in hand there is a third option: **soften the effect rather than remove it** — reduce the expansion factor, lift the black point, or blend a fraction of the original colour back in. The player keeps the scripted moment; the tone mapper stops being handed a hard-clipped frame.

Practical notes: it is compiled at load, so iteration is a restart rather than a rebuild; back up the originals; and edits here *are* modifications to shipped game files, so Steam file verification will revert them and they must never be redistributed as patched originals — ship a diff or an install script.

### 9.3 `liblist.gam`: shipping the launch arguments as a mod file

`cryoffear/liblist.gam` carries a `commandargs` field, used stock as:

```
commandargs "-num_edicts 4096 -heapsize 1024000"
```

This is a mod-level way to pass engine arguments, which in principle could carry the window-mode flags from Step 4 without the user touching Steam's launch options. Tempting for install simplicity — but it edits a shipped file that Steam verification reverts, and it is worth confirming first whether Steam's launch options even reach `cof.exe` given that `CoFLaunchApp.exe` is what Steam actually starts. Treat as a documented option, not the default path.

### 9.4 Lightmaps: the largest change, and the largest effort

Recompiling maps with modern compilers (VHLT / vluzacn's tools) and re-authored lighting is the single asset change that most improves the HDR result: widen the gap between lit and unlit areas, cut flat ambient fill, and let bright sources genuinely blow out in SDR so the tone expander has something unambiguous to lift.[^17][^1]

Toolchain:

- **Mapping:** Cry of Fear SDK 1.3 with J.A.C.K. or Hammer 3.5, using the Cry of Fear FGD.[^18][^20][^25]
- **Decompiling for study:** SamVanheer's Half-Life Unified SDK Map Decompiler (BSP v29/v30).[^17]
- **Compiling:** VHLT / vluzacn's ZHLT derivatives.[^1][^17]
- **Models:** Crowbar plus a modern `studiomdl.exe` (Sven Co-op's is the usual choice) for MDL v10.[^26][^27][^28][^29][^30]
- **Textures/WADs:** Wally or an equivalent WAD manager. Note `gl_max_size 1024` in the stock config and the many `.wad` files under `cryoffear/`.

Worth doing, in priority order:

1. **Light-source contrast.** Raise the intensity of practical lights (fluorescent tubes, fires, TV screens) well beyond current values and cut ambient. Highlights that clip in SDR are what a tone expander maps to high nits.
2. **Sprite flares and glows** on bright sources. Cheap, engine-native, and they read as HDR bloom once expanded.
3. **Texture local contrast.** Stronger local contrast and brighter specular-ish highlights, rather than uniformly brighter albedo.
4. **Avoid large smooth gradients** on big surfaces. That is what bands under expansion; GoldSrc's lightmap precision cannot support them.

GoldSrc's hard limits (`MAX_MODELS`, `MAX_TEXTURES`, `MAX_GLTEXTURES`, `MAX_EDICTS`, lightmap allocation) are inherited by this branch and are unforgiving — HD texture packs and extra glow sprites hit them fast, producing crashes, missing models or invisible entities rather than graceful degradation.[^36][^37][^2] Budget before authoring.

### 9.5 Menu fonts, the HUD, and what cannot be scaled

At 2560×1440 the menus are tiny, because `clientscheme.res` and `trackerscheme.res` declare fixed pixel sizes (16 / 13 / 12 px) with no resolution scaling.

**What works.** The engine does support resolution-dependent fonts: `trackerscheme.res` already guards `EngineFont` with `yres` range blocks (480-599, 600-767, … 1200-6000), and another font carries the comment *“This version should not scale”* — so the mechanism is both present and deliberate. `tools/Set-CofFontScale.ps1` adds a `yres`-guarded block to each remaining font, which leaves behaviour below the threshold byte-for-byte unchanged. It edits the player's own files rather than shipping modified ones, since those are game content.

**What does not, and why.** Three plausible-looking avenues are dead ends, all confirmed by inspection rather than assumption:

- **`*_textscheme.txt`** (`640_`, `800_`, … `1600_`) look exactly like per-resolution font settings. They are referenced by **no binary in the game** — a byte search of `hw.dll`, `client.dll`, `hl.dll` and `GameUI.dll` finds the string nowhere. Leftovers from the Half-Life SDK. Editing them does nothing.
- **The in-game HUD text.** `client.dll` uses VGUI**1** (`vgui::Font`, `CSchemeManager`) with sizes constructed in code. There is no `hud_scale` cvar in `client.dll` or `cl_dlls/hl.dll`.
- **The HUD sprites.** `sprites/hud.txt` gives source rectangles into sprite sheets, drawn 1:1; the `640` column is a resolution *class*, not a scale factor, and GoldSrc only knows 320 and 640. Making the HUD bigger means authoring larger `.spr` files, not editing a config.

So the honest position is: menus scale, the HUD does not. The only lever that enlarges the HUD is rendering at a lower resolution and letting the display upscale — a real option, but one that trades away the sharpness the rest of this document works for.

**Dialog geometry is the known follow-up.** The dialog `.res` files use fixed pixel sizes (`wide 824`, `tall 736`). If larger fonts overflow their buttons, those files need scaling too; that is deliberately not done up front, since 38 files recalculated blind is a bigger intervention than the problem may warrant.

---

## 10. What the Mod Actually Consists Of

Because the working HDR path is configuration rather than code, there is no `.dll` to build and no engine to patch. What gets built is a **package of four artifacts**, each of which exists because it removes one specific manual failure point. `README.md` carries the distributable version of this; the reasoning is here.

```
cof-hdr/
├─ README.md                          for the release page
├─ CHANGELOG.md                       verified vs. unverified, per release
├─ LICENSE                            MIT + scope note on game content
├─ HDRmodCOF.md                       this report
├─ install/
│  ├─ KURZANLEITUNG.md                end-user quick start
│  ├─ autoexec.cfg                    merged onto the stock 1.6 config (Section 5)
│  ├─ cof-hdr-nvidia-*.nip           NVIDIA profiles, one per complete state (10.1.1)
│  └─ cgshaders/black_fp.cg           softened B/W post-effect (Section 9.2)
└─ tools/
   ├─ Install-CofHdr.ps1              backup, config, DPI flag, shader, profile
   ├─ Set-CofFontScale.ps1            menu font scaling (Section 9.5)
   ├─ Uninstall-CofHdr.ps1            full revert
   ├─ Test-CofHdr.ps1                 read-only diagnosis
   └─ Build-Release.ps1               release zip from an allow-list
```

### 10.1 The `.nip` profiles — the piece that does the real work

A `.nip` is an NVIDIA Profile Inspector export: XML, UTF-16, one `<Profile>` keyed to an executable, settings as **decimal** IDs and values.

```xml
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Cry of Fear (HDR)</ProfileName>
    <Executeables><string>cof.exe</string></Executeables>
    <Settings>
      <ProfileSetting>
        <SettingID>550932728</SettingID>   <!-- 0x20D690F8 present method -->
        <SettingValue>1</SettingValue>     <!-- layered on DXGI Swapchain -->
      </ProfileSetting>
      …
    </Settings>
  </Profile>
</ArrayOfProfile>
```

| Setting | Hex ID | Decimal | App route | Driver route |
|---|---|---|---|---|
| Vulkan/OpenGL Present Method | `0x20D690F8` | 550932728 | `1` | `1` |
| RTX HDR — Enable | `0x00DD48FB` | 14502139 | `1` | `1` |
| RTX HDR — Driver Flags | `0x00432F84` | 4403076 | `0` | `2` |
| Game Filters | `0x00980896` | 9963670 | `1` | `1` |
| undocumented (NvTrueHDR) | `0x1077A11A` | 276275482 | — | `1` |

Imported with `nvidiaProfileInspector.exe -silentImport <file>`. This single file collapses Step 2 and Step 3 into one action, which is the largest single win available for install simplicity — those two steps are where nearly every failure originates.

### 10.1.1 Importing replaces; it does not merge

**Each `.nip` must describe the complete desired profile.** This was learned the hard way: importing a quality-only profile on top of a working HDR profile silently removed the RTX HDR and present-method settings from the driver. `-silentImport` overwrites the named profile wholesale.

That is why the package ships pre-combined files rather than composable ones:

| File | Contents |
|---|---|
| `cof-hdr-nvidia-app.nip` | HDR via NVOverlay |
| `cof-hdr-nvidia-app-quality.nip` | HDR via NVOverlay + image quality |
| `cof-hdr-nvidia-driver.nip` | HDR via driver |
| `cof-hdr-nvidia-driver-quality.nip` | HDR via driver + image quality — **the usual choice** |
| `cof-hdr-nvidia-driver-quality-noaa.nip` | as above, without MSAA and transparency supersampling |
| `cof-hdr-nvidia-driver-indicator.nip` | as driver-quality, plus the on-screen indicator |
| `cof-hdr-nvidia-reset.nip` | everything back to driver defaults |

`Test-CofHdr.ps1` guards against the trap by reading the profile's settings back out of `nvdrsdb0.bin` — the records sit immediately before the profile name as 16-byte `[A4 00 10 00][id][02 10 00 00][value]` entries — and reporting which are actually active.

### 10.1.2 Image-quality settings

GoldSrc offers neither antialiasing nor anisotropic filtering, so both are forced at driver level. At 1440p on this hardware the cost is not measurable.

| Setting | Hex ID | Value |
|---|---|---|
| Anisotropic Filtering — Mode / Setting | `0x10D2BB16` / `0x101E61A9` | User-defined / 16x |
| Texture Filtering — Quality | `0x00CE2691` | High quality |
| Trilinear / Aniso / Aniso-sample optimisations | `0x002ECAF2`, `0x0084CD70`, `0x00E73211` | all off |
| Texture Filtering — Negative LOD bias | `0x0019BB68` | Clamp |
| Antialiasing (MSAA) — Mode / Setting | `0x107EFC5B` / `0x10D773D2` | Override / `0x25` |
| Antialiasing — Gamma Correction | `0x107D639D` | On |
| Antialiasing — Transparency Supersampling | `0x10D48A85` | 4x Sparse Grid |
| Maximum Pre-Rendered Frames | `0x007BA09E` | 1 |

`0x25` is 8xQ, true 8× multisampling — not `0x26`, which is 8× CSAA with only four colour samples. Negative LOD bias is clamped because over-sharpened mip selection shimmers, and a tone expander turns shimmer into sparkle.

**The one unknown** is how MSAA behaves alongside RTX HDR and the layered-DXGI present path; nothing documents that combination. If it flickers, leaves black borders, or crashes, import the `-noaa` variant instead of debugging it.

### 10.2 `autoexec.cfg`

Covered in Section 5. The packaging-relevant point is that it must be **merged onto the stock file**, and the installer must refuse to overwrite.

### 10.3 `Install-CofHdr.ps1` — and what it deliberately refuses to do

It locates the game via the Steam library (`libraryfolders.vdf`), backs up `SAVE/` and the configs to a timestamped folder, installs the config, sets the high-DPI override for `cof.exe`, and optionally imports the `.nip`. It supports `-WhatIf`.

It does **not** touch Windows HDR, Auto HDR, or Steam launch options. Those are user-facing OS settings; an installer that silently flips them is worse behaved than one that prints a checklist — and Auto HDR in particular must be off, which is a decision the user should see themselves make. It prints the checklist.

### 10.4 `Test-CofHdr.ps1` — the artifact that saves the most support time

The chain in Section 3 has roughly eight links, and when HDR "doesn't work" the symptom is identical for most of them: nothing changes. A read-only diagnostic that walks GPU, OS build, display HDR state, install path, `opengl32.dll`, config contents, Cg shaders, DPI override, launch options and NVIDIA app presence turns eight candidates into one.

Its design rule is that anything it cannot determine reliably is reported as `[?]`, never as a pass. A diagnostic that claims success it did not verify is worse than no diagnostic.

### 10.5 The shader, the reset profile and the uninstaller

Three artifacts exist purely so the package is reversible, which for something that
edits a game folder is not optional.

`install/cgshaders/black_fp.cg` (Section 9.2) is the only file that overwrites
something the game ships, so it is opt-in behind `-Shader`, the installer backs up
the original unconditionally, and the uninstaller restores it.

`install/cof-hdr-nvidia-reset.nip` sets the present method back to Auto and RTX HDR
off. Profile Inspector can import but not un-import, so undoing a profile needs a
profile — without it, the only route back is deleting the profile by hand.

`tools/Uninstall-CofHdr.ps1` restores from the newest backup, removes what was added,
and drops the DPI flag. It deliberately does **not** roll back `SAVE/`: the player's
progress since installing is newer than the backup, and silently reverting it would
destroy real playthrough data. It says so and leaves the backup on disk.

### 10.6 What is never shipped

`cof.exe`, `hw.dll`, Paranoia's `opengl32.dll`, stock WADs/BSPs/MDLs, or any patched binary. The package references the user's own Steam install. Shader or `liblist.gam` edits (Section 9) ship as scripts or diffs, never as replaced originals.

Under the Steam Subscriber Agreement, local configuration and driver settings are uncontroversial; it is binary replacement that carries risk.[^23][^24] The Paranoia-style custom `opengl32.dll` has historically caused problems when it ends up in *other* GoldSrc games, up to VAC complications — another reason the driver-level route is the right default.[^2][^4]

## 11. Safe Testing Environment

- Back up `…\Cry of Fear\cryoffear\SAVE\`, `autoexec.cfg` and `config.cfg` before starting. Cry of Fear stores saves in the game folder and has no cloud saves — a Steam file verification will take them with it.[^11][^42][^14]
- Disable automatic updates for Cry of Fear in Steam while testing, so a patch cannot change binaries mid-experiment.[^42]
- Record your **driver version, NVIDIA app version, Windows build, monitor firmware and the four RTX HDR slider values** together. Any one of them changing can change the result, and without the record you cannot tell which did.
- If you go as far as Section 7 or Section 9, work on a *copied* game folder, never the Steam-managed one.

---

## 12. Known Risks and Open Questions

Honest uncertainties, roughly in order of how likely they are to bite:

1. **NVIDIA app detection of `cof.exe`.** Legacy 32-bit executables are sometimes not offered the RTX HDR filter. Mitigations are documented (manual add, Route 3B), but this is the most likely point of failure for an end user.
2. **Route 3B on OpenGL.** Driver-level RTX HDR is reported to work broadly on DX9–DX12 with only partial, poorly documented OpenGL/Vulkan coverage, and the four tuning sliders are app-only. For a game as dark as this one, that combination is why Route 3A is the recommendation rather than merely the convenient option.[^62][^64]
3. **Present-method interaction with Paranoia's `opengl32.dll`.** The layered-DXGI path is a driver feature applied at buffer swap and should be agnostic to who is calling, but Cry of Fear's renderer is an unusual third-party GL wrapper and this specific combination is not documented anywhere. **This needs hands-on confirmation.**[^4][^51]
4. **Gamma behaviour.** How much of Cry of Fear's brightness pipeline runs through the hardware gamma ramp (inert under HDR) versus software texture/lightmap gamma at load time is not documented for this branch. The practical impact is only how far Middle Grey has to move; the fix is the same either way.[^58][^2]
5. **Scripted post-effects under tone expansion.** The black-and-white and desaturation sequences are the worst case and may need `gl_posteffects 0` for some players — an aesthetic regression traded for HDR comfort.[^13]
6. **Driver regressions.** RTX HDR's behaviour has changed across NVIDIA app versions before. Pin a known-good driver once you have a setup you like.
7. **Future Steam patches.** Cry of Fear is rarely updated now, but Valve's HL25 update did break Paranoia-renderer mods in Half-Life, which shows the class of risk.[^47][^48] The driver-level route survives this far better than any injector would.

---

## 13. Communities and Sources Worth Following

**Engine and SDK:** Valve Developer Community's GoldSrc, engine-versions, engine-limits and Cry of Fear pages;[^1][^2][^3][^5][^25][^36][^37] Valve's Half-Life SDK on GitHub.[^9]

**Modding/mapping:** TWHL — the best source for GoldSrc lighting technique, which is what Section 9 rests on;[^20][^1] ModDB / Team Psykskallar for the SDK and campaigns.[^18][^19][^21]

**Game-specific:** Steam Community discussions for App 223710 (renderer and fullscreen bugs);[^45][^43][^49][^50] the Cry of Fear Fandom wiki's bug and console-command pages;[^10][^13][^57] r/CryOfFear.[^38][^42][^44]

**HDR-specific:** PCGamingWiki's HDR glossary page, the best single reference for the DXGI present-method requirement;[^51] NVIDIA's developer forum thread on the same;[^52] NVIDIA app release notes for RTX HDR slider behaviour;[^55] Special K's wiki for Option B.[^53][^54]

**Engine internals:** Xash3D FWGS issues, for why the port route is closed;[^7][^38] ValveSoftware/Proton issue 2379, still the most detailed public account of how Cry of Fear loads the Paranoia renderer.[^4]

---

## Appendix A — Background: Why the Engine Cannot Do This Itself

Condensed from the original engine analysis; retained because it is what justifies Section 8.

**Build and lineage.** Cry of Fear's Steam standalone is GoldSrc build 5936, version 1.0.1.4, protocol 48 — a pre-SteamPipe branch that integrates the Paranoia mod's custom OpenGL renderer, loaded as a replacement `opengl32.dll` in the game root.[^1][^2][^3][^5] Proton bug reports confirm the engine looks for a "Paranoia hacked `opengl32.dll`" and falls back to software rendering when it is missing or mispatched, with `gl_renderer` and `gl_twopassdyn` controlling the renderer.[^4][^10]

**What that means for HDR.** The renderer targets OpenGL 1.x-era features, with one qualification added after inspecting a real install: it does carry a limited Cg shader path (Section 9.1), used for the water and black-and-white effects. What it does not have is a floating-point framebuffer, a full-screen tone-mapping pass, or an HDR-aware swapchain, and all content — textures, lightmaps, sprites — is authored 8-bit for an sRGB-ish SDR display.[^1][^2] Adding HDR inside the engine would mean rendering fixed-function calls into an `RGBA16F` target under a modern GL context and shipping an HDR swapchain; RenderDoc's documentation on why it supports only core profile 3.2+ is a good indication of how poorly legacy compatibility contexts travel to modern pipelines.[^33][^34]

**Why it cannot be fixed at the source.** Cry of Fear is a total conversion using no Half-Life 1 content, but the engine and gamecode are closed: `cof.exe`, `hw.dll`, `opengl32.dll`, `client.dll` and the server DLLs have never been released as source. Team Psykskallar's SDK (v1.3) covers mapping and custom campaigns only — FGDs, RMFs, example content.[^17][^18][^19][^20][^21] Xash3D FWGS maintainers state plainly that the closed-source gamecode is why Cry of Fear cannot be properly ported.[^7]

**Install layout,** for orientation:[^10][^11][^12]

```
Cry of Fear\
  cof.exe                    <- add THIS to the NVIDIA profile (Step 2)
  opengl32.dll               <- Paranoia renderer; do not touch, do not ship
  hw.dll, sw.dll             <- engine renderers
  cg.dll, cgGL.dll           <- NVIDIA Cg runtime used by the Paranoia renderer
  CoFLaunchApp.exe           <- what Steam starts; NOT the NVIDIA profile target
  cryoffear\
    autoexec.cfg             <- your config goes here (Step 5)
    config.cfg
    scriptsettings.dat
    SAVE\                    <- back this up
    liblist.gam              <- mod manifest; carries `commandargs` (9.3)
    cgshaders\               <- editable Cg shader sources (9.1 / 9.2)
    cl_dlls\hl.dll           <- client gamecode (per liblist.gam)
    dlls\                    <- server gamecode
    maps\ models\ sound\ sprites\ gfx\ resource\ *.wad
```

---

## Appendix B — Debugging Tools for Deeper Work

Only relevant if you pursue Section 7 or a custom wrapper.

**RenderDoc will not work** on the stock game. It supports only core profile OpenGL 3.2+ and explicitly does not handle fixed-function compatibility contexts, which is precisely what GoldSrc uses.[^33][^34]

**apitrace is the right tool** for legacy GL: `apitrace trace --api=gl cof.exe`, then analyse with `qapitrace`. This is how you would confirm what the Paranoia renderer actually issues per frame, and where a wrapper could intervene.[^35] gDEBugger and GLIntercept are alternatives, but less well maintained.

---

## References

[^1]: [GoldSrc - Valve Developer Community](https://developer.valvesoftware.com/wiki/GoldSrc)
[^2]: [GoldSrc](https://developer.valvesoftware.com/w/index.php?title=GoldSrc)
[^3]: [GoldSrc/Engine versions - Valve Developer Community](https://developer.valvesoftware.com/wiki/GoldSrc/Engine_versions)
[^4]: [Cry of Fear (223710) · Issue #2379 · ValveSoftware/Proton](https://github.com/ValveSoftware/Proton/issues/2379)
[^5]: [Cry of Fear - Valve Developer Community](https://developer.valvesoftware.com/wiki/Cry_of_Fear)
[^6]: [Best HDR upscaling apps for PC in 2026 — Unstore](https://unstore.io/discover/best-apps-for-hdr-upscaling-desktop/)
[^7]: [cry of fear on xash · Issue #2088 · FWGS/xash3d-fwgs](https://github.com/FWGS/xash3d-fwgs/issues/2088)
[^8]: [RHI/manifest.json at main · RankFTW/RHI · GitHub](https://github.com/RankFTW/RHI/blob/main/manifest.json)
[^9]: [ValveSoftware/halflife: Half-Life 1 engine based games](https://github.com/valvesoftware/halflife)
[^10]: [Single Player Bugs](https://cry-of-fear.fandom.com/wiki/Bugs_and_Glitches)
[^11]: [Cry of Fear (PC) | Download Save Game File (100%)](https://savegame.info/cry-of-fear/)
[^12]: [Cry of Fear - PCGamingWiki](https://www.pcgamingwiki.com/wiki/Cry_of_Fear)
[^13]: [Tricks Tips and Cheats | Cry of Fear Wiki - Fandomcry-of-fear.fandom.com › wiki › Tricks_...](https://cry-of-fear.fandom.com/wiki/Tricks_Tips_and_Cheats)
[^14]: [GitHub - hinqiwame/cof-linux-patcher: A patcher for Cry of Fear on Linux, addressing various bugs by replacing game build and engine DLL files with patched versions.](https://github.com/hinqiwame/cof-linux-patcher)
[^15]: [Cry of Fear - Crash patch for 64 bit users file](https://www.moddb.com/downloads/cry-of-fear-crash-patch-for-64-bit-users)
[^16]: [Paranoia Renderer not working specifically on windows. :: Cry of Fear General Discussions](https://steamcommunity.com/app/223710/discussions/0/3164316851917596841/?l=english)
[^17]: [Half-Life Unified SDK Map Decompiler file - Cry of Fear](https://www.moddb.com/games/cry-of-fear/downloads/half-life-unified-sdk-map-decompiler)
[^18]: [Cry of Fear - SDK v1.3 file](https://www.moddb.com/games/cry-of-fear/downloads/cry-of-fear-sdk-v13)
[^19]: [Downloads - Team Psykskallar](https://www.moddb.com/company/team-psykskallar/downloads)
[^20]: [Cry Of Fear SDK - TWHL: Half-Life and Source Mapping Tutorials ...](https://twhl.info/thread/view/18065)
[^21]: [Downloads - Cry of Fear - ModDB](https://www.moddb.com/games/cry-of-fear/downloads)
[^23]: [Use Auto HDR for better gaming in Windows - Microsoft Support](https://support.microsoft.com/en-us/windows/hardware/display-graphics/use-auto-hdr-for-better-gaming-in-windows)
[^24]: [Enable HDR in Windows 11 for Gaming (2026) - whysogeek.com](https://whysogeek.com/enable-hdr-windows-11-gaming-2026/)
[^25]: [Cry of Fear.fgd - Valve Developer Community](https://developer.valvesoftware.com/wiki/Cry_of_Fear.fgd)
[^26]: [Crowbar/Crowbar/- Documents/Specifications.txt at master · ZeqMacaw/Crowbar](https://github.com/ZeqMacaw/Crowbar/blob/master/Crowbar/-%20Documents/Specifications.txt)
[^27]: [Crowbar (Modding Tool) Guide](https://steamsolo.com/guide/crowbar-modding-tool-guide-source-sdk/)
[^28]: [Crowbar](https://valvedev.info/tools/crowbar/)
[^29]: [GoldSrc Model Export Tutorial - 303](https://the303.org/tutorials/gold_mdl.htm)
[^30]: [GoldSrc Model Export Tutorial - 303](https://the303.org/tutorials/gold_mdl_comp.htm)
[^31]: [Best HDR Settings for Gaming on Windows 11 (2026)](https://allthings.how/best-hdr-settings-for-gaming-on-windows-11/)
[^32]: [HDR Settings Guide for PC Gaming: How to Enable and Configure](https://www.switchbladegaming.com/game-settings/hdr-pc-gaming/)
[^33]: [OpenGL & OpenGL ES Support — RenderDoc documentation](https://renderdoc.org/docs/behind_scenes/opengl_support.html)
[^34]: [FAQ¶](https://renderdoc.org/docs/getting_started/faq.html)
[^35]: [OpenGL | DeveloperNote.com](https://developernote.com/category/graphics/opengl/)
[^36]: [GoldSrc (25th anniversary) - Valve Developer Community](https://developer.valvesoftware.com/wiki/GoldSrc_(25th_anniversary)
[^37]: [Template:Engine Limits/doc](https://developer.valvesoftware.com/wiki/Template:Engine_Limits/doc)
[^38]: [Where can I download Cry of Fear without steam, my pc doesn't support it.](https://www.reddit.com/r/CryOfFear/comments/1f35v56/where_can_i_download_cry_of_fear_without_steam_my/)
[^39]: [RTX HDR vs Windows Auto HDR ?](https://www.reddit.com/r/nvidia/comments/1axwdab/rtx_hdr_vs_windows_auto_hdr/)
[^40]: [Master HDR on Windows 11: Calibration, RTX HDR & Per-Game ...](https://windowsforum.com/news/master-hdr-on-windows-11-calibration-nvidia-rtx-hdr-and-per-game-tweaks.404764/)
[^42]: [uninstalled steam and lost all my progress : r/CryOfFear - Reddit](https://www.reddit.com/r/CryOfFear/comments/1hlq1cl/uninstalled_steam_and_lost_all_my_progress/)
[^43]: [Paranoia Renderer not working specifically on windows. :: Cry of Fear General Discussions](https://steamcommunity.com/app/223710/discussions/0/3164316851917596841/)
[^44]: [CoF Not Responding/Freezing after starting co-op](https://www.reddit.com/r/CryOfFear/comments/y768cp/cof_not_respondingfreezing_after_starting_coop/)
[^45]: [How do i fix fullscreen? :: Cry of Fear General Discussions](https://steamcommunity.com/app/223710/discussions/0/4840896974232669956/)
[^46]: [Cry of Fear - Steam Community](https://steamcommunity.com/app/223710)
[^47]: [Whats wrong with cry of fear :: Half-Life General Discussions](https://steamcommunity.com/app/70/discussions/0/864959809962738425/)
[^48]: [HL25: Mods that previously used the Paranoia renderer do not launch anymore - ValveSoftware/halflife Issue #3710](https://github.com/ValveSoftware/halflife/issues/3710)
[^49]: [Cry of Fear General Discussions :: Steam Community](https://steamcommunity.com/app/223710/discussions/)
[^50]: [are there mods in this game? :: Cry of Fear General Discussions](https://steamcommunity.com/app/223710/discussions/0/591759372396275381/)
[^51]: [Glossary:High dynamic range (HDR) - PCGamingWiki](https://www.pcgamingwiki.com/wiki/Glossary:High_dynamic_range_(HDR))
[^52]: [Use of DXGI Swapchain (Vulkan/OpenGL present method) - NVIDIA Developer Forums](https://forums.developer.nvidia.com/t/use-of-dxgi-swapchain-vulkan-opengl-present-method/329070)
[^53]: [HDR Retrofit - Special K Wiki](https://wiki.special-k.info/en/HDR/Retrofit)
[^54]: [Special K - PCGamingWiki](https://www.pcgamingwiki.com/wiki/Special_K)
[^55]: [NVIDIA App Beta Adds RTX Video Super Resolution, RTX Video HDR Sliders, and Display Settings](https://www.nvidia.com/en-us/geforce/news/nvidia-app-beta-update-rtx-vsr-hdr-controls-and-more/)
[^56]: [RTX Video FAQ - NVIDIA Support](https://nvidia.custhelp.com/app/answers/detail/a_id/5448/~/rtx-video-faq)
[^57]: [Console Commands & Helpful Commands (Cry of Fear) - Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2473185237)
[^58]: [Half-Life on an HDR monitor - Steam Community](https://steamcommunity.com/app/70/discussions/0/3825299737962211000/)
[^59]: [Vulkan/OpenGL Present Method auto-switches to layered DXGI - Sunshine Issue #1771](https://github.com/LizardByte/Sunshine/issues/1771)
[^60]: [HDR retrofit with Special K and dgVoodoo 2 - Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3081734759)
[^61]: [Wiki addition for critical Nvidia Control Panel setting - DXVK Issue #5171](https://github.com/doitsujin/dxvk/issues/5171)
[^62]: [NvTrueHDR - tool to enable RTX HDR in games - guru3D Forums](https://forums.guru3d.com/threads/nvtruehdr-tool-to-enable-rtx-hdr-in-games.451108/)
[^63]: [NvTrueHDR - RTX HDR in games - emoose/DLSSTweaks Issue #120](https://github.com/emoose/DLSSTweaks/issues/120)
[^64]: [Add RTX HDR known flags - Orbmu2k/nvidiaProfileInspector Issue #252](https://github.com/Orbmu2k/nvidiaProfileInspector/issues/252)
