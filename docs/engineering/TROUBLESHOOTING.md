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
