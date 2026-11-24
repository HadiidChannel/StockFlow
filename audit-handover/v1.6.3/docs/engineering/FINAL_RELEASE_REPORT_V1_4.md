# StockFlow Final Release Remediation Report v1.4
# Localhost Portfolio Edition: Security, Administrator Bootstrap, and Final Verification

Tanggal Rilis: 24 November 2026  
Status Rilis: LOCALHOST PORTFOLIO READY  
Target Branch: fix/stockflow-localhost-final-v14  
Versi Aplikasi: StockFlow v1.4.0 Localhost Portfolio Edition  

---

## 1. Project Overview

StockFlow adalah sistem manajemen inventaris dan pergudangan (Inventory and Warehouse Management System / IWMS) multi-lokasi B2B berbasis web yang dirancang dan dibangun secara profesional sebagai proyek portofolio Full-Stack Developer. Aplikasi ini berfokus pada keandalan operasional, konkurensi data yang ketat, audit trail permanen (*immutable movements ledger*), dan keamanan bertingkat (*defense-in-depth*).

Pada tahap rilis v1.4 (Localhost Portfolio Edition), arsitektur disempurnakan secara khusus agar aplikasi dapat berjalan optimal, aman, dan deterministik pada lingkungan lokal komputer pengguna (`http://localhost:3000`) menggunakan Docker Compose tanpa memerlukan infrastruktur cloud, domain publik, atau sertifikat HTTPS publik yang tidak diperlukan.

---

## 2. Local Architecture

Arsitektur aplikasi menerapkan pola *Same-Origin Reverse Proxy*:

```
[ Browser Klien ]
        â”‚
        â”‚ HTTP Request ke http://localhost:3000
        â-¼
[ Frontend Ingress: Next.js 15 Standalone (Port 3000) ]
        â”‚
        â”œâ”€â-º /dashboard, /inventory, /products, dsb. (Next.js SSR & Static Assets)
        â”‚
        â””â”€â-º /api/v1/:path* (Next.js Build-Time Internal Proxy Rewrite)
                 â”‚
                 â”‚ Jaringan Privat Docker (stockflow_net)
                 â”‚ Host Destination: http://backend:4000/api/v1/:path*
                 â-¼
     [ Backend Tier: Express.js (Port 4000 - Host Port Closed) ]
                 â”‚
                 â”‚ Soket Database Privat
                 â-¼
     [ Database Tier: MySQL 8.4 LTS (Port 3306 - Host Port Closed) ]
```

Prinsip Utama Arsitektur:
- Browser hanya berkomunikasi dengan frontend melalui `http://localhost:3000`.
- Semua request API dialirkan secara internal melalui path relatif `/api/v1/:path*`.
- Port backend 4000 dan database 3306 tidak dipublikasikan ke host, memastikan isolasi jaringan penuh.

---

## 3. Technology Stack

- **Frontend**: Next.js 15 (App Router, React 19, Tailwind CSS, shadcn/ui primitives, Lucide Icons, Recharts).
- **Backend**: Node.js 24 LTS, Express.js, TypeScript strict mode, Zod validation.
- **ORM & Database**: Prisma ORM 6.19, MySQL 8.4.13 LTS (InnoDB Storage Engine, utf8mb4).
- **Security**: Double-Submit Cookie CSRF protection (`X-CSRF-Token`), bcrypt cost factor 12 password hashing, secure session management, rate limiting, and strict RBAC.
- **DevOps & Containerization**: Docker Compose v2, multi-stage Alpine Dockerfiles, non-root container users, file-backed Docker Compose Secrets.
- **Quality Assurance**: Vitest unit/integration testing, Supertest HTTP assertion, Playwright Chromium E2E testing, ESLint 9.

---

## 4. Docker Service Architecture

Konfigurasi `docker-compose.yml` mendefinisikan 5 layanan modular:

