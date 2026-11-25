# StockFlow Test Execution Results

Dokumen ini mencatat ringkasan eksekusi pengujian pada setiap fase pengembangan.

---

## Log Eksekusi Test

| Tanggal | Fase / Milestone | Test Suite | Total Tests | Passed | Failed | Status | Catatan |
|---|---|---|---:|---:|---:|---|---|
| 2026-11-21 | Phase 0 | Audit Dokumen & Validasi Blueprint | - | - | - | PASS | Dokumen PRD, FSD, ERD, Schema, Design System lengkap |
| 2026-11-21 | Phase 1 | Foundation, Prisma Schema & Build | - | - | - | PASS | Prisma schema 14 tabel tervalidasi, Next.js 17 routes clean build |
| 2026-11-21 | Phase 2 | Backend Auth & Security Headers | 3 | 3 | 0 | PASS | Healthcheck, 404 envelope, validation error handling |
| 2026-11-21 | Phase 2 | RBAC & Warehouse Scope Middleware | 2 | 2 | 0 | PASS | Staff dibatasi dari admin endpoints, token role scoping diverifikasi |
| 2026-11-21 | Phase 3 | Error Handling & Custom Domain Errors | 7 | 7 | 0 | PASS | AppError status codes, envelope payloads, serialization |
| 2026-11-21 | Phase 4 | Zod Validation & Master Data Schemas | 5 | 5 | 0 | PASS | Login, Product, Stock In/Out positive & negative validation |
| 2026-11-21 | Phase 5 | Frontend Formatters & Calculations | 4 | 4 | 0 | PASS | Rupiah formatting, Decimal precision, Date format, Metric Delta |
| 2026-11-21 | Phase 6 | E2E Workflow Logic (In, Out, Reversal) | 5 | 5 | 0 | PASS | Concurrency protection, Reversal invariants, negative stock blocked |
| 2026-11-21 | Phase 7 | Browser Visual Inspection & Recording | 5 | 5 | 0 | PASS | 100% UI flow verified: Landing, Login, Dashboard, Inventory, Ledger |
| 2026-11-21 | Remediation v1.0 | Security Hardening & Concurrency | 68 | 68 | 0 | PASS | Idempotency hashing, DB checks, rate limiter, forced password change |
| 2026-11-22 | Remediation v1.1 | Dependency Security & Playwright E2E | 76 | 76 | 0 | PASS | 0 npm vulnerabilities, 13-stage browser E2E, MySQL 8.4 verification |
| 2026-11-23 | Final Release v1.2 | Production Origin & Multi-Table Rollback | 80 | 80 | 0 | PASS | Fail-fast prod origin, standalone docker, 5-table rollback, 0 leaks |
| 2026-11-23 | Final Release v1.3 | Reverse Proxy, Bootstrap Security & Docker Isolation | 95 | 95 | 0 | PASS | Internal proxy rewrite, dedicated bootstrap, host port isolation, 13-stage Docker E2E |
| 2026-11-24 | Release v1.4 | Localhost Portfolio Edition & Docker Secrets | 101 | 101 | 0 | PASS | APP_DEPLOYMENT_MODE local, Docker Secrets bootstrap, fresh MySQL 8.4 lifecycle, 13-stage Playwright E2E |
| 2026-11-24 | Release v1.5 | Localhost Network Isolation & Cryptographic Secrets | 107 | 107 | 0 | PASS | Loopback binding 127.0.0.1:3000, init-local.ps1 .NET crypto, placeholder secrets rejection, zero-fallback Playwright, sanitized evidence |
| 2026-11-24 | Release v1.6 | E2E Isolation, Security Hardening & Local Setup Reliability | 107 | 107 | 0 | PASS | Dedicated E2E stack (port 3100), dynamic crypto credentials, init-local rollback + ACL, bootstrap test fix, zero DB pollution |
| 2026-11-25 | Release v1.6.1 | Release Blocker Remediation, Full Isolation & Secret Hygiene | 125 | 125 | 0 | PASS | Healthcheck $$MYSQL_ROOT_PASSWORD, SID ACLs, strict mode safe rollback, bootstrap mock unit tests + fail-closed guard, dynamic E2E project namespaces, comprehensive secret scanner |
| 2026-11-25 | Release v1.6.2 | Verification Integrity & Security Gate Remediation | 147 | 147 | 0 | PASS | Real disposable MySQL 8.4 bootstrap test, 14 guard scenarios, 19 init-local tests with 4 fault rollbacks, Docker label ownership, rebuilt 6-pattern secret scanner, 8 release gates verified |
| 2026-11-25 | Release v1.6.3 | Master Remediation, Verification Integrity & Release Packaging | 161 | 161 | 0 | PASS | Windows Modify (M) ACL permission, fail-closed E2E secret cleanup, standardized owner labels, word-bounded secret scanner, 10 release quality gates verified (Note: jumlah 161 mencampurkan application tests & checks) |
| 2026-11-25 | Release v1.6.4 | Master Release Integrity Remediation & Complete Audit Handover | 145 app + 13 verifier suite | All Passed | 0 failed (3 skipped in default Vitest, executed in Bootstrap suite) | PASS | Pemisahan ketat Application Test Cases (145 inherited from v1.6.3 with unchanged app source) vs Engineering Verification Checks (13/13 fail-closed verifier scenarios, 11 secret fixtures, 5 compose configs, 13 release gates, handover 1-to-1 check) |

