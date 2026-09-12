# Cry of Fear HDR v1.1 — 1440p-Anpassung, Menüschrift, Treiberqualität

## Context

Das HDR-Setup läuft. Offen sind vier Punkte aus dem Spielbetrieb auf 2560×1440 @ 300 Hz
bei 125 % Windows-Skalierung:

1. Das Spiel ist nicht auf die Auflösung abgestimmt — GoldSrc bringt selbst kein
   Antialiasing und keine anisotrope Filterung mit, beides fällt bei 1440p auf.
2. Schrift und HUD sind zu klein.
3. Die FPS hängen bei 100 fest, obwohl `fps_max 300` gesetzt ist.
4. Die DPI-Situation ist unklar (125 % Systemskalierung, Spiel auf „Anwendung").

Die Recherche hat ergeben, dass sich davon **nicht alles** lösen lässt, und der
Nutzer hat die Kompromisse entschieden:

- **HUD:** nur die Menüschrift wird vergrößert. Das Spiel bleibt nativ 2560×1440.
- **FPS:** bleibt bei 100, die wirkungslose Zeile fliegt raus.
- **Treiberqualität:** alles, was geht — 16× AF, 8× MSAA, Transparenz-Supersampling.

---

## Verifizierte Befunde, die den Plan bestimmen

Alles gegen die reale Installation und die Binaries geprüft:

| Befund | Konsequenz |
|---|---|
| `fps_override` existiert **nicht** in `hw.dll`/`sw.dll` — nur `fps_max`, `fps_modem` | Die Zeile in `autoexec.cfg` ist ein No-op. Der 100er-Deckel ist in der Pre-SteamPipe-Engine fest. Nicht lösbar. |
| Kein `hud_scale`-Cvar in `client.dll` oder `cl_dlls/hl.dll` | HUD-Größe ist nicht konfigurierbar. |
| `*_textscheme.txt` wird von **keiner** Binary referenziert (Byte-Suche in hw/client/hl/GameUI) | Tote Altlast aus dem HL-SDK. Bearbeiten wäre wirkungslos. |
| `client.dll` nutzt VGUI**1** (`vgui::Font`, `CSchemeManager`) mit einkompilierten Größen | In-Game-HUD-Text nicht über Dateien änderbar. |
| `resource/trackerscheme.res` nutzt bei `EngineFont` bereits **`yres`-Blöcke** (480-599 … 1200-6000) | Der auflösungsabhängige Mechanismus existiert und wird ausgewertet. Das ist der saubere Hebel für die Menüschrift. |
| Dialog-`.res` verwenden feste Pixelmaße (z. B. `wide 824 / tall 736`) | Größere Schrift kann in unveränderten Panels abgeschnitten werden → zweistufig vorgehen. |
| `config.cfg` enthält Paranoia-Renderer-Cvars: `gl_overbright 0`, `gl_contrast 1.4`, `r_detailtextures 0`, `gl_max_size 1024` | Zusätzliche Qualitäts- und HDR-Stellschrauben. |

---

## Teil 1 — Treiberqualität über das NVIDIA-Profil

**Neu:** `install/cof-hdr-nvidia-quality.nip`, gleiches Profil `Cry of Fear (HDR)`,
Executable `cof.exe`. Wird **zusätzlich** zum bestehenden Treiberprofil importiert
(Profile Inspector führt zusammen, überschreibt nur genannte IDs).

| Einstellung | Hex-ID | Dezimal | Wert |
|---|---|---|---|
| Anisotropic Filtering – Mode | `0x10D2BB16` | 282245910 | 1 (User-defined) |
| Anisotropic Filtering – Setting | `0x101E61A9` | 270426537 | 16 (16×) |
| Texture Filtering – Quality | `0x00CE2691` | 13510289 | 4294967286 (High quality) |
| Texture Filtering – Trilinear Optimization | `0x002ECAF2` | 3066610 | 1 (Off) |
| Anisotropic Filter – Optimization | `0x0084CD70` | 8703344 | 0 (Off) |
| Anisotropic Filter – Sample Optimization | `0x00E73211` | 15151633 | 0 (Off) |
| Texture Filtering – Negative LOD bias | `0x0019BB68` | 1686376 | 1 (Clamp) |
| Antialiasing (MSAA) – Mode | `0x107EFC5B` | 276757595 | 1 (Override) |
| Antialiasing (MSAA) – Setting | `0x10D773D2` | 282555346 | 37 (8xQ = echtes 8× MSAA) |
| Antialiasing (MSAA) – Behavior Flags | `0x10ECDB82` | 283958146 | 0 (None) |
| Antialiasing – Gamma Correction | `0x107D639D` | 276652957 | 2 (On) |
| Antialiasing – Transparency Supersampling | `0x10D48A85` | 282364549 | 40 (4× Sparse Grid) |
| Maximum Pre-Rendered Frames | `0x007BA09E` | 8102046 | 1 |

**8xQ statt 8x:** `0x25` ist echtes 8× Multisampling, `0x26` wäre 8× CSAA
(4 Farb- + 4 Coverage-Samples). Auf einer 5070 Ti bei GoldSrc-Last ist die
Qualitätsvariante gratis.

**Risiko und Rückfallebene.** MSAA-Override gegen den Layered-DXGI-Pfad plus RTX HDR
ist nicht dokumentiert. Deshalb zusätzlich `install/cof-hdr-nvidia-quality-noaa.nip`
mit identischem Inhalt, aber MSAA-Mode `0` und Transparency-Supersampling `0` —
falls Flackern, schwarze Ränder oder ein Absturz auftreten, ist das ein Import
statt einer Fehlersuche.

Neuer Schalter `-Quality` in `Install-CofHdr.ps1` importiert das Profil zusätzlich.

---

## Teil 2 — Menüschrift auf 1440p skalieren

**Ansatz: die Dateien des Nutzers werden in place bearbeitet, nicht ersetzt.**
`clientscheme.res` und `trackerscheme.res` sind Spieldateien; modifizierte Kopien
auszuliefern wäre Weitergabe von Spielinhalt (siehe `LICENSE`). Stattdessen ein
Skript, das die vorhandene Datei parst und die Fontblöcke umschreibt — das
überlebt auch abweichende Spielversionen.

**Neu: `tools/Set-CofFontScale.ps1`**

- Parameter `-Scale` (Standard `1.55`), `-GamePath`, `-Revert`, `-WhatIf`.
- Sichert nach `backup/original/resource/` (einmalig, gleiche Logik wie der Installer).
- Bearbeitet `cryoffear/resource/trackerscheme.res` und `clientscheme.res`:
  Für jeden Font ohne `yres` wird der bestehende `"1"`-Block um einen
  vorangestellten Block mit `"yres" "1200 6000"` und skaliertem `tall` ergänzt.
  Dadurch bleibt das Verhalten unterhalb 1200 px exakt wie vorher — wichtig, weil
  das Paket auch an Leute mit 1080p geht.
- Fonts mit vorhandenen `yres`-Blöcken (`EngineFont`) bekommen einen zusätzlichen
  Bereich `1440 6000`; der bestehende `1200 6000`-Block wird auf `1200 1439` verengt.
- `Legacy_CreditsFont` bleibt unangetastet — die Datei sagt ausdrücklich
  „This version should not scale".

Zielgrößen bei `-Scale 1.55` (aufgerundet auf ganze Pixel):

| Font | jetzt | bei ≥1440p |
|---|---|---|
| `Default`, `DefaultBold`, `DefaultUnderline` | 16 | 25 |
| `DefaultSmall` | 13 | 20 |
| `DefaultVerySmall` | 12 | 19 |
| `Marlett` (Symbolfont) | 14 | 22 |
| `MenuLarge` | 18 | 28 |
| `EngineFont` | 24 | 37 |
| `CreditsFont` | 18 | 28 |

**Zweite Stufe nur bei Bedarf.** Die Dialog-`.res` haben feste Pixelmaße. Wenn nach
Stufe 1 Text in Buttons abgeschnitten wird, skaliert ein zweiter Durchlauf
(`-Layout`-Schalter) `xpos`/`ypos`/`wide`/`tall` in den betroffenen `.res`-Dateien
mit demselben Faktor. Das wird **nicht** vorab gemacht: 38 Dateien blind umzurechnen
ist ein größerer Eingriff als das Problem, das es vielleicht gar nicht gibt.

---

## Teil 3 — `autoexec.cfg` bereinigen und für 1440p abstimmen

In `install/autoexec.cfg`:

```
fps_override 1        ← ENTFERNEN, existiert in diesem Build nicht
fps_max      300      ← auf 100 (Engine-Hardcap; alles darüber wird geklemmt)
```

Kommentar dazu, warum 100 die Obergrenze ist, damit die Zeile nicht wieder
„repariert" wird. Der Refresh-Abgleich im Installer wird auf `min(refresh, 100)`
geändert.

Ergänzen, jeweils mit Begründung im Kommentar:

| Cvar | jetzt | neu | Warum |
|---|---|---|---|
| `r_detailtextures` | 0 | 1 | `gl_detailtex` steht bereits auf 1; Detailtexturen zahlen sich bei 1440p aus. Ohne mitgelieferte Detailtexturen schlicht wirkungslos. |
| `cl_fovmultiplier` | — | 1.0, Testwerte 1.1–1.15 dokumentiert | GoldSrc-FOV stammt aus 4:3. Auf 16:9 wirkt die Sicht enger. CoF-eigener Regler. |
| `gl_overbright` | 0 | **Testeintrag, auskommentiert** | Overbright-Lighting hebt helle Flächen über Weiß — genau die Reserve, die ein Tone-Expander braucht. Verändert aber den Bildlook merklich, deshalb bewusste Entscheidung des Spielers. |
| `gl_contrast` | 1.4 | **Testeintrag, auskommentiert** (≈1.15) | Vorgebackener Kontrast klemmt Lichter schon in SDR ab. Weniger Kontrast gibt RTX HDR mehr Spielraum — dieselbe Logik wie beim Contrast-Regler in Abschnitt 4. |

`gl_max_size 1024` bleibt: GoldSrc-Texturen liegen darunter, der Wert begrenzt nichts.

---

## Teil 4 — Auflösung und DPI

- Startoptionen in Steam setzen (steht noch aus, Steam lief):
  `-window -noborder -w 2560 -h 1440 -console`
- DPI-Override bleibt auf „Anwendung" (`HIGHDPIAWARE`). Das ist die Voraussetzung
  dafür, dass nativ 2560×1440 gerendert wird statt 2048×1152 mit Windows-Upscaling.
  Die 125 % Systemskalierung betrifft damit das Spiel bewusst nicht — die
  Menüschrift holt Teil 2 auf.

---

## Teil 5 — Paket nachziehen

- `tools/Uninstall-CofHdr.ps1`: `resource/*.res` aus `backup/original/resource/`
  zurückschreiben; Reset-Profil um die neuen Qualitäts-IDs erweitern
  (`install/cof-hdr-nvidia-reset.nip`), sonst bleiben MSAA und AF nach der
  Deinstallation im Treiberprofil stehen.
- `tools/Test-CofHdr.ps1`: prüfen, ob die Fontblöcke vorhanden sind, und
  `fps_override` in der Config als Fehler melden statt es zu ignorieren.
- `tools/Build-Release.ps1`: neue Dateien in die Positivliste.
- `HDRmodCOF.md`: neuer Abschnitt zu Auflösung, Schrift und dem FPS-Deckel; die
  jetzt widerlegte `fps_override`-Empfehlung in Abschnitt 5 korrigieren.
- `CHANGELOG.md`: v1.1 mit denselben Abschnitten „Verified" / „Not verified".

## Zu ändernde Dateien

- `install/autoexec.cfg`
- `install/cof-hdr-nvidia-quality.nip` *(neu)*, `install/cof-hdr-nvidia-quality-noaa.nip` *(neu)*
- `install/cof-hdr-nvidia-reset.nip`
- `tools/Set-CofFontScale.ps1` *(neu)*
- `tools/Install-CofHdr.ps1`, `tools/Uninstall-CofHdr.ps1`, `tools/Test-CofHdr.ps1`, `tools/Build-Release.ps1`
- `HDRmodCOF.md`, `CHANGELOG.md`, `README.md`, `install/KURZANLEITUNG.md`

---

## Verifikation

**Vor dem Spielstart, automatisch prüfbar:**

1. `.nip`-Dateien als XML parsen, Setting-IDs und Werte gegen die Tabelle oben prüfen.
2. Nach dem Import: Profildatenbank `nvdrsdb0.bin` binär nachlesen — alle neuen
   IDs müssen im Umfeld des Profilnamens `Cry of Fear (HDR)` stehen (dieselbe
   Methode, die den ersten Import bestätigt hat).
3. `Set-CofFontScale.ps1 -WhatIf`, danach Diff der `.res`-Dateien gegen
   `backup/original/resource/` — es dürfen ausschließlich Fontblöcke hinzugekommen sein.
4. `Test-CofHdr.ps1` läuft ohne `[FAIL]`.
5. Alle Skripte parsen; `Build-Release.ps1` baut vollständig.

**Im Spiel, nur durch dich prüfbar:**

6. Hauptmenü und Optionen: Schrift lesbar, kein abgeschnittener Text in Buttons.
   Wenn abgeschnitten → Stufe 2 aus Teil 2.
7. Kanten an Geländern und Türrahmen: mit 8× MSAA sichtbar glatt. Wenn Flackern
   oder schwarze Ränder → `cof-hdr-nvidia-quality-noaa.nip` importieren.
8. Boden in einem langen Gang: mit 16× AF bis in die Tiefe scharf statt matschig.
9. HDR unverändert intakt — Taschenlampenkegel deutlich heller als Menüweiß.
10. FPS-Anzeige: 100. Das ist das erwartete Maximum, kein Fehler.

## Risiken

- **MSAA × RTX HDR × Layered-DXGI** ist die einzige echte Unbekannte. Rückfall-Profil
  liegt bereit.
- **Schrift vs. Panelgröße** — Stufe 2 ist vorbereitet, aber bewusst nicht vorab gemacht.
- **Steam-Dateiprüfung** setzt die `.res`-Dateien zurück, wie beim Shader. Sicherung
  und Uninstaller decken das ab.
