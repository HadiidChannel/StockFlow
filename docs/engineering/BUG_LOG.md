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

### BUG-018: Ketiadaan Isolasi Database Disposable pada Pengujian Integrasi Bootstrap Admin
- **Severity**: Critical
- **Deskripsi**: Logika bootstrap admin sebelumnya belum diuji secara nyata terhadap database MySQL 8.4 murni tanpa menyentuh database operasional, serta ketiadaan fail-closed guard yang menolak eksekusi pada database non-disposable.
- **Steps to Reproduce**: Menjalankan pengujian bootstrap dengan DATABASE_URL yang mengarah ke database operasional.
- **Root Cause**: Pengujian hanya mengandalkan mock unit test dan tidak memiliki harness kontainer terisolasi dengan fail-closed guard berbasis run ID.
- **Fix**: Mengimplementasikan `backend/src/utils/bootstrap-guard.ts` dengan 14 skenario penolakan ketat, arsitektur `docker-compose.bootstrap-test.yml` pada port 3307, dan runner otomatis `scripts/run-bootstrap-test.ps1` yang mengeksekusi integrasi nyata pada kontainer sekali pakai.
- **Regression Test**: Test suite `backend/tests/bootstrap-guard.test.ts` (14 passed) dan `backend/tests/bootstrap.integration.test.ts` (3 passed) lolos 100% hijau.
- **Status**: Fixed & Verified

### BUG-019: Kegagalan Rollback Transaksional Penuh dan Ketiadaan Penegakan ACL Folder .secrets Pre-Existing
- **Severity**: High
- **Deskripsi**: Skrip `init-local.ps1` tidak melakukan rollback jika terjadi interupsi pada tahap pemindahan file target, serta mengabaikan penetapan ulang izin ACL folder `.secrets` apabila folder tersebut telah ada sebelumnya.
- **Steps to Reproduce**: Menghentikan proses `init-local.ps1` setelah file temporary dipindahkan, atau memeriksa ACL folder `.secrets` yang dibuat sebelum eksekusi skrip.
- **Root Cause**: Logika pembuatan folder hanya mengeksekusi `icacls.exe` pada blok pembuatan awal dan penanganan error belum mencakup pembersihan staged files di setiap checkpoint.
- **Fix**: Menambahkan parameter `-TestFaultStage` dengan 4 checkpoint fault injection, memastikan blok catch membersihkan file temporary tanpa merusak file pengguna yang sudah ada, serta menegakkan `icacls.exe` tanpa syarat pada folder `.secrets`.
- **Regression Test**: Test suite `tests/test-init-local.ps1` mencakup 19 skenario pengujian termasuk 4 fault injection rollback nyata, seluruhnya lulus 100%.
- **Status**: Fixed & Verified

### BUG-020: Ketiadaan Pelabelan Kepemilikan Resource Docker E2E dan Penegakan Fail-Closed Secret ACL
- **Severity**: High
- **Deskripsi**: Kontainer, network, dan volume Docker E2E tidak memiliki label kepemilikan unik berbasis `run_id` sehingga rentan terjadi konflik resource yatim (orphan), serta skrip runner E2E tidak menghentikan eksekusi secara fail-closed jika penetapan izin ACL rahasia gagal.
- **Steps to Reproduce**: Menjalankan pengujian E2E paralel atau mensimulasikan kegagalan penetapan izin Windows ACL pada file rahasia E2E.
- **Root Cause**: Konfigurasi `docker-compose.e2e.yml` tidak mendefinisikan label metadata kepemilikan dan skrip `run-e2e.ps1` tidak memvalidasi status exit code ACL secara ketat.
- **Fix**: Menambahkan label `stockflow.e2e.run_id` dan `stockflow.e2e.owner` pada seluruh resource E2E, menambahkan fallback tag image lokal (`${E2E_*_IMAGE:-...}`), serta mengimplementasikan fail-closed abort jika ACL secret gagal diaplikasikan.
- **Regression Test**: Skenario E2E lolos 100% dan verifikasi label Docker tervalidasi pada `evidence/v1.6.2/e2e_resource_ownership.txt`.
- **Status**: Fixed & Verified

