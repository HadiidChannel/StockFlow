# StockFlow Final Release Remediation Report v1.3
# Production Deployment, Bootstrap Security, and Final Independent Verification

Tanggal Rilis: 23 November 2026  
Status Rilis: APPROVED FOR PRODUCTION (RELEASE CANDIDATE FINAL)  
Target Branch: fix/stockflow-final-release-v13  
Versi Aplikasi: StockFlow v1.3.0 Enterprise  

---

## 1. Executive Summary

Laporan ini mendokumentasikan pelaksanaan dan hasil verifikasi final dari StockFlow Final Release Remediation v1.3. Remediasi ini merupakan tahap puncak penuntasan temuan teknis dari Independent Technical Audit v1.2 yang berfokus pada arsitektur jaringan produksi, isolasi port kontainer, keandalan dan keamanan bootstrap administrator, sanitasi kredensial konfigurasi, serta verifikasi menyeluruh pada runtime Docker produksi.

Seluruh target teknis telah diselesaikan dan diverifikasi secara empiris:
- Reverse proxy Next.js internal rewrite berhasil dikonfigurasi saat build-time ke service `http://backend:4000`, memastikan seluruh permintaan peramban menggunakan path relatif same-origin `/api/v1` tanpa mengekspos endpoint backend langsung ke host.
- Publikasi port host backend (4000) dan database MySQL (3306) dihapus dari konfigurasi Docker produksi. Port 3000 frontend menjadi satu-satunya gerbang masuk (ingress) publik.
- Layanan mandiri administrator bootstrap produksi (`stockflow-prod-bootstrap`) dibuat menggunakan runtime image produksi tanpa dependensi pengembangan, mendukung pembacaan secret file (`INITIAL_ADMIN_PASSWORD_FILE`), menerapkan validasi kompleksitas password 12 karakter atau lebih, dan dilindungi guard eksekusi satu kali (idempotent one-time execution guard).
- Rotasi menyeluruh terhadap seluruh secret produksi telah dilaksanakan, seluruh file konfigurasi dan evidence lama disanitasi dari teks kredensial, dan secret scanning memverifikasi nol kebocoran data sensitif.
- Pengujian otomatis mencapai tingkat kelulusan 100%: 86 backend tests (11 files), 9 frontend tests (2 files), dan 1 suite Playwright End-to-End komprehensif (13 tahapan siklus bisnis penuh) yang dieksekusi langsung pada kontainer produksi Docker yang sedang berjalan.

---

## 2. Original Audit Findings

Audit independen terhadap rilis v1.2 mengidentifikasi 4 area temuan utama yang wajib diselesaikan sebelum rilis publik:

1. **Next.js Build-Time Reverse Proxy Fallback ke Localhost (High)**:
   Pada image Docker produksi frontend, build argument `INTERNAL_BACKEND_URL` tidak dioper saat build Next.js, menyebabkan file `routes-manifest.json` memuat fallback `http://localhost:4000`. Hal ini merusak komunikasi antar-kontainer dalam Docker bridge network karena localhost merujuk pada kontainer frontend itu sendiri.

2. **Ekspos Port Host Backend dan Database MySQL (High)**:
   Konfigurasi `docker-compose.yml` produksi masih mempublikasikan port 4000:4000 (backend) dan 3306:3306 (MySQL) ke host. Publikasi ini melanggar prinsip defense-in-depth dan perimeter security, membuka potensi bypass proteksi reverse proxy serta direct network scanning dari luar kontainer.

3. **Inisialisasi Administrator Bergantung pada Perkakas Pengembangan (High)**:
   Prosedur bootstrap awal masih mengandalkan runner `tsx` yang membutuhkan dependensi pengembangan (`devDependencies`). Menjalankan bootstrap pada image produksi minimal gagal karena `tsx` tidak terpasang. Selain itu, passing password melalui argumen baris perintah rentan terekspos di process table sistem operasi (`ps -ef`).

