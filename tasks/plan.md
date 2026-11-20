# Implementation Plan: StockFlow Full-Stack Application

## Overview
StockFlow adalah sistem manajemen inventaris dan pergudangan (IWMS) level produksi dengan pemisahan frontend (Next.js App Router, TypeScript, Tailwind CSS, shadcn/ui), backend (Node.js, Express.js, TypeScript), dan database (MySQL 8.4 LTS dengan Prisma ORM). Rencana implementasi ini dirancang bertahap dalam vertical slices, memprioritaskan functional correctness, data integrity, security by design, testing komprehensif, dan pembelajaran fundamental.

## Architecture Decisions
- Monorepo Terstruktur: Menggunakan root repository dengan folder terpisah `frontend/`, `backend/`, `docs/`, dan `tasks/`. Menjaga pemisahan concern yang bersih namun memudahkan koordinasi satu codebase.
- Session-Based Authentication dengan Cookie HttpOnly: Menggunakan token acak opaque yang disimpan dalam cookie HttpOnly `sf_session`. Token mentah tidak disimpan di database (hanya hash SHA-256) untuk mencegah pencurian token saat database bocor.
- Double-Submit CSRF Protection: Menggunakan cookie `sf_csrf` dan header `X-CSRF-Token` pada setiap request mutasi data (POST, PUT, PATCH, DELETE) untuk mencegah Cross-Site Request Forgery.
- Isolasi Gudang Tingkat Service & Query: Warehouse Staff dibatasi hanya dapat mengakses data pada gudang yang ditugaskan secara eksplisit oleh Admin. Query database selalu menyertakan filter `warehouse_id IN (...)` untuk Warehouse Staff.
- Atomic Inventory Transactions dengan Row-Level Locking: Mutasi saldo inventaris pada Stock In dan Stock Out menggunakan transaksi database dengan `SELECT ... FOR UPDATE` untuk mencegah race condition dan saldo negatif saat transaksi konkuren.
- Audit Ledger Immutable (Stock Movements): Setiap mutasi stok menghasilkan record `stock_movements` yang mencatat saldo sebelum (`balance_before`), kuantitas, dan saldo sesudah (`balance_after`). Record ini tidak pernah diubah atau dihapus.
- Koreksi Transaksi Berupa Full Reversal: Sesuai spesifikasi FSD, transaksi yang salah tidak diedit di tempat, melainkan dibatalkan sepenuhnya melalui transaksi reversal yang mencatat movement penyeimbang.

## Task List

### Phase 0: Project Audit and Architecture Documentation
- [x] Task 0.1: Audit seluruh dokumen acuan (PRD, FSD, ERD, Schema SQL, API Contract, Design System, MotionSites Vertex).
- [ ] Task 0.2: Buat dokumen arsitektur dan engineering (`docs/engineering/`).
- [ ] Task 0.3: Buat dokumen pembelajaran fundamental (`docs/learning/`).

### Phase 1: Project Foundation and Environment Setup
- [ ] Task 1.1: Inisialisasi Backend Express.js dengan TypeScript, ESLint, dan arsitektur folder modular.
- [ ] Task 1.2: Konfigurasi Prisma ORM dan MySQL Schema sesuai baseline SQL v1.0.
- [ ] Task 1.3: Buat script database bootstrap dan database seed (`npm run db:bootstrap`, `npm run db:seed`).
- [ ] Task 1.4: Inisialisasi Frontend Next.js App Router dengan TypeScript, Tailwind CSS, shadcn/ui, dan token warna StockFlow.
- [ ] Task 1.5: Konfigurasi Docker dan Docker Compose (`docker-compose.yml`, `docker-compose.dev.yml`).

### Checkpoint 1: Foundation Verification
- [ ] Schema database termigrasi bersih di MySQL tanpa error.
- [ ] Script bootstrap berhasil membuat organisasi dan akun Admin pertama.
- [ ] Backend dan Frontend dapat dijalankan dan saling terhubung.

### Phase 2: Core Authentication, Organization, and User Management
- [ ] Task 2.1: Implementasi API Authentication (Login, Logout, Me, Change Password) dengan session cookie dan CSRF protection.
- [ ] Task 2.2: Implementasi Middleware Autentikasi dan Role-Based Access Control (Admin vs Warehouse Staff).
- [ ] Task 2.3: Implementasi API Organization Profile dan User Management (CRUD User, Deaktivasi, Reset Password).
- [ ] Task 2.4: Implementasi API Warehouse Assignment untuk Warehouse Staff.
- [ ] Task 2.5: Implementasi UI Halaman Login, Force Change Password, dan User Management di Frontend.

### Checkpoint 2: Auth and Identity Verification
- [ ] Login Admin dan Warehouse Staff berhasil dengan pemberian cookie aman.
- [ ] Protected route menolak akses tanpa session valid.
- [ ] Admin dapat menetapkan gudang ke Warehouse Staff.

