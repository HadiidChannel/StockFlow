# StockFlow v1.6.3: Independent Audit Handover Manifest

Date: 2026-11-25 03:34:02 +08:00
Release Version: v1.6.3
Branch: fix/stockflow-v16-3-release-integrity
Commit: 307939065353e6e4578ea898b071e0be9bcdfa1b

## 1. Directory Structure Overview

This audit handover package is organized into two primary pillars:
- source/: Exact, pristine codebase components under review.
- evidence/: Verifiable test logs, environmental baselines, security scans, and execution results.

`
audit-handover/v1.6.3/
├── AUDIT_FILE_MANIFEST.md
├── source/
│   ├── root/                      # Root configuration and compose files
│   ├── backend/                   # Backend API, schema, migrations, and tests
│   ├── frontend/                  # Frontend UI, components, and Playwright tests
│   ├── scripts/                   # Production lifecycle scripts
│   └── tests/                     # Security and ACL integration test suites
└── evidence/
    ├── git/                       # Git status, branch, commit, and diff proofs
    ├── backend/                   # Vitest backend and bootstrap guard results
    ├── frontend/                  # Vitest frontend unit test results
    ├── bootstrap/                 # Disposable MySQL 8.4 bootstrap results
    ├── windows-acl/               # Windows NTFS ACL and fault rollback results
    ├── e2e/                       # Playwright E2E and teardown logs
    ├── security/                  # Secret scan results and self-test verification
    ├── docker/                    # Docker compose configuration validation
    ├── operational/               # Main stack protection and health proofs
    └── reconciliation/            # Consolidated test execution reconciliation
`

## 2. Source File Inventory and Verification Mapping

| Category | Relative File Path | Role and Description | Verification Status |
| :--- | :--- | :--- | :--- |
| Root | source/root/.env.example | Template environment configuration | Verified Present |
| Root | source/root/package.json | Monorepo root configuration | Verified Present |
| Root | source/root/docker-compose.yml | Production stack definition | Validated (Exit 0) |
| Root | source/root/docker-compose.dev.yml | Development stack definition | Validated (Exit 0) |
| Root | source/root/docker-compose.e2e.yml | Isolated E2E stack definition | Validated (Exit 0) |
| Root | source/root/docker-compose.bootstrap-test.yml | Disposable MySQL 8.4 stack | Validated (Exit 0) |
| Root | source/root/docker-compose.test.yml | Unit test stack definition | Validated (Exit 0) |
| Backend | source/backend/prisma/schema.prisma | Database schema definition | Validated |
| Backend | source/backend/src/scripts/bootstrap.ts | Administrator bootstrap logic | Unit and Integration Tested |
| Backend | source/backend/src/utils/bootstrap-guard.ts | Disposable database guard | Unit Tested (14/14 Passed) |
| Frontend | source/frontend/playwright.config.ts | Playwright configuration | Executed (3/3 Passed) |
| Scripts | source/scripts/init-local.ps1 | Local environment initialization | Tested (19/19 Scenarios) |
| Scripts | source/scripts/run-e2e.ps1 | Isolated E2E test runner | Executed (100% Clean) |
| Scripts | source/scripts/run-bootstrap-test.ps1 | Disposable MySQL test runner | Executed (3/3 Passed) |
| Scripts | source/scripts/scan-secrets.ps1 | Credential and secret scanner | Executed (0 Findings) |
| Scripts | source/scripts/verify-release.ps1 | 10-Gate release verification | Verified Pass |
| Scripts | source/scripts/package-release.ps1 | Official release packaging | Verified Pass |
| Tests | source/tests/test-init-local.ps1 | Windows ACL and fault tests | Executed (19/19 Passed) |

## 3. Evidence File Inventory and Test Traceability

| Domain | Evidence File Path | Executed Command | Results |
| :--- | :--- | :--- | :--- |
| Backend | evidence/backend/backend_test_results.txt | npm test (vitest run) | 111 Passed, 3 Skipped (114 Total) |
| Backend | evidence/backend/bootstrap_guard_test_results.txt | vitest run bootstrap-guard | 14 Passed, 0 Failed |
| Frontend | evidence/frontend/frontend_test_results.txt | npm test (vitest run) | 9 Passed, 0 Failed |
| Bootstrap | evidence/bootstrap/bootstrap_integration_test_results.txt | run-bootstrap-test.ps1 | 3 Passed, Disposable Cleaned |
| Windows ACL | evidence/windows-acl/init_local_test_results.txt | test-init-local.ps1 | 19 Passed, 100% Scenarios |
| E2E | evidence/e2e/e2e_test_results.txt | run-e2e.ps1 (Playwright) | 3 Passed (13 Stages Complete) |
| E2E | evidence/e2e/e2e_cleanup_verification.txt | run-e2e.ps1 finally block | 100% VERIFIED_CLEAN, Secret Purged |
| Security | evidence/security/secret_scan.txt | scan-secrets.ps1 | 276 Files, 0 Findings (Clean) |
| Security | evidence/security/secret_scanner_self_test.txt | scan-secrets.ps1 -SelfTest | 6/6 Categories, 0 False Positives |
| Docker | evidence/docker/docker_compose_verification.txt | docker compose config | 5/5 Validated Successfully |
| Main Stack | evidence/operational/main_stack_before.txt | docker ps | Verified Up (Port 3000) |
| Main Stack | evidence/operational/main_stack_after.txt | docker ps | Verified Up (Port 3000 Untouched) |
| Main DB | evidence/operational/main_database_after.txt | GET /api/v1/health | HTTP 200 UP, DB CONNECTED |
| Reconciliation | evidence/reconciliation/test_reconciliation.txt | Consolidated analysis | 161 Passed across 23 files |

## 4. Auditor Verification Summary

All listed items have been compiled directly from real command execution on Windows NTFS.
Operational database volume stockflow-prod_mysql_prod_data and containers on port 3000 were strictly preserved.
Zero secrets or credentials exist in either source or evidence files.