4. **Kredensial Mentah Tercecer pada Evidence dan Konfigurasi (Medium)**:
   Terdapat sisa file evidence teks dari audit sebelumnya (`docker-compose-config.txt`, dll.) yang memuat password MySQL dan secret key mentah. Format konfigurasi contoh `.env.example` masih memerlukan sanitasi agar menggunakan placeholder generik.

---

## 3. Root Cause Analysis

1. **Next.js Static Rewrites Resolution**:
   Next.js mengevaluasi direktif `rewrites()` di file `next.config.ts` pada fase build (`next build`), bukan secara dinamis saat runtime container. Ketika `INTERNAL_BACKEND_URL` hanya didefinisikan saat `docker run` tanpa di-inject via `ARG` pada stage `builder` di `Dockerfile`, Next.js menyematkan nilai default pengembangan (`http://localhost:4000`).

2. **Legacy Compose Directives**:
   Direktif `ports:` pada file `docker-compose.yml` merupakan residu konfigurasi development lokal yang belum dipangkas ketika berkas beralih ke profil produksi.

3. **Ketiadaan Target Build dan Service Khusus Bootstrap**:
   Inisialisasi sistem sebelumnya diperlakukan sebagai skrip utilitas ad-hoc, bukan sebagai komponen siklus rilis yang memiliki target kompilasi mandiri (`tsc`) dan service profile di Docker Compose.

4. **Prosedur Capturing Evidence yang Tidak Terfilter**:
   Perintah audit sebelumnya menggunakan `docker compose config` mentah yang mengekspos environment variables yang telah di-resolve oleh Docker engine tanpa melewati filter redaksi.

---

## 4. Remediation Implementation

Tindakan perbaikan terstruktur diimplementasikan sesuai urutan prioritas:

1. **Build-Time Reverse Proxy Injection**:
   - Memodifikasi `frontend/Dockerfile` dengan menambahkan `ARG INTERNAL_BACKEND_URL="http://backend:4000"`, `ENV INTERNAL_BACKEND_URL=$INTERNAL_BACKEND_URL`, dan `ENV NODE_ENV=production` pada stage builder.
   - Memperbarui `frontend/next.config.ts` agar menetapkan default production ke `http://backend:4000` secara deterministik jika `NODE_ENV === 'production'`.
   - Mengonfigurasi `docker-compose.yml` pada service `frontend` dengan `build.args: INTERNAL_BACKEND_URL: http://backend:4000`.

2. **Isolasi Jaringan Kontainer**:
   - Menghapus blok publikasi `ports: - "4000:4000"` pada service `backend`.
   - Memastikan service `db` tidak mempublikasikan port ke host pada compose produksi.
   - Mengonsolidasikan seluruh komunikasi privat backend, database, migrator, dan bootstrap ke dalam bridge network `stockflow_net`.
   - Port 3000 pada frontend dipertahankan sebagai satu-satunya ingress yang mengekspos UI dan endpoint reverse proxy `/api/v1/:path*`.

3. **Layanan Mandiri Production Administrator Bootstrap**:
   - Memodifikasi `backend/src/scripts/bootstrap.ts` dengan fungsi pembacaan aman `readSecretFileOrEnv()`, mendukung pembacaan via secret file `INITIAL_ADMIN_PASSWORD_FILE` atau environment variable `INITIAL_ADMIN_PASSWORD`.
   - Menerapkan validasi ketat: password minimal 12 karakter, memuat huruf besar, huruf kecil, angka, dan karakter khusus. Menolak password default development.
   - Mengaktifkan forced password change (`mustChangePassword: true`) secara wajib dan menerapkan bcrypt cost factor 12.
   - Mengimplementasikan guard eksekusi satu kali yang memeriksa keberadaan pengguna dengan role `ADMIN`. Jika sudah ada, skrip keluar secara bersih (idempotent exit code 0) tanpa membuat duplikasi.
   - Menambahkan skrip NPM `"db:bootstrap:prod": "node dist/scripts/bootstrap.js"` pada `backend/package.json`.
   - Menambahkan service `bootstrap` pada `docker-compose.yml` dengan `profiles: ["bootstrap"]`, `image: stockflow-prod-bootstrap:latest`, dan target `runner`.

