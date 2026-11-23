# StockFlow End-to-End (E2E) Browser Testing Report

## 1. Executive Summary

- Test Framework: Playwright v1.65.1 (Chromium Engine)
- Target Application: StockFlow Inventory and Warehouse Management System
- Frontend: Next.js 15 Standalone Reverse Proxy on http://localhost:3000
- Backend: Express.js on internal Docker network (backend:4000, host port closed)
- Database: MySQL 8.4 LTS on internal Docker network (db:3306, host port closed)
- Execution Mode: Real Browser, Real REST API, Real Production Docker Database (Zero Mocks)
- Result: 13 / 13 Stages Passed (100% Green, 0 Failures, 0 Flaky)
- Total Test Duration: 8.1s

---

## 2. 13-Stage Verification Matrix

| Stage | Test Scenario | Verified Condition | HTTP / DB Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| Stage 1 | Admin Login | Submit admin credential, verify redirect to /dashboard and Administrator header | 200 OK, Session Cookie Issued | PASSED |
| Stage 2 | Create Category & Product | Create category and product with SKU and min stock in database | 201 Created in MySQL | PASSED |
| Stage 3 | Create Warehouses | Create assigned warehouse (JKT) and unassigned warehouse (SUB) | 201 Created in MySQL | PASSED |
| Stage 4 | Stock In 50 Units | Post Stock In with purchase reference and note | 201 Created, Ledger Updated | PASSED |
| Stage 5 | Verify Inventory Balance | Search product SKU and assert balance equals 50 PCS in assigned warehouse | Verified 50 PCS | PASSED |
| Stage 6 | Create Warehouse Staff | Create staff user with assigned warehouse checkbox selected | 201 Created, mustChangePassword=true | PASSED |
| Stage 7 | Warehouse Assignment | Verify warehouse assignment modal shows assigned checked and unassigned unchecked | 200 OK, Assignment Confirmed | PASSED |
| Stage 8 | Warehouse Staff Login | Logout admin, login as staff, trigger forced password change (P0-02), access dashboard | 200 OK, Staff Header Verified | PASSED |
| Stage 9 | Stock Out 15 Units | Submit Stock Out of 15 units with live balance indicator | 201 Created, Balance Reduced to 35 | PASSED |
| Stage 10 | Stock Movement History | Verify movement ledger contains MASUK (+50), KELUAR (-15), and ending balance (35) | Ledger Verified in UI | PASSED |
| Stage 11 | Access Unassigned Warehouse | Staff attempts Stock Out against unassigned warehouse via API | Request Dispatched | PASSED |
| Stage 12 | Access Denied Guard | Assert request is rejected with HTTP 403 Forbidden and error message | HTTP 403 Forbidden, Akses ditolak | PASSED |
| Stage 13 | Full Reversal & Balance Restore | Execute Full Reversal on Stock Out transaction, verify balance restored to 50 PCS | 201 Created, Balance Restored | PASSED |

---

## 3. Detailed Stage Walkthrough and Evidence

### Stage 1: Admin Login & Forced Password Change
- Navigated to `/login`.
- Input email `admin@stockflow.com` and initial administrator password loaded from `.secrets/initial_admin_password.txt`.
- Clicked "Masuk ke Sistem".
- System detected `must_change_password=1` from fresh bootstrap, redirecting to `/change-password`.
- Form filled with initial password and new permanent administrator password.
- Submitted password update and asserted URL redirect to `/dashboard`.
- Asserted header contains text "Administrator".

### Stage 2: Create Category and Product
- Navigated to `/categories`.
- Opened modal "Tambah Kategori Baru", entered category name and description, submitted.
- Confirmed category row visible in catalog table.
- Navigated to `/products`.
- Opened modal "Tambah Produk Baru", entered product name, SKU, selected newly created category, unit "PCS", and minimum stock "5.000".
- Confirmed product row in catalog table.
- Captured created product UUID via authenticated API: `011b65fc-b73e-48e8-aa81-cb0cc8973ee9`.

### Stage 3: Create Warehouses
- Navigated to `/warehouses`.
- Created assigned warehouse: `Gudang Utama JKT` (Code: `W13972`).
- Created unassigned warehouse: `Gudang Terlarang SUB` (Code: `W23972`).
- Captured unassigned warehouse UUID via admin session: `4734bdcf-af35-41a7-b83f-fcfb2ac51fbd`.

