@echo off
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start-local-connected.ps1"
if errorlevel 1 (
  echo.
  echo VakilSetu could not start. Read the error above.
  pause
)