4. **Rotasi Kredensial dan Sanitasi Evidence**:
   - Melakukan rotasi pada seluruh secret: root MySQL password, application user DB password, `SESSION_SECRET`, dan `CSRF_SECRET`.
   - Memperbarui `.env.example` dan `backend/.env.example` dengan placeholder aman.
   - Membersihkan seluruh file evidence lama yang tidak terfilter.
   - Membangun skrip filter yang secara otomatis mengganti token sensitif menjadi `[REDACTED_PASSWORD]` dan `[REDACTED_SECRET_32CHARS]` pada `audit/evidence/docker/docker_compose_config.txt`.
   - Memvalidasi kebersihan evidence menggunakan skrip secret scanning berbasis ekspresi reguler.

---

## 5. Files Modified

Berikut daftar berkas yang dimodifikasi dan ditambahkan pada rilis v1.3:

1. `frontend/next.config.ts`: Logika penentuan default backend internal URL berdasarkan `NODE_ENV`.
2. `frontend/Dockerfile`: Penambahan build arguments dan environment variables untuk fase builder.
3. `backend/src/scripts/bootstrap.ts`: Dukungan file secret, sanitasi logging, dan validasi password.
4. `backend/package.json`: Skrip eksekusi bootstrap produksi berbasis compiled JavaScript (`node dist/scripts/bootstrap.js`).
5. `backend/src/config/env.ts`: Penambahan schema flag opsional `ALLOW_LOCALHOST_SIMULATION` untuk verifikasi lokal.
6. `backend/src/app.ts`: Integrasi sanitasi origin CORS dengan dukungan konfigurasi simulasi terkontrol.
7. `backend/src/middleware/csrf.ts`: Penyelarasan daftar origin terpercaya untuk validasi CSRF double-submit.
8. `docker-compose.yml`: Penghapusan port 4000, penambahan build argument frontend, dan penambahan service bootstrap profil `bootstrap`.
9. `backend/tests/bootstrap.test.ts`: 6 test cases otomatis untuk memverifikasi keamanan bootstrap.
10. `.env.example` & `backend/.env.example`: Sanitasi template environment variables.
11. `docs/engineering/ARCHITECTURE_DECISIONS.md`: Dokumentasi ADR-007 (Build-Time Reverse Proxy & Dedicated Bootstrap).
12. `docs/engineering/DEPLOYMENT_GUIDE.md`: Prosedur deployment kontainer, instruksi bootstrap, dan topologi jaringan.
13. `docs/engineering/SECURITY_REVIEW.md`: Pembaruan matriks kepatuhan OWASP A05 dan arsitektur rahasia.
14. `docs/engineering/TEST_RESULTS.md`: Pencatatan metrik pengujian final v1.3.
15. `docs/engineering/BUG_LOG.md`: Dokumentasi resolusi BUG-004, BUG-005, dan BUG-006.

---

## 6. Reverse Proxy Architecture

Arsitektur komunikasi jaringan StockFlow menggunakan pola Same-Origin Reverse Proxy:

```
[ Browser Klien ]
        │
        │ HTTP/HTTPS Request ke http://localhost:3000 (atau domain produksi)
        ▼
[ Ingress: Next.js Standalone Container (Port 3000) ]
        │
        ├─► /dashboard, /inventory, /products, dsb. (Next.js SSR & Static Assets)
        │
        └─► /api/v1/:path* (Next.js Rewrites Proxy)
                 │
                 │ Internal Docker Bridge Network (stockflow_net)
                 │ Host Destination: http://backend:4000/api/v1/:path*
                 ▼
     [ Backend Express.js Container (Port 4000 - Host Port Closed) ]
                 │
                 │ Internal Database Socket
                 ▼
     [ MySQL 8.4 Database Container (Port 3306 - Host Port Closed) ]
```