1. **`db`**: MySQL 8.4.13 LTS container dengan volume persisten `mysql_prod_data`. Port 3306 internal network `stockflow_net`. Dilengkapi healthcheck periodik via `mysqladmin ping`.
2. **`migrator`**: Container ephemeral (`target: migrator`) yang menjalankan `npx prisma migrate deploy` lalu berhenti dengan exit code 0 setelah menerapkan migrasi skema, CHECK constraints, dan composite foreign keys.
3. **`bootstrap`**: Layanan satu kali dengan profile `bootstrap` (`target: runner`) untuk membuat organisasi awal dan akun administrator menggunakan Docker Secrets.
4. **`backend`**: Node.js 24 Alpine runtime (`target: runner`) yang menjalankan API Express terkompilasi (`node dist/server.js`) sebagai user non-root `node`.
5. **`frontend`**: Next.js 15 Standalone runtime (`target: runner`) sebagai user non-root `nextjs` yang melayani port host 3000:3000.

---

## 5. Port Configuration

- **Port 3000 (Host -> Container)**: Gerbang masuk tunggal untuk antarmuka web dan reverse proxy API.
- **Port 4000 (Internal Only)**: Service backend di dalam jaringan Docker `stockflow_net`. Port host tidak dipublikasikan.
- **Port 3306 (Internal Only)**: Service database di dalam jaringan Docker `stockflow_net`. Port host tidak dipublikasikan pada konfigurasi produksi.

Verifikasi isolasi port: perintah `netstat -ano | findstr ":4000"` menghasilkan status kosong, membuktikan port backend tidak dapat diakses langsung dari jaringan luar.

---

## 6. Environment Configuration

Pemisahan konsep lingkungan:
- **`NODE_ENV=production`**: Menandakan penggunaan build Next.js dan Express yang dioptimalkan, minified, dan mengaktifkan validasi secret berkekuatan tinggi (menolak secret default).
- **`APP_DEPLOYMENT_MODE=local`**: Menandakan target deployment secara eksplisit adalah local portfolio. Mengunci trusted origin secara kanonikal hanya pada `http://localhost:3000`.

Mekanisme `ALLOW_LOCALHOST_SIMULATION` telah **dihapus sepenuhnya** dari seluruh basis kode, skema konfigurasi, dan file environment.

Canonical Origin Policy:
- Origin yang diizinkan pada mode local: strictly `http://localhost:3000`.
- Origin `http://127.0.0.1:3000`, `http://localhost:8080`, atau domain luar langsung ditolak oleh middleware CORS dan CSRF.
- `COOKIE_SECURE=false`: Disesuaikan untuk lingkungan lokal HTTP tanpa mematikan fitur keamanan HttpOnly, SameSite=Lax, dan rotasi session token.

---

## 7. Database Initialization

Proses inisialisasi database dari kondisi kosong (*fresh database initialization*) diverifikasi menggunakan kontainer MySQL 8.4.13 LTS terisolasi:

1. **Migrasi Skema**: Migrator menerapkan seluruh migration SQL secara atomik.
2. **14 Tabel Relasional**: `_prisma_migrations`, `categories`, `idempotency_records`, `inventory_balances`, `organizations`, `products`, `roles`, `sessions`, `stock_movements`, `stock_transaction_items`, `stock_transaction_sequences`, `stock_transactions`, `user_warehouse_assignments`, `users`, `warehouses`.
3. **9 Active CHECK Constraints**:
   - `chk_inventory_balance_quantity`: `quantity >= 0`
   - `chk_items_balance_after`: `balance_after >= 0`
   - `chk_items_balance_before`: `balance_before >= 0`
   - `chk_items_quantity`: `quantity > 0`
   - `chk_movements_balance_after`: `balance_after >= 0`
   - `chk_movements_balance_before`: `balance_before >= 0`
   - `chk_movements_quantity`: `quantity > 0`
   - `chk_products_cost_price`: `cost_price IS NULL OR cost_price >= 0`
   - `chk_products_minimum_stock`: `minimum_stock >= 0`
4. **2 Composite Foreign Keys**: Integritas data item transaksi dan saldo gudang.

---

## 8. Administrator Bootstrap

