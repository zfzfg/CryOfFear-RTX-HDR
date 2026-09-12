@echo off
setlocal
cd /d "%~dp0"
echo ======================================================================
echo  Cry of Fear HDR - Treiber-Qualitaetsprofil importieren
echo  (16x AF, Hohe Texturqualitaet, RTX HDR - Absturzsicher ohne MSAA)
echo ======================================================================
echo.
echo Starte NVIDIA Profile Inspector als Administrator...
echo Bitte das Windows-Bestaetigungsfenster (UAC) mit JA bestaetigen.
echo.

powershell -Command "Start-Process '%~dp0nvidiaProfileInspector\nvidiaProfileInspector.exe' -ArgumentList '-silentImport', '%~dp0..\install\cof-hdr-nvidia-driver-quality-noaa.nip' -Verb runas -Wait"

echo.
echo Import abgeschlossen! Pruefe Status...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Test-CofHdr.ps1"
echo.
pause
