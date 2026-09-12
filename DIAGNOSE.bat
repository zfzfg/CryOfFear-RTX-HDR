@echo off
setlocal
title Cry of Fear HDR - Diagnostics
cd /d "%~dp0"

echo ==============================================================================
echo   CRY OF FEAR: SYSTEM & MOD DIAGNOSTICS
echo ==============================================================================
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tools\Test.ps1"

echo.
pause
