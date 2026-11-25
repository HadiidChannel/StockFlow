# StockFlow Deployment and Operations Guide

## 1. Arsitektur Deployment Produksi

StockFlow didesain untuk deployment kontainer terisolasi menggunakan Docker Compose dengan pemisahan peran yang ketat:
1. `db`: MySQL 8.4 LTS dengan persistent volume pada storage engine InnoDB dan integritas data ACID.
2. `migrator`: Kontainer migrasi dedicated yang menjalankan `prisma migrate deploy` secara otomatis sebelum backend menyala.
3. `backend`: Node.js Express.js server yang melayani REST API pada port internal 4000 dengan non-root user `node` dan image ramping tanpa devDependencies.
4. `frontend`: Next.js production standalone server yang melayani aplikasi web pada port 3000 dengan reverse proxy internal same-origin.

```text
[ Internet / Browser Client ]
              â”‚
              â-¼
    [ Reverse Proxy / Ingress ]
              â”‚
              â-¼
   [ Frontend Next.js :3000 ]
     â”‚ (Same-Origin Relative /api/v1)
     â”‚ Next.js Rewrites (Internal Bridge)
     â-¼
   [ Backend Express.js :4000 ]
     â”‚
     â-¼
   [ MySQL 8.4 LTS :3306 (Internal Bridge) ]
```

### Prinsip Same-Origin API pada Produksi
Browser client hanya berkomunikasi dengan domain frontend yang sama via path relatif `/api/v1`. Next.js melakukan proxying internal ke `INTERNAL_BACKEND_URL` (`http://backend:4000`).
Keuntungan arsitektur ini:
- Mengeliminasi paparan port backend langsung ke jaringan publik.
- Mengeliminasi cross-origin issues dan kebocoran cookie browser.
- Mendukung perlindungan CSRF yang ketat menggunakan cookie SameSite.

---

## 2. Environment Variables

### Variabel Lingkungan Produksi (Production .env)

```env
# Database Configuration (Dihasilkan secara otomatis oleh scripts/init-local.ps1)
DB_ROOT_PASSWORD=[REDACTED_GENERATED_PASSWORD]
DB_USER=stockflow_user
DB_PASSWORD=[REDACTED_GENERATED_PASSWORD]
DATABASE_URL="mysql://stockflow_user:[REDACTED_GENERATED_PASSWORD]@localhost:3306/stockflow_db"

# Backend Configuration
NODE_ENV=production
APP_DEPLOYMENT_MODE=local
PORT=4000
FRONTEND_URL="http://localhost:3000"
COOKIE_DOMAIN=""
COOKIE_SECURE="false"
COOKIE_SAME_SITE="lax"
SESSION_SECRET="[REDACTED_GENERATED_HEX]"
CSRF_SECRET="[REDACTED_GENERATED_HEX]"
LOG_LEVEL="info"

# Initial Bootstrap (Menggunakan Docker Compose Secrets)
# File secret diletakkan pada: .secrets/initial_admin_password.txt
INITIAL_ORG_NAME="PT StockFlow Logistik Nusantara"
INITIAL_ADMIN_NAME="System Administrator"
INITIAL_ADMIN_EMAIL="admin@stockflow.com"

# Frontend Configuration
# NEXT_PUBLIC_API_URL bernilai /api/v1 agar browser menggunakan same-origin relatif
NEXT_PUBLIC_API_URL="/api/v1"
INTERNAL_BACKEND_URL="http://backend:4000"
```

### Validasi Fail-Fast pada Lingkungan Produksi
Jika `NODE_ENV=production`, server backend akan menolak startup dan berhenti seketika (fail-fast) jika:
- `SESSION_SECRET` atau `CSRF_SECRET` menggunakan nilai default development yang tidak aman.
- `DATABASE_URL` menggunakan kredensial default development (`stockflow_pass123` atau `root:root`).
- Pada `APP_DEPLOYMENT_MODE=local`: `FRONTEND_URL` tidak bernilai tepat canonical `http://localhost:3000`.
- Pada `APP_DEPLOYMENT_MODE=production`: `COOKIE_SECURE` bernilai false, atau `FRONTEND_URL` memuat localhost/127.0.0.1 atau tidak menggunakan HTTPS.