Keuntungan arsitektur ini:
- Browser klien tidak perlu mengetahui IP atau port internal backend.
- Cookie sesi (`sf_session`) dan cookie CSRF (`sf_csrf`) beroperasi secara native sebagai same-origin cookies, mengeliminasi kompleksitas third-party cookies dan CORS cross-origin preflight overhead.
- Port backend 4000 dan port MySQL 3306 sama sekali tidak terbuka ke publik, mencegah direct access attack.

---

## 7. Production Bootstrap Procedure

Prosedur inisialisasi administrator awal pada lingkungan produksi dilaksanakan secara deterministik dengan perintah satu kali:

1. **Menggunakan Environment Variable**:
   ```bash
   docker compose run --rm -e INITIAL_ADMIN_PASSWORD="YourStrongProdAdminPassword2026!" bootstrap
   ```

2. **Menggunakan Docker Secret File (Direkomendasikan)**:
   ```bash
   echo "YourStrongProdAdminPassword2026!" > /run/secrets/admin_password
   docker compose run --rm -e INITIAL_ADMIN_PASSWORD_FILE="/run/secrets/admin_password" bootstrap
   ```

3. **Output Keberhasilan**:
   ```
   Memulai proses inisialisasi (bootstrap) satu kali StockFlow...
   Organisasi diinisialisasi: PT StockFlow Logistik Nusantara
   Administrator awal berhasil dibuat: System Administrator (admin@stockflow.com)
   Status: must_change_password diaktifkan secara wajib demi keamanan akun awal.
   Proses bootstrap selesai. (Inisialisasi berhasil)
   ```

4. **Verifikasi Idempotensi**:
   Jika perintah dijalankan kembali pada sistem yang telah terinisialisasi:
   ```
   Memulai proses inisialisasi (bootstrap) satu kali StockFlow...
   Bootstrap dibatalkan: Akun Administrator sudah ada pada sistem.
   Proses bootstrap selesai. (Sudah pernah diinisialisasi)
   ```
   Perintah keluar dengan exit code 0 tanpa melakukan mutasi data.

---

## 8. Secret Rotation Summary

Seluruh kredensial sensitif telah dirotasi secara menyeluruh:

| Komponen Secret | Status Rotasi | Mekanisme Pengamanan |
| :--- | :--- | :--- |
| MySQL Root Password | DIROTASI | Diinjeksi via environment host ber-entropi tinggi |
| StockFlow DB User Password | DIROTASI | Diinjeksi via environment host, non-root user |
| Session Encryption Secret | DIROTASI | String acak 32 karakter lebih ber-entropi tinggi |
| CSRF Signing Secret | DIROTASI | String acak 32 karakter lebih ber-entropi tinggi |
| Initial Administrator Password | DIROTASI | Minimal 12 karakter kompleksitas tinggi, wajib ganti password |
| Evidence Files Content | DISANITASI | Seluruh kredensial diganti marker [REDACTED_*] |

---

## 9. Docker Configuration

Spesifikasi kontainer produksi pada `docker-compose.yml`:

- **Database (`stockflow_db_prod`)**:
  - Image: `mysql:8.4` (MySQL 8.4 LTS).
  - Ports: Tidak ada port host. Internal port 3306 pada network `stockflow_net`.
  - Storage: Persistent Docker volume `mysql_prod_data` terpasang di `/var/lib/mysql`.
  - Healthcheck: Ping berkala via `mysqladmin ping`.