### BUG-021: Blindspot pada Pemindai Rahasia Terhadap String Koneksi Database dan Argumen CLI
- **Severity**: Medium
- **Deskripsi**: Skrip pemindai rahasia sebelumnya memiliki celah deteksi pada password alfanumerik dalam argumen CLI `-p<pass>`, string koneksi database, dan tidak memiliki mekanisme pengujian mandiri (self-test).
- **Steps to Reproduce**: Menyisipkan password alfanumerik pada parameter `-p` atau URI koneksi MySQL pada file uji.
- **Root Cause**: Ekspresi reguler hanya mendeteksi karakter hexadesimal dan tidak memindai pola URI koneksi database umum serta tidak menyediakan fixture uji positif/negatif.
- **Fix**: Membangun ulang `scripts/scan-secrets.ps1` dengan 6 pola ekspresi reguler komprehensif, masking 100% `[REDACTED]`, serta menambahkan modul `-SelfTest` terintegrasi yang memvalidasi 6 uji positif dan 3 uji negatif.
- **Regression Test**: Self-test berhasil 6/6 deteksi dan 3/3 pengecualian valid, serta pemindaian 309 file repositori menghasilkan 0 temuan bocor.
- **Status**: Fixed & Verified

### BUG-022: Inkonsistensi Packaging Script Terhadap File .env.example dan Port Binding Publik Dev
- **Severity**: Medium
- **Deskripsi**: Skrip pemaketan rilis berpotensi mengabaikan template konfigurasi aman `.env.example`, dan `docker-compose.dev.yml` mengikat port ke antarmuka publik `0.0.0.0`.
- **Steps to Reproduce**: Menjalankan skrip rilis dengan filter regex yang terlalu agresif dan memeriksa port binding pada docker dev.
- **Root Cause**: Pola exclude `.env*` menghapus `.env.example`, dan port binding pada `docker-compose.dev.yml` tidak secara eksplisit dibatasi ke antarmuka loopback `127.0.0.1`.
- **Fix**: Memperbaiki regex pemaketan menjadi `(?i)(?:^|[\\/])\.env(?:\.(?!example$)[^\\/]+)?$` sehingga `.env.example` tetap disertakan, serta mengikat seluruh port service dev ke `127.0.0.1:3306`, `127.0.0.1:4000`, dan `127.0.0.1:3000`.
- **Regression Test**: Verifikasi arsip rilis membuktikan `.env.example` ada di dalam ZIP tanpa file rahasia asli, dan `docker compose -f docker-compose.dev.yml config` terikat ketat ke loopback.
- **Status**: Fixed & Verified

### BUG-023: Windows NTFS ACL Izin Hapus (Delete Permission) Hilang pada Konfigurasi (R,W)
- **Severity**: High
- **Deskripsi**: Pemberian hak akses `(R,W)` melalui `icacls.exe` pada file rahasia hanya memberikan izin Read dan Write tanpa izin Delete `(D)`. Pada filesystem NTFS Windows, operasi penghapusan file melalui PowerShell (`Remove-Item`) memicu `UnauthorizedAccessException: Access to the path ... is denied`.
- **Steps to Reproduce**: Menerapkan izin `icacls $file /grant:r "*${userSid}:(R,W)"` lalu mencoba `Remove-Item -Force $file`.
- **Root Cause**: Windows NTFS membedakan izin Write dan Delete. Hak akses Modify `(M)` diperlukan agar pemilik file memiliki izin baca, tulis, dan hapus tanpa memberikan Full Control kepada pihak ketiga.
- **Fix**: Memperbarui `scripts/init-local.ps1` dan `scripts/run-e2e.ps1` untuk memberikan hak akses Modify `(M)` kepada pengguna pemilik (`*${userSid}:(M)`), serta menambahkan fungsi `Remove-SafeRollbackFile` yang memberikan izin `(M)` sebelum penghapusan file sementara pada blok catch rollback.
- **Regression Test**: Test suite `tests/test-init-local.ps1` (skenario 11-18) lolos 100%, file staging dan moved berhasil dibersihkan tanpa exception.
- **Status**: Fixed & Verified

