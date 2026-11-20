# StockFlow Task List and Execution Checklist

## Phase 0: Project Audit and Architecture Documentation
- [x] Task 0.1: Audit seluruh dokumen acuan
  - Acceptance: Seluruh dokumen PRD, FSD, ERD, SQL Schema, API Contract, dan Design System dipelajari dan dipetakan ke dalam SPEC.md.
  - Verify: File SPEC.md dan tasks/plan.md tersedia dan valid.
  - Files: `SPEC.md`, `tasks/plan.md`, `tasks/todo.md`
- [x] Task 0.2: Buat dokumen arsitektur dan engineering
  - Acceptance: Tersedia ARCHITECTURE_DECISIONS.md, SECURITY_REVIEW.md, TESTING_STRATEGY.md, TEST_RESULTS.md, BUG_LOG.md, DEPLOYMENT_GUIDE.md, DATABASE_MAINTENANCE.md, TROUBLESHOOTING.md.
  - Verify: File-file di docs/engineering/ lengkap dan terstruktur.
  - Files: `docs/engineering/*.md`
- [x] Task 0.3: Buat dokumen pembelajaran fundamental
  - Acceptance: Tersedia LEARNING_ROADMAP.md, LEARNING_PROGRESS.md, ARCHITECTURE_OVERVIEW.md, TECHNOLOGY_GLOSSARY.md, serta modul panduan teknologi 01 hingga 09.
  - Verify: File-file di docs/learning/ lengkap dengan penjelasan kontekstual.
  - Files: `docs/learning/*.md`, `docs/learning/guides/*.md`

## Phase 1: Project Foundation and Environment Setup
- [x] Task 1.1: Setup Backend Express.js dengan TypeScript
  - Acceptance: Backend memiliki package.json, tsconfig.json, script dev/build, dan arsitektur modular yang rapi.
  - Verify: `cd backend && npm run build` berhasil tanpa error.
  - Files: `backend/package.json`, `backend/tsconfig.json`, `backend/src/*`
- [x] Task 1.2: Konfigurasi Prisma ORM dan MySQL Schema
  - Acceptance: Schema Prisma memetakan ke-14 tabel dari ERD v1.0 dengan tipe data, relasi, dan nama kolom snake_case yang tepat.
  - Verify: `npx prisma validate` berhasil dan `prisma-client-js` ter-generate.
  - Files: `backend/prisma/schema.prisma`
- [x] Task 1.3: Script Database Bootstrap dan Seed
  - Acceptance: Script bootstrap dapat membuat organisasi dan akun Admin pertama secara transaksional dengan password hashing Argon2id. Seed data awal membuat role default dan demo dataset.
  - Verify: Script bootstrap dan seed dapat dijalankan tanpa error sintaksis.
  - Files: `backend/src/scripts/bootstrap.ts`, `backend/prisma/seed.ts`
- [x] Task 1.4: Setup Frontend Next.js App Router dengan TypeScript dan Tailwind CSS
  - Acceptance: Frontend terkonfigurasi dengan Next.js App Router, Tailwind CSS, design tokens StockFlow, dan utility helper.
  - Verify: `cd frontend && npm run build` berhasil menghasilkan 17 halaman statis.
  - Files: `frontend/package.json`, `frontend/tsconfig.json`, `frontend/tailwind.config.ts`, `frontend/src/*`
- [x] Task 1.5: Konfigurasi Docker dan Docker Compose
  - Acceptance: Tersedia Dockerfile untuk backend dan frontend, serta docker-compose.yml dan docker-compose.dev.yml yang menyertakan service db (MySQL 8.4), backend, dan frontend dengan persistent volume dan healthcheck.
  - Verify: Konfigurasi compose tervalidasi secara sintaksis.
  - Files: `docker-compose.yml`, `docker-compose.dev.yml`, `backend/Dockerfile`, `frontend/Dockerfile`

## Checkpoint 1: Foundation Complete
- [x] Backend terkompilasi bersih tanpa type error.
- [x] Frontend terkompilasi bersih dan siap produksi.
- [x] Schema database, seeder demo, dan script bootstrap siap pakai.

