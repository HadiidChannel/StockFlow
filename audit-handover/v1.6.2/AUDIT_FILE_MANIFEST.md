# StockFlow v1.6.2 Audit File Manifest & Verification Mapping

Dokumen ini merupakan panduan pemetaan resmi untuk independent technical auditor dalam memverifikasi penyelesaian seluruh temuan audit StockFlow v1.6.2.

Setiap temuan dipetakan secara eksplisit ke file implementasi sumber daya (source code) dan bukti uji aktual (verification evidence) yang dapat diverifikasi secara independen.

---

## 1. Tabel Pemetaan Temuan Audit (Findings to Artifacts Mapping)

| No | ID Temuan Audit | Deskripsi Temuan Audit | File Sumber Daya (Source Code) | File Bukti Verifikasi (Evidence) | Status |
|---|---|---|---|---|---|
| 1 | FINDING-01 | Ketiadaan Pengujian Integrasi Bootstrap pada Database Nyata | `backend/tests/bootstrap.integration.test.ts`<br>`docker-compose.bootstrap-test.yml`<br>`scripts/run-bootstrap-test.ps1` | `evidence/v1.6.2/bootstrap_integration_test_results.txt` | RESOLVED & VERIFIED |
| 2 | FINDING-02 | Ketiadaan Fail-Closed Guard pada Eksekusi Bootstrap | `backend/src/utils/bootstrap-guard.ts`<br>`backend/tests/bootstrap-guard.test.ts` | `evidence/v1.6.2/bootstrap_guard_test_results.txt` | RESOLVED & VERIFIED |
| 3 | FINDING-03 | Pengujian Otomatis Setup Lokal Belum Mencakup Rollback Transaksional Penuh | `scripts/init-local.ps1`<br>`tests/test-init-local.ps1` | `evidence/v1.6.2/init_local_test_results.txt` | RESOLVED & VERIFIED |
| 4 | FINDING-04 | Ketiadaan Penegakan ACL Restriktif pada Direktori .secrets yang Telah Ada | `scripts/init-local.ps1`<br>`tests/test-init-local.ps1` | `evidence/v1.6.2/init_local_test_results.txt` | RESOLVED & VERIFIED |
| 5 | FINDING-05 | Ketiadaan Pelabelan Kepemilikan Resource Docker E2E | `docker-compose.e2e.yml`<br>`scripts/run-e2e.ps1` | `evidence/v1.6.2/e2e_resource_ownership.txt` | RESOLVED & VERIFIED |
| 6 | FINDING-06 | Ketiadaan Penegakan Fail-Closed Secret ACL pada Runner E2E | `scripts/run-e2e.ps1` | `evidence/v1.6.2/e2e_secret_acl_test_results.txt` | RESOLVED & VERIFIED |
| 7 | FINDING-07 | Blindspot Deteksi Pemindai Rahasia pada Argumen CLI dan Connection String | `scripts/scan-secrets.ps1` | `evidence/v1.6.2/secret_scan.txt`<br>`evidence/v1.6.2/secret_scanner_self_test.txt` | RESOLVED & VERIFIED |
| 8 | FINDING-08 | Ketiadaan Pengujian Mandiri (Self-Test) pada Pemindai Rahasia | `scripts/scan-secrets.ps1` | `evidence/v1.6.2/secret_scanner_self_test.txt` | RESOLVED & VERIFIED |
| 9 | FINDING-09 | Inkonsistensi Filter Packaging Terhadap Template .env.example | `scripts/package-release.ps1` | `StockFlow_Final_v8_2.zip`<br>`StockFlow_Release_Checksums_v8_2.txt` | RESOLVED & VERIFIED |
| 10 | FINDING-10 | Port Binding Publik 0.0.0.0 pada Docker Compose Development | `docker-compose.dev.yml` | `evidence/v1.6.2/docker_compose_verification.txt` | RESOLVED & VERIFIED |
| 11 | FINDING-11 | Ketiadaan Skrip Verifikasi Gerbang Rilis Terintegrasi | `scripts/verify-release.ps1` | `evidence/v1.6.2/release_verification_summary.md` | RESOLVED & VERIFIED |
| 12 | FINDING-12 | Rekonsiliasi Jumlah Uji Otomatis Belum Selaras Antar-Dokumen | `docs/engineering/TEST_RESULTS.md`<br>`README.md`<br>`docs/engineering/FINAL_RELEASE_REPORT_V1_6_2.md` | `evidence/v1.6.2/test_reconciliation.txt` | RESOLVED & VERIFIED |
| 13 | FINDING-13 | Kerentanan Build Offline pada Docker Compose E2E | `docker-compose.e2e.yml`<br>`scripts/run-e2e.ps1` | `evidence/v1.6.2/e2e_test_results.txt` | RESOLVED & VERIFIED |
| 14 | FINDING-14 | Pemindaian Vitest Frontend yang Meluber ke Spec Playwright | `frontend/vitest.config.ts` | `evidence/v1.6.2/frontend_test_results.txt` | RESOLVED & VERIFIED |
| 15 | FINDING-15 | Potensi Gangguan pada Stack Produksi Utama Saat Pengujian E2E | `scripts/run-e2e.ps1`<br>`docker-compose.e2e.yml` | `evidence/v1.6.2/main_stack_before.txt`<br>`evidence/v1.6.2/main_stack_after.txt` | RESOLVED & VERIFIED |
| 16 | FINDING-16 | Kepatuhan Format Penulisan Laporan (Larangan Karakter En Dash dan Em Dash) | Seluruh file dokumentasi `.md` dan skrip `.ps1` | `evidence/v1.6.2/release_verification_summary.md` | RESOLVED & VERIFIED |