### BUG-024: E2E Runner Membungkam Kegagalan Penghapusan Secret File Sementara
- **Severity**: High
- **Deskripsi**: Skrip `run-e2e.ps1` pada v1.6.2 membungkam kegagalan penghapusan file password admin sementara menggunakan `-ErrorAction SilentlyContinue`, sehingga file secret tertinggal di folder `.secrets/` dan tercatat `Temporary Secret Removed: NO`.
- **Steps to Reproduce**: Menjalankan pengujian E2E dan memeriksa log teardown pada `evidence/v1.6.2/e2e_cleanup_verification.txt`.
- **Root Cause**: File secret dibuat dengan izin `(R,W)` yang tidak mengizinkan penghapusan, dan exception penghapusan disembunyikan oleh `SilentlyContinue`.
- **Fix**: Menerapkan izin Modify `(M)` sebelum penghapusan, mengubah penghapusan menjadi `Remove-Item -LiteralPath $e2eSecretFile -Force -ErrorAction Stop`, memvalidasi keberadaan file setelah penghapusan, dan menetapkan status `CLEANUP_FAILED` serta exit code 1 jika file masih tersisa (fail-closed).
- **Regression Test**: Pengujian E2E v1.6.3 membuktikan `Temporary Secret Removed: YES`, `Cleanup Status: 100% VERIFIED_CLEAN`, dan file di `.secrets/` terhapus total.
- **Status**: Fixed & Verified

### BUG-025: Inkonsistensi Label Kepemilikan Resource stockflow.e2e.owner pada Docker Compose E2E
- **Severity**: Medium
- **Deskripsi**: Label kepemilikan resource `stockflow.e2e.owner` pada file `docker-compose.e2e.yml` memiliki nilai yang tidak konsisten di antara layanan db, migrator, bootstrap, backend, frontend, volume, dan network.
- **Steps to Reproduce**: Memeriksa seluruh label pada `docker-compose.e2e.yml`.
- **Root Cause**: Perbedaan penamaan label saat penggabungan file komposisi E2E.
- **Fix**: Menyeragamkan seluruh 7 definisi label kepemilikan menjadi `stockflow.e2e.owner: stockflow-e2e-runner` di seluruh kontainer, volume, dan network E2E.
- **Regression Test**: Inspeksi konfigurasi `docker-compose.e2e.yml` membuktikan seluruh 7 label konsisten 100%.
- **Status**: Fixed & Verified

### BUG-026: False Positive Pemindai Rahasia pada Default Value Variabel Docker Compose
- **Severity**: Medium
- **Deskripsi**: Skrip `scan-secrets.ps1` menandai ekspresi `${DEV_MYSQL_ROOT_PASSWORD:-dev_root_pass_2026}` pada `docker-compose.dev.yml` sebagai kebocoran rahasia tingkat tinggi.
- **Steps to Reproduce**: Menjalankan `scan-secrets.ps1` terhadap file konfigurasi Compose yang menggunakan sintaks substitusi default bash `:-`.
- **Root Cause**: Regex Kategori 3 tidak memiliki batas kata (word boundary) atau negative lookbehind, sehingga kata `MYSQL_ROOT_PASSWORD` cocok di dalam nama variabel `DEV_MYSQL_ROOT_PASSWORD`, dan karakter `:` cocok dengan `[:=]`, menyisakan `-dev_root_pass_2026` yang tidak cocok dengan filter `"dev_`.
- **Fix**: Menambahkan negative lookbehind `(?<![A-Za-z0-9_])` pada nama variabel secret dan word boundary `\b`, sehingga variabel berawalan `DEV_`, `TEST_`, atau `PROD_` tidak memicu deteksi palsu.
- **Regression Test**: Eksekusi `scan-secrets.ps1` pada repositori menghasilkan 0 temuan (100% CLEAN).
- **Status**: Fixed & Verified

### BUG-027: Pemindai Rahasia Mendeteksi Identifier Variabel TypeScript Sebagai String Password
- **Severity**: Medium
- **Deskripsi**: Skrip `scan-secrets.ps1` menandai nama variabel TypeScript seperti `const secureTestPassword` dan referensinya dalam test assertion sebagai hardcoded credential.
- **Steps to Reproduce**: Mendefinisikan variabel bernama `secureTestPassword` tanpa tanda petik dalam file test.
- **Root Cause**: Regex Kategori 4 menggunakan tanda petik opsional `["']?` sehingga mencocokkan identifier kode biasa. Selain itu, password pengujian integrasi bootstrap masih menggunakan string statis.
- **Fix**: Mewajibkan tanda petik pembuka dan penutup `["']` pada pola password statis Kategori 4, mengganti string statis pada `backend/tests/bootstrap.integration.test.ts` menjadi password dinamis yang dibuat secara kriptografis saat runtime (`crypto.randomBytes`), dan mengganti password mock unit test menjadi placeholder.
- **Regression Test**: Self-test scanner mendeteksi seluruh 6 kategori positif tanpa false positive, dan pemindaian repositori bersih 100%.
- **Status**: Fixed & Verified