## Phase 2: Core Authentication, Organization, and User Management
- [x] Task 2.1: Implementasi API Authentication (Login, Logout, Me, Change Password)
  - Acceptance: Endpoint `/api/v1/auth/login`, `/api/v1/auth/logout`, `/api/v1/auth/me`, `/api/v1/auth/change-password` berfungsi dengan session cookie HttpOnly dan rotasi CSRF token.
  - Verify: Unit test API Auth berhasil mengembalikan cookie dan status 200.
  - Files: `backend/src/modules/auth/*`, `backend/src/middleware/auth.ts`
- [x] Task 2.2: Implementasi Role-Based Access Control dan Scope Gudang Middleware
  - Acceptance: Middleware memvalidasi peran Admin vs Warehouse Staff, serta menyaring akses gudang sesuai penugasan aktif.
  - Verify: Test autorisasi menolak Warehouse Staff mengakses endpoint Admin dengan status 403.
  - Files: `backend/src/middleware/rbac.ts`, `backend/src/middleware/warehouse-scope.ts`
- [x] Task 2.3: Implementasi API Organization Profile dan User Management
  - Acceptance: Admin dapat melihat dan memperbarui profil organisasi, serta melakukan CRUD user dan deaktivasi akun.
  - Verify: Service dan route untuk `/api/v1/organization` dan `/api/v1/users` terimplementasi.
  - Files: `backend/src/modules/organization/*`, `backend/src/modules/users/*`
- [x] Task 2.4: Implementasi API Warehouse Assignment
  - Acceptance: Admin dapat menetapkan satu atau beberapa gudang aktif kepada Warehouse Staff dengan validasi minimal satu gudang aktif.
  - Verify: Method `assignWarehouses` pada users service tervalidasi.
  - Files: `backend/src/modules/users/users.service.ts`
- [x] Task 2.5: Implementasi Frontend Auth dan User Management Pages
  - Acceptance: Halaman login, force change password, daftar user, dan dialog penugasan gudang terintegrasi ke backend dengan feedback UI lengkap.
  - Verify: Komponen render dengan benar, validasi form berjalan.
  - Files: `frontend/src/app/(auth)/*`, `frontend/src/app/(dashboard)/users/*`

## Checkpoint 2: Auth and Users Complete
- [x] Login flow berfungsi penuh dengan session cookie.
- [x] User management dan warehouse assignment berfungsi.

## Phase 3: Master Data Management (Warehouses, Categories, Products)
- [x] Task 3.1: API Category Management
  - Acceptance: CRUD kategori dengan validasi keunikan nama per organisasi dan pencegahan hapus permanen jika sudah dipakai produk.
  - Verify: API router `/api/v1/categories` terpasang.
  - Files: `backend/src/modules/categories/*`
- [x] Task 3.2: API Warehouse Management
  - Acceptance: CRUD gudang dengan kode unik, aturan deaktivasi yang melindungi penugasan staff aktif.
  - Verify: API router `/api/v1/warehouses` terpasang dengan proteksi deaktivasi.
  - Files: `backend/src/modules/warehouses/*`
- [x] Task 3.3: API Product Management
  - Acceptance: CRUD produk dengan SKU unik, satuan dasar, minimum stock, harga pokok opsional, dan pencarian/filter.
  - Verify: API router `/api/v1/products` terpasang.
  - Files: `backend/src/modules/products/*`
- [x] Task 3.4: Frontend Pages untuk Master Data
  - Acceptance: UI untuk Gudang, Kategori, dan Produk dengan tabel interaktif, modal form, filter, search, pagination, dan indikator status.
  - Verify: Halaman ter-render dengan baik dan responsif.
  - Files: `frontend/src/app/(dashboard)/warehouses/*`, `frontend/src/app/(dashboard)/categories/*`, `frontend/src/app/(dashboard)/products/*`

## Checkpoint 3: Master Data Complete
- [x] Master data gudang, kategori, dan produk selesai di backend dan frontend.

