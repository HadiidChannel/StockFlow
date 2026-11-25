# StockFlow Troubleshooting Guide

Dokumen ini memuat panduan identifikasi dan pemecahan masalah teknis yang sering ditemui selama pengembangan maupun operasional StockFlow.

---

## 1. Masalah Autentikasi dan Cookie

### Gejala: Browser tidak mengirimkan cookie session atau status selalu 401
- **Penyebab**:
  - Konfigurasi CORS `credentials: true` belum aktif di backend.
  - Nilai `SameSite` atau `Secure` tidak cocok dengan protokol (misal flag `Secure=true` digunakan di `http://localhost`).
  - Origin frontend tidak terdaftar dalam allowlist CORS backend.
- **Solusi**:
  - Di environment development lokal, pastikan `COOKIE_SECURE=false` jika tidak menggunakan HTTPS.
  - Pastikan backend CORS mengonfigurasi `origin: ['http://localhost:3000']` dan `credentials: true`.
  - Pastikan frontend Axios / Fetch menyertakan opsi `credentials: 'include'`.

---

## 2. Masalah Transaksi Inventaris

### Gejala: Error 422 INSUFFICIENT_STOCK padahal stok terlihat masih ada di UI
- **Penyebab**:
  - Terjadi mutasi lain yang mengurangi stok sesaat sebelum request diproses (race condition yang berhasil dicegah).
  - Tampilan frontend belum merefresh saldo terkini.
  - Pengguna memilih gudang yang berbeda dari gudang tempat stok berada.
- **Solusi**:
  - Periksa `inventory_balances` secara langsung di database untuk produk dan gudang terkait.
  - Frontend harus menangani error 422 dengan pesan ramah: "Stok tersedia telah berubah. Silakan refresh halaman dan coba kembali."

---

## 3. Masalah Koneksi Database dan Prisma

### Gejala: `PrismaClientInitializationError: Can't reach database server`
- **Penyebab**:
  - Container database MySQL belum siap menerima koneksi (MySQL sedang melakukan initial startup initialization).
  - Format string koneksi `DATABASE_URL` salah.
- **Solusi**:
  - Di Docker Compose, manfaatkan `healthcheck` pada service `db` dengan perintah `mysqladmin ping -h localhost`.
  - Pastikan service `backend` memiliki `depends_on` dengan kondisi `service_healthy`.
  - Periksa kredensial user, host, port, dan nama database di `.env`.

---

## 4. Masalah Eksekusi Script di PowerShell (Windows)

### Gejala: `File npm.ps1 cannot be loaded because running scripts is disabled`
- **Penyebab**:
  - Execution Policy Windows PowerShell membatasi eksekusi file `.ps1`.
- **Solusi**:
  - Gunakan `npm.cmd` dan `npx.cmd` secara eksplisit alih-alih `npm` dan `npx`.
  - Untuk menjalankan skrip inisialisasi lingkungan lokal, sertakan parameter bypass: `powershell -ExecutionPolicy Bypass -File scripts/init-local.ps1`.

---

## 5. Masalah Inisialisasi Administrator Bootstrap

### Gejala: `Bootstrap ditolak: Password pada secret file terdeteksi sebagai password default yang tidak aman`
- **Penyebab**:
  - File secret `.secrets/initial_admin_password.txt` memuat password contoh atau password umum yang masuk daftar blacklist (seperti `AdminStockFlow2026!`, `password`, atau `admin123456`).
- **Solusi**:
  - Hasilkan password awal yang aman dan ber-entropi tinggi secara otomatis menggunakan `scripts/init-local.ps1`.
  - Pastikan password memiliki panjang minimal 12 karakter dan memuat kombinasi huruf besar, huruf kecil, angka, dan simbol.

### Gejala: `Bootstrap ditolak: INITIAL_ADMIN_PASSWORD melalui environment variable tidak lagi diizinkan`
- **Penyebab**:
  - Mengirimkan password awal administrator melalui variabel lingkungan langsung pada perintah shell atau file konfigurasi.
