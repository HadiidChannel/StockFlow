# StockFlow Technical Audit Remediation Report

Dokumen ini merupakan laporan pelacakan resmi proses perbaikan (engineering remediation) aplikasi StockFlow berdasarkan hasil audit teknis independen.

---

## 1. Metadata Audit & Remediasi

- **Proyek**: StockFlow (Inventory & Warehouse Management System)
- **Branch Git**: `fix/stockflow-audit-remediation`
- **Lead Remediation Engineers**: Principal Software Engineer, AppSec Engineer, Database Engineer, QA Engineer, DevOps Engineer
- **Status Remediasi**: COMPLETED & VERIFIED (Milestone 0 s.d. Milestone 8 Selesai)
- **Baseline Test Suite Awal**: 26 Tests (17 Backend, 9 Frontend) Passing
- **Remediated Test Suite Akhir**: 79 Tests (70 Backend across 10 Suites, 9 Frontend) Passing (100% Pass Rate)
- **Production Build Status**: Backend & Frontend Build Clean (Exit Code 0)
- **Database Engine**: MySQL 8.4 LTS dengan InnoDB Storage Engine

---

## 2. Matriks Temuan Audit & Status Remediasi

| Finding ID | Severity | Deskripsi Temuan | Komponen / File Utama | Status | Resolved In Commit |
|---|---|---|---|---|---|
| **P0-01** | Critical | Demo seeder dan hardcoded credentials dapat dijalankan di production | `backend/prisma/seed.ts`, `backend/src/scripts/bootstrap.ts`, `docs/DEPLOYMENT_GUIDE.md` | **Resolved** | `e18b540` |
| **P0-02** | Critical | Insecure fallback secrets di docker-compose dan tidak ada fail-fast environment validation | `docker-compose.yml`, `backend/src/config/env.ts`, `.env.example` | **Resolved** | `e18b540` |
| **P0-03** | Critical | Forced password change hanya ditegakkan di frontend, API endpoint terbuka | `backend/src/middleware/auth.ts`, `backend/src/app.ts` | **Resolved** | `e18b540` |
| **P1-01** | High | 9 Database CHECK constraints dari acuan ERD hilang pada migrasi Prisma | `backend/prisma/migrations/20261121031500_add_check_constraints_and_composite_fks/` | **Resolved** | `2cc5634` |
| **P1-02** | High | Composite Foreign Keys relasi mutasi dan item hilang pada migrasi | `backend/prisma/migrations/20261121031500_add_check_constraints_and_composite_fks/` | **Resolved** | `2cc5634` |
| **P1-03** | High | Validasi migrasi database clean install MySQL 8.4 dan upgrade safety | Database migration tier | **Resolved** | `2cc5634` |
| **P1-04** | High | Produk dan gudang nonaktif masih dapat digunakan pada transaksi stok baru | `backend/src/modules/inventory/inventory.service.ts`, `products.service.ts`, `warehouses.service.ts` | **Resolved** | `2cc5634` |
| **P1-05** | Medium | Penyelarasan dokumentasi password hashing (bcrypt cost 12 vs Argon2id) | `docs/engineering/SECURITY_REVIEW.md`, `backend/src/modules/auth/auth.service.ts` | **Resolved** | `666727b` |
| **P1-06** | Medium | Origin validation dan CSRF allowlist pada browser state-changing requests | `backend/src/middleware/csrf.ts`, `backend/src/app.ts` | **Resolved** | `666727b` |
| **P1-07** | Medium | Tiered rate limiting untuk auth, password change, stock transactions, dan users | `backend/src/middleware/rate-limiter.ts`, `backend/src/app.ts` | **Resolved** | `666727b` |
| **P1-08** | Medium | Warehouse scope middleware memblokir akses histori staf pada gudang nonaktif | `backend/src/middleware/warehouse-scope.ts` | **Resolved** | `2cc5634` |
| **P1-09** | High | Idempotency belum lengkap (request hash mismatch 409, atomic lock, reversal idempotency, frontend key) | `backend/src/modules/inventory/inventory.service.ts`, `frontend/src/lib/api.ts` | **Resolved** | `2cc5634` |
| **P1-10** | High | Deadlock risk karena urutan lock produk tidak deterministik dan ketiadaan retry jitter | `backend/src/modules/inventory/inventory.service.ts` | **Resolved** | `2cc5634` |
| **P1-11** | High | Frontend Dockerfile merujuk folder public yang belum tersedia dan NEXT_PUBLIC_API_URL build arg | `frontend/Dockerfile`, `frontend/public/`, `docker-compose.yml` | **Resolved** | `f5e4051` |
| **P1-12** | High | Health check readiness backend tidak memverifikasi koneksi database MySQL | `backend/src/app.ts` | **Resolved** | `e18b540` |
| **P1-13** | High | Testing suite belum memiliki actual MySQL integration test dan penamaan fake E2E test | `backend/tests/integration-api-flows.test.ts`, `frontend/tests/workflow-logic.test.ts` | **Resolved** | `d47bbf8` |
| **P1-14** | Medium | Dashboard movement chart menghitung baris movement bukan distinct transaction headers | `backend/src/modules/dashboard/dashboard.service.ts`, `dashboard.controller.ts` | **Resolved** | `c427d48` |
| **P1-15** | Medium | Sequence transaction reference number menggunakan UTC alih-alih timezone organisasi (Asia/Makassar) | `backend/src/utils/sequence.ts`, `backend/src/modules/inventory/inventory.service.ts` | **Resolved** | `c427d48` |