---

## 3. Prosedur Deployment

### A. Prosedur Deployment Development
Mode development digunakan untuk pengujian lokal dengan database dev dan seeding data contoh.

```bash
# 1. Jalankan container database development
docker compose -f docker-compose.dev.yml up -d

# 2. Pasang dependensi
cd backend && npm install
cd ../frontend && npm install

# 3. Jalankan migrasi dan seeder development
cd backend
npx prisma migrate dev
npm run db:seed

# 4. Jalankan aplikasi secara lokal
npm run dev        # Backend: port 4000
# Pada terminal terpisah:
cd ../frontend && npm run dev   # Frontend: port 3000
```

### B. Prosedur Deployment Produksi
Mode produksi mengisolasi runtime, mengikat frontend hanya ke 127.0.0.1:3000, menjalankan migrator otomatis, dan tidak pernah memuat data dummy atau seeder testing.

```bash
# Langkah 1: Jalankan skrip inisialisasi lingkungan lokal terenkripsi
# Skrip ini menghasilkan .env dan .secrets/initial_admin_password.txt dengan entropi kriptografis kuat
powershell -ExecutionPolicy Bypass -File scripts/init-local.ps1

# Langkah 2: Inisialisasi Administrator Awal (Dedicated Bootstrap Service)
# Service membaca password awal secara eksklusif dari file secret yang di-mount Docker
docker compose --profile bootstrap run --rm bootstrap

# Langkah 3: Build image produksi tanpa cache jika belum dilakukan
docker compose build --no-cache

# Langkah 4: Jalankan stack kontainer di background
docker compose up -d

# Urutan startup kontainer yang terjadi secara otomatis:
# 1. Container 'db' booting dan menunggu healthcheck MySQL siap.
# 2. Container 'migrator' berjalan, mengeksekusi 'prisma migrate deploy', lalu selesai (exit 0).
# 3. Container 'backend' menyala setelah migrator berhasil (service_completed_successfully).
# 4. Container 'frontend' menyala setelah backend siap.

# Langkah 5: Verifikasi status seluruh service dan binding port loopback
docker compose ps
docker compose port frontend 3000
```

> PENTING: Jangan pernah menjalankan `npm run db:seed` pada environment produksi. Perintah `npm run db:seed` hanya untuk development karena memuat data transaksi contoh. Untuk produksi, gunakan secara eksklusif `docker compose --profile bootstrap run --rm bootstrap` yang hanya membuat akun Administrator awal dengan policy keamanan ketat (password minimal 12 karakter, bcrypt cost factor 12, dan flag wajib ganti password pada login pertama). Password awal dibaca secara eksklusif dari `.secrets/initial_admin_password.txt` via Docker Compose Secrets. Variabel environment `INITIAL_ADMIN_PASSWORD` secara tegas ditolak.

---

## 4. Pemeliharaan dan Operasional Database

### Menjalankan Migrasi Manual pada Produksi
Jika terdapat migrasi skema baru yang perlu diaplikasikan ke database produksi:
```bash
docker compose run --rm migrator
```

