# StockFlow Engineering Remediation and Final Verification Report v1.5
## Localhost Portfolio Finalization and Security Verification

Tanggal: 24 November 2026  
Status Rilis: **LOCALHOST PORTFOLIO READY**  
Branch Git: `fix/stockflow-localhost-final-v15`  
Target Lingkungan: Localhost Portfolio Environment (`http://localhost:3000`)

---

## 1. Executive Summary

Laporan ini mendokumentasikan penyelesaian menyeluruh dari seluruh temuan audit independen pada siklus Remediasi v1.4 untuk aplikasi StockFlow. StockFlow adalah Inventory and Warehouse Management System (IWMS) berbasis web yang dikembangkan sebagai proyek portofolio profesional Full-Stack Developer.

Fokus utama dari rilis v1.5 mencakup:
1. Isolasi jaringan lokal absolut melalui binding port frontend secara eksplisit ke loopback interface `127.0.0.1:3000`.
2. Generator kredensial dan environment lokal mandiri (`scripts/init-local.ps1`) berbasis API kriptografi Windows .NET.
3. Penolakan ketat nilai rahasia bertipe placeholder pada validasi fail-fast environment backend.
4. Pembersihan dan koreksi dokumentasi instalasi awal pada `README.md`, `DEPLOYMENT_GUIDE.md`, dan `TROUBLESHOOTING.md` tanpa password hardcoded.
5. Penghapusan total fallback password hardcoded pada suite pengujian peramban Playwright E2E.
6. Sanitasi dan sinkronisasi seluruh arsip bukti pengujian (`audit/evidence/`) tanpa duplikasi dan bebas dari kredensial sensitif.

Aplikasi diverifikasi berjalan optimal pada komputer lokal dengan arsitektur produksi kontainer Docker, lulus 100% pada seluruh pengujian otomatis (95 backend unit/integration tests, 9 frontend logic tests, dan 3 Playwright browser E2E tests). Seluruh kriteria rilis terpenuhi dengan status **LOCALHOST PORTFOLIO READY**.

---

## 2. Localhost Architecture

Arsitektur StockFlow Localhost Portfolio Edition dirancang dengan prinsip pemisahan tanggung jawab (Separation of Concerns) dan pertahanan berlapis (Defense-in-Depth):

```text
+-------------------------------------------------------------------+
|                        CLIENT BROWSER                             |
|  - Terhubung ke http://localhost:3000 (Loopback Interface)        |
|  - Next.js 15 App Router & React 19 Client Components             |
+----------------------------------+--------------------------------+
                                   |
                  HTTP (Port 3000) | Bound exclusively to 127.0.0.1
                                   v
+----------------------------------+--------------------------------+
|                   FRONTEND TIER (Next.js 15)                      |
|  - Standalone Node.js Runner Server                               |
|  - Ingress Gateway Tunggal Komputer Host                          |
|  - Build-Time Reverse Proxy (/api/v1/:path* -> backend:4000)      |
+----------------------------------+--------------------------------+
                                   |
          Docker Internal Network  | stockflow_net (Bridge)
                       REST API v1 | Port 4000 (Host Port Closed)
                                   v
+----------------------------------+--------------------------------+
|                    BACKEND TIER (Express.js)                      |
|  - Production Runner Image (Non-root user: node)                  |
|  - Double-Submit CSRF Protection (sf_csrf cookie + Header)        |
|  - Session-Based Auth (bcrypt cost 12, SHA-256 session token)     |
|  - Pessimistic Row Locking Concurrency Manager                    |
|  - Zod Request Schema Validation & Fail-Fast Environment Check    |
+----------------------------------+--------------------------------+
                                   |
          Docker Internal Network  | stockflow_net (Bridge)
                        Prisma ORM | Port 3306 (Host Port Closed)
                                   v
+----------------------------------+--------------------------------+
|                  DATABASE TIER (MySQL 8.4 LTS)                    |
|  - MySQL 8.4.13 Enterprise LTS with InnoDB Engine                 |
|  - 14 Relational Tables, 9 CHECK Constraints, 2 Composite FKs     |
|  - Persistent Named Volume: mysql_prod_data                       |
+-------------------------------------------------------------------+
```

