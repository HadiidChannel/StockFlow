# StockFlow Testing Strategy & Quality Assurance Framework

## 1. Filosofi Testing
Testing di StockFlow diposisikan sebagai bagian integral dari siklus pengembangan (Continuous Quality Assurance), bukan pekerjaan tambahan di akhir. Fitur baru hanya dianggap selesai jika lulus pengujian otomatis dan terbukti perilakunya melalui bukti empiris.

## 2. Test Pyramid & Scope

```text
       / \
      /   \     E2E Tests (Playwright) - Alur Bisnis Kritis
     /-----\
    /       \   API & Integration Tests (Supertest, Vitest) - Controller, Service, DB
   /---------\
  /           \ Unit Tests (Vitest) - Math, Validation, Formatting, Sequence
 /-------------\
```

### A. Unit Testing
- **Tools**: Vitest
- **Fokus**:
  - Validasi schema Zod (input sanitization, parsing).
  - Generator nomor transaksi transaksional (`IN-YYYYMMDD-XXXXXX`).
  - Kalkulasi presisi desimal kuantitas stok.
  - Formatting angka dan tanggal.
  - Role permission helper logic.

### B. Integration Testing
- **Tools**: Vitest + Supertest
- **Fokus**:
  - Middleware autentikasi dan validasi cookie session.
  - Proteksi CSRF (double-submit verification).
  - Middleware otorisasi (RBAC & Warehouse Scoping).
  - Alur service database dengan Prisma (transaksi commit dan rollback).
  - Pencegahan race condition dan pengujian locking baris saldo.

### C. API Contract Testing
- **Fokus**:
  - Kesesuaian response body dengan `StockFlow_API_Contract_v1.0.md` dan `StockFlow_OpenAPI_v1.0.yaml`.
  - Struktur standard envelope: `{ data: ... }` untuk 2xx dan `{ error: { code, message, details, requestId } }` untuk 4xx/5xx.
  - Penanganan error kode HTTP standar (400, 401, 403, 404, 409, 422, 429, 500).

### D. Frontend Testing
- **Tools**: Vitest + React Testing Library
- **Fokus**:
  - Validasi form interaktif (Stock In, Stock Out, Form Produk).
  - Tampilan state visual: Loading skeleton, Empty state, Error banner, Success feedback.
  - Interaksi navigasi dan switching theme (Light, Dark, System).

### E. End-to-End Testing
- **Tools**: Playwright
- **Fokus Workflow Utama**:
  1. Bootstrap dan Login Admin.
  2. Setup Profil Organisasi dan Tambah Gudang Pertama.
  3. Tambah Kategori dan Tambah Produk.
  4. Lakukan Stock In awal (saldo bertambah).
  5. Buat akun Warehouse Staff dan assign gudang.
  6. Login sebagai Warehouse Staff (verifikasi pembatasan gudang).
  7. Lakukan Stock Out (saldo berkurang).
  8. Lakukan Stock Out melebihi saldo (verifikasi penolakan sistem).
  9. Periksa Dashboard dan Riwayat Stock Movement.

## 3. Strategi Pengujian Konkurensi
Untuk menguji keamanan mutasi stok terhadap race condition:
- Script pengujian mengirim 10 request Stock Out secara simultan dengan kuantitas yang jika diakumulasikan melebihi stok yang tersedia.
- Hasil yang diharapkan: Hanya request yang kuantitasnya mencukupi yang berhasil, sisanya ditolak dengan status 422 `INSUFFICIENT_STOCK`. Saldo akhir tidak pernah boleh bernilai negatif.