### Stage 4: Stock In 50 Units
- Navigated to `/inventory/stock-in`.
- Selected assigned warehouse and product from hydrated dropdowns.
- Filled quantity `50.000`, reference PO number, and receiving note.
- Submitted "Posting Stock In".
- Verified success notification: "Stock In Berhasil Diposting!".

### Stage 5: Verify Inventory Balance
- Navigated to `/inventory`.
- Filtered table by product SKU.
- Verified balance row displays 50 units for the product in the assigned warehouse.

### Stage 6: Create Warehouse Staff
- Navigated to `/users`.
- Clicked "Tambah Pengguna".
- Entered staff name, email, initial temporary password, and selected role `WAREHOUSE_STAFF`.
- Checked assigned warehouse checkbox in the assignment section.
- Submitted "Simpan Akun".
- Verified staff user created in user table.

### Stage 7: Warehouse Assignment
- In `/users`, located staff row and clicked "Gudang".
- Verified "Penugasan Gudang" modal displayed.
- Verified assigned warehouse checkbox is checked.
- Verified unassigned warehouse checkbox is not checked.
- Clicked "Simpan Penugasan".

### Stage 8: Warehouse Staff Login (P0-02 Forced Password Change)
- Clicked logout button in navigation topbar.
- Verified redirect to `/login`.
- Logged in with staff email and temporary password.
- Verified security enforcement redirect to `/change-password` because `mustChangePassword` is `true`.
- Entered current password and new permanent password (`StaffPermanentPassword2026!`).
- Submitted password change form.
- Verified redirect to `/dashboard` with header displaying staff name and "Warehouse Staff" badge.

### Stage 9: Stock Out 15 Units
- Navigated to `/inventory/stock-out`.
- Selected assigned warehouse and product.
- Verified live balance indicator: "Saldo Tersedia di Gudang Ini" is visible.
- Filled quantity `15.000`, reference DO number, and delivery note.
- Submitted "Posting Stock Out".
- Verified success notification: "Stock Out Berhasil Diposting!".

### Stage 10: Verify Movement Ledger
- Navigated to `/movements`.
- Filtered ledger by product SKU.
- Confirmed movement rows:
  * IN transaction: +50 PCS
  * OUT transaction: -15 PCS
  * Current ending balance: 35 PCS

### Stage 11 & 12: Unauthorized Warehouse Access and 403 Forbidden
- Staff session extracted CSRF token from browser cookie `sf_csrf`.
- Staff session dispatched POST `/api/v1/inventory/stock-out` attempting to issue stock from `Gudang Terlarang SUB` (unassigned warehouse).
- Received HTTP 403 Forbidden response:
  ```json
  {
    "error": {
      "code": "FORBIDDEN",
      "message": "Akses ditolak: Anda tidak memiliki penugasan aktif pada gudang ini atau gudang berstatus tidak aktif.",
      "requestId": "req_1795292720399_m8iosbp"
    }
  }
  ```
- Confirmed role-based warehouse scoping middleware strictly isolates data and operations.

### Stage 13: Full Reversal and Final Balance Restoration
- Navigated to `/movements`.
- Filtered ledger by product SKU.
- Located OUT transaction and clicked "Reversal".
- Confirmed "Konfirmasi Reversal Transaksi" modal appeared.
- Filled reason "Pembatalan transaksi salah kirim E2E".
- Clicked "Lakukan Pembalikan Penuh".
- Verified success alert: "Transaksi berhasil dibatalkan".
- Navigated to `/inventory`, filtered by product SKU.
- Verified inventory balance restored to 50 PCS.

---

## 4. Verification Artifacts

- Playwright Test File: `frontend/tests/e2e/stockflow-lifecycle.spec.ts`
- Playwright Configuration: `frontend/playwright.config.ts`
- JSON Execution Report: `audit/evidence/e2e/results.json`
- HTML Interactive Report: `audit/evidence/e2e/playwright-report/`
- Test Finished Screenshot: `audit/evidence/e2e/test-results/`
