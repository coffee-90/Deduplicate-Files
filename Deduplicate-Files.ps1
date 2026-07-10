param (
    [string]$TargetFolder = ".\"
)

$TargetFolder = (Resolve-Path $TargetFolder).Path

function Format-Size ([long]$bytes) {
    if ($bytes -ge 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { "{0:N2} KB" -f ($bytes / 1KB) }
    else { "$bytes Bytes" }
}

# Fungsi mencari huruf Drive kosong untuk bypass Long Path
function Get-FreeDriveLetter {
    $usedDrives = [System.IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0,1) }
    $allDrives = 90..67 | ForEach-Object { [char]$_ } # Dari Z mundur ke C
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

# Mengambil semua file (kecuali .lnk)
$allFiles = Get-ChildItem -LiteralPath $TargetFolder -Recurse -File | Where-Object { $_.Extension -ne '.lnk' }

$totalSizeBefore = ($allFiles | Measure-Object -Property Length -Sum).Sum
$totalDeletedSize = 0
$totalShortcutSize = 0

$sizeMap = @{}
foreach ($file in $allFiles) {
    $sizeMap[$file.FullName] = $file.Length
}

Write-Host "Kapasitas awal file asli : $(Format-Size $totalSizeBefore)" -ForegroundColor Gray
Write-Host "Menghitung hash MD5 untuk $($allFiles.Count) file. Harap tunggu..." -ForegroundColor Yellow

$hashedFiles = $allFiles | Get-FileHash -Algorithm MD5
$duplicates = $hashedFiles | Group-Object Hash | Where-Object Count -gt 1

if ($duplicates.Count -eq 0) {
    Write-Host "`nTidak ditemukan file duplikat." -ForegroundColor Green
    Write-Host "Kapasitas folder tetap: $(Format-Size $totalSizeBefore)" -ForegroundColor Gray
    exit
}

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
            # --- BYPASS LONG PATH UNTUK PEMBUATAN SHORTCUT ---
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
                    continue
                }
            } else {
                # Normal mode
                $shortcut = $WshShell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $masterFile
                $shortcut.Save()
            }

            # PENGAMANAN BARU: Hapus file duplikat HANYA jika proses save shortcut di atas berhasil tanpa error
            Remove-Item -LiteralPath $duplicateFile -Force
            $totalDeletedSize += $sizeMap[$duplicateFile]

            # Hitung ukuran shortcut yang baru dibuat
            if (Test-Path -LiteralPath $shortcutPath) {
                $newShortcutSize = (Get-Item -LiteralPath $shortcutPath).Length
                $totalShortcutSize += $newShortcutSize
                Write-Host " [~] Diganti jadi Shortcut: $duplicateName.lnk" -ForegroundColor DarkCyan
            }

        } catch {
            # Jika WScript.Shell menolak membuat shortcut (biasanya karena limitasi lawas internalnya), 
            # abaikan file tersebut dan jangan dihapus agar data Anda tetap aman.
            Write-Host " [!] Gagal diproses: Shortcut gagal dibuat untuk '$duplicateName'. File asli tetap aman." -ForegroundColor Red
            
            # Bersihkan virtual drive jika nyangkut
            if ($freeDrive) {
                & cmd.exe /c "subst $freeDrive /D" 2>$null
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