---

## 2. Struktur Direktori Audit Handover

```text
audit-handover/v1.6.2/
├── AUDIT_FILE_MANIFEST.md         # Dokumen pemetaan dan instruksi audit ini
├── source/                        # Seluruh file implementasi sumber daya kunci
│   ├── .env.example
│   ├── backend.env.example
│   ├── bootstrap-guard.ts
│   ├── bootstrap-guard.test.ts
│   ├── bootstrap.integration.test.ts
│   ├── bootstrap.unit.test.ts
│   ├── docker-compose.bootstrap-test.yml
│   ├── docker-compose.dev.yml
│   ├── docker-compose.e2e.yml
│   ├── docker-compose.yml
│   ├── init-local.ps1
│   ├── package-release.ps1
│   ├── run-bootstrap-test.ps1
│   ├── run-e2e.ps1
│   ├── scan-secrets.ps1
│   ├── test-init-local.ps1
│   ├── verify-release.ps1
│   ├── vitest.config.backend.ts
│   └── vitest.config.frontend.ts
└── evidence/                      # Seluruh rekaman bukti uji verifikasi independen
    ├── backend_test_results.txt
    ├── bootstrap_guard_test_results.txt
    ├── bootstrap_integration_test_results.txt
    ├── bootstrap_unit_test_results.txt
    ├── docker_compose_verification.txt
    ├── e2e_cleanup_verification.txt
    ├── e2e_compose_config_sanitized.txt
    ├── e2e_resource_ownership.txt
    ├── e2e_secret_acl_test_results.txt
    ├── e2e_test_results.txt
    ├── frontend_test_results.txt
    ├── init_local_test_results.txt
    ├── main_stack_after.txt
    ├── main_stack_before.txt
    ├── release_verification_summary.md
    ├── secret_scan.txt
    ├── secret_scanner_self_test.txt
    └── test_reconciliation.txt
```

---

## 3. Prosedur Verifikasi Cepat untuk Auditor

Auditor independen dapat memvalidasi seluruh kepatuhan rekayasa dengan menjalankan satu skrip verifikasi otomatis:

```bash
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

Skrip ini akan memvalidasi secara deterministik:
1. Integritas arsip dan manifest hash SHA-256.
2. Kelengkapan seluruh file sumber daya tanpa meninggalkan sampah build.
3. Ketiadaan file kredensial aktif di dalam arsip rilis.
4. Isolasi ketat binding loopback 127.0.0.1 pada seluruh file compose.
5. Ketiadaan kebocoran kredensial dengan 0 temuan pemindai rahasia.
6. Rekonsiliasi 147 test gate 100% passed hijau.
7. Ketiadaan karakter en dash dan em dash pada dokumen rilis.