---

## 3. Rincian Teknis Remediasi Tiap Milestone

### Milestone 1: P0 Security Remediation (Commit: `e18b540`)
1. **P0-01 (Production Seed & Bootstrap Security)**:
   - File `backend/prisma/seed.ts` ditambahkan pemeriksaan eksplisit `if (process.env.NODE_ENV === 'production')` yang serta-merta menghentikan eksekusi seeder demo di lingkungan produksi.
   - File `backend/src/scripts/bootstrap.ts` diperbarui untuk menolak kredensial default, memvalidasi kompleksitas password (minimal 12 karakter, huruf besar, huruf kecil, angka, dan simbol), mengeset flag `mustChangePassword = true`, serta mengimplementasikan one-time execution lock agar tidak dapat dipanggil berulang kali.
2. **P0-02 (Fail-Fast Environment Validation & Secure Docker Configuration)**:
   - Dibuat modul `backend/src/config/env.ts` menggunakan Zod schema dengan aturan ketat: pada mode `production`, secret default (`super-secret...`) dan DB password default (`stockflow_pass123`) ditolak saat startup aplikasi.
   - File `docker-compose.yml` diperbarui dengan menghilangkan seluruh fallback secret default yang tidak aman. Seluruh secret wajib di-supply melalui environment host (`${DB_ROOT_PASSWORD:?wajib diisi}`, dll.).
3. **P0-03 (Enforcement Forced Password Change di Backend)**:
   - Ditambahkan middleware `enforcePasswordChange` di `backend/src/middleware/auth.ts` yang memblokir semua request pengguna dengan status `mustChangePassword === true` menuju endpoint operasional bisnis dengan kode 403 `FORCED_PASSWORD_CHANGE_REQUIRED`.
   - Hanya rute `/auth/me`, `/auth/change-password`, dan `/auth/logout` yang dikecualikan.
   - Dipasang pada seluruh 9 operational routers di `backend/src/app.ts`.
4. **P1-14 (Real Database Readiness Healthcheck)**:
   - Endpoint `GET /api/v1/health` di `backend/src/app.ts` diperbarui dengan ping aktual ke database (`prisma.$queryRaw\`SELECT 1\``) dengan timeout race 1500ms. Jika database down atau unreachable, endpoint mengembalikan status HTTP 503 SERVICE_UNAVAILABLE (`DOWN`).

---

