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
| 2026-11-25 | Release v1.6.5 | ZIP Portability, Release Verification Hardening & Final Audit | 145 app + 44 verifier suite | All Passed | 0 failed (3 skipped in default Vitest, executed in Bootstrap suite) | PASS | POSIX forward-slash ZIP (`0` raw `0x5C` entries), paritas ekstraksi 3-engine Python/Info-ZIP/.NET (`GATE-14`), validasi Handover dua arah (`GATE-09`), audit 4-laporan rahasia (`GATE-11`), bukti Git metadata lengkap (`GATE-12`), pindai dash seluruh scope (`GATE-13`), 44/44 skenario uji negatif/positif |

### Ringkasan Rekonsiliasi Pengujian dan Verifikasi v1.6.5 (Tanpa Double-Counting)

Catat Metodologi: Seluruh modul kode sumber aplikasi (`backend/`, `frontend/`), inisialisasi Windows ACL (`init-local.ps1`, `tests/test-init-local.ps1`), bootstrap integrasi (`run-bootstrap-test.ps1`), dan konfigurasi E2E (`run-e2e.ps1`, `docker-compose*.yml`) tidak mengalami perubahan sejak commit asal `e7bccf7792725888a449822c8a838cc1a556de01` (v1.6.3, dilanjutkan utuh lewat v1.6.4 `dbf511602874c899a03e58d89c8c4a811d21b33f`). Bukti mentah 145 Application Test Cases tersebut dipertahankan sebagai **Inherited via v1.6.4 from e7bccf7 (relevant source unchanged)**. Seluruh verifikasi rilis, portabilitas ZIP, keamanan, dan rekayasa pada `v1.6.5` dieksekusi ulang (**Re-executed in v1.6.5**).

#### 1. Application Test Cases (Total Unik: 145 Lulus, 0 Gagal - Inherited from e7bccf7 via v1.6.4)
- **Backend Unit & Integration (Vitest)**: 111 Passed, 3 Skipped across 13 files (ke-14 test `bootstrap-guard.test.ts` sudah termasuk di dalam angka 111 ini).
- **Disposable MySQL 8.4 Bootstrap Integration (Vitest + Docker)**: 3 Passed (`backend/tests/bootstrap.integration.test.ts`; merupakan 3 test yang dilewati saat default Vitest run).
- **Frontend Unit & Workflow Logic (Vitest)**: 9 Passed across 2 files.
- **Windows NTFS File ACL & Rollback Suite (`tests/test-init-local.ps1`)**: 19 Passed scenarios.
- **Playwright Browser E2E (`frontend/tests/e2e/stockflow-lifecycle.spec.ts`)**: 3 Test Cases Passed covering 13 workflow stages.

#### 2. Engineering Verification Checks (Re-executed in v1.6.5)
- **Expanded Release Verifier Negative & Positive Suite (`tests/test-verify-release.ps1`)**: 44 / 44 scenarios Passed (Core 11, Gate 09 Bidirectional Manifest 7, Gate 11 4-Report Secret Scan 6, Gate 12 Git Metadata/Clean/Fail-Closed 9, Gate 13 All-Scope Dash 4, Gate 14 Raw Backslash/Traversal/Absolute/Duplicate/CRC/Collision/3-Way Portability 7).
- **Secret Scanner Automated Fixtures (`scripts/scan-secrets.ps1 -SelfTest`)**: 11 / 11 fixtures Passed (6/6 kategori terdeteksi pada 7 uji positif, 0 false positives pada 4 berkas aman).
- **Secret Scanner 4-Target Reports**: Memindai repositori aktif + Source ZIP + Verification ZIP + Handover ZIP (seluruh 4 laporan terverifikasi terpisah, `0` findings, `Exit Code: 0`).
- **Docker Compose Configuration Validation**: 5 / 5 konfigurasi Compose tervalidasi dengan output mentah ter-sanitasi.
- **14 Fail-Closed Release Quality Gates (`scripts/verify-release.ps1`) & Cross-Platform 3-Way ZIP Extraction**: Python `zipfile` + Info-ZIP `unzip` + .NET `ZipFile` terverifikasi pasca-pengemasan dengan hasil akhir tercatat di `release-output/v1.6.5/FINAL_RELEASE_REPORT_V1_6_5.md`.