### Backup Database Produksi
```bash
docker compose exec db mysqldump -u root -p"$DB_ROOT_PASSWORD" stockflow_db > backup_stockflow_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database Produksi
```bash
docker compose exec -i db mysql -u root -p"$DB_ROOT_PASSWORD" stockflow_db < backup_file.sql
```

---

## 5. Standar Keamanan Kontainer
1. User Non-Root: Image runner backend, frontend, dan bootstrap berjalan dengan non-root user `node`.
2. Image Minimalis: Backend runner membuang devDependencies (`npm ci --omit=dev`). Frontend runner menggunakan artefak standalone Next.js.
3. Isolasi Total Jaringan Internal: Port 3306 (MySQL) dan Port 4000 (Backend Express) tidak dipublikasikan ke host publik pada konfigurasi produksi. Backend dan database hanya dapat diakses melalui Docker network internal `stockflow_net`.
4. Sanitasi Secret: Tidak ada secret atau password yang disimpan di dalam Dockerfile layer atau di-log ke terminal. Seluruh kredensial diinjeksi via environment variables atau secret files saat runtime.
5. Pemeriksaan Kesehatan: Endpoint `/api/v1/health` melakukan verifikasi koneksi database aktif (`SELECT 1`) dengan timeout proteksi.

---

## 6. Prosedur Pengujian End-to-End (E2E) Terisolasi

StockFlow menyediakan lingkungan pengujian Playwright E2E yang sepenuhnya terisolasi dari aplikasi utama untuk menjamin zero test data pollution dan zero downtime pada port produksi.

### Perbandingan Lingkungan Aplikasi Utama vs Stack E2E

| Parameter | Aplikasi Utama (Main Stack) | Stack Pengujian E2E (E2E Test Stack) |
| :--- | :--- | :--- |
| File Compose | `docker-compose.yml` | `docker-compose.e2e.yml` |
| Project Name | `stockflow-prod` | `stockflow-e2e-test` |
| Ingress URL | `http://localhost:3000` (`127.0.0.1:3000`) | `http://127.0.0.1:3100` (`127.0.0.1:3100`) |
| Network Docker | `stockflow_net` | `stockflow_e2e_net` |
| Database Volume | `mysql_prod_data` (Persistent) | `mysql_e2e_data` (Disposable / Ephemeral) |
| Kredensial Admin | Dibaca dari `.secrets/initial_admin_password.txt` | Dihasilkan secara acak via `crypto.randomInt` |
| Siklus Hidup | Long-running production demo | Otomatis dibuat, diuji, dan dibersihkan (`down -v`) |

### Menjalankan Pengujian E2E Terisolasi

Untuk mengeksekusi rangkaian pengujian E2E 13 tahap:
```bash
powershell -ExecutionPolicy Bypass -File scripts/run-e2e.ps1
```

Skrip runner akan melakukan secara otomatis:
1. Memverifikasi ketersediaan port 3100 pada loopback host (`127.0.0.1`).
2. Membuat kredensial kriptografis dinamis untuk database dan user E2E.
3. Menjalankan container database `stockflow_e2e_db` dan menunggu status healthy.
4. Menjalankan migrator skema database E2E (`prisma migrate deploy`).
5. Mengeksekusi bootstrap administrator satu kali untuk akun awal E2E.
6. Menjalankan backend dan frontend E2E pada port `3100`.
7. Menjalankan Playwright test suite (`frontend/tests/e2e/stockflow-lifecycle.spec.ts`).
8. Melakukan teardown bersih (`docker compose down -v`) untuk menghapus volume database sekali pakai `mysql_e2e_data`.
9. Membuktikan bahwa kontainer aplikasi utama pada port `3000` tetap aktif dan tidak tersentuh.

---

## 7. Prosedur Verifikasi Rilis dan Pemaketan v1.6.4 (Anti-Circular Pipeline)

Untuk menjamin integritas paket rilis sebelum diserahkan, repositori StockFlow menerapkan pipeline pemaketan anti-sirkular ke satu lokasi keluaran resmi `release-output/v1.6.4/`.

### A. Verifikasi 13 Gerbang Kualitas Rilis Fail-Closed (`scripts/verify-release.ps1`)

Jalankan gerbang verifikasi rilis melalui terminal PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

Skrip ini memvalidasi 13 gerbang secara fail-closed (setiap kegagalan langsung berhenti dengan exit code 1):
1. **GATE-01 (Git Tooling & Worktree)**: Memastikan `git.exe` tersedia dan direktori target merupakan worktree Git yang valid.
2. **GATE-02 (Artifacts & Manifest Schema)**: Memastikan ketiga arsip (`StockFlow_Final_v8_4.zip`, `StockFlow_Final_Verification_v8_4.zip`, `StockFlow_Audit_Handover_v8_4.zip`) dan manifest eksternal (`StockFlow_Release_Checksums_v8_4.txt`) tersedia dengan skema lengkap dan 40-karakter commit hash valid.
3. **GATE-03 (Branch Match)**: Membandingkan branch Git aktif terhadap branch harapan (`fix/stockflow-v16-4-release-integrity`) dan manifest.
4. **GATE-04 (Full 40-Char Commit Match)**: Membandingkan `git rev-parse HEAD` secara exact match (seluruh 40 karakter) terhadap manifest eksternal.
5. **GATE-05 (Clean Working Tree)**: Memastikan `git status --porcelain --untracked-files=all` kosong sepenuhnya dan manifest mencatat `Working Tree: Clean`.
6. **GATE-06 (Byte Size & SHA-256)**: Memverifikasi ukuran byte aktual dan hash SHA-256 ketiga ZIP cocok 100% terhadap blok manifest masing-masing.
7. **GATE-07 (Archive Extraction Integrity)**: Mengekstrak ketiga ZIP dan memastikan bebas korupsi serta non-kosong.
8. **GATE-08 (Source Hygiene & No Embedded Manifests)**: Memastikan template `.env.example`, `backend/.env.example`, dan `frontend/.env.example` hadir di Source ZIP, serta tidak ada `.env` aktif, `.secrets/`, maupun file `StockFlow_Release_Checksums_*.txt` di dalam ketiga ZIP.
9. **GATE-09 (Audit Handover Manifest Accuracy)**: Memverifikasi `AUDIT_FILE_MANIFEST.md` secara baris per baris terhadap berkas aktual dan hash SHA-256 di dalam Handover ZIP (0 file `Missing` atau klaim palsu).
10. **GATE-10 (Loopback Port Binding)**: Memastikan seluruh port pada konfigurasi Docker Compose terikat ketat ke antarmuka loopback `127.0.0.1`.
11. **GATE-11 (Deep Secret Scan)**: Memindai isi ekstraksi ketiga ZIP dengan `scripts/scan-secrets.ps1` (wajib 0 temuan).
12. **GATE-12 (Git Evidence Consistency)**: Memastikan `evidence/git/git_commit.txt`, `git_branch.txt`, dan `git_status.txt` di dalam Verification ZIP dan Handover ZIP identik dengan kondisi Git aktual.
13. **GATE-13 (Writing Constraint Check)**: Memastikan 0 en dash (`U+2013`) dan 0 em dash (`U+2014`) pada dokumentasi markdown.

### B. Prosedur Pembuatan Paket Rilis Resmi (`scripts/package-release.ps1`)