Prinsip Utama:
- Ingress Tunggal: Hanya port frontend 3000 yang dipublikasikan ke komputer lokal.
- Host Port Backend dan Database Ditutup: Port 4000 Express dan Port 3306 MySQL tidak dipublikasikan ke host, menjamin komunikasi privat di dalam Docker bridge network.
- Same-Origin Relative API: Komunikasi browser client menggunakan path relatif `/api/v1`, dialirkan oleh reverse proxy internal Next.js tanpa membocorkan alamat backend.

---

## 3. Local Network Isolation

Pada audit sebelumnya, pemetaan port frontend menggunakan sintaks `"3000:3000"`, yang secara default mengikat port ke `0.0.0.0` (seluruh interface host). Pada rilis v1.5, isolasi jaringan lokal telah diperkuat:

1. Pemetaan Port Eksplisit:
   Konfigurasi `docker-compose.yml` diubah menjadi:
   ```yaml
   ports:
     - "127.0.0.1:3000:3000"
   ```
2. Hasil Verifikasi Binding Port Docker:
   ```text
   $ docker compose port frontend 3000
   127.0.0.1:3000
   ```
3. Hasil Verifikasi Koneksi TCP Windows Host:
   ```powershell
   Get-NetTCPConnection -LocalPort 3000 -State Listen
   LocalAddress: 127.0.0.1
   LocalPort:    3000
   State:        Listen
   Process:      com.docker.backend
   ```
4. Verifikasi Port Backend dan Database:
   Pemeriksaan port pada kontainer membuktikan host port backend (`4000/tcp`) dan database (`3306/tcp`) bernilai `null` (tidak dipublikasikan). Tidak ada port yang terbuka ke jaringan lokal (LAN).

---

## 4. Environment Initialization

Untuk mencegah pembuatan rahasia manual yang rawan kesalahan dan rentan menggunakan nilai default atau placeholder, telah dibangun skrip inisialisasi lingkungan otomatis:
- Path: `scripts/init-local.ps1`
- Target Platform: Windows (PowerShell 7+ / Windows PowerShell 5.1).
- Fitur Keselamatan (Fail-Safe):
  1. Memeriksa keberadaan file `.env` dan direktori `.secrets/`.
  2. Jika file sudah ada, skrip menolak eksekusi dan membatalkan proses dengan pesan kesalahan jelas untuk mencegah penimpaan konfigurasi yang sudah berjalan.
  3. Menggunakan penulisan file atomik (menulis ke file `.tmp` terlebih dahulu sebelum dipindahkan ke nama target).
  4. Menerapkan pembatasan hak akses file Windows ACL melalui `icacls.exe` sehingga file rahasia hanya dapat diakses oleh user lokal aktif dan System Administrators.
  5. Nilai rahasia dilarang dicetak ke layar terminal maupun PowerShell transcript demi menjaga kerahasiaan.

---

## 5. Secret Generation Strategy

Strategi pembangkitan rahasia pada `scripts/init-local.ps1` menggunakan engine kriptografi standar industri:
1. Engine Kriptografi: `System.Security.Cryptography.RandomNumberGenerator`.
2. Kredensial Database (`DB_ROOT_PASSWORD` dan `DB_PASSWORD`):
   - Dibangkitkan sebagai string heksadesimal acak sepanjang 48 karakter (192 bits entropy).
   - Karakter heksadesimal murni dijamin aman dari masalah URL-encoding saat diserialisasikan ke dalam `DATABASE_URL`.
3. Kunci Sesi dan CSRF (`SESSION_SECRET` dan `CSRF_SECRET`):
   - Dibangkitkan sebagai string heksadesimal acak sepanjang 64 karakter (256 bits entropy).
   - Memenuhi validasi panjang minimal 32 karakter dan tidak berada dalam daftar secret default.
4. Password Administrator Awal:
   - Dibangkitkan sepanjang 24 karakter dengan pengacakan kriptografis Fisher-Yates.
   - Memenuhi aturan kompleksitas NIST: minimal 2 huruf besar, 2 huruf kecil, 2 angka, dan 2 simbol (`!@#$%^&*()-_=+`).
   - Tidak menggunakan password default atau kata umum.
