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

## 7. Prosedur Verifikasi Rilis dan Pemaketan v1.6.3

Untuk menjamin integritas paket rilis sebelum diserahkan, repositori StockFlow menyediakan skrip verifikasi otomatis dan pipeline pemaketan resmi.

### A. Verifikasi 10 Gerbang Kualitas Rilis (scripts/verify-release.ps1)

Jalankan gerbang verifikasi rilis melalui terminal PowerShell:
```bash
powershell -ExecutionPolicy Bypass -File scripts/verify-release.ps1
```

Skrip ini memverifikasi 10 kriteria penentu:
1. **Git Repository and Branch Validation**: Memastikan branch aktif adalah `fix/stockflow-v16-3-release-integrity`.
2. **Commit Hash Consistency**: Memverifikasi konsistensi commit hash 40 karakter antara `git rev-parse HEAD` dan manifest.
3. **Artifact Presence**: Memastikan ketiga arsip (`StockFlow_Final_v8_3.zip`, `StockFlow_Final_Verification_v8_3.zip`, `StockFlow_Audit_Handover_v8_3.zip`) dan manifest external (`StockFlow_Release_Checksums_v8_3.txt`) tersedia dan tidak kosong.
4. **Checksum & Size Verification**: Menghitung hash SHA-256 dan ukuran byte riil dari setiap file arsip dan memverifikasinya terhadap isi manifest.
5. **Archive Extraction Integrity**: Menguji pembukaan dan ekstraksi seluruh arsip ZIP untuk membuktikan arsip valid dan tidak corrupt.
6. **Required Template Presence**: Memastikan `.env.example` terkonfirmasi ada di dalam source package ZIP.
7. **Clean Sensitive Data**: Memastikan file rahasia aktif (`.env`, `.env.local`, `.secrets/`) tidak ada di dalam source package.
8. **Loopback Binding Verification**: Memvalidasi bahwa seluruh konfigurasi compose hanya mempublikasikan port ke antarmuka loopback `127.0.0.1`.
9. **Deep Secret Scanning**: Memindai seluruh isi ketiga arsip ZIP yang diekstrak untuk menjamin zero credential leakage (0 findings).
10. **Writing Constraint Verification**: Memindai seluruh dokumen laporan rilis untuk memastikan tidak ada karakter terlarang seperti en dash atau em dash.

### B. Prosedur Pembuatan Paket Rilis Resmi (scripts/package-release.ps1)

Untuk menghasilkan arsip rilis bersih secara otomatis:
```bash
powershell -ExecutionPolicy Bypass -File scripts/package-release.ps1
```

Skrip akan menghasilkan empat artefak rilis utama:
- `StockFlow_Final_v8_3.zip`: Berisi source code lengkap, konfigurasi Docker, dokumen arsitektur, dan skrip runner bersih dengan `.env.example`.
- `StockFlow_Final_Verification_v8_3.zip`: Berisi seluruh rekaman bukti uji verifikasi (`evidence/v1.6.3/`) dan laporan engineering.
- `StockFlow_Audit_Handover_v8_3.zip`: Berisi direktori `audit-handover/v1.6.3/` yang memuat pemetaan manifest file, berkas sumber daya terkait, dan file bukti mentah independen.
- `StockFlow_Release_Checksums_v8_3.txt`: Berisi tanda tangan digital SHA-256 dan ukuran byte untuk memvalidasi integritas ketiga arsip.

Seluruh artefak secara otomatis ditempatkan pada `release-output/v1.6.3/`, diduplikasi ke `audit/v8_3/`, dan disalin ke project root.