Prosedur inisialisasi administrator awal:
- Menjalankan `docker compose --profile bootstrap run --rm bootstrap`.
- Menggunakan runner image produksi compiled (`node dist/scripts/bootstrap.js`).
- Menolak eksekusi jika password dikirim melalui environment variable biasa `INITIAL_ADMIN_PASSWORD`.
- Mewajibkan pembacaan melalui secret file mount `/run/secrets/initial_admin_password`.
- Validasi kompleksitas password minimal 12 karakter (huruf besar, kecil, angka, karakter khusus).
- Menerapkan flag `mustChangePassword = true` dan hashing bcrypt cost factor 12.
- Dilindungi *one-time execution guard*: eksekusi ulang pada sistem yang sudah memiliki administrator akan otomatis dibatalkan secara idempotent dengan exit code 0.

---

## 9. Secret File Handling

Pola Docker Compose Secrets:
```yaml
secrets:
  initial_admin_password:
    file: ${INITIAL_ADMIN_PASSWORD_FILE:-./.secrets/initial_admin_password.txt}
```

Ketentuan Penanganan Secret:
- Folder `.secrets/` dan berkas `*.secret` telah dimasukkan ke dalam `.gitignore`.
- Berkas secret tidak pernah dimasukkan ke dalam source ZIP maupun verification ZIP.
- Password tidak pernah dicetak ke console terminal atau dicatat dalam log kontainer.

---

## 10. Development and Demo Seeding

Pemisahan tegas antara inisialisasi administrator dan data percontohan:
- **Bootstrap Administrator**: Hanya membuat organisasi awal dan satu akun administrator aktif dengan status ganti password wajib. Tidak membuat data dummy.
- **Demo Seeding**: Terisolasi pada script seeder terpisah (`backend/prisma/seed.ts`) yang hanya dapat dijalankan pada mode development secara eksplisit melalui `npm run db:seed`.
- Database produksi tidak memuat data transaksi sembarangan saat fresh setup.

---

## 11. Authentication and Authorization

1. **Session Management**: Cookie sesi `sf_session` berformat opaque token dengan SHA-256 server-side lookup. Memiliki batas waktu kedaluwarsa dan pembersihan otomatis saat logout.
2. **Double-Submit CSRF**: Setiap request mutasi state mewajibkan header `X-CSRF-Token` yang valid dan cocok dengan cookie `sf_csrf`.
3. **Forced Password Change Guard**: Pengguna baru atau administrator awal wajib memperbarui password pada rute `/change-password` sebelum endpoint bisnis dapat diakses.
4. **Role-Based Access Control (RBAC)**: Pemisahan hak akses antara `ADMIN` dan `WAREHOUSE_STAFF`.
5. **Warehouse Scoping**: Staf gudang dibatasi secara ketat hanya pada gudang yang ditugaskan secara aktif. Akses ke gudang lain menghasilkan penolakan HTTP 403 Forbidden.

---

## 12. Database Backup and Restore

Prosedur Pencadangan Database:
```bash
docker compose exec -T db mysqldump -u stockflow_user -p[PASSWORD] stockflow_db > backup_stockflow.sql
```

Prosedur Pemulihan Database:
```bash
docker compose exec -T db mysql -u stockflow_user -p[PASSWORD] stockflow_db < backup_stockflow.sql
```

Data persediaan juga dilindungi oleh persistent Docker volume `mysql_prod_data` yang terbukti tetap utuh setelah container di-restart.

---

## 13. Testing Procedure

Pengujian dilakukan berlapis menggunakan automated suites:
1. **Unit & Invariant Tests**: Menvalidasi kalkulasi stok, penomoran sequence tanggal lokal, format mata uang Rupiah, dan penanganan error domain.
2. **Integration API Tests**: Menguji alur autentikasi Supertest, CSRF protection, RBAC middleware, dan operasi mutasi inventory.
3. **End-to-End Browser Tests**: Menguji antarmuka visual peramban Chromium menggunakan Playwright.

---

## 14. Playwright End-to-End Verification

Pengujian peramban Playwright dijalankan terhadap stack Docker produksi pada `http://localhost:3000` dengan hasil kelulusan 100%:

