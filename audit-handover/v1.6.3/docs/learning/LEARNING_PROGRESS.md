# StockFlow Learning Progress Tracker

Dokumen ini memantau perkembangan pemahaman konsep fundamental yang dicapai sepanjang siklus pengembangan aplikasi.

---

## Tabel Pelacakan Konsep

| No. | Topik / Konsep | Modul Terkait | Status | Bukti Implementasi di Kode | Catatan Evaluasi |
|---:|---|---|---|---|---|
| 1 | TypeScript Strict Typing | Root, Backend & Frontend | Mastered | `tsconfig.json` strict mode, Zod schemas, API types | 0 any, type safety penuh dari DB ke UI |
| 2 | Express Middleware Pipeline | Backend Tier | Mastered | `backend/src/middleware/*` | Pipeline rapi: Helmet -> CORS -> CookieParser -> ReqId -> Auth -> CSRF -> RBAC -> Error |
| 3 | MySQL Constraints & Precision | Database Tier | Mastered | `schema.prisma`, migrations | `DECIMAL(18,3)` kuantitas, CHECK constraint, FK cascade restrict |
| 4 | Row-Level Locking (Pessimistic) | Inventory Service | Mastered | `inventory.service.ts` | `SELECT ... FOR UPDATE` via raw SQL dalam transaksi InnoDB |
| 5 | Session-Based Cookie Auth | Security Tier | Mastered | `auth.service.ts`, `auth.ts` | Cookie HttpOnly `sf_session`, SHA-256 hash lookup di database |
| 6 | Double-Submit Cookie CSRF | Security Tier | Mastered | `csrf.ts`, `api.ts` interceptor | Cookie `sf_csrf` dipasangkan dengan header `X-CSRF-Token` pada request mutasi |
| 7 | Next.js App Router Architecture | Frontend Tier | Mastered | `frontend/src/app/(marketing)`, `(auth)`, `(dashboard)` | Server layout inheritance, static pre-rendering 17 halaman |
| 8 | Design System Tokens & Dark Mode | UI/UX Tier | Mastered | `tailwind.config.ts`, `globals.css`, `theme-provider.tsx` | Palet Indigo dan Mint, CSS variables, zero visual flash |
| 9 | Docker Multi-Stage Packaging | DevOps Tier | Mastered | `backend/Dockerfile`, `frontend/Dockerfile`, `docker-compose.yml` | Multi-stage builder, Alpine base image, non-root user execution |
| 10 | Testing Piramida & Concurrency | QA Tier | Mastered | `backend/tests/*`, `frontend/tests/*` | 26 automated tests passed, browser visual walkthrough |
