# StockFlow Technical Audit Remediation Report

Dokumen ini merupakan laporan pelacakan resmi proses perbaikan (*engineering remediation*) aplikasi StockFlow berdasarkan hasil audit teknis independen.

---

## 1. Metadata Audit & Remediasi

- **Proyek**: StockFlow (Inventory & Warehouse Management System)
- **Branch Git**: `fix/stockflow-audit-remediation`
- **Lead Remediation Engineers**: Principal Software Engineer, AppSec Engineer, Database Engineer, QA Engineer, DevOps Engineer
- **Status Remediasi**: In Progress (Milestone 0 Completed)
- **Baseline Test Suite**: 26 Tests (17 Backend, 9 Frontend) Passing

---

## 2. Matriks Temuan Audit & Status Remediasi

| Finding ID | Severity | Deskripsi Temuan | Komponen / File Utama | Status | Target Milestone |
|---|---|---|---|---|---|
| **P0-01** | Critical | Demo seeder dan hardcoded credentials dapat dijalankan di production | `backend/prisma/seed.ts`, `backend/src/scripts/bootstrap.ts`, `docs/DEPLOYMENT_GUIDE.md` | In Progress | Milestone 1 |
| **P0-02** | Critical | Insecure fallback secrets di docker-compose dan tidak ada fail-fast environment validation | `docker-compose.yml`, `backend/src/server.ts`, `.env.example` | In Progress | Milestone 1 |
| **P0-03** | Critical | Forced password change hanya ditegakkan di frontend, API endpoint terbuka | `backend/src/middleware/auth.ts`, `backend/src/app.ts` | In Progress | Milestone 1 |
| **P1-01** | High | 9 Database CHECK constraints dari acuan ERD hilang pada migrasi Prisma | `backend/prisma/migrations/`, `arahan/StockFlow_MySQL_Schema_v1.0.sql` | Pending | Milestone 2 |
| **P1-02** | High | Composite Foreign Keys relasi mutasi dan item hilang pada migrasi | `backend/prisma/schema.prisma`, `backend/prisma/migrations/` | Pending | Milestone 2 |
| **P1-03** | High | Validasi migrasi database clean install MySQL 8.4 dan upgrade safety | Database tier | Pending | Milestone 2 |
| **P1-04** | High | Produk dan gudang nonaktif masih dapat digunakan pada transaksi stok baru | `backend/src/modules/inventory/inventory.service.ts` | Pending | Milestone 2 |
| **P1-05** | Medium | Tidak ada validasi duplikasi produk pada array payload Stock In dan Stock Out | `backend/src/modules/inventory/inventory.service.ts` | Pending | Milestone 2 |
| **P1-06** | Medium | Dashboard movement chart menghitung baris movement bukan transaction headers | `backend/src/modules/dashboard/dashboard.service.ts` | Pending | Milestone 7 |
| **P1-07** | Medium | Sequence transaction reference number menggunakan UTC alih-alih timezone organisasi (Asia/Makassar) | `backend/src/utils/sequence.ts` | Pending | Milestone 7 |
| **P1-08** | Medium | Warehouse scope middleware memblokir akses histori staf pada gudang nonaktif | `backend/src/middleware/warehouse-scope.ts` | Pending | Milestone 2 |
| **P1-09** | High | Idempotency belum lengkap (request hash mismatch 409, atomic lock, reversal idempotency, frontend key) | `backend/src/modules/inventory/inventory.service.ts`, `frontend/src/lib/api.ts` | Pending | Milestone 3 |
| **P1-10** | High | Deadlock risk karena urutan lock produk tidak deterministik dan ketiadaan retry jitter | `backend/src/modules/inventory/inventory.service.ts` | Pending | Milestone 3 |
| **P1-11** | Medium | Origin validation dan CSRF allowlist pada browser state-changing requests | `backend/src/middleware/csrf.ts`, `backend/src/app.ts` | Pending | Milestone 4 |
| **P1-12** | Medium | Penyelarasan dokumentasi password hashing (bcrypt cost 12 vs Argon2id) | `docs/engineering/SECURITY_REVIEW.md`, `backend/src/modules/auth/auth.service.ts` | Pending | Milestone 4 |
| **P1-13** | High | Frontend Dockerfile merujuk folder public yang belum tersedia dan NEXT_PUBLIC_API_URL | `frontend/Dockerfile`, `docker-compose.yml`, `frontend/src/lib/api.ts` | Pending | Milestone 5 |
| **P1-14** | High | Health check readiness backend tidak memverifikasi koneksi database MySQL | `backend/src/app.ts` | Pending | Milestone 5 |
| **P1-15** | High | Testing suite belum memiliki actual MySQL integration test dan real Playwright E2E browser test | `backend/tests/`, `frontend/tests/`, Playwright config | Pending | Milestone 6 |

---

## 3. Log Rinci Perbaikan Temuan

*(Detail teknis perbaikan akan diisi secara bertahap seiring berjalannya setiap milestone)*
