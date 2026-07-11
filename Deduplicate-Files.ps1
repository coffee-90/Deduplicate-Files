param (
    [string]$TargetFolder = ".\"
)

# Mencegah error minor (seperti Access Denied pada 1 file) menghentikan seluruh skrip
$ErrorActionPreference = 'Continue' 

# Membungkus seluruh skrip dengan pelacak Error Fatal
try {
    $TargetFolder = (Resolve-Path $TargetFolder).Path

    function Format-Size ([long]$bytes) {
        if ($bytes -ge 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
        elseif ($bytes -ge 1MB) { "{0:N2} MB" -f ($bytes / 1MB) }
        elseif ($bytes -ge 1KB) { "{0:N2} KB" -f ($bytes / 1KB) }
        else { "$bytes Bytes" }
    }

    function Get-FreeDriveLetter {
        $usedDrives = [System.IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0,1) }
        $allDrives = 90..67 | ForEach-Object { [char]$_ } 
        foreach ($drive in $allDrives) {
            if ($usedDrives -notcontains $drive) {
                return "$drive`:"
            }
        }
        return $null
    }

    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host " Memulai Deduplikasi Menggunakan Shortcut (.lnk)" -ForegroundColor Cyan
    Write-Host " Target Folder : $TargetFolder" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    # Mengambil file (Mengabaikan error akses file yang dikunci oleh Windows)
    $allFiles = Get-ChildItem -LiteralPath $TargetFolder -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.lnk' }
    
    if (-not $allFiles) {
        Write-Host "Tidak ada file yang ditemukan untuk dipindai." -ForegroundColor Yellow
        $allFiles = @()
    }

    # Kalkulasi ukuran awal
    $totalSizeBefore = ($allFiles | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalSizeBefore) { $totalSizeBefore = 0 }
    
    $totalDeletedSize = 0
    $totalShortcutSize = 0
    $errorList = @()

    $sizeMap = @{}
    foreach ($file in $allFiles) {
        $sizeMap[$file.FullName] = $file.Length
    }

    Write-Host "Kapasitas awal file asli : $(Format-Size $totalSizeBefore)" -ForegroundColor Gray
    
    if ($allFiles.Count -gt 0) {
        Write-Host "Menghitung hash MD5 untuk $($allFiles.Count) file. Harap tunggu..." -ForegroundColor Yellow
        # Menghitung Hash
        $hashedFiles = $allFiles | Get-FileHash -Algorithm MD5 -ErrorAction SilentlyContinue
        $duplicates = $hashedFiles | Group-Object Hash | Where-Object Count -gt 1
    } else {
        $duplicates = @()
    }

    # JIKA TIDAK ADA DUPLIKAT, langsung melompat ke laporan akhir tanpa perintah exit
    if ($duplicates.Count -eq 0) {
        Write-Host "`nTidak ditemukan file duplikat." -ForegroundColor Green
    } else {
        $WshShell = New-Object -ComObject WScript.Shell

        foreach ($group in $duplicates) {
            $masterFile = $group.Group[0].Path

            Write-Host "`nDitemukan $($group.Count) file identik:" -ForegroundColor White
            Write-Host " [+] Master dipertahankan: $masterFile ($(Format-Size $sizeMap[$masterFile]))" -ForegroundColor Green

            for ($i = 1; $i -lt $group.Count; $i++) {
                $duplicateFile = $group.Group[$i].Path
                $duplicateDir = Split-Path $duplicateFile
                $duplicateName = Split-Path $duplicateFile -Leaf
                
                $shortcutPath = Join-Path -Path $duplicateDir -ChildPath "$duplicateName.lnk"
                $freeDrive = $null
                
                try {
                    if ($shortcutPath.Length -ge 248) {
                        $freeDrive = Get-FreeDriveLetter
                        if ($freeDrive) {
                            & cmd.exe /c "subst $freeDrive `"$duplicateDir`""
                            $virtualShortcutPath = "$freeDrive\$duplicateName.lnk"
                            
                            $shortcut = $WshShell.CreateShortcut($virtualShortcutPath)
                            $shortcut.TargetPath = $masterFile
                            $shortcut.Save()
                            
                            & cmd.exe /c "subst $freeDrive /D" | Out-Null
                        } else {
                            Write-Host " [!] Diabaikan: Path sangat panjang & tidak ada Drive letter kosong." -ForegroundColor Yellow
                            $errorList += [PSCustomObject]@{ File = $duplicateFile; Alasan = "Path terlalu panjang, Bypass penuh" }
                            continue
                        }
                    } else {
                        $shortcut = $WshShell.CreateShortcut($shortcutPath)
                        $shortcut.TargetPath = $masterFile
                        $shortcut.Save()
                    }

                    # Force stop jika proses hapus gagal, agar di-catch dan dicatat
                    Remove-Item -LiteralPath $duplicateFile -Force -ErrorAction Stop
                    $totalDeletedSize += $sizeMap[$duplicateFile]

                    if (Test-Path -LiteralPath $shortcutPath) {
                        $newShortcutSize = (Get-Item -LiteralPath $shortcutPath).Length
                        $totalShortcutSize += $newShortcutSize
                        Write-Host " [~] Diganti jadi Shortcut: $duplicateName.lnk" -ForegroundColor DarkCyan
                    }

                } catch {
                    Write-Host " [!] Gagal diproses: '$duplicateName'." -ForegroundColor Red
                    $errorList += [PSCustomObject]@{ File = $duplicateFile; Alasan = $_.Exception.Message }
                    
                    if ($freeDrive) {
                        & cmd.exe /c "subst $freeDrive /D" 2>$null
                    }
                }
            }
        }
    }

    $totalSpaceSaved = $totalDeletedSize - $totalShortcutSize
    $totalSizeAfter = $totalSizeBefore - $totalSpaceSaved

    # LAPORAN AKHIR (Sekarang dipastikan selalu muncul)
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host " Laporan Ringkasan Deduplikasi (.lnk)" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host " Total Ukuran Sebelum : $(Format-Size $totalSizeBefore)" -ForegroundColor White
    Write-Host " Total Ukuran Sesudah : $(Format-Size $totalSizeAfter)" -ForegroundColor Green
    Write-Host " Total Ruang Dihemat  : $(Format-Size $totalSpaceSaved)" -ForegroundColor Yellow
    Write-Host "===================================================" -ForegroundColor Cyan

    if ($errorList.Count -gt 0) {
        Write-Host "`n===================================================" -ForegroundColor Red
        Write-Host " DAFTAR FILE GAGAL DIPROSES" -ForegroundColor Red
        Write-Host " File-file di bawah ini tidak dihapus demi keamanan data." -ForegroundColor Yellow
        Write-Host "===================================================" -ForegroundColor Red
        
        foreach ($err in $errorList) {
            Write-Host " - Path  : $($err.File)" -ForegroundColor White
            Write-Host "   Error : $($err.Alasan)" -ForegroundColor Gray
        }
        Write-Host "===================================================" -ForegroundColor Red
    }

} catch {
    # Mencegah layar tertutup jika ada masalah besar/fatal
    Write-Host "`n[FATAL ERROR] Skrip terhenti secara darurat karena kesalahan sistem!" -ForegroundColor Red
    Write-Host "Detail Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Laporan akhir tidak dapat dibuat. Data Anda tetap aman." -ForegroundColor Gray
}
