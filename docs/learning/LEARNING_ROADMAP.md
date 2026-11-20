# StockFlow Fundamental Learning Roadmap

Dokumen ini memetakan materi dan konsep fundamental rekayasa perangkat lunak yang dipelajari secara kontekstual selama pembangunan aplikasi StockFlow. Pembelajaran dilakukan berdampingan dengan implementasi nyata tanpa mengorbankan delivery produk.

---

## 1. Peta Jalan Pembelajaran Berdasarkan Komponen

```text
                  [ StockFlow Learning Roadmap ]
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
 [ Frontend Tier ]       [ Backend Tier ]       [ Database & DevOps ]
   • JS & TS Core          • Node.js Event Loop    • Relational Modeling
   • React Architecture    • Express Middleware    • ACID Transactions
   • Next.js App Router    • REST API Contracts    • Pessimistic Locking
   • Tailwind & UI/UX      • Auth & Session Mgmt   • Prisma ORM
   • Motion & State        • Security Hardening    • Docker Containerization
```

---

## 2. Rincian Modul Pembelajaran

### Modul 1: TypeScript & JavaScript Modern di Skala Enterprise
- **Konsep**: Static typing, interface vs type, generics, strict null checks, utility types (`Partial`, `Pick`, `Omit`), immutability.
- **Penerapan di StockFlow**: Membangun kontrak tipe data domain yang konsisten antara DTO backend dan tipe props frontend.

### Modul 2: Arsitektur Backend dengan Node.js & Express.js
- **Konsep**: Asynchronous I/O, Event Loop, HTTP request-response cycle, middleware chain, error handling pipeline, dependency injection sederhana.
- **Penerapan di StockFlow**: Pemisahan layer router, controller, service, dan data access untuk seluruh modul bisnis inventaris.

### Modul 3: Database Relasional, ACID, & Concurrency (MySQL 8.4)
- **Konsep**: Desain skema normalisasi (3NF), Primary Key vs Foreign Key, indeks komposit, integritas referensial, transaksi ACID, tingkat isolasi, dan locking baris (`SELECT ... FOR UPDATE`).
- **Penerapan di StockFlow**: Pencegahan saldo negatif dan race condition pada transaksi Stock Out simultan.

### Modul 4: Object-Relational Mapping (ORM) dengan Prisma
- **Konsep**: Data modeling declarative, automated migrations, type-safe queries, transaction rollback, composite keys, pagination offset/cursor.
- **Penerapan di StockFlow**: Eksekusi mutasi saldo inventaris dan pencatatan ledger pergerakan stok dalam `$transaction`.

### Modul 5: Keamanan Aplikasi Web Modern (Security by Design)
- **Konsep**: Hashing password adaptif (Argon2id), session management dengan opaque token, proteksi XSS dengan context escaping dan HttpOnly cookies, mitigasi CSRF dengan Double-Submit Cookie pattern, proteksi Brute-Force dengan Rate Limiting.
- **Penerapan di StockFlow**: Membangun sistem autentikasi dan otorisasi RBAC anti-bocor untuk staf gudang dan admin.

### Modul 6: Frontend Engineering dengan Next.js App Router & React 19
- **Konsep**: Server Components vs Client Components, streaming SSR, layout inheritance, form handling dengan server/client validation, state management, custom hooks.
- **Penerapan di StockFlow**: Membangun dashboard operasional yang responsif dan landing page bertaraf premium.

### Modul 7: Kontainerisasi & Lingkungan Pengembangan dengan Docker
- **Konsep**: Container vs Virtual Machine, layer caching Dockerfile, multi-stage builds, orkestrasi multi-service dengan Docker Compose, persistent volumes, dan internal networking.
- **Penerapan di StockFlow**: Menjalankan frontend, backend, dan database dalam satu orkestrasi yang konsisten di semua mesin developer.