### Milestone 2: Database Integrity, CHECK Constraints, & Active Guards (Commit: `2cc5634`)
1. **P1-01 & P1-02 (Database CHECK Constraints & Composite FKs)**:
   - Dibuat migration SQL `20261121031500_add_check_constraints_and_composite_fks` yang menambahkan 9 CHECK constraints dan 2 Composite Foreign Keys pada engine MySQL InnoDB:
     * `chk_inv_bal_qty_non_negative`: `quantity >= 0` pada `inventory_balances`
     * `chk_prod_min_stock_non_negative`: `minimum_stock >= 0` pada `products`
     * `chk_prod_cost_price_non_negative`: `cost_price IS NULL OR cost_price >= 0` pada `products`
     * `chk_tx_items_qty_positive`: `quantity > 0` pada `stock_transaction_items`
     * `chk_tx_items_bal_before_non_negative`: `balance_before >= 0` pada `stock_transaction_items`
     * `chk_tx_items_bal_after_non_negative`: `balance_after >= 0` pada `stock_transaction_items`
     * `chk_movements_qty_positive`: `quantity > 0` pada `stock_movements`
     * `chk_movements_bal_before_non_negative`: `balance_before >= 0` pada `stock_movements`
     * `chk_movements_bal_after_non_negative`: `balance_after >= 0` pada `stock_movements`
     * `fk_movements_transaction_warehouse`: Composite FK memastikan warehouse mutasi identik dengan warehouse header transaksi.
     * `fk_movements_transaction_item_product`: Composite FK memastikan produk mutasi identik dengan produk item transaksi.
2. **P1-04 (Active Status Enforcement on Transactions)**:
   - Pada `processStockIn` dan `processStockOut`, ditambahkan validasi `warehouse.isActive` dan `product.isActive`. Transaksi mutasi dengan entitas nonaktif ditolak seketika dengan 400 `ValidationError`.
   - Pada `products.service.ts`, penonaktifan produk (`isActive: false`) dicegah jika produk masih memiliki saldo stok lebih besar dari 0 di gudang manapun.
   - Pada `warehouses.service.ts`, penonaktifan gudang (`isActive: false`) dicegah jika gudang masih memiliki saldo stok lebih besar dari 0.
3. **P1-08 (Warehouse Scope Read vs Write Differentiation)**:
   - Pada `backend/src/middleware/warehouse-scope.ts`, dipisahkan hak baca vs ubah: request `GET` mengizinkan akses ke seluruh gudang yang pernah ditugaskan (termasuk gudang nonaktif) untuk keperluan audit trail histori, sedangkan request mutatif (`POST`, `PUT`, `DELETE`) mewajibkan gudang berstatus `isActive: true`.
4. **P1-05 / P1-10 (Duplicate Product Lines Validation)**:
   - Ditambahkan fungsi `validateUniqueProductLines` pada payload `items` di transaksi Stock In dan Stock Out. Jika terdapat ID produk yang berulang dalam satu transaksi, ditolak dengan 400 `ValidationError`.

---

### Milestone 3: Idempotency & Concurrency Hardening (Commit: `2cc5634`)
1. **P1-09 (Full Idempotency Implementation)**:
   - Dibuat fungsi kanonikal rekursif `canonicalize` dan `computePayloadHash` dengan hashing SHA-256 pada seluruh nested object payload transaksi.
   - Jika suatu `Idempotency-Key` dikirimkan ulang dengan payload identik, sistem mengembalikan data response sebelumnya (replay) tanpa membuat baris baru di database.
   - Jika `Idempotency-Key` yang sama dikirimkan dengan payload berbeda, sistem melemparkan HTTP 409 Conflict (`IDEMPOTENCY_CONFLICT`).
   - Pencatatan tabel `idempotencyRecord` dilakukan secara atomik di dalam database transaction yang sama dengan header transaksi.
   - Pada `frontend/src/lib/api.ts`, disediakan helper `generateIdempotencyKey()` dan request interceptor otomatis untuk mutasi inventaris.