Pastikan seluruh perubahan source code, skrip, dan dokumentasi terlacak telah di-commit ke Git dan working tree bersih, lalu jalankan:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/package-release.ps1
```

Skrip menjalankan urutan deterministik pada `release-output/v1.6.4/`:
- Menjalankan `scripts/capture-evidence.ps1` untuk merekam bukti Git pasca-commit, validasi Docker Compose mentah, secret scan repositori, serta 13 skenario uji negatif/positif `tests/test-verify-release.ps1`.
- Membangun `StockFlow_Final_v8_4.zip` langsung dari `git archive HEAD` tanpa manifest historis maupun secret lokal.
- Menjalankan `scripts/assemble-handover.ps1` untuk membangun dan memvalidasi kelengkapan `StockFlow_Audit_Handover_v8_4.zip`.
- Membangun `StockFlow_Final_Verification_v8_4.zip` berisi bukti v1.6.4, bukti warisan v1.6.3 berlabel asal, dan dokumentasi rekayasa.
- Menghitung SHA-256 ketiga ZIP dan menulis manifest eksternal `StockFlow_Release_Checksums_v8_4.txt` di luar ketiga ZIP.
- Mengeksekusi `scripts/verify-release.ps1` dan memastikan status Git tetap bersih 100%.

---

## 8. Verifikasi Portabilitas ZIP Lintas Platform & 14 Gerbang Rilis (v1.6.5)

Mulai v1.6.5, keluaran rilis resmi StockFlow dikemas ke `release-output/v1.6.5/` memakai separator POSIX `/` murni agar kompatibel penuh di Windows, Linux, dan macOS.

### A. Perubahan Pipeline Anti-Sirkular v1.6.5 (`scripts/package-release.ps1`)
1. Pastikan branch aktif adalah `fix/stockflow-v16-5-zip-portability` dengan working tree bersih setelah commit final.
2. Pastikan Python 3 (`python`) dan Info-ZIP `unzip` (`unzip` pada PATH atau `C:\Program Files\Git\usr\bin\unzip.exe`) tersedia di mesin eksekusi.
3. Jalankan `powershell -ExecutionPolicy Bypass -File scripts/package-release.ps1`:
   - `capture-evidence.ps1` memproduksi bukti pre-package (`git_status.txt` ber-marker metadata, validasi Compose, scan repo, serta 44 skenario uji negatif/positif).
   - `New-PortableZipArchive` (`scripts/zip-utils.ps1`) mengemas Source ZIP (`StockFlow_Final_v8_5.zip`), Handover ZIP (`StockFlow_Audit_Handover_v8_5.zip`), dan Verification ZIP (`StockFlow_Final_Verification_v8_5.zip`) tanpa byte `0x5C`.
   - Manifest eksternal `StockFlow_Release_Checksums_v8_5.txt` dan laporan scan post-package Verification ZIP (`verification_package_scan.txt`) dibangkitkan sebelum pengecekan gerbang.
   - `scripts/verify-release.ps1` mengeksekusi **14 gerbang fail-closed** (`GATE-01` s.d. `GATE-14`) termasuk uji ekstraksi 3-arah Python `zipfile` + Info-ZIP `unzip` + .NET `ZipFile`, validasi Handover dua arah (Gate 09), audit 4 laporan secret scan (Gate 11), bukti Git independen Verification & Handover (Gate 12), dan pindaian dash di seluruh Markdown (Gate 13).
   - Skrip menangkap status stack produksi beserta jumlah baris read-only tabel database sesudah pengemasan (`main_stack_after.txt`, `main_database_after.txt`, `main_volume_after.txt`).

---

## 9. Verifikasi Header Biner ZIP (Gate 15) & Pipeline Rilis Final v1.6.6

Mulai v1.6.6, artefak rilis resmi StockFlow disimpan di `release-output/v1.6.6/` dan diverifikasi dengan **15 gerbang fail-closed** (`GATE-01` s.d. `GATE-15`) plus bundel bukti pasca-pengemasan tersendiri.

### A. Prosedur Eksekusi Pipeline v1.6.6
1. Pastikan branch aktif adalah `fix/stockflow-v16-6-zip-header-validation` dengan working tree Git 100% bersih pasca-commit.
2. Tangkap baseline operasional awal (`main_stack_before.txt`, `main_database_before.txt`, `main_volume_before.txt`) ke `release-output/v1.6.6/post-package-evidence/v1.6.6/operational/` secara read-only.
3. Jalankan `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/package-release.ps1`:
   - `capture-evidence.ps1` mengeksekusi validasi 32-skenario biner `tests/test-local-header.ps1` (`LH-01`..`LH-32`), suite verifier 51-skenario `tests/test-verify-release.ps1`, Docker Compose 5-config check, dan secret scanner self-test + repo scan.
   - `New-PortableZipArchive` mengemas `StockFlow_Final_v8_6.zip`, `StockFlow_Audit_Handover_v8_6.zip`, dan `StockFlow_Final_Verification_v8_6.zip` beserta `StockFlow_Release_Checksums_v8_6.txt`.
   - `scripts/verify-release.ps1` mengeksekusi **15 gerbang fail-closed**, dengan **GATE-15** berjalan pertama pra-ekstraksi melalui `Inspect-ZipBinaryHeaders` (`local_header_archive_verification.txt`, `local_header_binary_details.txt`, `release_gate_15_results.txt`) sebelum `GATE-14` (ekstraksi 3-engine Python + Info-ZIP + .NET) dan `GATE-07`..`GATE-13`.
   - Pipeline mengarsipkan bundel bukti lengkap pasca-pengemasan menjadi `StockFlow_PostPackage_Evidence_v8_6.zip` dengan manifest indeks `POST_PACKAGE_EVIDENCE_INDEX.md` serta sidecar checksum eksternal `StockFlow_PostPackage_Evidence_Checksum_v8_6.txt`.
