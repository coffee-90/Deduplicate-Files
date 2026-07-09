@echo off
echo Menjalankan Aplikasi Deduplikasi File...

REM Mendapatkan path folder tempat file .bat ini berada
set "SCRIPT_DIR=%~dp0"

REM Menjalankan script powershell dengan ExecutionPolicy Bypass agar tidak diblokir Windows
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%Deduplicate-Files.ps1" -TargetFolder "%SCRIPT_DIR%."

pause