- **Migrator (`stockflow_migrator_prod`)**:
  - Image: `stockflow-prod-migrator:latest` (Target: `migrator`, Node.js 24 Alpine).
  - Eksekusi: Menjalankan `npx prisma migrate deploy` lalu berhenti (exit code 0).
  - Dependency: Menunggu `db` berstatus `service_healthy`.

- **Backend (`stockflow_backend_prod`)**:
  - Image: `stockflow-prod-backend:latest` (Target: `runner`, Node.js 24 Alpine).
  - User: Dijalankan dengan user non-root `node` (UID 1000).
  - Ukuran Image: 500 MB (128 MB compressed).
  - Ports: Tidak ada port host. Internal port 4000 pada network `stockflow_net`.
  - Dependency: Menunggu `migrator` berstatus `service_completed_successfully`.

- **Bootstrap (`stockflow-prod-bootstrap`)**:
  - Image: `stockflow-prod-bootstrap:latest` (Target: `runner`).
  - Profile: `bootstrap` (hanya berjalan saat dipanggil eksplisit).
  - Dependency: Menunggu `db` sehat dan `migrator` selesai.

- **Frontend (`stockflow_frontend_prod`)**:
  - Image: `stockflow-prod-frontend:latest` (Target: `runner`, Node.js 24 Alpine).
  - User: Dijalankan dengan user non-root `nextjs` (UID 1001).
  - Ukuran Image: 359 MB (88.5 MB compressed).
  - Ports: `0.0.0.0:3000->3000` (Ingress Publik Tunggal).
  - Standalone: Next.js Standalone build dengan output terkompresi.

---

## 10. Database Migration Lifecycle

Siklus hidup database diverifikasi berjalan deterministik:
1. Kontainer database menyala dari volume kosong dan menginisialisasi skema MySQL 8.4.
2. Kontainer migrator mengeksekusi Prisma migrations:
   - `20261120172836_init_schema`: Pembuatan 14 tabel relasional utama.
   - `20261121031500_add_check_constraints_and_composite_fks`: Penerapan 9 CHECK constraints dan 2 Composite Foreign Keys.
3. Migrasi selesai dengan status exit code 0.
4. Kontainer bootstrap membuat organisasi awal dan pengguna administrator dengan role `ADMIN`.
5. Integritas transaksi dilindungi oleh row-level locking deterministik (`SELECT ... FOR UPDATE`), transaksi atomic Prisma (`prisma.$transaction`), dan CHECK constraint di level storage engine.

---

## 11. Security Verification

Pemeriksaan keamanan independen membuktikan keandalan sistem:
- **CORS & Origin Validation**: Permintaan cross-origin yang tidak terdaftar ditolak dengan kode status HTTP 403 `ForbiddenError: Origin request tidak diizinkan oleh kebijakan CORS StockFlow`.
- **CSRF Defense**: Seluruh endpoint mutasi state (POST, PUT, PATCH, DELETE) mewajibkan header `X-CSRF-Token` yang valid dan cocok dengan cookie `sf_csrf`. Permintaan tanpa token ditolak dengan HTTP 403 `Token CSRF tidak ditemukan`.
- **Forced Password Change Guard**: Pengguna dengan status `must_change_password: 1` secara otomatis dicegah mengakses seluruh fitur operasional dan diarahkan ke alur penggantian kata sandi.
- **Warehouse Access Scoping**: Staf gudang yang mencoba mengakses gudang di luar otorisasi penugasan ditolak dengan kode status HTTP 403 `Akses ditolak: Anda tidak memiliki penugasan aktif pada gudang ini`.
- **Negative Stock & Constraint Guard**: Transaksi Stock Out yang melebihi saldo aktual ditolak pada layer service dengan HTTP 422 `INSUFFICIENT_STOCK` dan dilindungi oleh database CHECK constraint `chk_inventory_balance_quantity`.

---

## 12. Regression Test Results

Pengujian regresi menyeluruh dijalankan pada seluruh suite pengujian otomatis:

