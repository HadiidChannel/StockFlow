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
