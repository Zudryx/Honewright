@echo off
rem Installs the newest Honewright TEST build (a GitHub pre-release that hasn't
rem gone to CurseForge yet). Use "Update Honewright.bat" for normal releases.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-Honewright.ps1" -Testing %*
echo.
pause