## Phase 4: Inventory Transactions and Concurrency Control
- [x] Task 4.1: Sequence Number Generator
  - Acceptance: Generator nomor transaksi `IN-YYYYMMDD-XXXXXX` dan `OUT-YYYYMMDD-XXXXXX` aman dari race condition menggunakan locking pada `stock_transaction_sequences`.
  - Verify: Unit test concurrency menghasilkan nomor urut yang unik tanpa lompatan atau tabrakan.
  - Files: `backend/src/utils/sequence.ts`
- [x] Task 4.2: API Stock In
  - Acceptance: Pencatatan barang masuk atomik yang memperbarui saldo inventaris dan mencatat snapshot produk di stock movements.
  - Verify: Endpoint `/api/v1/inventory/stock-in` terpasang dan saldo bertambah.
  - Files: `backend/src/modules/inventory/inventory.service.ts`, `backend/src/modules/inventory/inventory.controller.ts`
- [x] Task 4.3: API Stock Out dengan Concurrency Protection
  - Acceptance: Pencatatan barang keluar yang memvalidasi ketersediaan saldo dengan pessimistic row lock. Transaksi ditolak dengan status 422 jika stok kurang.
  - Verify: Concurrent test membuktikan tidak terjadi saldo negatif atau overselling.
  - Files: `backend/src/modules/inventory/inventory.service.ts`, `backend/src/modules/inventory/inventory.controller.ts`
- [x] Task 4.4: API Full Reversal Transaksi
  - Acceptance: Membatalkan transaksi stok yang sudah diposting dengan membuat transaksi pembalik dan movement penyeimbang.
  - Verify: Service reversal mengembalikan saldo ke kondisi awal.
  - Files: `backend/src/modules/inventory/inventory.service.ts`
- [x] Task 4.5: API Inventory Balances dan Stock Movement History
  - Acceptance: Endpoint `/api/v1/inventory/balances` dan `/api/v1/movements` menyajikan data saldo dan audit trail dengan filter gudang sesuai hak akses.
  - Verify: Filter per gudang dan ledger mutasi terimplementasi.
  - Files: `backend/src/modules/inventory/inventory.service.ts`, `backend/src/modules/movements/*`
- [x] Task 4.6: Frontend Formulir Transaksi dan Riwayat Mutasi
  - Acceptance: UI formulir Stock In, formulir Stock Out dengan validasi saldo realtime, dan halaman riwayat mutasi stok.
  - Verify: Interaksi form lancar, feedback error stok tidak cukup tampil jelas.
  - Files: `frontend/src/app/(dashboard)/inventory/*`, `frontend/src/app/(dashboard)/movements/*`

## Checkpoint 4: Inventory Core Complete
- [x] Stock In, Stock Out, dan Reversal teruji atomik dan aman dari konkurensi.
- [x] UI inventaris dan mutasi terintegrasi.

## Phase 5: Dashboard, Landing Page, and Operational Insights
- [x] Task 5.1: Backend API Dashboard
  - Acceptance: Endpoint `/api/v1/dashboard/summary`, `/api/v1/dashboard/movement-chart`, `/api/v1/dashboard/recent-movements`, dan `/api/v1/dashboard/alerts` mengembalikan metrik yang akurat sesuai scope pengguna.
  - Verify: Endpoint mengembalikan struktur JSON yang tepat.
  - Files: `backend/src/modules/dashboard/*`
- [x] Task 5.2: Frontend Dashboard Operasional
  - Acceptance: Tampilan KPI cards, grafik Recharts, alert stok menipis, dan recent movements terintegrasi dengan data backend.
  - Verify: Dashboard responsif di mobile, tablet, dan desktop.
  - Files: `frontend/src/app/(dashboard)/dashboard/*`
- [x] Task 5.3: Landing Page Kreatif dan Premium
  - Acceptance: Landing page berkarakter Vertex (dark theme hero, refined lighting, clean typography, glow CTA, product feature showcases).
  - Verify: Tampilan visual estetis, responsif, dan performa tinggi.
  - Files: `frontend/src/app/(marketing)/*`
- [x] Task 5.4: Theme Management (Light, Dark, System)
  - Acceptance: User dapat beralih tema Light, Dark, dan System dengan preferensi tersimpan di user profile dan localStorage.
  - Verify: Komponen merespons perubahan tema tanpa visual glitch.
  - Files: `frontend/src/components/theme-provider.tsx`, `frontend/src/components/theme-toggle.tsx`

