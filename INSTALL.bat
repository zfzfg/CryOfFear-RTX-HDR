@echo off
setlocal
title Cry of Fear HDR - 1-Click Installer
cd /d "%~dp0"

echo ==============================================================================
echo   CRY OF FEAR: RTX HDR & 1440P ENHANCEMENT MOD
echo   By Collin Lerche (zfzfg) ^| STERRA (https://sterra.online)
echo ==============================================================================
echo.
echo Running automated installation...
echo A UAC prompt appears only for the NVIDIA driver profile import. Click YES.
echo Close Steam first if you want launch options written automatically.
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Install.ps1"
if errorlevel 1 (
    echo.
    echo Installation reported an error.
    pause
    exit /b 1
)

echo.
echo ==============================================================================
echo Running verification diagnostics...
echo ==============================================================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Test.ps1"
echo.
pause
