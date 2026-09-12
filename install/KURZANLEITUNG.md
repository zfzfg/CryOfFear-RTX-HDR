# Cry of Fear in HDR — Kurzanleitung

Für RTX 50er-Serie + HDR1000-Monitor + Windows 11. **Ohne ReShade, ohne Dateien im Spielordner außer einer `.cfg`.**
Dauer: ca. 15 Minuten. Ausführliche Begründungen und Fehlersuche: `../HDRmodCOF.md`.

> **Schneller Weg:** Schritt 4 und 5 macht `..\tools\Install-CofHdr.ps1` automatisch,
> inklusive Sicherung. Erst `-WhatIf` zum Anschauen, dann ohne. `..\tools\Test-CofHdr.ps1`
> prüft anschließend jeden Punkt dieser Anleitung durch.
> Alles rückgängig: `..\tools\Uninstall-CofHdr.ps1`.

---

### 1. Windows-HDR einschalten (5 Min.)

- `Einstellungen → System → Bildschirm → HDR` → **HDR verwenden** = AN
- Auf derselben Seite: **Auto HDR = AUS** (wichtig — Auto HDR und RTX HDR dürfen nie gleichzeitig laufen)
- **Windows HDR Calibration** aus dem Microsoft Store installieren und durchlaufen lassen. Nicht überspringen — ohne diesen Schritt sieht HDR ausgewaschen aus.
- Am Monitor selbst: HDR-Modus aktivieren, aber „Dynamic Tone Mapping" / „Smart HDR" ausschalten.

### 2. Der entscheidende NVIDIA-Schalter (1 Min.)

Ohne diesen Schritt passiert gar nichts — OpenGL-Spiele werden von Windows sonst als reines SDR behandelt.

- **NVIDIA Systemsteuerung → 3D-Einstellungen verwalten → Programmeinstellungen**
- **Hinzufügen** → `…\steamapps\common\Cry of Fear\cof.exe`
- **Vulkan/OpenGL-Präsentationsmethode** = **„Auf DXGI-Swapchain aufgesetzt bevorzugen"**
  (englisch: *Prefer layered on DXGI Swapchain*)
- Übernehmen. **Nur für dieses Programm setzen, nicht global** — global kostet es in anderen Spielen Leistung.

### 3. RTX HDR aktivieren (1 Min.)

**RTX HDR gibt es in der klassischen NVIDIA-Systemsteuerung nicht** — und wird es auch nicht geben; die Systemsteuerung ist Altbestand und wird von NVIDIA schrittweise durch die NVIDIA App ersetzt. Schritt 2 oben ist der letzte Teil dieser Anleitung, der noch in der Systemsteuerung stattfindet.

**Weg A — mit der NVIDIA App (empfohlen):**

- NVIDIA App von nvidia.com laden, falls nicht vorhanden. Eigenständiger, kostenloser Download; **kein** Treiber-Neuinstall nötig, vorhandene Programmprofile werden übernommen, die Systemsteuerung funktioniert daneben weiter.
- **NVIDIA App → Grafik** → Cry of Fear auswählen (falls nicht gefunden: *Programm hinzufügen* → `cof.exe`)
- **RTX HDR** einschalten, Regler vorerst auf Standard lassen

**Weg B — ohne App:** RTX HDR lässt sich auch rein über das Treiberprofil aktivieren, per Tool `NvTrueHDR` oder NVIDIA Profile Inspector (Einstellung `0x00DD48FB` = 1, `0x00432F84` = 2, `0x1077A11A` = 1, `0x00980896` = 1; Treiber 531.18+, Windows 11).

**Der Haken bei Weg B:** Die vier Regler aus Schritt 6 — vor allem **Middle Grey** — gibt es nur über die NVIDIA App. Ohne sie bekommst du die Standard-Tonkurve und kannst nichts nachjustieren. Genau bei Cry of Fear ist das bitter: Unter HDR ist die Gammarampe des Spiels wirkungslos, das Bild kommt also dunkler an als der Tone-Mapper erwartet — und Middle Grey ist der Regler, der das geradezieht. **Nimm Weg A, wenn irgend möglich.**

### 4. Fenstermodus erzwingen (1 Min.)

Der Vollbildmodus von Cry of Fear ist auf modernem Windows kaputt (winziges Fenster in der Bildschirmmitte).

- Steam → Rechtsklick auf Cry of Fear → **Eigenschaften → Startoptionen**:
  ```
  -window -noborder -w 2560 -h 1440 -console -noforcemparms -noforcemaccel -noforcemspd
  ```

  Die drei `-noforce*`-Schalter sind Pflicht: ohne sie schreibt die Engine bei
  jedem Start die Windows-Mauseinstellungen um und schaltet
  „Zeigerbeschleunigung verbessern“ wieder ein.
  (Auflösung anpassen)
- Rechtsklick auf `cof.exe` → **Eigenschaften → Kompatibilität → Hohe DPI-Einstellungen ändern → Überschreibung des Verhaltens bei hoher DPI-Skalierung → Anwendung**

### 5. Config kopieren (1 Min.)

`autoexec.cfg` aus diesem Ordner nach:

```
…\steamapps\common\Cry of Fear\cryoffear\autoexec.cfg
```