### Ringkasan Rekonsiliasi Pengujian dan Verifikasi v1.6.4 (Tanpa Double-Counting)

Catatan Metodologi: Pengujian aplikasi (`backend/`, `frontend/`, `init-local.ps1`, `run-bootstrap-test.ps1`, `run-e2e.ps1`) tidak mengalami perubahan kode sumber antara rilis `v1.6.3` dan `v1.6.4`, sehingga bukti mentahnya dipertahankan sebagai **Inherited from v1.6.3, relevant source unchanged** dengan timestamp dan commit asal asli (`e7bccf7792725888a449822c8a838cc1a556de01`). Seluruh komponen rilis, keamanan, Git, Docker Compose, pemaketan, dan handover yang berubah atau terdampak pada `v1.6.4` dieksekusi ulang secara nyata (**Re-executed in v1.6.4**).

#### 1. Application Test Cases (Total Unik: 145 Lulus, 0 Gagal)
- **Backend Unit & Integration (Vitest)**: 111 Passed, 3 Skipped across 13 files (`Inherited from v1.6.3, relevant source unchanged`). Ke-14 test `bootstrap-guard.test.ts` sudah termasuk di dalam angka 111 ini (tidak dihitung ganda).
- **Disposable MySQL 8.4 Bootstrap Integration (Vitest + Docker)**: 3 Passed (`Inherited from v1.6.3, relevant source unchanged`; ini merupakan 3 test yang dilewati saat default Vitest run).
- **Frontend Unit & Workflow Logic (Vitest)**: 9 Passed across 2 files (`Inherited from v1.6.3, relevant source unchanged`).
- **Windows NTFS File ACL & Rollback Suite (`tests/test-init-local.ps1`)**: 19 Passed scenarios (`Inherited from v1.6.3, relevant source unchanged`).
- **Playwright Browser E2E (`frontend/tests/e2e/stockflow-lifecycle.spec.ts`)**: 3 Test Cases Passed covering 13 workflow stages (`Inherited from v1.6.3, relevant source unchanged`).

#### 2. Engineering Verification Checks (Re-executed in v1.6.4)
- **Release Verifier Negative & Positive Suite (`tests/test-verify-release.ps1`)**: 13 / 13 scenarios Passed (`Re-executed in v1.6.4`, menguji fail-closed rejection untuk commit mismatch, branch mismatch, dirty modified, untracked, missing git, missing/corrupt manifest, missing ZIP, checksum mismatch, embedded manifest, false verified claim, dan stale git evidence).
- **Secret Scanner Automated Fixtures (`scripts/scan-secrets.ps1 -SelfTest`)**: 11 / 11 fixtures Passed (6/6 kategori terdeteksi pada 7 uji positif, 0 false positives pada 4 berkas aman).
- **Secret Scanner Repository & Packages**: Memindai repositori aktif (0 findings) serta memindai masing-masing Source ZIP, Verification ZIP, dan Audit Handover ZIP (seluruh hasil final tercatat dalam `release-output/v1.6.4/`).
- **Docker Compose Configuration Validation**: 5 / 5 konfigurasi Compose tervalidasi dengan output mentah ter-sanitasi (`docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.e2e.yml`, `docker-compose.bootstrap-test.yml`, `docker-compose.test.yml`).
- **Release Packaging, Handover Completeness, dan 13 Fail-Closed Gates**: Dieksekusi langsung pasca-commit oleh `scripts/package-release.ps1` dan `scripts/verify-release.ps1` dengan laporan akhir lengkap pada `release-output/v1.6.4/FINAL_RELEASE_REPORT_V1_6_4.md`.
