# StockFlow Deployment and Operations Guide

## 1. Arsitektur Deployment Produksi

StockFlow didesain untuk deployment kontainer terisolasi menggunakan Docker Compose dengan pemisahan peran yang ketat:
1. `db`: MySQL 8.4 LTS dengan persistent volume pada storage engine InnoDB dan integritas data ACID.
2. `migrator`: Kontainer migrasi dedicated yang menjalankan `prisma migrate deploy` secara otomatis sebelum backend menyala.
3. `backend`: Node.js Express.js server yang melayani REST API pada port internal 4000 dengan non-root user `node` dan image ramping tanpa devDependencies.
4. `frontend`: Next.js production standalone server yang melayani aplikasi web pada port 3000 dengan reverse proxy internal same-origin.

```text
[ Internet / Browser Client ]
              │
              ▼
    [ Reverse Proxy / Ingress ]
              │
              ▼
   [ Frontend Next.js :3000 ]
     │ (Same-Origin Relative /api/v1)
     │ Next.js Rewrites (Internal Bridge)
     ▼
   [ Backend Express.js :4000 ]
     │
     ▼
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
# Database Configuration
DB_ROOT_PASSWORD=ganti_dengan_root_password_berentropi_tinggi_32karakter
DB_USER=stockflow_user
DB_PASSWORD=ganti_dengan_app_password_berentropi_tinggi_32karakter
DATABASE_URL="mysql://stockflow_user:ganti_dengan_app_password_berentropi_tinggi_32karakter@db:3306/stockflow_db"

# Backend Configuration
NODE_ENV=production
APP_DEPLOYMENT_MODE=local
PORT=4000
FRONTEND_URL="http://localhost:3000"
COOKIE_DOMAIN=""
COOKIE_SECURE="false"
COOKIE_SAME_SITE="lax"
SESSION_SECRET="ganti_dengan_session_secret_acak_minimal_32_karakter"
CSRF_SECRET="ganti_dengan_csrf_secret_acak_minimal_32_karakter"
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