2. **P1-10 (Deterministic Multi-Item Lock Ordering & Deadlock Prevention)**:
   - Seluruh pemrosesan multi-item diurutkan secara deterministik berdasarkan `productId` secara alfabetis sebelum mengeksekusi baris `SELECT ... FOR UPDATE`.
   - Penghindaran deadlock diperkuat dengan wrapper `withDeadlockRetry` menggunakan algoritma exponential backoff dan jitter acak (3 kali percobaan ulang).

---

### Milestone 4: P1 Security Hardening (Commit: `666727b`)
1. **P1-05 (Dokumentasi Password Hashing Discrepancy)**:
   - Diselaraskan seluruh file dokumentasi (`docs/engineering/SECURITY_REVIEW.md`, `docs/learning/ARCHITECTURE_OVERVIEW.md`, `docs/learning/LEARNING_ROADMAP.md`, `docs/learning/TECHNOLOGY_GLOSSARY.md`) dan komentar kode di `backend/src/modules/auth/auth.service.ts`.
   - Dinyatakan secara akurat bahwa sistem menggunakan hashing bcrypt dengan work factor (cost) 12 (NIST SP 800-63B compliant). Klaim tidak akurat mengenai Argon2id telah dihapus.
2. **P1-06 (Strict Origin / Referer Validation)**:
   - Pada `backend/src/middleware/csrf.ts`, ditambahkan validasi ketat `validateOrigin`: setiap request browser mutatif (`POST`, `PUT`, `PATCH`, `DELETE`) wajib memiliki Origin atau Referer yang terdaftar dalam allowlist (`FRONTEND_URL`, `http://localhost:3000`). Request dengan origin tidak dikenal ditolak dengan 403 `ForbiddenError`.
3. **P1-07 (Tiered Rate Limiting)**:
   - Dibuat modul `backend/src/middleware/rate-limiter.ts` yang membagi proteksi rate limit menjadi tier khusus:
     * `loginLimiter`: 10 request per 15 menit per IP pada `/auth/login`
     * `passwordChangeLimiter`: 5 request per 15 menit pada `/auth/change-password`
     * `inventoryTransactionLimiter`: 120 request per menit pada mutasi stok
     * `userManagementLimiter`: 30 request per menit pada manajemen pengguna
     * `globalApiLimiter`: 1000 request per 15 menit untuk proteksi generic DoS di level aplikasi

---

### Milestone 5: Docker & Production Readiness (Commit: `f5e4051`)
1. **P1-11 (Frontend Dockerfile Public Directory & Build Args)**:
   - Dibuat direktori `frontend/public/` lengkap dengan file `robots.txt` dan `site.webmanifest` sehingga perintah `COPY --from=builder /app/public ./public` tidak gagal saat build image Docker.
   - Dideklarasikan `ARG NEXT_PUBLIC_API_URL` dan `ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL` pada stage builder `frontend/Dockerfile`.
   - Divalidasi sintaks dan service graph menggunakan `docker-compose config` dengan hasil bersih (exit code 0).

---

### Milestone 6: Real Testing & QA (Commit: `d47bbf8`)
1. **P1-13 (Koreksi Penamaan Test & Real Supertest Integration Suite)**:
   - File `frontend/tests/e2e-workflow.test.ts` di-rename menjadi `frontend/tests/workflow-logic.test.ts` dan deskripsinya diselaraskan sebagai unit test logika invariant bisnis agar tidak menyesatkan.
   - Dibuat test suite integrasi komprehensif `backend/tests/integration-api-flows.test.ts` (13 tests) yang menguji alur HTTP nyata menggunakan Supertest terhadap database MySQL nyata:
     * Penolakan login salah (401)
     * Keberhasilan login admin dan penerimaan cookie sesi `sf_session` serta `sf_csrf`
     * Akses profil `/auth/me` terautentikasi
     * Penolakan mutasi tanpa CSRF token (403)
     * Penolakan mutasi dengan CSRF token tidak cocok (403)
     * Pembuatan kategori, produk, dan gudang via API (201)
     * Mutasi Stock In dan verifikasi saldo (201)
     * Mutasi Stock Out dan verifikasi pengurangan saldo (201)
     * Penolakan Stock Out defisit saldo (422 INSUFFICIENT_STOCK)
     * Reversal transaksi dan perlindungan invariant saldo (422 INSUFFICIENT_STOCK)
     * Logout dan pencabutan sesi pengguna (200)

