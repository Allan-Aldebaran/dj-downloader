@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0DJ-Downloader-v3.5.ps1"
if errorlevel 1 pause