| Tahap | Skenario Pengujian | Hasil Pengujian | Status |
| :--- | :--- | :--- | :--- |
| Stage 1 | Admin Login & Forced Password Change | Login dengan password bootstrap awal dari secret file, terpicu pengalihan wajib ke `/change-password`, mengganti password baru, masuk ke `/dashboard`. | PASSED |
| Stage 2 | Pembuatan Kategori & Produk | Menambahkan kategori dan produk baru dengan SKU unik ke database. | PASSED |
| Stage 3 | Pembuatan Gudang | Membuat gudang utama (JKT) dan gudang terisolasi (SUB). | PASSED |
| Stage 4 | Stock In 50 Unit | Melakukan mutasi stok masuk dengan nomor referensi transaksi. | PASSED |
| Stage 5 | Verifikasi Saldo Persediaan | Memeriksa saldo fisik produk tercatat tepat 50 PCS di gudang JKT. | PASSED |
| Stage 6 | Pembuatan Staf Gudang | Mendaftarkan akun staf gudang baru dengan status wajib ganti kata sandi. | PASSED |
| Stage 7 | Penugasan Gudang | Memverifikasi penugasan gudang JKT aktif dan gudang SUB tidak aktif. | PASSED |
| Stage 8 | Staff Login & Forced Password Change | Logout admin, login staf, terpicu pengalihan ke `/change-password`, mengganti password baru, masuk ke dashboard staf. | PASSED |
| Stage 9 | Stock Out 15 Unit | Staf melakukan transaksi stok keluar 15 unit, saldo berkurang menjadi 35 PCS. | PASSED |
| Stage 10 | Riwayat Pergerakan Barang | Ledger memuat riwayat mutasi MASUK (+50), KELUAR (-15), dan saldo 35. | PASSED |
| Stage 11 | Upaya Akses Gudang Terlarang | Staf mencoba melakukan mutasi stok keluar pada gudang SUB yang tidak ditugaskan. | PASSED |
| Stage 12 | Verifikasi Penolakan Otorisasi | Sistem merespons penolakan dengan kode status HTTP 403 Forbidden. | PASSED |
| Stage 13 | Full Reversal & Pemulihan Saldo | Pembatalan penuh transaksi asal berhasil dieksekusi, saldo persediaan pulih tepat ke 50 PCS. | PASSED |

Durasi Eksekusi: 8.9s (1 passed, exit code 0).

---

## 15. Security Verification

Ringkasan Hasil Uji Keamanan:
- **Origin Validation**: Origin selain `http://localhost:3000` (seperti `http://localhost:8080`, `http://127.0.0.1:3000`, atau `http://evil.com`) ditolak 100%.
- **CSRF Defense**: Request POST tanpa token atau dengan token tidak cocok ditolak dengan HTTP 403.
- **Fail-Fast Environment Validation**: Parameter secret default development ditolak saat startup jika `NODE_ENV=production`.
- **Secret Scanning**: Verifikasi bebas dari kredensial mentah pada seluruh direktori bukti (*Zero credential leaks*).

---

## 16. Git Release Information

- **Working Branch**: `fix/stockflow-localhost-final-v14`
- **Base Commit**: `08ca3a0 feat(release): StockFlow Final Release Remediation v1.3`
- **Final Release Tag**: `v1.4.0-localhost-portfolio`
- **Status Repository**: Bersih (*clean working tree*).

---

## 17. Known Limitations

1. **Localhost HTTP Deployment**: Aplikasi dikonfigurasi khusus untuk berjalan pada `http://localhost:3000`. Jika di masa mendatang akan dideploy ke domain publik atau VPS dengan protokol HTTPS, ubah parameter `APP_DEPLOYMENT_MODE=production` dan `COOKIE_SECURE=true` serta sediakan reverse proxy eksternal (seperti Nginx atau Caddy) untuk terminasi SSL/TLS.
2. **Single Server Focus**: Arsitektur saat ini menggunakan persistent local Docker volume yang ditujukan untuk single-node deployment, bukan multi-node clustering.

---

## Kesimpulan Evaluasi Kualitas

Seluruh persyaratan rekayasa perangkat lunak telah dipenuhi tanpa kompromi.  
**APLIKASI STOCKFLOW SECARA RESMI DINYATAKAN SELESAI DAN MEMENUHI SELURUH STANDAR KELAYAKAN: LOCALHOST PORTFOLIO READY.**