5. Validasi Backend Fail-Fast (`backend/src/config/env.ts`):
   - Menolak pola placeholder umum seperti `YOUR_`, `CHANGE_ME`, `REPLACE_`, `EXAMPLE_SECRET`, dan `PLACEHOLDER` pada `SESSION_SECRET`, `CSRF_SECRET`, dan `DATABASE_URL`.
   - Dibuktikan melalui 3 unit test baru pada `backend/tests/env-validation.test.ts`.

---

## 6. Administrator Bootstrap

Inisialisasi akun Administrator awal berjalan melalui service dedicated `bootstrap` pada Docker Compose:
1. Docker Compose Secrets Integration:
   File password awal dipasang ke kontainer melalui mekanisme Docker Secrets pada path `/run/secrets/initial_admin_password`.
2. Larangan Environment Variable Biasa:
   Skrip `bootstrap.ts` secara tegas menolak eksekusi jika password dikirim melalui variabel lingkungan biasa `INITIAL_ADMIN_PASSWORD`.
3. Kebijakan Keamanan Akun Awal:
   Akun Administrator dibuat dengan flag `must_change_password = 1`. Administrator diwajibkan memperbarui password pada login pertama sebelum dapat membuka fitur operasional.
4. One-Time Execution Guard:
   Jika proses bootstrap dijalankan kembali, sistem mendeteksi keberadaan akun Administrator dan membatalkan proses secara graceful tanpa mengubah data yang ada (exit code 0).

---

## 7. Fresh Database Verification

Siklus inisialisasi dari basis data kosong diverifikasi pada stack MySQL 8.4.13 LTS:
1. Migrasi Skema:
   Service `migrator` mengeksekusi `prisma migrate deploy` pada database kosong, menghasilkan 14 tabel relasional:
   - `_prisma_migrations`, `categories`, `idempotency_records`, `inventory_balances`
   - `organizations`, `products`, `roles`, `sessions`
   - `stock_movements`, `stock_transaction_items`, `stock_transaction_sequences`
   - `stock_transactions`, `user_warehouse_assignments`, `users`, `warehouses`
2. CHECK Constraints Aktif (9 Aturan Database):
   - `chk_inventory_balance_quantity`: (`quantity` >= 0)
   - `chk_items_balance_after`: (`balance_after` >= 0)
   - `chk_items_balance_before`: (`balance_before` >= 0)
   - `chk_items_quantity`: (`quantity` > 0)
   - `chk_movements_balance_after`: (`balance_after` >= 0)
   - `chk_movements_balance_before`: (`balance_before` >= 0)
   - `chk_movements_quantity`: (`quantity` > 0)
   - `chk_products_cost_price`: ((`cost_price` is null) or (`cost_price` >= 0))
   - `chk_products_minimum_stock`: (`minimum_stock` >= 0)
3. Composite Foreign Keys (2 Kunci Relasional Terpadu):
   - Menghubungkan integritas warehouse dan product antar tabel transaksi.
4. Sanitasi Bukti:
   Seluruh command dan log pada `audit/evidence/database/fresh_bootstrap_evidence.txt` telah disanitasi dari password mentah (`-p[REDACTED]`).

---

## 8. Playwright E2E Results

Pengujian peramban Playwright dijalankan terhadap kontainer produksi yang berjalan pada `http://localhost:3000`:
1. Penghapusan Fallback Password Hardcoded:
   Fungsi `getInitialAdminPassword()` pada `frontend/tests/e2e/stockflow-lifecycle.spec.ts` diperbarui untuk membaca file secret secara ketat. Jika file tidak ada, fungsi langsung melempar error dan membatalkan pengujian.
2. Hasil Eksekusi Suite Playwright:
   - `P1-Playwright-01`: Memastikan secret file initial admin tersedia dan terbaca tanpa fallback hardcoded (LULUS, 9ms).
   - `P1-Playwright-02`: Memastikan fungsi melempar error jika secret file tidak ditemukan (LULUS, 2ms).
   - `Complete 13-stage inventory lifecycle workflow`: Menjalankan alur operasional penuh (LULUS, 8.1s).
   - Total waktu: 8.9 detik (3 passed, 0 failed, exit code 0).
