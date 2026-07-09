param (
    [string]$TargetFolder = ".\"
)

$TargetFolder = (Resolve-Path $TargetFolder).Path

# Fungsi pembantu untuk mengubah ukuran Byte menjadi format yang mudah dibaca (KB/MB/GB)
function Format-Size ([long]$bytes) {
    if ($bytes -ge 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { "{0:N2} KB" -f ($bytes / 1KB) }
    else { "$bytes Bytes" }
}

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Memulai Deduplikasi Menggunakan Shortcut (.lnk)" -ForegroundColor Cyan
Write-Host " Target Folder : $TargetFolder" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# Mengambil semua file (mengabaikan file .lnk agar skrip aman jika dijalankan berulang)
$allFiles = Get-ChildItem -Path $TargetFolder -Recurse -File | Where-Object { $_.Extension -ne '.lnk' }

# 1. Hitung total kapasitas awal seluruh file asli sebelum proses
$totalSizeBefore = ($allFiles | Measure-Object -Property Length -Sum).Sum
$totalDeletedSize = 0
$totalShortcutSize = 0

# Membuat map/kamus untuk mencatat ukuran setiap file (untuk efisiensi data)
$sizeMap = @{}
foreach ($file in $allFiles) {
    $sizeMap[$file.FullName] = $file.Length
}

Write-Host "Kapasitas awal file asli : $(Format-Size $totalSizeBefore)" -ForegroundColor Gray
Write-Host "Menghitung hash MD5 untuk $($allFiles.Count) file. Harap tunggu..." -ForegroundColor Yellow

# Proses kalkulasi MD5 Hash
$hashedFiles = $allFiles | Get-FileHash -Algorithm MD5
$duplicates = $hashedFiles | Group-Object Hash | Where-Object Count -gt 1

if ($duplicates.Count -eq 0) {
    Write-Host "`nTidak ditemukan file duplikat." -ForegroundColor Green
    Write-Host "Kapasitas folder tetap: $(Format-Size $totalSizeBefore)" -ForegroundColor Gray
    exit
}

# Membuat COM Object untuk pembuatan shortcut (.lnk)
$WshShell = New-Object -ComObject WScript.Shell

foreach ($group in $duplicates) {
    $masterFile = $group.Group[0].Path

    Write-Host "`nDitemukan $($group.Count) file identik:" -ForegroundColor White
    Write-Host " [+] Master dipertahankan: $masterFile ($(Format-Size $sizeMap[$masterFile]))" -ForegroundColor Green

    for ($i = 1; $i -lt $group.Count; $i++) {
        $duplicateFile = $group.Group[$i].Path
        $duplicateDir = Split-Path $duplicateFile
        $duplicateName = Split-Path $duplicateFile -Leaf

        # Catat ukuran file yang akan dihapus
        $totalDeletedSize += $sizeMap[$duplicateFile]

        # Hapus file duplikat fisik
        Remove-Item -Path $duplicateFile -Force
        
        # Buat shortcut (.lnk) di lokasi file yang dihapus mengarah ke Master
        $shortcutPath = Join-Path -Path $duplicateDir -ChildPath "$duplicateName.lnk"
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $masterFile
        $shortcut.Save()

        # Hitung ukuran shortcut yang baru dibuat untuk akurasi kalkulasi
        $newShortcutSize = (Get-Item $shortcutPath).Length
        $totalShortcutSize += $newShortcutSize
        
        Write-Host " [~] Diganti jadi Shortcut: $shortcutPath" -ForegroundColor DarkCyan
    }
}

# Hitung kalkulasi akhir
$totalSpaceSaved = $totalDeletedSize - $totalShortcutSize
$totalSizeAfter = $totalSizeBefore - $totalSpaceSaved

Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host " Laporan Ringkasan Deduplikasi (.lnk)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Total Ukuran Sebelum : $(Format-Size $totalSizeBefore)" -ForegroundColor White
Write-Host " Total Ukuran Sesudah : $(Format-Size $totalSizeAfter)" -ForegroundColor Green
Write-Host " Total Ruang Dihemat  : $(Format-Size $totalSpaceSaved)" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan
