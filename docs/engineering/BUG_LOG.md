# StockFlow Bug Management & Issue Tracking Log

Dokumen ini mencatat setiap bug atau kegagalan sistem yang ditemukan selama pengembangan, langkah reproduksi, akar penyebab (root cause), perbaikan, dan status regresi.

---

## Format Pencatatan Bug
- **ID**: `BUG-XXX`
- **Severity**: Critical / High / Medium / Low
- **Deskripsi**: Penjelasan ringkas masalah
- **Steps to Reproduce**: Langkah-langkah mereproduksi bug
- **Root Cause**: Analisis teknis penyebab mendasar masalah
- **Fix**: Solusi teknis yang diimplementasikan
- **Regression Test**: Test case otomatis yang dibuat untuk mencegah masalah berulang
- **Status**: Open / Investigating / Fixed & Verified

---

## Daftar Bug & Resolusi

### BUG-001: Prisma Shadow Database Permission Denial
- **Severity**: High
- **Deskripsi**: Perintah `prisma migrate dev` gagal saat mencoba membuat database sementara (`prisma_migrate_shadow_db_*`) dengan kode error P3014 / P1010.
- **Steps to Reproduce**: Menjalankan migrasi Prisma awal pada MySQL lokal dengan user database yang hanya memiliki akses scope `stockflow_db.*`.
- **Root Cause**: Prisma Migrate membutuhkan hak akses `CREATE DATABASE` dan `DROP DATABASE` di level global untuk membuat shadow database demi memverifikasi idempotensi file migrasi.
- **Fix**: Memberikan privilege `GRANT ALL PRIVILEGES ON *.* TO 'stockflow_user'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;` melalui user root.
- **Regression Test**: `npx prisma migrate dev` berhasil membuat dan menerapkan migrasi `init_schema`.
- **Status**: Fixed & Verified

### BUG-002: TypeScript Interface Mismatch pada Flattened Movement Ledger
- **Severity**: Medium
- **Deskripsi**: Build frontend Next.js sempat gagal karena properti `referenceNumber`, `productName`, `sku`, dan `warehouseName` tidak ditemukan pada tipe `StockMovement`.
- **Steps to Reproduce**: Menjalankan `next build` pada halaman `/movements`.
- **Root Cause**: API backend mengembalikan struktur pergerakan yang sudah di-flatten (dilebarkan) untuk performa rendering tabel, sedangkan interface `StockMovement` di frontend sebelumnya mengasumsikan relasi bertingkat (`item.transaction.referenceNumber`).
- **Fix**: Memperbarui interface `StockMovement` pada `frontend/src/types/index.ts` agar mencakup properti flattened yang dikirim backend.
- **Regression Test**: `npm run typecheck` dan `npm run build` frontend berhasil 100% tanpa error.
- **Status**: Fixed & Verified

### BUG-003: Chrome DevTools MCP Port Sync Desynchronization
- **Severity**: Medium
- **Deskripsi**: Subagent browser gagal tersambung ke Chrome DevTools MCP dengan error `Invalid DevToolsActivePort '9222\n' found`.
- **Steps to Reproduce**: Menjalankan subagent browser saat file `DevToolsActivePort` hanya memuat nomor port tanpa websocket path di baris kedua.
- **Root Cause**: Chrome DevTools MCP mensyaratkan tepat 2 baris: baris 1 nomor port (`9222`) dan baris 2 path websocket riil (`/devtools/browser/<guid>`).
- **Fix**: Mengimplementasikan script background daemon `scripts/chrome-daemon.js` yang menjaga Chrome tetap berjalan dan secara otomatis mengekstrak `pathname` dari endpoint `/json/version` ke dalam `DevToolsActivePort`.
- **Regression Test**: Subagent browser berhasil tersambung, melakukan navigasi, dan mengambil screenshot seluruh halaman.
- **Status**: Fixed & Verified

### BUG-004: Next.js Build-Time Reverse Proxy Fallback ke Localhost
- **Severity**: High
- **Deskripsi**: Reverse proxy rewrite Next.js menghasilkan fallback ke `http://localhost:4000` di dalam image Docker production jika environment variable build tidak disuplai secara eksplisit.
- **Steps to Reproduce**: Menjalankan build Docker frontend tanpa build argument `INTERNAL_BACKEND_URL`.
- **Root Cause**: File `next.config.ts` membaca variabel yang tidak di-inject pada fase build Next.js sehingga `routes-manifest.json` mengekspos destination localhost yang tidak dapat diakses di dalam container jaringan Docker.
- **Fix**: Menambahkan `ARG INTERNAL_BACKEND_URL="http://backend:4000"` pada `frontend/Dockerfile` dan menyetel default production rewrite ke service name `http://backend:4000`.
- **Regression Test**: File `.next/routes-manifest.json` tervalidasi memuat `destination: http://backend:4000/api/v1/:path*`.
- **Status**: Fixed & Verified

### BUG-005: Publikasi Port Host Backend dan Database pada Konfigurasi Production
- **Severity**: High
- **Deskripsi**: File `docker-compose.yml` mengekspos port 4000 backend dan port 3306 database secara langsung ke jaringan host.
- **Steps to Reproduce**: Memeriksa direktif `ports` pada service backend dan db di `docker-compose.yml`.
- **Root Cause**: Konfigurasi port development terbawa ke dalam konfigurasi production Docker compose.
- **Fix**: Menghapus publikasi host port untuk backend dan db. Hanya port 3000 frontend yang dipublikasikan sebagai ingress tunggal. Komunikasi backend dan database berlangsung privat di jaringan Docker internal `stockflow_net`.
- **Regression Test**: Perintah `netstat -ano | findstr ":4000"` membuktikan tidak ada listener host pada port 4000.
- **Status**: Fixed & Verified

### BUG-006: Inisialisasi Administrator Awal Bergantung pada Dev Dependencies dan Rentan Bocor
- **Severity**: High
- **Deskripsi**: Skrip inisialisasi administrator awal dijalankan dengan `tsx` yang tidak tersedia pada runner image production, rentan membocorkan password di argumen terminal, dan tidak memiliki proteksi eksekusi berulang.
- **Steps to Reproduce**: Menjalankan skrip inisialisasi awal pada image production tanpa dependensi dev.
- **Root Cause**: Ketiadaan service inisialisasi mandiri pada konfigurasi Docker compose serta validasi kredensial yang lemah.
- **Fix**: Membuat service mandiri `bootstrap` (`profiles: ["bootstrap"]`) dengan runner image production compiled (`node dist/scripts/bootstrap.js`), mendukung pembacaan secret file (`INITIAL_ADMIN_PASSWORD_FILE`), menerapkan validasi kompleksitas password 12+ karakter, dan memasang one-time execution guard.
- **Regression Test**: Test suite `backend/tests/bootstrap.test.ts` (6 automated tests) dan eksekusi Docker runner compose memverifikasi seluruh kriteria keamanan.
- **Status**: Fixed & Verified

### BUG-007: Kerentanan Flag ALLOW_LOCALHOST_SIMULATION pada Kebijakan Origin
- **Severity**: Medium
- **Deskripsi**: Penggunaan flag `ALLOW_LOCALHOST_SIMULATION=true` berpotensi membuka celah keamanan karena mengubah trusted origin secara ad-hoc saat `NODE_ENV=production`.
- **Steps to Reproduce**: Memeriksa konfigurasi CORS allowlist ketika flag simulasi diaktifkan pada mode production.
- **Root Cause**: Ketiadaan pemisahan eksplisit antara build mode (`NODE_ENV`) dan deployment target (`APP_DEPLOYMENT_MODE`).
- **Fix**: Menghapus flag `ALLOW_LOCALHOST_SIMULATION` dari seluruh sistem. Memperkenalkan `APP_DEPLOYMENT_MODE=local` yang secara eksplisit dan terkontrol mengizinkan canonical origin `http://localhost:3000`.
- **Regression Test**: Test suite `env-validation.test.ts` dan `security-hardening.test.ts` memverifikasi penolakan origin selain canonical `http://localhost:3000`.
- **Status**: Fixed & Verified

### BUG-008: Ketiadaan Definisi Top-Level Docker Compose Secrets pada Bootstrap
- **Severity**: Medium
- **Deskripsi**: Service bootstrap sebelumnya membaca environment variable `INITIAL_ADMIN_PASSWORD_FILE` namun `docker-compose.yml` belum mendefinisikan top-level `secrets` sehingga file secret belum termount secara otomatis ke kontainer.
- **Steps to Reproduce**: Menjalankan compose bootstrap tanpa menyuplai volume mount manual untuk file secret.
- **Root Cause**: Konfigurasi Docker Compose belum mengimplementasikan spesifikasi Docker Compose Secrets.
- **Fix**: Menambahkan blok top-level `secrets` pada `docker-compose.yml`, mengaitkan secret `initial_admin_password` ke service `bootstrap`, mengabaikan folder `.secrets/` pada `.gitignore`, dan memperbarui `bootstrap.ts` agar menolak password melalui environment variable biasa.
- **Regression Test**: Eksekusi `docker compose --profile bootstrap run --rm bootstrap` dan 8 unit test di `backend/tests/bootstrap.test.ts` lulus 100%.
- **Status**: Fixed & Verified

### BUG-009: Binding Port Frontend Docker Compose Mengekspos Host Interface 0.0.0.0
- **Severity**: Medium
- **Deskripsi**: Pemetaan port frontend sebelumnya menggunakan `"3000:3000"` yang menyebabkan Docker mempublikasikan port ke seluruh host interface (`0.0.0.0`), membuka kemungkinan akses tidak sengaja dari LAN.
- **Steps to Reproduce**: Memeriksa output `docker compose port frontend 3000` atau `Get-NetTCPConnection` pada port 3000.
- **Root Cause**: Ketiadaan binding host IP loopback yang eksplisit pada konfigurasi port Compose.
- **Fix**: Mengubah port mapping frontend pada `docker-compose.yml` menjadi `"127.0.0.1:3000:3000"`.
- **Regression Test**: Perintah `docker compose port frontend 3000` dan `Get-NetTCPConnection -LocalPort 3000` membuktikan port 3000 terikat secara eksklusif ke `127.0.0.1`.
- **Status**: Fixed & Verified

### BUG-010: Kerentanan Fallback Password Hardcoded pada E2E dan Ketiadaan Script Generator Lokal
- **Severity**: Medium
- **Deskripsi**: Helper Playwright `getInitialAdminPassword()` memuat password fallback hardcoded jika file secret tidak ditemukan, dan konfigurasi lokal masih bergantung pada pembuatan secret manual yang rawan placeholder.
- **Steps to Reproduce**: Menjalankan pengujian E2E saat file secret tidak ada, helper tetap mengembalikan password hardcoded tanpa error.
- **Root Cause**: Ketiadaan generator lingkungan kriptografis dan toleransi fallback diam-diam pada test runner.
- **Fix**: Mengimplementasikan `scripts/init-local.ps1` dengan API kriptografi .NET, menghapus seluruh fallback hardcoded pada `stockflow-lifecycle.spec.ts` (wajib melempar error jika secret tidak ditemukan), dan menambahkan validasi pola placeholder pada `backend/src/config/env.ts`.
- **Regression Test**: Unit test `P1-Playwright-01`, `P1-Playwright-02`, dan test suite `env-validation.test.ts` (13 tests) lulus 100%.
- **Status**: Fixed & Verified