Falls dort schon eine liegt: **vorher sichern und zusammenführen**, nicht blind überschreiben.
Ebenfalls vorher sichern: `cryoffear\SAVE\` — Cry of Fear hat keine Cloud-Saves.

### 6. Feineinstellung (5 Min.)

Zwei feste Testszenen wählen und immer wieder zu beiden zurückkehren:

- **Szene A (Highlights):** U-Bahn/Straße, Taschenlampe an, auf eine nahe Wand gerichtet
- **Szene B (Schatten):** unbeleuchteter Wohnungsflur, Taschenlampe aus

Immer nur **einen** Regler ändern, dann beide Szenen prüfen:

| Regler | Startwert | Warum |
|---|---|---|
| **Peak Brightness** | ~800 nits (etwas **unter** dem Panel-Peak) | Kaum ein HDR1000-Monitor hält 1000 nits über größere Flächen. Zu hoch = der Lichtkegel wird zur flachen weißen Scheibe. |
| **Middle Grey** | **über** Standard | Wichtigster Regler hier, und er geht in die andere Richtung als bei den meisten Spielen: Das Spiel ist dunkel, und unter HDR ist die Gammarampe wirkungslos, auf die es sich sonst stützt. |
| **Contrast** | Standard oder leicht darunter | Die 8-Bit-Lightmaps der Engine bilden bei stärkerer Spreizung sichtbare Banding-Streifen. |
| **Saturation** | Standard oder leicht darunter | Die grau-grüne Farbpalette ist Absicht; mehr Sättigung lässt Hauttöne und Blut comichaft wirken. |

**Endwerte notieren** — beim nächsten NVIDIA-App-Update sind sie sonst weg.

*(Dieser Schritt setzt Weg A aus Schritt 3 voraus. Mit Weg B gibt es diese Regler nicht.)*

---

### Optional: Schwarzweiß-Effekt entschärfen

Die Nightmare-/Schwarzweiß-Sequenzen sind der unangenehmste Fall unter HDR: der
Original-Shader rechnet `1.2 - 4.0 * (r+g+b)`, also eine sehr steile Kurve, deren
heller Teil sofort bei Weiß landet — und Weiß zieht der Tone-Expander auf die
Spitzenhelligkeit des Panels, mitten in einer stockdunklen Szene.

`install/cgshaders/black_fp.cg` ist eine entschärfte Fassung: flachere Kurve,
Ausgabe unterhalb von Weiß gedeckelt. Der Effekt bleibt erhalten, statt ihn per
`gl_posteffects 0` ganz abzuschalten.

```powershell
..\tools\Install-CofHdr.ps1 -Shader
```

Achtung: Das überschreibt als einzige Datei des Pakets eine mitgelieferte
Spieldatei. Steams Dateiprüfung setzt sie zurück; das Original wird vorher
gesichert. Anpassen lässt sie sich über drei Konstanten am Dateianfang.

---

### Funktioniert es? Drei Kontrollen

1. **Weg A:** Im NVIDIA-Overlay (`Alt+Z`) steht RTX HDR auf **aktiv**, nicht nur „aktiviert". **Weg B:** Kein Overlay vorhanden — stattdessen `0x00432F84` testweise auf `3` setzen („Enabled + Indicator"), dann zeichnet der Treiber eine Anzeige ins Bild; danach zurück auf `2`.
2. Beim Alt-Tab ändert sich die Desktop-Helligkeit sichtbar, solange das Spiel läuft.
3. Im Spiel: Der Kern des Taschenlampenkegels ist deutlich heller als der weiße Text im Pausenmenü. Sind beide gleich hell, greift HDR nicht — zurück zu Schritt 2.

### Die drei häufigsten Probleme

| Problem | Ursache | Lösung |
|---|---|---|
| RTX HDR an, aber nichts ändert sich | Präsentationsmethode steht noch auf „Automatisch" | Schritt 2 |
| RTX HDR in der NVIDIA-Systemsteuerung nicht auffindbar | Dort gibt es die Funktion nicht | NVIDIA App installieren (Weg A) |
| Alles viel zu dunkel | Gammarampe ist unter HDR wirkungslos | **Middle Grey** anheben — nicht den Helligkeitsregler im Spiel |
| Ausgewaschene, graue Schwarzwerte | Auto HDR läuft zusätzlich, oder Kalibrierung fehlt | Auto HDR aus, HDR-Kalibrierung nachholen |

Vollständige Fehlertabelle: `../HDRmodCOF.md`, Abschnitt 6.

---

### Für hohe Auflösungen (ab 1440p)

**Bildqualität.** GoldSrc kann von sich aus weder Kantenglättung noch anisotrope
Filterung. Beides wird über das Treiberprofil erzwungen — nimm dafür die Datei
`cof-hdr-nvidia-driver-quality.nip` statt `...-driver.nip`. Wichtig: **ein Import
ersetzt das Profil, er ergänzt es nicht.** Zwei Dateien nacheinander zu importieren
löscht die Einstellungen der ersten. Jede Datei enthält deshalb bereits alles.

Falls es flackert, schwarze Ränder gibt oder abstürzt:
`cof-hdr-nvidia-driver-quality-noaa.nip` importieren — dieselbe Datei ohne MSAA.

**Menüschrift.** Zu klein auf 1440p, weil die Größen fest in Pixeln stehen:

```powershell
..\tools\Set-CofFontScale.ps1
```

Rückgängig mit `-Revert`, anderer Faktor mit `-Scale 1.8`.

**Das HUD im Spiel lässt sich nicht vergrößern.** Die Größen stecken fest in
`client.dll`, es gibt kein Cvar dafür, und die `*_textscheme.txt`-Dateien im
Spielordner sehen zwar danach aus, werden aber von keiner Programmdatei gelesen.
Der einzige Hebel wäre, in niedrigerer Auflösung zu rendern.

**Die FPS bleiben bei 100.** Das ist kein Fehler: Diese Engine-Version kennt das
Cvar `fps_override` gar nicht, und der Deckel ist fest einkompiliert. Die
GoldSrc-Physik arbeitet ohnehin nur bis 100 sauber.