### BUG-028: Ketergantungan Siklus Manifest Rilis Terhadap Commit Git (Circular Commit Dependency)
- **Severity**: Medium
- **Deskripsi**: Pembuatan arsip rilis yang menyertakan manifest dengan commit Git hash mengalami masalah integritas jika file rilis atau manifest dibuat di dalam working tree git yang sedang dilacak, menyebabkan status git dirty.
- **Steps to Reproduce**: Membuat file manifest atau zip di dalam repositori sebelum commit git final dilakukan.
- **Root Cause**: Manifest mencatat commit hash git, namun jika manifest atau arsip dilacak oleh git, pembuatan file tersebut mengubah status git menjadi tidak bersih.
- **Fix**: Menambahkan `release-output/`, `audit/`, `*.zip`, dan `StockFlow_Release_Checksums_*.txt` ke `.gitignore`. Mengarahkan skrip pemaketan rilis untuk menghasilkan output ke direktori `release-output/v1.6.3/` dan `audit/v8_3/` yang diabaikan git, sehingga commit git bersih dapat dilakukan terlebih dahulu sebelum artefak rilis final dieksekusi.
- **Regression Test**: Skrip verifikasi release gate memvalidasi status git clean dan mencocokkan commit hash 40 karakter secara presisi.
- **Status**: Fixed & Verified

### BUG-029: Verifikasi Git Commit Bersifat Fail-Open dan Ketiadaan Cek Working Tree pada Release Verifier (FINDING-01)
- **Severity**: Critical
- **Deskripsi**: Pada v1.6.3, `scripts/verify-release.ps1` hanya mengeluarkan `Write-Warning` saat commit HEAD tidak cocok dengan manifest dan tetap mengeksekusi `$checksPassed++`. Selain itu, tidak terdapat validasi `git status --porcelain --untracked-files=all` maupun pengujian negatif terisolasi.
- **Steps to Reproduce**: Mengubah nilai `Final Git Commit` pada manifest rilis menjadi hash berbeda lalu menjalankan `verify-release.ps1` v1.6.3.
- **Root Cause**: Blok kondisi mismatch menggunakan warning non-terminating tanpa `exit 1` dan logika pencacahan kelulusan dijalankan di luar percabangan error.
- **Fix**: Mengimplementasikan fungsi fail-closed `Fail-Gate` pada `scripts/verify-release.ps1` (Gate 01 sampai Gate 13) yang langsung keluar dengan kode 1 apabila branch tidak cocok, 40-karakter commit hash berbeda, working tree tidak bersih, atau Git CLI tidak tersedia. Membuat harness pengujian `tests/test-verify-release.ps1` dengan 13 skenario positif dan negatif terisolasi.
- **Regression Test**: Seluruh 13 skenario pada `tests/test-verify-release.ps1` lulus 100% (commit mismatch, branch mismatch, dirty modified, untracked, missing git, missing manifest, corrupt manifest, missing ZIP, checksum mismatch, embedded manifest, false verified claim, dan stale git evidence seluruhnya ditolak fail-closed).
- **Status**: Fixed & Verified

### BUG-030: Inkonsistensi Hash Commit pada Bukti Git Akibat Pembuatan Bukti Sebelum Commit Final (FINDING-02)
- **Severity**: High
- **Deskripsi**: Manifest eksternal v1.6.3 mencatat commit `e7bccf7`, namun berkas `evidence/git/git_commit.txt` di dalam Audit Handover mencatat `db8f53f` serta `git_status.txt` menampilkan file modified/deleted.
- **Steps to Reproduce**: Mengekstrak `StockFlow_Audit_Handover_v8_3.zip` dan membandingkan `git_commit.txt` dengan manifest eksternal.
- **Root Cause**: Skrip perakitan handover merekam `git_commit.txt` dan memasukkannya ke dalam commit terakhir, sehingga commit terakhir mengubah hash HEAD menjadi nilai baru yang berbeda dari isi file yang ikut dikomit.
- **Fix**: Menerapkan urutan rilis anti-sirkular: melakukan commit final terlebih dahulu, memverifikasi working tree 100% bersih, lalu membangkitkan seluruh bukti Git dan bundel rilis di dalam direktori terisolasi `.gitignore` (`release-output/v1.6.4/`). Menambahkan Gate 12 pada `verify-release.ps1` untuk mencocokkan `git_commit.txt`, `git_branch.txt`, dan `git_status.txt` di dalam arsip Verification dan Handover terhadap Git HEAD aktual.
- **Regression Test**: `tests/test-verify-release.ps1` Scenario 13 membuktikan Gate 12 menolak bukti Git kadaluarsa di dalam arsip, dan pipeline rilis v1.6.4 menghasilkan hash 40 karakter yang identik 100%.
- **Status**: Fixed & Verified

