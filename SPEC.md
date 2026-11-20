# Spec: StockFlow - Professional Inventory and Warehouse Management System

## Objective
StockFlow adalah aplikasi web B2B Inventory & Warehouse Management System (IWMS) level produksi yang dirancang untuk mengelola stok multi-gudang secara terpusat, akurat, dan dapat diaudit secara penuh. Sistem ini dibangun dengan arsitektur terpisah antara Frontend (Next.js App Router, TypeScript, Tailwind CSS, shadcn/ui, Motion), Backend (Node.js, Express.js, TypeScript), dan Database (MySQL 8.4 LTS dengan Prisma ORM), serta diorkestrasi menggunakan Docker Compose.

Tujuan utama produk:
1. Menyediakan pencatatan data master (Organisasi, Pengguna, Gudang, Kategori, Produk) yang terpusat.
2. Menyediakan pelacakan saldo inventaris secara realtime per kombinasi produk dan gudang.
3. Mencatat setiap mutasi stok (Stock In dan Stock Out) secara atomik dengan audit trail lengkap (nomor referensi unik, snapshot nama/SKU/unit/gudang/petugas, timestamp UTC, balance before, balance after).
4. Mencegah terjadinya saldo negatif dan inkonsistensi data melalui isolasi transaksi database yang ketat (pessimistic locking / conditional updates).
5. Menerapkan Role-Based Access Control (RBAC) dengan pembatasan gudang:
   - Admin: Akses penuh ke seluruh organisasi, konfigurasi, user management, dan seluruh gudang.
   - Warehouse Staff: Hanya dapat melihat saldo dan mencatat transaksi pada gudang aktif yang ditugaskan secara eksplisit oleh Admin.
6. Menyediakan mekanisme koreksi transaksi yang aman berupa reversal penuh (full reversal).
7. Menyediakan antarmuka dashboard operasional yang responsif dan informatif (KPI stok, alert stok menipis, grafik pergerakan barang, riwayat mutasi terbaru).

## Tech Stack
- Frontend: Next.js 15 (App Router), React 19, TypeScript, Tailwind CSS, shadcn/ui (Radix UI primitives), Lucide Icons, Motion for React, Recharts.
- Backend: Node.js 24, Express.js 4/5, TypeScript, Zod (schema validation), Argon2id (password hashing), Helmet, CORS, Cookie-parser, Express-rate-limit.
- Database: MySQL 8.4 LTS (InnoDB, utf8mb4, UTC Datetime).
- ORM: Prisma 6.
- Containerization & DevOps: Docker, Docker Compose, Multi-stage Dockerfiles.
- Testing: Vitest (unit & integration), Supertest (API integration), Playwright (End-to-End).

## Commands
- Root Dev (Docker): `docker compose -f docker-compose.dev.yml up --build`
- Root Dev (Local):
  - Backend: `cd backend && npm run dev`
  - Frontend: `cd frontend && npm run dev`
- Database:
  - Prisma Generate: `cd backend && npx prisma generate`
  - Prisma Migration: `cd backend && npx prisma migrate dev`
  - Prisma Seed: `cd backend && npm run db:seed`
  - Bootstrap Admin: `cd backend && npm run db:bootstrap`
- Build:
  - Backend: `cd backend && npm run build`
  - Frontend: `cd frontend && npm run build`
- Test:
  - Backend Unit/Integration: `cd backend && npm test`
  - Frontend Unit: `cd frontend && npm test`
  - E2E Tests: `npx playwright test`
- Lint & Typecheck:
  - Backend: `cd backend && npm run lint && npm run typecheck`
  - Frontend: `cd frontend && npm run lint && npm run typecheck`

## Project Structure
```text
StockFlow/
├── arahan/                      # Arsip dokumen spesifikasi awal
├── docker-compose.yml           # Docker Compose untuk Production
├── docker-compose.dev.yml       # Docker Compose untuk Development
├── .env.example                 # Root environment variables blueprint
├── SPEC.md                      # Spesifikasi acuan proyek
├── tasks/
│   ├── plan.md                  # Implementation plan detail
│   └── todo.md                  # Task breakdown & progress checklist
├── docs/
│   ├── engineering/             # Dokumentasi teknis & arsitektur
│   │   ├── ARCHITECTURE_DECISIONS.md
│   │   ├── SECURITY_REVIEW.md
│   │   ├── TESTING_STRATEGY.md
│   │   ├── TEST_RESULTS.md
│   │   ├── BUG_LOG.md
│   │   ├── DEPLOYMENT_GUIDE.md
│   │   ├── DATABASE_MAINTENANCE.md
│   │   └── TROUBLESHOOTING.md
│   └── learning/                # Catatan pembelajaran fundamental
│       ├── LEARNING_ROADMAP.md
│       ├── LEARNING_PROGRESS.md
│       ├── ARCHITECTURE_OVERVIEW.md
│       ├── TECHNOLOGY_GLOSSARY.md
│       └── guides/              # Panduan modul teknologi spesifik
├── backend/                     # Express.js REST API
│   ├── Dockerfile
│   ├── package.json
│   ├── tsconfig.json
│   ├── prisma/
│   │   ├── schema.prisma        # Prisma data model
│   │   ├── migrations/          # SQL migrations
│   │   └── seed.ts              # Database seeder
│   └── src/
│       ├── config/              # Environment & constants
│       ├── database/            # Prisma client instance & db helpers
│       ├── middleware/          # Auth, RBAC, CSRF, error, rate-limit
│       ├── modules/             # Domain modules (auth, users, products, etc.)
│       │   ├── auth/
│       │   ├── users/
│       │   ├── organization/
│       │   ├── categories/
│       │   ├── products/
│       │   ├── warehouses/
│       │   ├── inventory/
│       │   ├── movements/
│       │   └── dashboard/
│       ├── utils/               # Logger, crypto, math, sequence generator
│       ├── scripts/             # Bootstrap CLI script
│       ├── app.ts               # Express application setup
│       └── server.ts            # HTTP server entrypoint
└── frontend/                    # Next.js App Router Application
    ├── Dockerfile
    ├── package.json
    ├── tsconfig.json
    ├── next.config.ts
    ├── tailwind.config.ts
    └── src/
        ├── app/                 # Next.js routes
        │   ├── (marketing)/     # Landing page (Creative Premium / Vertex-inspired)
        │   ├── (auth)/          # Login & force change password
        │   └── (dashboard)/     # Operational workspace
        ├── components/          # Reusable UI & shadcn components
        ├── hooks/               # Custom React hooks
        ├── lib/                 # API client, formatting, utils
        └── types/               # TypeScript domain contracts
```