---

### Milestone 7: Business Corrections & Optimization (Commit: `c427d48` & `223b549`)
1. **P1-14 (Movement Chart Metrics Definition Discrepancy)**:
   - Pada `backend/src/modules/dashboard/dashboard.service.ts`, implementasi `getMovementChart` diperbaiki untuk menghitung distinct transaction headers (`stockTransaction` dengan status `POSTED`), bukan baris detail pergerakan item.
   - Ditambahkan dukungan filter berdasarkan `days` dan `warehouseId`.
2. **P1-15 (Sequence Reference Number Timezone)**:
   - Pada `backend/src/utils/sequence.ts`, dibuat helper `getLocalCalendarDate` yang memformat tanggal kalender berdasarkan timezone lokal organisasi (default `Asia/Makassar` atau `Asia/Jakarta`) menggunakan `Intl.DateTimeFormat`.
   - Mencegah pergeseran tanggal kalender transaksi saat transaksi terjadi di sekitar pergantian hari lokal dibandingkan UTC.

---

## 4. Metrik Hasil Pengujian & Quality Gate

### Ringkasan Eksekusi Test Suite (Status: 100% Pass)

```text
================================================================================
TEST SUITE RUNNER REPORT (STOCKFLOW REMEDIATION)
================================================================================
Backend Suites (Vitest against Local MySQL 8.4 via Supertest & Prisma):
  ✓ tests/app-error.test.ts (7 tests)
  ✓ tests/env-validation.test.ts (4 tests)
  ✓ tests/forced-password-change.test.ts (6 tests)
  ✓ tests/rbac.test.ts (2 tests)
  ✓ tests/validation.test.ts (5 tests)
  ✓ tests/security-hardening.test.ts (10 tests)
  ✓ tests/business-corrections.test.ts (5 tests)
  ✓ tests/inventory-integrity.test.ts (15 tests)
  ✓ tests/api-health.test.ts (3 tests)
  ✓ tests/integration-api-flows.test.ts (13 tests)

Total Backend Tests: 70 Passed | 0 Failed (10 Test Files)

Frontend Suites (Vitest Logic & Invariants):
  ✓ tests/workflow-logic.test.ts (5 tests)
  ✓ tests/utils.test.ts (4 tests)

Total Frontend Tests: 9 Passed | 0 Failed (2 Test Files)

TOTAL AGGREGATE TESTS: 79 PASSED | 0 FAILED (100% PASS RATE)
================================================================================
```

### Build & Typecheck Artifacts
- **Backend Typecheck (`tsc --noEmit`)**: Passed (0 errors).
- **Backend Build (`tsc`)**: Passed (`backend/dist/` generated successfully).
- **Frontend Typecheck (`tsc --noEmit`)**: Passed (0 errors).
- **Frontend Build (`next build`)**: Passed (17 static routes generated successfully).

---

## 5. Ringkasan Evaluasi Postur Keamanan & Rilis

1. **Zero High / Critical Findings**: Seluruh temuan kritis (P0) dan tingkat tinggi (P1) telah tuntas diselesaikan dengan bukti kode dan pengujian otomatis.
2. **Database Integrity**: Skema database dilindungi di tingkat engine storage MySQL dengan 9 CHECK constraints, 2 composite FKs, serta row-level locking deterministik.
3. **Data Immutability & Audit Trail**: Transaksi berstatus `POSTED` bersifat immutable. Setiap pembalikan transaksi dilakukan melalui mekanisme full reversal dengan snapshot saldo dan nama pelaku.
4. **Defense in Depth**: Autentikasi dilindungi bcrypt cost 12, rotasi sesi, validasi Origin browser, CSRF double-submit tokens, dan rate limiting bertingkat.
5. **Kesimpulan Release Gate**: Aplikasi StockFlow dinyatakan **LAYAK DAN SIAP UNTUK PRODUCTION RELEASE (PRODUCTION READY)**.