### BUG-031: Manifest Checksum Historis dan Aktif Ikut Terkemas di Dalam Source ZIP (FINDING-03)
- **Severity**: High
- **Deskripsi**: Arsip `StockFlow_Final_v8_3.zip` kedapatan masih menyertakan `StockFlow_Release_Checksums_v8_2.txt` dan `StockFlow_Release_Checksums_v8_3.txt`.
- **Steps to Reproduce**: Memeriksa daftar berkas hasil ekstraksi `StockFlow_Final_v8_3.zip`.
- **Root Cause**: Berkas `StockFlow_Release_Checksums_v8_2.txt` masih terlacak pada Git index sebelumnya, dan skrip `package-release.ps1` v1.6.3 menyalin manifest ke root proyek serta menyapu seluruh direktori root tanpa rule eksklusi spesifik untuk pola manifest checksum.
- **Fix**: Menghapus `StockFlow_Release_Checksums_v8_2.txt` dari Git index, membangun `StockFlow_Final_v8_4.zip` secara deterministik melalui `git archive HEAD` dengan eksklusi eksplisit `(?:^|[\\/])StockFlow_Release_Checksums_.*\.txt$`, menghentikan penyalinan ke root proyek (satu lokasi resmi `release-output/v1.6.4/`), serta menambahkan pengecekan pelarangan manifest di Gate 08.
- **Regression Test**: `tests/test-verify-release.ps1` Scenario 11 membuktikan Gate 08 menolak Source ZIP apabila mengandung berkas manifest checksum historis.
- **Status**: Fixed & Verified

### BUG-032: Ketidaklengkapan Source Backend/Frontend pada Audit Handover dan Klaim Manifest Tidak Akurat (FINDING-04)
- **Severity**: Critical
- **Deskripsi**: Paket Audit Handover v1.6.3 hanya menyertakan sebagian kecil file sumber backend/frontend (tidak memuat `backend/src/` lengkap, `frontend/src/` lengkap, lockfiles, Dockerfiles, `next.config.ts`, dan `.env.example` per workspace), serta `AUDIT_FILE_MANIFEST.md` mengklaim `source/root/package.json` berstatus Verified Present padahal file tersebut tidak ada pada repositori.
- **Steps to Reproduce**: Memeriksa struktur direktori `StockFlow_Audit_Handover_v8_3.zip` dan membandingkannya dengan tabel pada `AUDIT_FILE_MANIFEST.md`.
- **Root Cause**: Skrip `assemble-handover.ps1` v1.6.3 menyalin file secara selektif berbasis daftar manual parsial dan mencetak baris manifest statis tanpa validasi keberadaan fisik file.
- **Fix**: Membangun ulang `scripts/assemble-handover.ps1` agar mengekspor seluruh workspace `backend/` dan `frontend/` (source implementation, `prisma/`, `public/`, `tests/`, lockfiles `package-lock.json`, Dockerfiles, konfigurasi Next/Vitest/Playwright/TypeScript, serta seluruh template `.env.example`) secara lengkap dari `git archive HEAD`, memetakan struktur monorepo aktual tanpa mengarang file fiktif, menghitung SHA-256 setiap berkas secara programatis untuk menyusun `AUDIT_FILE_MANIFEST.md`, serta menambahkan validasi 1-to-1 pada Gate 09 di `verify-release.ps1`.
- **Regression Test**: `tests/test-verify-release.ps1` Scenario 12 memverifikasi Gate 09 menolak manifest yang mengklaim berkas hilang sebagai `Verified`, dan `assemble-handover.ps1` memvalidasi kesesuaian hash 100% setelah ekstraksi ulang ZIP.
- **Status**: Fixed & Verified