## Code Style
- TypeScript: Strict mode (`"strict": true`, no implicit any, exact optional property types).
- Naming:
  - PascalCase untuk React Components, TypeScript Interfaces, dan Classes.
  - camelCase untuk function, variables, methods, dan properti API JSON.
  - snake_case untuk tabel database MySQL dan kolom database.
  - UPPER_SNAKE_CASE untuk konstanta dan enum values.
  - kebab-case untuk nama file komponen dan route directories.
- Karakter Formatting: DILARANG menggunakan karakter en dash atau em dash. Hanya gunakan hyphen (-), comma (,), colon (:), atau period (.).
- Error Handling:
  - Backend: Centralized AppError class dengan status code dan machine-readable error code.
  - Response contract standar: `{ data: ... }` untuk sukses, `{ error: { code, message, details, requestId } }` untuk gagal.
  - Stack trace dan query SQL tidak boleh bocor ke client.
- Database Concurrency:
  - Mutasi stok wajib menggunakan `SELECT ... FOR UPDATE` dalam transaksi database untuk menjamin serializability dan mencegah race condition / saldo negatif.

## Testing Strategy
- Unit Testing: Menguji perhitungan saldo stok, helper validasi, pembuat nomor referensi, sanitasi input, dan utility formatting desimal.
- Integration Testing: Menguji controller, middleware (autentikasi session cookie, validasi CSRF, proteksi RBAC, pengecekan gudang assignment), integrasi Prisma dengan database transaksi rollback.
- API Testing: Pengujian menyeluruh seluruh endpoint REST API terhadap API Contract dan OpenAPI spec v1.0.
- Frontend Testing: Testing rendering komponen, penanganan form, transisi state (loading, error, empty, permission denied).
- End-to-End Testing (Playwright): Menguji skenario workflow pengguna secara penuh: Bootstrap -> Login Admin -> Setup Profil & Gudang -> Kategori & Produk -> Stock In -> Buat Akun Staff & Assign Gudang -> Login Staff -> Stock Out -> Verifikasi Saldo & Audit Ledger.

## Boundaries
- Always:
  - Validasi seluruh input di backend dengan Zod sebelum diproses ke database.
  - Gunakan transaksi database untuk operasi yang melibatkan pembaruan saldo dan pencatatan movement.
  - Simpan timestamp dalam UTC dan kuantitas dalam tipe DECIMAL presisi tinggi (3 digit di belakang koma).
  - Terapkan scope gudang pada setiap query yang diakses oleh Warehouse Staff.
  - Buat regression test untuk setiap bug yang ditemukan dan diperbaiki.
- Ask First:
  - Perubahan model data database di luar ERD v1.0.
  - Penambahan dependensi pihak ketiga baru yang signifikan.
  - Modifikasi endpoint API yang mengubah kontrak publik API v1.0.
- Never:
  - Menyimpan password dalam bentuk plaintext (wajib hashing Argon2id).
  - Menyimpan token sesi mentah di database atau mengembalikan token sesi pada JSON response body.
  - Mengizinkan mutasi stok menghasilkan saldo negatif.
  - Melakukan hard delete terhadap data yang telah memiliki riwayat transaksi atau movement.
  - Memotong tahapan testing atau menurunkan batas validasi untuk mengejar kecepatan rilis.
  - Menggunakan karakter en dash atau em dash dalam kode, komentar, dokumen, UI, atau pesan sistem.

## Success Criteria
1. Seluruh 14 tabel database terimplementasi dengan schema Prisma dan constraint SQL InnoDB yang valid.
2. Endpoint REST API `/api/v1` berfungsi 100% sesuai spesifikasi OpenAPI v1.0.
3. Fitur autentikasi session cookie, rotasi CSRF token, dan RBAC berfungsi dengan keamanan teruji.
4. Alur operasional Stock In, Stock Out, dan Full Reversal berjalan atomik dan tahan terhadap concurrent requests.
5. Halaman UI/UX (Landing page, Login, Dashboard, Inventaris, Gudang, Produk, User Management) responsif di desktop, tablet, dan smartphone dengan dukungan Light & Dark mode.
6. Test suites (Unit, Integration, E2E) berjalan dan lulus hijau.
7. Dokumentasi arsitektur, bug log, security review, dan materi pembelajaran tersedia lengkap.