- **Solusi**:
  - Gunakan mekanisme Docker Compose Secrets: pasang file secret ke path `/run/secrets/initial_admin_password` dan tentukan variabel `INITIAL_ADMIN_PASSWORD_FILE=/run/secrets/initial_admin_password`.
  - Jalankan service bootstrap menggunakan profile resmi: `docker compose --profile bootstrap run --rm bootstrap`.

---

## 6. Masalah Eksekusi Pengujian E2E Terisolasi (Port 3100)

### Gejala: `Port 3100 pada 127.0.0.1 sedang digunakan oleh proses lain`
- **Penyebab**:
  - Ada proses lain atau sisa kontainer pengujian E2E sebelumnya yang masih berjalan pada port 3100.
- **Solusi**:
  - Periksa koneksi aktif menggunakan `Get-NetTCPConnection -LocalPort 3100 -State Listen`.
  - Bersihkan sisa kontainer stack E2E menggunakan perintah:
    ```bash
    docker compose -p stockflow-e2e-<runId> -f docker-compose.e2e.yml down -v
    ```
  - Atau gunakan docker ps untuk mencari nama container yang mendengarkan pada port 3100:
    ```bash
    docker ps --filter "publish=3100"
    ```
  - Pastikan flag `-KeepStack` tidak diaktifkan jika pengujian dijalankan dalam mode otomatis.

### Gejala: Playwright menjalankan test unit backend alih-alih file spec E2E
- **Penyebab**:
  - Playwright dijalankan dari root direktori tanpa menentukan file konfigurasi eksplisit, sehingga Playwright memindai file `.test.ts` di seluruh proyek.
- **Solusi**:
  - Jalankan Playwright dengan argumen konfigurasi eksplisit:
    ```bash
    npx.cmd --prefix frontend playwright test -c frontend/playwright.config.ts
    ```
  - Atau gunakan skrip runner terintegrasi: `powershell -ExecutionPolicy Bypass -File scripts/run-e2e.ps1`.

---

## 7. Masalah Inisialisasi Lingkungan Lokal (scripts/init-local.ps1)

### Gejala: `Inisialisasi dibatalkan: File '.env' sudah ada`
- **Penyebab**:
  - Skrip mendeteksi file `.env` atau `.secrets/initial_admin_password.txt` yang sudah ada demi mencegah penimpaan kredensial secara tidak sengaja.
- **Solusi**:
  - Skrip ini sengaja bersifat fail-safe dan tidak menimpa konfigurasi yang sudah aktif.
  - Jika Anda benar-benar ingin menginisialisasi ulang dari awal, hapus file `.env` dan `.secrets/initial_admin_password.txt` secara manual terlebih dahulu sebelum menjalankan kembali skrip.

### Gejala: `Gagal menerapkan Windows ACL pada target path. Exit code: ...`
- **Penyebab**:
  - Sistem file host tidak mendukung Windows ACL (misalnya partisi FAT32 atau network share) atau user tidak memiliki hak modifikasi ACL.
- **Solusi**:
  - Pastikan folder proyek terletak pada drive partisi NTFS standar.
  - Jalankan terminal PowerShell dengan hak akses pengguna lokal yang memiliki wewenang penuh atas folder proyek.
  - Skrip secara otomatis melakukan rollback terhadap file sementara jika penetapan ACL gagal.

---

## 8. Masalah Pengujian Integrasi Bootstrap (scripts/run-bootstrap-test.ps1)

### Gejala: Port 3307 terdeteksi sedang digunakan
- **Penyebab**:
  - Sisa kontainer pengujian bootstrap sebelumnya belum dibersihkan atau ada aplikasi lain yang mendengarkan pada port 3307.