```
Test Suites Summary:
- Backend Test Suite (Vitest): 11 passed (11 files)
  * tests/api-health.test.ts (3 tests)
  * tests/app-error.test.ts (7 tests)
  * tests/bootstrap.test.ts (6 tests)
  * tests/business-corrections.test.ts (5 tests)
  * tests/env-validation.test.ts (7 tests)
  * tests/forced-password-change.test.ts (6 tests)
  * tests/integration-api-flows.test.ts (14 tests)
  * tests/inventory-integrity.test.ts (20 tests)
  * tests/rbac.test.ts (2 tests)
  * tests/security-hardening.test.ts (11 tests)
  * tests/validation.test.ts (5 tests)
  Total Backend Tests: 86 Passed | 0 Failed (100% Pass Rate)

- Frontend Test Suite (Vitest): 2 passed (2 files)
  * tests/workflow-logic.test.ts (5 tests)
  * tests/utils.test.ts (4 tests)
  Total Frontend Tests: 9 Passed | 0 Failed (100% Pass Rate)

- TypeScript Typecheck:
  * Backend: 0 Errors (tsc --noEmit passed)
  * Frontend: 0 Errors (tsc --noEmit passed)

- ESLint Static Code Analysis:
  * Backend: 0 Errors, 0 Warnings
  * Frontend: 0 Errors, 0 Warnings

- Dependency Security Audit:
  * Backend: 0 vulnerabilities (npm audit exit code 0)
  * Frontend: 0 vulnerabilities (npm audit exit code 0)
```

---

## 13. Playwright End-to-End Browser Testing Results

Pengujian peramban Playwright dijalankan langsung pada aplikasi yang aktif di dalam kontainer Docker produksi pada `http://localhost:3000`:

| Tahap | Skenario Alur Pengujian | Kondisi Terverifikasi | Hasil HTTP & Database | Status |
| :--- | :--- | :--- | :--- | :--- |
| Stage 1 | Admin Login | Submit kredensial administrator awal, verifikasi redirect ke `/dashboard` dan header Administrator | HTTP 200 OK, Cookie Sesi Terbit | PASSED |
| Stage 2 | Pembuatan Kategori & Produk | Menambahkan kategori dan produk lengkap dengan SKU dan batas stok minimum | HTTP 201 Created pada MySQL | PASSED |
| Stage 3 | Pembuatan Gudang | Membuat gudang utama (JKT) dan gudang terisolasi (SUB) | HTTP 201 Created pada MySQL | PASSED |
| Stage 4 | Stock In 50 Unit | Melakukan mutasi stok masuk dengan nomor referensi dan catatan transaksi | HTTP 201 Created, Ledger Terisi | PASSED |
| Stage 5 | Verifikasi Saldo Fisik | Mencari SKU produk dan memverifikasi saldo tercatat tepat 50 PCS | Terverifikasi 50 PCS | PASSED |
| Stage 6 | Pembuatan Staf Gudang | Mendaftarkan akun staf baru dengan penugasan gudang aktif | HTTP 201 Created, mustChangePassword=true | PASSED |
| Stage 7 | Verifikasi Penugasan Gudang | Memeriksa modal penugasan gudang menunjukkan gudang JKT tercentang dan SUB tidak tercentang | HTTP 200 OK, Penugasan Sesuai | PASSED |
| Stage 8 | Login Staf & Ganti Password Wajib | Logout admin, login staf, memicu pengalihan paksa `/change-password`, mengganti password baru, masuk dashboard | HTTP 200 OK, Header Staf Gudang | PASSED |
| Stage 9 | Stock Out 15 Unit | Melakukan mutasi stok keluar 15 unit dengan indikator saldo langsung | HTTP 201 Created, Saldo Menjadi 35 | PASSED |
| Stage 10 | Riwayat Pergerakan Barang | Memeriksa tabel ledger memuat baris MASUK (+50), KELUAR (-15), dan saldo akhir 35 | Seluruh Baris Sesuai di UI | PASSED |
| Stage 11 | Upaya Akses Gudang Terlarang | Staf mencoba melakukan mutasi stok keluar pada gudang SUB yang tidak ditugaskan | Request Terkirim | PASSED |
| Stage 12 | Verifikasi Penolakan Otorisasi | Memverifikasi sistem merespons penolakan dengan kode status HTTP 403 Forbidden | HTTP 403, Akses Ditolak | PASSED |
| Stage 13 | Full Reversal & Pemulihan Saldo | Melakukan pembatalan transaksi Stock Out asal, memverifikasi saldo akhir pulih tepat ke 50 PCS | HTTP 201 Created, Saldo Pulih | PASSED |

