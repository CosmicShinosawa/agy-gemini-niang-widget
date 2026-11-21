@echo off
start "" wscript.exe //B //NoLogo "%~dp0runtime\launch-hidden.vbs" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0widget.ps1"
