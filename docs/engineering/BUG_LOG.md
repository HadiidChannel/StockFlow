# StockFlow Bug Management & Issue Tracking Log

Dokumen ini mencatat setiap bug atau kegagalan sistem yang ditemukan selama pengembangan, langkah reproduksi, akar penyebab (root cause), perbaikan, dan status regresi.

---

## Format Pencatatan Bug
- **ID**: `BUG-XXX`
- **Severity**: Critical / High / Medium / Low
- **Deskripsi**: Penjelasan ringkas masalah
- **Steps to Reproduce**: Langkah-langkah mereproduksi bug
- **Root Cause**: Analisis teknis penyebab mendasar masalah
- **Fix**: Solusi teknis yang diimplementasikan
- **Regression Test**: Test case otomatis yang dibuat untuk mencegah masalah berulang
- **Status**: Open / Investigating / Fixed & Verified

---

## Daftar Bug & Resolusi

### BUG-001: Prisma Shadow Database Permission Denial
- **Severity**: High
- **Deskripsi**: Perintah `prisma migrate dev` gagal saat mencoba membuat database sementara (`prisma_migrate_shadow_db_*`) dengan kode error P3014 / P1010.
- **Steps to Reproduce**: Menjalankan migrasi Prisma awal pada MySQL lokal dengan user database yang hanya memiliki akses scope `stockflow_db.*`.
- **Root Cause**: Prisma Migrate membutuhkan hak akses `CREATE DATABASE` dan `DROP DATABASE` di level global untuk membuat shadow database demi memverifikasi idempotensi file migrasi.
- **Fix**: Memberikan privilege `GRANT ALL PRIVILEGES ON *.* TO 'stockflow_user'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;` melalui user root.
- **Regression Test**: `npx prisma migrate dev` berhasil membuat dan menerapkan migrasi `init_schema`.
- **Status**: Fixed & Verified

### BUG-002: TypeScript Interface Mismatch pada Flattened Movement Ledger
- **Severity**: Medium
- **Deskripsi**: Build frontend Next.js sempat gagal karena properti `referenceNumber`, `productName`, `sku`, dan `warehouseName` tidak ditemukan pada tipe `StockMovement`.
- **Steps to Reproduce**: Menjalankan `next build` pada halaman `/movements`.
- **Root Cause**: API backend mengembalikan struktur pergerakan yang sudah di-flatten (dilebarkan) untuk performa rendering tabel, sedangkan interface `StockMovement` di frontend sebelumnya mengasumsikan relasi bertingkat (`item.transaction.referenceNumber`).
- **Fix**: Memperbarui interface `StockMovement` pada `frontend/src/types/index.ts` agar mencakup properti flattened yang dikirim backend.
- **Regression Test**: `npm run typecheck` dan `npm run build` frontend berhasil 100% tanpa error.
- **Status**: Fixed & Verified

### BUG-003: Chrome DevTools MCP Port Sync Desynchronization
- **Severity**: Medium
- **Deskripsi**: Subagent browser gagal tersambung ke Chrome DevTools MCP dengan error `Invalid DevToolsActivePort '9222\n' found`.
- **Steps to Reproduce**: Menjalankan subagent browser saat file `DevToolsActivePort` hanya memuat nomor port tanpa websocket path di baris kedua.
- **Root Cause**: Chrome DevTools MCP mensyaratkan tepat 2 baris: baris 1 nomor port (`9222`) dan baris 2 path websocket riil (`/devtools/browser/<guid>`).
- **Fix**: Mengimplementasikan script background daemon `scripts/chrome-daemon.js` yang menjaga Chrome tetap berjalan dan secara otomatis mengekstrak `pathname` dari endpoint `/json/version` ke dalam `DevToolsActivePort`.
- **Regression Test**: Subagent browser berhasil tersambung, melakukan navigasi, dan mengambil screenshot seluruh halaman.
- **Status**: Fixed & Verified