## Checkpoint 5: Visual and Operational Complete
- [x] Seluruh halaman aplikasi fungsional dan estetis.
- [x] Theme switching bekerja di seluruh komponen.

## Phase 6: Comprehensive Testing and Bug Hardening
- [x] Task 6.1: Backend Unit and Integration Test Suite
  - Acceptance: Test suite mencakup auth, RBAC, master data validation, dan error handling.
  - Verify: `cd backend && npm test` lulus 100% (17 tests passed).
  - Files: `backend/tests/*`
- [x] Task 6.2: Frontend Unit and Component Tests
  - Acceptance: Pengujian helper formatters, calculations, dan UI states.
  - Verify: `cd frontend && npm test` lulus (9 tests passed).
  - Files: `frontend/tests/*`
- [x] Task 6.3: E2E Business Workflow Logic Test Suite
  - Acceptance: Test suite memverifikasi skenario bisnis lengkap dari autentikasi hingga mutasi saldo dan reversal.
  - Verify: `npm test` sukses pada frontend.
  - Files: `frontend/tests/e2e-workflow.test.ts`
- [x] Task 6.4: Security Hardening Review
  - Acceptance: Pemeriksaan OWASP Top 10, sanitasi input, rate limiting, validasi CSRF, dan pencatatan temuan di `SECURITY_REVIEW.md`.
  - Verify: Audit keamanan terdokumentasi tanpa celah kritis yang terbuka.
  - Files: `docs/engineering/SECURITY_REVIEW.md`
- [x] Task 6.5: Bug Management dan Regression Log
  - Acceptance: Seluruh format penelusuran bug tercatat di `BUG_LOG.md`.
  - Verify: Status verifikasi tercatat jelas.
  - Files: `docs/engineering/BUG_LOG.md`

## Phase 7: Final Production Packaging and Portfolio Readiness
- [x] Task 7.1: Multi-stage Dockerfile dan Compose Production
  - Acceptance: Dockerfile frontend dan backend menggunakan multi-stage build yang memisahkan dev dependencies.
  - Verify: Docker build configuration tersedia dan aman dengan non-root user.
  - Files: `backend/Dockerfile`, `frontend/Dockerfile`, `docker-compose.yml`, `docker-compose.dev.yml`
- [x] Task 7.2: Production Build Verification
  - Acceptance: Frontend dan backend berhasil dibuild untuk production tanpa error atau warning kritis.
  - Verify: `npm run build` sukses pada frontend (17 static routes) dan backend.
- [x] Task 7.3: Seed Data Demo dan Akun Presentasi
  - Acceptance: Data demo realistis tersedia (organisasi, gudang, aneka kategori dan produk, riwayat transaksi, serta akun demo Admin dan Staff).
  - Verify: Demo data dapat dimuat ulang dengan mudah melalui seeder.
  - Files: `backend/prisma/seed.ts`
- [x] Task 7.4: Dokumentasi Portofolio Kelas Profesional
  - Acceptance: README.md utama yang memuat problem statement, arsitektur sistem, ERD, screenshot visual, panduan setup lokal dan Docker, panduan testing, serta highlight teknis untuk portofolio.
  - Verify: Dokumentasi lengkap dan siap dipresentasikan kepada hiring manager atau klien.
  - Files: `README.md`

## Checkpoint 7: Product Complete and Verified
- [x] MySQL database migration diaplikasikan dan demo dataset tersemai dengan transaksi riil.
- [x] Backend Express dan Frontend Next.js aktif dan terintegrasi di port 4000 dan 3000.
- [x] 26 Automated test suite lulus 100% (17 backend, 9 frontend).
- [x] Browser visual walkthrough diverifikasi dan direkam (Landing Page, Login, Dashboard, Inventory, Movements).
- [x] Media screenshot dan video rekaman tersimpan di `docs/assets/screenshots/` dan `docs/assets/walkthrough-recording.mp4`.
- [x] Seluruh kriteria PRD dan FSD MVP terpenuhi secara menyeluruh.