### Phase 3: Master Data Management (Warehouses, Categories, Products)
- [ ] Task 3.1: Implementasi Backend API Category Management (CRUD, status aktif).
- [ ] Task 3.2: Implementasi Backend API Warehouse Management (CRUD, kode unik, aturan deaktivasi penugasan staff).
- [ ] Task 3.3: Implementasi Backend API Product Management (CRUD, SKU unik, satuan, minimum stock, harga pokok).
- [ ] Task 3.4: Implementasi UI Frontend untuk Halaman Gudang, Kategori, dan Produk dengan tabel interaktif, filter, dan modal.

### Checkpoint 3: Master Data Verification
- [ ] Master data gudang, kategori, dan produk tersimpan akurat dengan validasi Zod di backend.
- [ ] Soft-delete / deaktivasi berfungsi; pencegahan deaktivasi gudang yang menyebabkan staff kehilangan seluruh gudang aktif terverifikasi.

### Phase 4: Inventory Transactions and Concurrency Control
- [ ] Task 4.1: Implementasi Sequence Number Generator transaksional (`IN-YYYYMMDD-XXXXXX` dan `OUT-YYYYMMDD-XXXXXX`).
- [ ] Task 4.2: Implementasi API Stock In (Header, Items, Inventory Balance update, Stock Movement creation, Idempotency).
- [ ] Task 4.3: Implementasi API Stock Out (Pemeriksaan saldo sebelum mutasi, pencegahan saldo negatif, atomic rollback jika stok kurang).
- [ ] Task 4.4: Implementasi API Full Reversal untuk koreksi transaksi stok.
- [ ] Task 4.5: Implementasi Backend API Inventory Balance dan Stock Movement History dengan filter gudang dan produk.
- [ ] Task 4.6: Implementasi UI Frontend Formulir Stock In, Formulir Stock Out, dan Riwayat Mutasi Stok.

### Checkpoint 4: Transaction & Concurrency Verification
- [ ] Uji transaksi konkuren pada Stock Out tidak menghasilkan saldo negatif.
- [ ] Audit trail movement mencatat balance before dan balance after secara presisi.
- [ ] Full reversal berhasil mengembalikan saldo fisik dan mencatat movement reversal.

### Phase 5: Dashboard, Landing Page, and Operational Insights
- [ ] Task 5.1: Implementasi Backend API Dashboard (KPI ringkasan, Low Stock alerts, Recent movements, Movement chart aggregates).
- [ ] Task 5.2: Implementasi Frontend Dashboard Operasional (KPI cards, Recharts chart, Low stock badges, quick action drawer).
- [ ] Task 5.3: Implementasi Landing Page Kreatif dan Premium (inspirasi MotionSites Vertex: cinematic hero, high-contrast palette, CTA glow button).
- [ ] Task 5.4: Implementasi Dukungan Light Mode, Dark Mode, dan System Preference dengan transisi halus.

### Checkpoint 5: UI/UX & Integration Verification
- [ ] Dashboard menampilkan data metrik yang terisolasi sesuai scope pengguna.
- [ ] Desain responsif teruji pada mobile, tablet, dan desktop.
- [ ] Landing page tampil modern, berkarakter, dan selaras dengan design system.

### Phase 6: Comprehensive Testing and Bug Hardening
- [ ] Task 6.1: Menulis Unit & Integration Tests untuk Service dan Controller Backend (Target coverage alur kritis).
- [ ] Task 6.2: Menulis Frontend Tests untuk Form Validation dan UI State handling.
- [ ] Task 6.3: Menulis End-to-End Test (Playwright) untuk skenario lengkap lifecycle inventaris.
- [ ] Task 6.4: Audit Keamanan (OWASP Top 10, IDOR, SQL injection, Rate Limiting, Security Headers Helmet) dan catat di `SECURITY_REVIEW.md`.
- [ ] Task 6.5: Bug reproduction, root cause analysis, dan dokumentasi perbaikan di `BUG_LOG.md`.

### Phase 7: Final Production Packaging and Portfolio Readiness
- [ ] Task 7.1: Setup multi-stage production Dockerfile untuk Frontend dan Backend.
- [ ] Task 7.2: Verifikasi build production (`npm run build`) tanpa warning dan tanpa type errors.
- [ ] Task 7.3: Siapkan Seed Data Demo yang realistis dan kredensial uji siap pakai.
- [ ] Task 7.4: Buat README.md portofolio kelas profesional dengan arsitektur diagram, screenshot, panduan instalasi, dan panduan presentasi.

## Risks and Mitigations
| Risk | Impact | Mitigation Strategy |
|---|---|---|
| Race condition saat Stock Out bersamaan | High | Gunakan transaksi database InnoDB dengan row-level locking (`SELECT ... FOR UPDATE`) pada `inventory_balances`. |
| Kebocoran data lintas gudang untuk Staff | High | Terapkan middleware dan service-layer query scoping yang wajib memeriksa tabel `user_warehouse_assignments`. |
| Duplikasi transaksi akibat network retry | Medium | Implementasikan header `Idempotency-Key` dan tabel `idempotency_records` di backend. |
| Perbedaan timezone pelaporan data | Medium | Standarisasi penyimpanan semua timestamp dalam UTC (`DATETIME(3)`), konversi ke timezone organisasi saat agregasi dan display. |
| Kerusakan data akibat floating point math | High | Gunakan tipe data `DECIMAL(18,3)` di MySQL dan representasi string desimal di API / JavaScript layer. |
