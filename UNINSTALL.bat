@echo off
setlocal
title Cry of Fear HDR - Uninstaller
cd /d "%~dp0"

echo ==============================================================================
echo   CRY OF FEAR: REVERT TO VANILLA
echo ==============================================================================
echo.
echo Restoring original files and resetting driver profile...
echo Saves are not rolled back. A UAC prompt appears only for the driver reset.
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Uninstall.ps1"
echo.
pause