### BUG-011: Ketiadaan Isolasi Lingkungan Pengujian E2E dari Aplikasi Utama
- **Severity**: High
- **Deskripsi**: Pengujian Playwright E2E sebelumnya dijalankan langsung ke stack aplikasi utama di port 3000 atau berbagi volume database produksi `mysql_prod_data`, memicu risiko polusi data pengujian dan potensi perusakan data aplikasi utama saat pengujian diulang.
- **Steps to Reproduce**: Menjalankan suite pengujian Playwright E2E secara langsung ke localhost:3000.
- **Root Cause**: Tidak tersedianya file compose dedicated dan siklus hidup database sekali pakai untuk kebutuhan E2E.
- **Fix**: Menyediakan `docker-compose.e2e.yml` dengan nama project `stockflow-e2e-test`, port loopback `127.0.0.1:3100`, volume terpisah `mysql_e2e_data`, network terpisah `stockflow_e2e_net`, serta skrip orkestrator `scripts/run-e2e.ps1`.
- **Regression Test**: Pengujian E2E berjalan 100% pada port 3100 dengan database disposable, dan status kontainer utama pada port 3000 terbukti tetap utuh dan aktif.
- **Status**: Fixed & Verified

### BUG-012: Keberadaan Kredensial Statis dan Hardcoded pada Test Suite E2E
- **Severity**: Medium
- **Deskripsi**: File `frontend/tests/e2e/stockflow-lifecycle.spec.ts` sebelumnya memuat password statis pada skenario pengujian serta branch login alternatif yang mengasumsikan password statis.
- **Steps to Reproduce**: Memeriksa variabel password pada `stockflow-lifecycle.spec.ts`.
- **Root Cause**: Pola pengujian masa lalu yang belum mengadopsi pembangkitan kredensial acak kriptografis secara menyeluruh.
- **Fix**: Mengimplementasikan fungsi pembantu `generateSecureRandomPassword(length)` berbasis `crypto.randomInt` untuk menghasilkan seluruh password sementara dan permanen secara acak pada runtime, serta menghapus branch login fallback statis.
- **Regression Test**: Eksekusi Playwright E2E berhasil 3 passed dalam 8.8 detik dengan 0 kredensial statis.
- **Status**: Fixed & Verified

### BUG-013: False Positive Assertion Bypass pada Test Inisialisasi Bootstrap
- **Severity**: Medium
- **Deskripsi**: Pengujian `backend/tests/bootstrap.test.ts` sebelumnya menggunakan pengkondisian `if (existingAdmin)` sehingga jika database telah memiliki admin, kode pembuatan bootstrap awal tidak pernah dieksekusi dan tidak ada assertion yang dijalankan.
- **Steps to Reproduce**: Menjalankan vitest pada database yang sudah terinisialisasi.
- **Root Cause**: Penggunaan percabangan kondisional di dalam unit test alih-alih isolasi fixture.
- **Fix**: Mengisolasi pengujian dengan memindahkan sementara role admin lama ke dummy role `TEMP_TEST_ROLE`, mengeksekusi bootstrap pada kondisi database kosong, memvalidasi pembuatan user, flag `mustChangePassword`, hash bcrypt, dan penolakan pada eksekusi kedua, lalu mengembalikan data admin lama pada blok `finally`.
- **Regression Test**: Test suite `backend/tests/bootstrap.test.ts` berhasil 8 passed dari 8 tests secara konsisten.
- **Status**: Fixed & Verified

### BUG-014: Skrip scripts/init-local.ps1 Belum Memiliki Staged Rollback dan Pengecekan Windows ACL Ketat
- **Severity**: Medium
- **Deskripsi**: Skrip `init-local.ps1` sebelumnya dapat meninggalkan artefak parsial jika terjadi kegagalan di tengah proses dan belum memverifikasi `$LASTEXITCODE` dari perintah `icacls.exe`.
- **Steps to Reproduce**: Menghentikan skrip atau memicu error saat penulisan file secret.
- **Root Cause**: Penulisan langsung ke file target tanpa tahapan staged temporary files dan penanganan error rollback atomik.
- **Fix**: Mengimplementasikan pembuatan staged temporary files (`.env.tmp`, `.secrets/initial_admin_password.txt.tmp`), pembatasan izin ACL menggunakan `icacls.exe` dengan pengecekan `$LASTEXITCODE`, pemindahan atomik ke lokasi target, serta mekanisme rollback otomatis di blok `catch`. Menambahkan test otomatis `tests/test-init-local.ps1`.
- **Regression Test**: Test suite `tests/test-init-local.ps1` berhasil 3 passed (100% green).
- **Status**: Fixed & Verified