3. Matriks Alur 13 Tahap yang Terverifikasi:
   - Stage 1: Admin Login dengan secret awal & Forced Password Change ke password permanen.
   - Stage 2: Pembuatan Kategori dan Produk dengan SKU acak.
   - Stage 3: Pembuatan Gudang Utama (assigned) dan Gudang Terlarang (unassigned).
   - Stage 4: Transaksi Stock In 50 unit barang masuk.
   - Stage 5: Verifikasi saldo inventaris bertambah menjadi 50 PCS.
   - Stage 6: Pembuatan akun Warehouse Staff dengan penugasan gudang.
   - Stage 7: Verifikasi hak akses penugasan gudang di modal user management.
   - Stage 8: Login staf gudang dan penyelesaian forced password change pertama.
   - Stage 9: Transaksi Stock Out 15 unit barang keluar.
   - Stage 10: Verifikasi ledger mutasi stok (+50, -15, sisa saldo 35).
   - Stage 11 & 12: Pengujian isolasi otorisasi gudang yang tidak ditugaskan (HTTP 403 Forbidden).
   - Stage 13: Transaksi Full Reversal dan pemulihan saldo akhir kembali ke 50 PCS.

---

## 9. Database Integrity

Integritas inventaris dan konsistensi transaksi StockFlow dijamin melalui:
1. Pessimistic Concurrency Locking:
   Query mutasi stok menggunakan `SELECT ... FOR UPDATE` pada tingkat row database InnoDB untuk mengunci saldo secara eksklusif selama transaksi berjalan, mencegah race condition akibat request paralel.
2. Pencegahan Saldo Negatif:
   Kombinasi validasi di service layer dan CHECK constraint tingkat mesin database memastikan saldo gudang tidak pernah menyentuh nilai di bawah nol.
3. Audit Ledger Immutable:
   Setiap transaksi masuk dan keluar dicatat secara permanen pada tabel `stock_movements` dengan snapshot saldo sebelum (`balance_before`) dan saldo sesudah (`balance_after`).
4. Full Reversal Transaksional:
   Pembatalan mutasi dilakukan melalui pembalikan penuh dengan mencatat transaksi penyeimbang baru yang merujuk pada `correction_of_transaction_id`, menjaga rantai audit tetap utuh tanpa penghapusan baris data.

---

## 10. Security Verification

Evaluasi keamanan berbasis threat model STRIDE dan checklist OWASP Top 10:
1. Broken Access Control (OWASP A01):
   Pemeriksaan otorisasi berbasis RBAC dan warehouse assignment scoping diuji di backend. Akses lintas gudang ditolak dengan HTTP 403 Forbidden.
2. Cryptographic Failures (OWASP A02):
   Password di-hash dengan bcrypt (cost factor 12). Token sesi di-hash dengan SHA-256 sebelum disimpan di tabel `sessions`. Tidak ada password dalam plain text.
3. Injection (OWASP A03):
   Prisma ORM menggunakan parameterized queries untuk seluruh operasi database. Penggunaan raw query pada concurrency locking memanfaatkan tagged template literals yang aman.
4. Security Misconfiguration (OWASP A05):
   Helmet mengamankan HTTP response headers. Binding port loopback `127.0.0.1:3000` mengeliminasi paparan jaringan luar.
5. Identification and Authentication Failures (OWASP A07):
   Pemberlakuan `must_change_password` memaksa penggantian password awal. Cookie sesi menggunakan flag `HttpOnly` dan `SameSite=Lax`.
6. Cross-Site Request Forgery (CSRF):
   Double-Submit Cookie CSRF (`sf_csrf` cookie dan `X-CSRF-Token` header) aktif pada seluruh endpoint mutasi state (POST, PUT, DELETE, PATCH).

---

## 11. Regression Testing

Seluruh test suite dijalankan ulang secara menyeluruh (full regression) dengan hasil 100% hijau:

| Komponen Pengujian | Metrik / Cakupan | Hasil Aktual | Status |
|---|---|---|---|
| **Backend Vitest Suite** | 11 file uji (Auth, Security, Concurrency, Rollback, Secret Bootstrap, Env Validation) | 95 tests passed, 0 failed | PASSED (Exit code 0) |
| **Frontend Vitest Suite** | 2 file uji (Formatters, Concurrency calculation, Ledger reconciliation, Reversal) | 9 tests passed, 0 failed | PASSED (Exit code 0) |
| **Playwright Browser E2E** | 3 skenario (Credential validation, zero fallback check, 13-stage lifecycle) | 3 tests passed in 8.9s | PASSED (Exit code 0) |
| **TypeScript Typecheck** | Backend & Frontend (`tsc --noEmit`) | 0 errors | PASSED (Exit code 0) |
| **ESLint Quality Gate** | Backend & Frontend (`eslint src/`) | 0 errors, 0 warnings | PASSED (Exit code 0) |
| **Dependency Security** | `npm audit` (Backend & Frontend) | 0 vulnerabilities | PASSED (Exit code 0) |
| **Persistent Volume** | Retensi data melintasi restart kontainer (`docker compose restart`) | Users=2, Products=1, Warehouses=2, Balances=1 | PASSED |

