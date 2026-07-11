@echo off
echo ===================================================
echo Menjalankan Aplikasi Deduplikasi File...
echo ===================================================

REM Mendapatkan path folder tempat file .bat ini berada
set "SCRIPT_DIR=%~dp0"

REM 1. Mengecek apakah file .ps1 benar-benar ada atau dihapus Antivirus
if not exist "%SCRIPT_DIR%Deduplicate-Files.ps1" (
    echo.
    echo [ERROR FATAL] File "Deduplicate-Files.ps1" TIDAK DITEMUKAN!
    echo Kemungkinan besar file tersebut telah dikarantina/dihapus oleh Kaspersky.
    echo Silakan cek riwayat Karantina Kaspersky Anda, pulihkan file tersebut, 
    echo dan pastikan folder ini sudah dimasukkan ke dalam Exclusions.
    echo.
    pause
    exit
)

REM 2. Menjalankan skrip dengan parameter -NoExit agar layar tidak langsung tertutup jika ada Syntax Error
echo File skrip ditemukan. Memulai PowerShell...
powershell.exe -ExecutionPolicy Bypass -NoProfile -NoExit -File "%SCRIPT_DIR%Deduplicate-Files.ps1" -TargetFolder "%SCRIPT_DIR%."

pause
