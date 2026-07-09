# Windows File Deduplicator (.lnk Shortcut Method)

Skrip PowerShell sederhana dan efisien untuk mengidentifikasi file duplikat di dalam suatu folder dan subfolder berdasarkan nilai **Hash MD5**, menghapus file duplikat tersebut, dan menggantinya dengan **Windows Shortcut (.lnk)** yang mengarah ke file master (asli). 

Aplikasi ini juga dilengkapi dengan fitur kalkulasi otomatis untuk menampilkan kapasitas penyimpanan sebelum dan sesudah optimasi, serta total ruang penyimpanan yang berhasil dihemat.

## 🎯 Fungsi dan Kegunaan
Aplikasi ini sangat berguna untuk:
* **Menghemat Kapasitas Penyimpanan:** Menghapus salinan file fisik yang berukuran besar (seperti video, foto resolusi tinggi, atau dokumen) dan menggantinya dengan shortcut yang hanya berukuran 1-2 KB.
* **Merapikan Folder Backup/Arsip:** Cocok digunakan pada folder di mana sering terjadi duplikasi file karena proses *copy-paste* yang berulang dari waktu ke waktu.
* **Mempertahankan Struktur Akses File:** Meskipun file fisik duplikat dihapus, Anda tetap bisa mengakses file tersebut dari lokasi semula karena file shortcut (`.lnk`) akan menjembatani dan membuka file master (aslinya).

## 🚀 Fitur Utama
- **Identifikasi Akurat:** Menggunakan algoritma **MD5 Hash** untuk memastikan file benar-benar identik, bukan hanya berdasarkan nama atau ukuran file.
- **Pencarian Mendalam (Recursive):** Memindai seluruh file hingga ke dalam subfolder terdalam.
- **Efisiensi Ruang:** Menghapus duplikat fisik dan menggantinya dengan file `.lnk` yang berukuran sangat kecil (1-2 KB).
- **Laporan Ringkasan Selesai:** Menampilkan total kapasitas sebelum proses, sesudah proses, dan jumlah ruang hardsik yang berhasil diselamatkan.
- **Dua Cara Eksekusi:** Dapat dijalankan langsung via Command Prompt (CMD) / Double-Click menggunakan file Batch (`.bat`) atau dijalankan manual via PowerShell (`.ps1`).

## 📁 Struktur File Repository
Pastikan kedua file ini diletakkan di dalam folder yang sama:
1. `Deduplicate-Files.ps1` — Skrip logika utama PowerShell.
2. `Run-Deduplicate.bat` — File peluncur (launcher) berbasis Batch untuk CMD.

## 🛠️ Cara Penggunaan

### Cara 1: Melalui Double-Click / CMD (Sangat Mudah)
1. Unduh dan masukkan file `Deduplicate-Files.ps1` dan `Run-Deduplicate.bat` ke dalam folder target yang ingin Anda bersihkan duplikatnya.
2. Klik ganda (*double-click*) pada file `Run-Deduplicate.bat`.
3. Jendela CMD akan terbuka dan otomatis memproses deduplikasi pada folder tersebut serta subfolder di dalamnya.
4. Setelah selesai, ringkasan kapasitas akan muncul. Tekan tombol apa saja untuk menutup jendela.

### Cara 2: Melalui PowerShell secara Manual (Advanced)
Jika Anda ingin mengeksekusinya tanpa memindahkan file skrip ke folder target, buka PowerShell dan jalankan perintah berikut:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Path\Ke\Script\Deduplicate-Files.ps1" -TargetFolder "D:\Path\Folder\Target\Anda"
```

## ⚠️ Peringatan Penting (⚠️ Harap Dibaca)
JANGAN dijalankan di Folder Sistem Windows: Dilarang keras menjalankan skrip ini di folder krusial seperti C:\\Windows, C:\\Program Files, atau C:\\Users\\NamaUser\\AppData. Menghapus duplikat pada file sistem dapat menyebabkan Windows crash atau aplikasi tidak berfungsi. Gunakan hanya untuk folder data pribadi (seperti Foto, Video, Dokumen, Backup, dll).

### Risiko Broken Link:
Karena file duplikat diubah menjadi shortcut yang mengarah ke 1 file Master (asli), jika di masa mendatang Anda menghapus, memindahkan, atau mengubah nama file Master tersebut, seluruh shortcut yang mengarah kepadanya tidak akan bisa dibuka (broken link).

### Penghapusan Permanen:
Skrip ini menggunakan perintah Remove-Item -Force yang akan menghapus file duplikat secara permanen tanpa memindahkannya ke Recycle Bin. Disarankan melakukan uji coba terlebih dahulu pada folder dummy (uji coba).

## 🛡️ Catatan Keamanan Antivirus (False Positive)
Beberapa antivirus sensitif (seperti Kaspersky, Windows Defender, dll) mungkin akan mendeteksi skrip ini sebagai Trojan.Win32.Generic atau ancaman sejenis saat pertama kali dijalankan.

Mengapa ini terjadi?

Skrip ini menggunakan instruksi ExecutionPolicy Bypass pada file .bat agar Windows mengizinkan eksekusi skrip eksternal.

Skrip ini memanggil komponen sistem WScript.Shell untuk membuat file .lnk dan melakukan penghapusan file secara massal. Kombinasi perilaku ini sering dicurigai oleh sistem heuristik antivirus sebagai aktivitas malware.

Solusinya:
Skrip ini 100% aman dan transparan karena Anda dapat melihat langsung seluruh baris kodenya. Jika terblokir, Anda hanya perlu menambahkan file skrip ini atau folder tempat skrip dijalankan ke dalam daftar pengecualian (Exclusions / Trusted Zone) pada antivirus Anda.

## 📄 Lisensi
Proyek ini bersifat open-source. Anda bebas memodifikasi dan membagikannya kembali sesuai kebutuhan.