Total pengujian otomatis yang lulus: 107 test cases.

---

## 12. Docker Verification

Konfigurasi dan image kontainer diverifikasi siap pakai:
1. Docker Compose Configuration:
   `docker compose config` tervalidasi valid. Port frontend terikat ke `127.0.0.1:3000`, port backend dan database tertutup dari host.
2. Multi-Stage Production Build:
   - `stockflow-prod-backend`: Image runner ramping tanpa devDependencies (`npm ci --omit=dev`), berjalan dengan user `node`.
   - `stockflow-prod-frontend`: Artefak standalone Next.js 15, reverse proxy rewrite dikompilasi ke `http://backend:4000`.
   - `stockflow-prod-migrator`: Dedicated migrator kontainer yang mengeksekusi migrasi skema dan langsung exit dengan kode 0.
3. Healthcheck Probes:
   Service `db` dilengkapi healthcheck MySQL ping yang memverifikasi database siap sebelum migrator dan backend menyala.

---

## 13. Persistent Storage Verification

Pengujian penyimpanan persisten dilakukan dengan langkah:
1. Menjalankan pengujian Playwright E2E lengkap yang membuat 1 produk, 2 gudang, dan 1 mutasi inventaris.
2. Melakukan restart seluruh kontainer: `docker compose restart`.
3. Memeriksa ketersediaan API setelah booting: `http://localhost:3000/api/v1/health` mengembalikan HTTP 200 OK (`status: UP`, `database: CONNECTED`).
4. Menginspeksi database via backend runtime:
   Data terverifikasi utuh: 2 user, 1 produk, 2 gudang, dan 1 saldo inventaris persisten tersimpan di volume `mysql_prod_data`.

---

## 14. Git Information

Status repositori Git pada rilis v1.5:
- Branch Rilis: `fix/stockflow-localhost-final-v15`
- Base Commit: `d346f2d` (feat(release): StockFlow v1.4 Localhost Portfolio Edition)
- Working Tree: Bersih (Clean) tanpa file yang belum terkelola.
- Proteksi Sensitif `.gitignore`:
  File `.env`, `.secrets/`, `node_modules/`, `.next/`, `dist/`, dan `audit/` dikecualikan secara ketat dari pelacakan Git.

---

## 15. Remaining Limitations

StockFlow versi ini didesain dan dioptimalkan secara spesifik untuk portofolio lokal:
1. Single Host / Localhost Only: Aplikasi ditujukan untuk berjalan pada mesin pengembang lokal (`http://localhost:3000`).
2. Ketiadaan TLS/HTTPS Publik: Karena berjalan secara lokal, aplikasi menggunakan protokol HTTP dengan `COOKIE_SECURE=false`. Jika di masa mendatang akan dideploy ke cloud publik, `APP_DEPLOYMENT_MODE=production` dan `COOKIE_SECURE=true` wajib diaktifkan dengan sertifikat TLS/HTTPS yang valid.
3. Arsitektur Single-Instance: Concurrency control saat ini dioptimalkan untuk single database instance MySQL InnoDB menggunakan row-level locks, bukan untuk multi-master clustering atau distributed consensus.

---

## 16. Final Release Decision

Berdasarkan seluruh hasil pengujian faktual, verifikasi integritas data, isolasi jaringan loopback, otomasi kredensial kriptografis, dan sanitasi bukti audit:

Status Kelayakan Rilis:  
**LOCALHOST PORTFOLIO READY**

StockFlow telah memenuhi standar rekayasa perangkat lunak level produksi untuk aplikasi portofolio Full-Stack yang aman, stabil, andal, dan siap didemokan secara profesional.