- **Solusi**:
  - Hentikan kontainer bootstrap test sisa dengan perintah:
    ```bash
    docker compose -f docker-compose.bootstrap-test.yml down -v
    ```
  - Periksa listener port menggunakan `Get-NetTCPConnection -LocalPort 3307 -State Listen` dan hentikan proses yang menempati port tersebut.

### Gejala: `BootstrapGuardError: Target database is an operational database`
- **Penyebab**:
  - `DATABASE_URL` yang disediakan mengarah ke database operasional (`stockflow_db`, `stockflow_dev_db`, `stockflow_prod`, atau `stockflow_e2e_db`).
- **Solusi**:
  - Fail-closed guard secara sengaja menolak mengeksekusi bootstrap terhadap database non-test.
  - Pastikan target database diawali dengan nama `stockflow_test_` atau `stockflow_bootstrap_` yang sesuai dengan `BOOTSTRAP_TEST_RUN_ID`.

---

## 9. Masalah Eksekusi E2E Offline dan Pemindaian Rahasia

### Gejala: Docker Compose mencoba build ulang image saat mesin offline
- **Penyebab**:
  - Layanan Compose E2E tidak menemukan tag image statis lokal sehingga Docker mencoba mengunduh dependensi dari internet (misalnya binary Prisma Alpine).
- **Solusi**:
  - Konfigurasi `docker-compose.e2e.yml` telah dilengkapi tag fallback `${E2E_*_IMAGE:-stockflow-e2e-test-*:latest}`.
  - Pastikan image pengujian telah di-build terlebih dahulu saat koneksi internet aktif dengan perintah:
    ```bash
    docker compose -f docker-compose.e2e.yml build
    ```

### Gejala: Scanner rahasia melaporkan temuan pada file baru
- **Penyebab**:
  - File baru memuat kata kunci seperti `password=`, `secret=`, atau flag CLI `-p` dengan nilai alfanumerik mentah.
- **Solusi**:
  - Gunakan placeholder aman seperti `dev_password_placeholder` atau variabel lingkungan yang disanitasi.
  - Jalankan pemindai mandiri untuk memverifikasi pola:
    ```bash
    powershell -ExecutionPolicy Bypass -File scripts/scan-secrets.ps1 -SelfTest
    ```

---

## 10. Masalah Izin Windows NTFS ACL dan Pembersihan Secret E2E

### Gejala: `UnauthorizedAccessException: Access to the path ... is denied` saat Rollback atau Penghapusan File
- **Penyebab**:
  - File rahasia diatur dengan izin `(R,W)` melalui `icacls.exe`. Pada sistem file Windows NTFS, izin Write tidak mencakup izin Delete `(D)`.
- **Solusi**:
  - Gunakan izin Modify `(M)` melalui `scripts/init-local.ps1` atau `scripts/run-e2e.ps1`.
  - Berikan izin Modify kepada pengguna pemilik sebelum penghapusan file:
    ```powershell
    icacls $filePath /grant:r "*${userSid}:(M)"
    Remove-Item -LiteralPath $filePath -Force
    ```

### Gejala: Temporary Secret E2E Tertinggal di Folder `.secrets/`
- **Penyebab**:
  - Versi sebelumnya membungkam kegagalan penghapusan secret dengan `-ErrorAction SilentlyContinue`.
- **Solusi**:
  - Gunakan skrip `scripts/run-e2e.ps1` v1.6.3+ yang menerapkan pembersihan fail-closed dengan verifikasi post-kondisi dan melempar error jika secret tidak terhapus.

---

## 11. Masalah Verifikasi Rilis dan Pemaketan Anti-Sirkular (v1.6.4)

### Gejala: `[GATE-04] FAIL - Git commit mismatch` atau `[GATE-05] FAIL - Dirty Git working tree`
- **Penyebab**:
  - Terjadi modifikasi atau penambahan commit pada file terlacak setelah manifest rilis dibuat, atau terdapat file tidak terabaikan `.gitignore` yang belum di-commit.