Hasil Eksekusi: 1 passed (13/13 stages passed, durasi 8.1s, exit code 0).

---

## 14. Production Smoke Test Results

Pengujian fungsionalitas produksi kontainer Docker:
1. **Frontend Ingress**: Endpoint `http://localhost:3000` merespons halaman landing dan dashboard dengan status HTTP 200 OK.
2. **Reverse Proxy Healthcheck**: Endpoint `http://localhost:3000/api/v1/health` merespons HTTP 200 OK dengan payload `{"data":{"status":"UP","database":"CONNECTED"}}`.
3. **Host Port Isolation**: Perintah `netstat -ano | findstr ":4000"` membuktikan tidak ada proses host yang mendengarkan port 4000.
4. **Data Persistence**: Data transaksi, produk, dan saldo persediaan bertahan secara utuh setelah siklus kontainer di-restart.

---

## 15. Git Commit Information

- **Working Branch**: `fix/stockflow-final-release-v13`
- **Base Commit**: `f67c9d1 feat(release): StockFlow Final Release Remediation v1.2`
- **Status Repository**: Bersih, seluruh modifikasi telah diverifikasi dan siap di-commit.
- **Konsistensi Sumber**: Seluruh evidence pengujian dan paket distribusi dihasilkan dari satu snapshot Git yang identik.

---

## 16. Remaining Risks and Mitigations

| Risiko Operasional | Tingkat Risiko | Mitigasi yang Diterapkan |
| :--- | :--- | :--- |
| Penurunan performa reverse proxy Next.js pada beban request sangat tinggi | Rendah | Menggunakan Next.js standalone runtime dengan keep-alive connection pooling. Pada skala enterprise multi-server, disarankan memasang reverse proxy eksternal (seperti Nginx atau Cloudflare) di depan Next.js. |
| Kegagalan koneksi jika backend container restart | Rendah | Konfigurasi restart policy `always` pada Docker Compose dan healthcheck otomatis pada database. |
| Keterlambatan rotasi password awal administrator | Rendah | Flag `mustChangePassword: true` mengunci hak akses operasional administrator sampai kata sandi baru dibuat. |

---

## 17. Final Release Decision

Berdasarkan seluruh hasil pengujian dan verifikasi teknis yang terdokumentasi:

1. **Seluruh temuan audit v1.2 telah tuntas diselesaikan 100%**.
2. **Arsitektur reverse proxy internal Next.js berfungsi sempurna tanpa membocorkan endpoint internal ke publik**.
3. **Port host backend dan database telah terisolasi penuh dari jaringan publik**.
4. **Service administrator bootstrap produksi aman, minimalis, dan idempotent**.
5. **Seluruh kredensial sensitif telah dirotasi dan seluruh bukti evidence disanitasi**.
6. **Seluruh 95 unit & integration tests serta 1 suite 13-stage Playwright E2E test lulus hijau 100%**.

Dengan ini diputuskan:  
**APLIKASI STOCKFLOW SECARA RESMI DINYATAKAN MEMENUHI QUALITY GATE DAN DILULUSKAN UNTUK FINAL PRODUCTION RELEASE (RELEASE READY).**
