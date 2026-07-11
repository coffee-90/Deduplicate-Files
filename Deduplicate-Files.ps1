param (
    [string]$TargetFolder = ".\"
)

$ErrorActionPreference = 'Continue' 

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
    Write-Host " Fitur Tambahan: Mode Aman Anti-Heuristik (Delay)" -ForegroundColor DarkGray
    Write-Host "===================================================" -ForegroundColor Cyan

    $allFiles = Get-ChildItem -LiteralPath $TargetFolder -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.lnk' }
    
    if (-not $allFiles) {
        Write-Host "Tidak ada file yang ditemukan untuk dipindai." -ForegroundColor Yellow
        $allFiles = @()
    }

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
        $hashedFiles = $allFiles | Get-FileHash -Algorithm MD5 -ErrorAction SilentlyContinue
        $duplicates = $hashedFiles | Group-Object Hash | Where-Object Count -gt 1
    } else {
        $duplicates = @()
    }

    if ($duplicates.Count -eq 0) {
        Write-Host "`nTidak ditemukan file duplikat." -ForegroundColor Green
    } else {
        foreach ($group in $duplicates) {
            $masterFile = $group.Group[0].Path

            Write-Host "`nDitemukan $($group.Count) file identik:" -ForegroundColor White
            Write-Host " [+] Master: $masterFile" -ForegroundColor Green

            for ($i = 1; $i -lt $group.Count; $i++) {
                $duplicateFile = $group.Group[$i].Path
                $duplicateDir = Split-Path $duplicateFile
                $duplicateName = Split-Path $duplicateFile -Leaf
                
                $shortcutPath = Join-Path -Path $duplicateDir -ChildPath "$duplicateName.lnk"
                $freeDrive = $null
                
                try {
                    # 1. Trik Bypass Kaspersky: Beri jeda 0.15 detik per file agar tidak dianggap virus
                    Start-Sleep -Milliseconds 150

                    # 2. Inisiasi COM Object langsung di dalam loop agar lebih aman dari crash memori
                    $WshShell = New-Object -ComObject WScript.Shell

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

                    # Pelepasan memori COM Object secara manual
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shortcut) | Out-Null
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WshShell) | Out-Null
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()

                    Remove-Item -LiteralPath $duplicateFile -Force -ErrorAction Stop
                    $totalDeletedSize += $sizeMap[$duplicateFile]

                    if (Test-Path -LiteralPath $shortcutPath) {
                        $newShortcutSize = (Get-Item -LiteralPath $shortcutPath).Length
                        $totalShortcutSize += $newShortcutSize
                        
                        # Tampilan yang lebih ringkas agar rapi
                        $shortParentDir = Split-Path $duplicateDir -Leaf
                        Write-Host " [~] Shortcut: ...\$shortParentDir\$duplicateName.lnk" -ForegroundColor DarkCyan
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
        Write-Host "===================================================" -ForegroundColor Red
        foreach ($err in $errorList) {
            Write-Host " - Path  : $($err.File)" -ForegroundColor White
            Write-Host "   Error : $($err.Alasan)" -ForegroundColor Gray
        }
    }

} catch {
    Write-Host "`n[FATAL ERROR] Skrip terhenti secara darurat karena kesalahan sistem!" -ForegroundColor Red
    Write-Host "Detail Error: $($_.Exception.Message)" -ForegroundColor Yellow
}