- **Solusi**:
  - Periksa `git status --porcelain --untracked-files=all`.
  - Pastikan seluruh perubahan kode sumber, skrip, dan dokumentasi terlacak telah di-commit bersih terlebih dahulu.
  - Jalankan ulang `scripts/package-release.ps1` sehingga manifest dan bukti Git diperbarui konsisten terhadap `HEAD` terbaru.

### Gejala: `[GATE-08] FAIL - Checksum manifest file(s) illegally embedded inside ZIP`
- **Penyebab**:
  - Berkas `StockFlow_Release_Checksums_*.txt` tersisa terlacak di Git index atau disalin ke direktori sumber.
- **Solusi**:
  - Hapus manifest lama dari Git tracking (`git rm`), pastikan pola `StockFlow_Release_Checksums_*.txt` terdaftar pada `.gitignore`, dan selalu bangun Source ZIP melalui `scripts/package-release.ps1` yang mengekspor dari `git archive HEAD`.

### Gejala: `[GATE-09] FAIL - Manifest claims '...' is 'Verified' but file is MISSING`
- **Penyebab**:
  - Daftar file pada `AUDIT_FILE_MANIFEST.md` tidak sinkron dengan isi aktual `StockFlow_Audit_Handover_v8_4.zip`.
- **Solusi**:
  - Gunakan `scripts/assemble-handover.ps1` untuk menyusun manifest secara otomatis langsung dari direktori staging aktual serta memvalidasi hash SHA-256 pasca-ekstraksi.

---

## 12. Portabilitas ZIP Lintas Platform & Fail-Closed Release Gates (v1.6.5)

### Gejala: `[GATE-14] FAIL - NOT VERIFIED - ENVIRONMENT BLOCKED: Info-ZIP unzip executable unavailable or blocked`
- **Penyebab**:
  - Utilitas Info-ZIP `unzip` tidak ditemukan pada `PATH` maupun instalasi Git for Windows (`C:\Program Files\Git\usr\bin\unzip.exe`), atau proses diblokir oleh kebijakan sandbox/ACL saat inisialisasi MSYS2 (`NtCreateDirectoryObject ... 0xC0000022`).
- **Solusi**:
  - Pasang Info-ZIP `unzip` atau jalankan PowerShell pada konteks host Windows standar di luar pembatasan ACL MSYS2 agar `unzip.exe` dapat mengeksekusi `-t` dan ekstraksi penuh. Jangan pernah meloloskan gerbang secara manual apabila salah satu alat ekstraksi terblokir.

### Gejala: `[GATE-14] FAIL - Backslash path separator (0x5C) in raw ZIP entry`
- **Penyebab**:
  - Arsip ZIP dibuat memakai `[System.IO.Compression.ZipFile]::CreateFromDirectory` pada .NET Framework Windows yang menyisipkan `\` ke header biner Central Directory meskipun beberapa alat baca di Windows menerjemahkannya secara otomatis menjadi `/`.
- **Solusi**:
  - Selalu gunakan fungsi `New-PortableZipArchive` dari `scripts/zip-utils.ps1` sehingga seluruh entry ditulis eksplisit via `ZipArchive::CreateEntry($entryName.Replace('\', '/'))`.

### Gejala: `[GATE-12] FAIL - git_status.txt ... missing required metadata` atau `[GATE-09] FAIL - Extra unlisted file(s)`
- **Penyebab**:
  - File `git_status.txt` berupa teks kosong/ringkas tanpa blok `PORCELAIN_OUTPUT_BEGIN`..`PORCELAIN_OUTPUT_END`, `Timestamp`, atau `Exit Code: 0`; atau ada file ekstra di dalam `StockFlow_Audit_Handover` yang belum terdaftar di tabel inventaris `AUDIT_FILE_MANIFEST.md`.
- **Solusi**:
  - Gunakan `scripts/capture-evidence.ps1` dan `scripts/assemble-handover.ps1` v1.6.5 lalu kemas ulang dari commit Git bersih melalui `scripts/package-release.ps1`.
