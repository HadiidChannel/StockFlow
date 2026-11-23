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
PORT=4000
FRONTEND_URL="https://app.stockflow.com"
COOKIE_DOMAIN=""
COOKIE_SECURE="true"
COOKIE_SAME_SITE="lax"
SESSION_SECRET="ganti_dengan_session_secret_acak_minimal_32_karakter"
CSRF_SECRET="ganti_dengan_csrf_secret_acak_minimal_32_karakter"
LOG_LEVEL="info"

# Initial Bootstrap (Hanya digunakan saat bootstrap akun awal)
INITIAL_ORG_NAME="PT StockFlow Logistik Nusantara"
INITIAL_ADMIN_NAME="System Administrator"
INITIAL_ADMIN_EMAIL="admin@stockflow.com"
INITIAL_ADMIN_PASSWORD="GantiPasswordKuatAdmin2026!"

# Frontend Configuration
# Kosongkan NEXT_PUBLIC_API_URL agar browser menggunakan same-origin relatif /api/v1
NEXT_PUBLIC_API_URL=""
INTERNAL_BACKEND_URL="http://backend:4000"
```

### Validasi Fail-Fast pada Mode Produksi
Jika `NODE_ENV=production`, server backend akan menolak startup dan berhenti seketika (fail-fast) jika:
- `SESSION_SECRET` atau `CSRF_SECRET` menggunakan nilai default development.
- `COOKIE_SECURE` bernilai false.
- `DATABASE_URL` menggunakan kredensial default development (`stockflow_pass123`).
- `FRONTEND_URL` tidak didefinisikan, bernilai localhost, bernilai 127.0.0.1, atau tidak menggunakan protokol HTTPS.

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
Mode produksi mengisolasi runtime, menjalankan migrator otomatis, dan tidak pernah memuat data dummy atau seeder testing.

```bash
# Langkah 1: Siapkan file environment produksi dari template blueprint
cp .env.example .env
# Edit .env dan masukkan secret nyata ber-entropi tinggi serta domain HTTPS produksi

# Langkah 2: Build image produksi tanpa cache
docker compose build --no-cache

# Langkah 3: Jalankan stack kontainer di background
docker compose up -d

# Urutan startup kontainer yang terjadi secara otomatis:
# 1. Container 'db' booting dan menunggu healthcheck MySQL siap.
# 2. Container 'migrator' berjalan, mengeksekusi 'prisma migrate deploy', lalu selesai (exit 0).
# 3. Container 'backend' menyala setelah migrator berhasil (service_completed_successfully).
# 4. Container 'frontend' menyala setelah backend siap.

# Langkah 4: Verifikasi status seluruh service
docker compose ps

# Langkah 5: Inisialisasi Administrator Awal (One-Time Dedicated Bootstrap)
# Service bootstrap dijalankan satu kali secara eksplisit melalui profile 'bootstrap'.
# Image runner produksi menjalankan kode terkompilasi 'node dist/scripts/bootstrap.js' tanpa devDependencies.

# Metode A: Menggunakan environment variable saat menjalankan service one-time
INITIAL_ADMIN_PASSWORD="YourSecurePassword2026!" docker compose run --rm bootstrap

# Metode B: Menggunakan file secret terisolasi
# echo "YourSecurePassword2026!" > ./secrets/admin_password.txt
INITIAL_ADMIN_PASSWORD_FILE="./secrets/admin_password.txt" docker compose run --rm bootstrap
```

> PENTING: Jangan pernah menjalankan `npm run db:seed` pada environment produksi. Perintah `npm run db:seed` hanya untuk development karena memuat data transaksi contoh. Untuk produksi, gunakan secara eksklusif `npm run db:bootstrap` yang hanya membuat akun Administrator awal dengan policy keamanan ketat (password minimal 12 karakter, bcrypt cost factor 12, dan flag wajib ganti password pada login pertama).

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