### BUG-015: File Legacy scripts/e2e-setup.js yang Tidak Terpakai Masih Tertinggal
- **Severity**: Low
- **Deskripsi**: File `scripts/e2e-setup.js` masih tersimpan di repositori meskipun tidak lagi direferensikan oleh package.json, workflow, atau test runner manapun.
- **Steps to Reproduce**: Memeriksa isi direktori `scripts/`.
- **Root Cause**: Artefak pengembangan awal yang belum dibersihkan saat arsitektur beralih ke Docker compose dan Playwright native runner.
- **Fix**: Menghapus file `scripts/e2e-setup.js` secara tuntas dan memverifikasi tidak ada referensi yang terputus.
- **Regression Test**: Seluruh test backend, frontend, dan E2E tetap berjalan normal tanpa error dependensi.
- **Status**: Fixed & Verified

### BUG-016: Historical Test Account Exposure di Main Database & Audit Artifact Leakage
- **Severity**: High
- **Deskripsi**: Ditemukan akun staf pengujian sisa siklus v1.5 pada database utama `stockflow_db` serta password staf permanen pada file dokumentasi historis `audit/evidence/e2e/E2E_REPORT.md`.
- **Steps to Reproduce**: Memeriksa tabel `users` pada `stockflow_db` dan memindai teks pada `audit/evidence/e2e/E2E_REPORT.md`.
- **Root Cause**: Siklus pengujian historis yang sempat mengeksekusi terhadap database bersama sebelum isolasi port 3100 diterapkan, serta pencatatan raw credential pada laporan markdown.
- **Fix**: Menetralisir akun staf pengujian pada database utama (status INACTIVE, rotasi hash bcrypt, revocasi seluruh sesi aktif), mengganti dokumen laporan dengan versi tersanitasi, serta membersihkan seluruh artefak debug frontend (`debug.log`, `tsconfig.tsbuildinfo`, `test-results`).
- **Regression Test**: Pemindaian secret scanner `scripts/scan-secrets.ps1` menghasilkan 0 temuan, dan query database membuktikan akun telah berstatus INACTIVE dengan sesi tercabut.
- **Status**: Fixed & Verified

### BUG-017: Healthcheck Password Expansion pada Docker Compose Config & Coupling Bootstrap Test
- **Severity**: High
- **Deskripsi**: Sintaks `test: ["CMD", "mysqladmin", "-p${DB_ROOT_PASSWORD}"]` menyebabkan `docker compose config` mengekspansi password root database ke dalam output teks. Selain itu, `bootstrap.test.ts` memanipulasi role admin pada database aktif menggunakan `TEMP_TEST_ROLE`.
- **Steps to Reproduce**: Menjalankan `docker compose config` dan memeriksa output baris healthcheck.
- **Root Cause**: Penggunaan ekspansi variabel shell compose tingkat pertama alih-alih ekspansi runtime container, serta pengujian logika bootstrap yang tidak memisahkan unit test dari database nyata.
- **Fix**: Mengubah healthcheck menjadi `CMD-SHELL` dengan sintaks double dollar `$$MYSQL_ROOT_PASSWORD` sehingga tidak dievaluasi oleh compose config. Memisahkan unit test bootstrap dengan mock Prisma (`bootstrap.unit.test.ts`) dan mengisolasi integration test dengan Fail-Closed Guard (`bootstrap.integration.test.ts`).
- **Regression Test**: Output `evidence/v1.6.1/e2e_compose_config_sanitized.txt` bersih 100% tanpa password root, 10 unit test bootstrap lolos dengan cepat tanpa DB, dan Fail-Closed Guard menolak eksekusi terhadap database non-test.
- **Status**: Fixed & Verified
