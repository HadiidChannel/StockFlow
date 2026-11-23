# StockFlow Architecture Decision Records (ADR)

Dokumen ini mencatat keputusan arsitektur penting yang diambil selama pengembangan StockFlow, alasan pemilihan, alternatif yang dipertimbangkan, serta konsekuensi teknisnya.

---

## ADR-001: Pemisahan Fisik Frontend (Next.js) dan Backend (Express.js)

### Status
Accepted

### Konteks
Aplikasi membutuhkan pemisahan concern yang tegas antara User Interface/Presentation Layer dan Core Business Logic/Data Access Layer. Terdapat opsi untuk menggunakan Next.js API Routes sebagai backend penuh, atau memisahkan backend Express.js tersendiri.

### Keputusan
Menggunakan Express.js terpisah sebagai backend server independen yang berjalan di port 4000, dan Next.js App Router sebagai frontend di port 3000.

### Alasan
1. Isolasi Tanggung Jawab: Next.js fokus pada server-rendering, layout, dan interaksi UI, sedangkan Express.js menjadi single source of truth untuk business logic, otorisasi, kontrol konkurensi, dan akses database.
2. Keamanan: Mencegah kebocoran credential database atau Prisma client instance ke dalam client-side bundle atau edge runtime.
3. Kontrol Koneksi Database: Express.js berjalan sebagai long-running Node.js process yang dapat mengelola MySQL connection pooling secara optimal tanpa risiko exhaustion yang sering terjadi pada serverless runtime.
4. Keselarasan Spesifikasi: PRD dan FSD menetapkan secara eksplisit bahwa Express.js adalah backend REST API utama.

### Konsekuensi
- Positif: Kemandirian scaling, kemudahan testing API independen, arsitektur enterprise standar.
- Negatif: Perlu setup CORS dan pengelolaan cookie lintas port pada environment development lokal.

---

## ADR-002: Session-Based Cookie Authentication dengan Hashing Opaque Token

### Status
Accepted

### Konteks
Sistem membutuhkan mekanisme autentikasi yang aman untuk aplikasi web internal B2B. Alternatif umum adalah JWT (JSON Web Token) yang disimpan di localStorage atau session-based cookie.

### Keputusan
Menggunakan opaque random session token yang disimpan dalam cookie HttpOnly `sf_session`. Database hanya menyimpan hash SHA-256 dari token tersebut di tabel `sessions`.

### Alasan
1. Revocation Seketika: Sesi dapat segera dicabut (revoked) saat admin menonaktifkan akun atau user melakukan logout. JWT tanpa blacklist database tidak dapat dicabut sebelum masa berlakunya habis.
2. Mitigasi XSS: Cookie HttpOnly tidak dapat dibaca oleh JavaScript jahat di browser, menghilangkan risiko pencurian credential melalui XSS.
3. Perlindungan Database Breach: Jika database terkompromi, penyerang hanya melihat hash token SHA-256, bukan token mentah yang dapat dipakai untuk membajak sesi aktif.

### Konsekuensi
- Positif: Keamanan tinggi, kontrol sesi penuh, audit last seen yang akurat.
- Negatif: Memerlukan database query pada setiap authenticated request (dapat dioptimalkan dengan index pada token_hash).

---

## ADR-003: Double-Submit Cookie CSRF Protection

### Status
Accepted

### Konteks
Karena autentikasi menggunakan cookie yang dikirim secara otomatis oleh browser, aplikasi rentan terhadap Cross-Site Request Forgery (CSRF) jika tidak diproteksi dengan benar.

### Keputusan
Menerapkan perlindungan CSRF berbasis double-submit pattern yang terikat pada sesi:
1. Cookie `sf_csrf` dikirimkan ke browser (non-HttpOnly, SameSite=Lax).
2. Frontend membaca cookie ini dan menyertakannya dalam header HTTP `X-CSRF-Token` pada setiap request mutasi (POST, PUT, PATCH, DELETE).
3. Backend memverifikasi bahwa hash header cocok dengan `csrf_token_hash` yang tersimpan pada sesi database.

### Alasan
Mencegah domain eksternal memicu transaksi atau perubahan data atas nama user yang sedang login.

---

## ADR-004: Tipe Data DECIMAL(18,3) untuk Kuantitas dan DECIMAL(18,2) untuk Harga

### Status
Accepted

### Konteks
Data kuantitas stok dan harga rentan mengalami ketidakakuratan perhitungan jika disimpan atau diproses menggunakan tipe floating point IEEE 754 (seperti FLOAT atau DOUBLE).

### Keputusan
1. Database MySQL menggunakan tipe `DECIMAL(18,3)` untuk semua kolom kuantitas stok (mendukung barang dengan satuan pecahan hingga 3 desimal, misalnya 1.250 kg).
2. Database MySQL menggunakan tipe `DECIMAL(18,2)` untuk harga pokok produk.
3. API Contract mengirimkan nilai kuantitas dan harga dalam bentuk formatted string decimal (bukan JSON number/float).

### Alasan
Mencegah bug akumulasi pembulatan floating point yang dapat merusak saldo inventaris dan laporan audit.

---

## ADR-005: Concurrency Control Menggunakan Pessimistic Locking (SELECT ... FOR UPDATE)

### Status
Accepted

### Konteks
Operasi Stock Out rentan terhadap race condition jika dua staf gudang melakukan transaksi pengurangan stok pada produk dan gudang yang sama secara simultan. Jika kedua transaksi membaca saldo 10 dan masing-masing mengurangi 8, saldo akhir dapat menjadi -6 jika tidak ada locking.

### Keputusan
Menerapkan transaksi database MySQL InnoDB dengan `SELECT ... FOR UPDATE` pada baris `inventory_balances` yang terkait, sebelum memvalidasi saldo dan melakukan mutasi.

### Alasan
1. Menjamin isolasi serializability pada tingkat baris.
2. Transaksi kedua akan menunggu lock dilepaskan oleh transaksi pertama, sehingga membaca saldo terkini yang sudah berkurang, lalu menolak transaksi jika stok tidak lagi mencukupi.
3. Didukung penuh oleh InnoDB engine tanpa memerlukan distributed lock eksternal seperti Redis untuk MVP.

---

## ADR-006: Koreksi Transaksi Melalui Full Reversal Saja

### Status
Accepted

### Konteks
Ketika terjadi kesalahan input pada transaksi Stock In atau Stock Out yang sudah terlanjur diposting, bagaimana mekanisme koreksinya?

### Keputusan
Aplikasi hanya mengizinkan Full Reversal (pembalikan penuh). Edit parsial atau penghapusan transaksi dilarang.

### Alasan
1. Mempertahankan prinsip immutable accounting ledger pada `stock_movements`.
2. Setiap transaksi yang dibalik memiliki referensi eksplisit ke transaksi asal melalui kolom `correction_of_transaction_id`.
3. Mengurangi kompleksitas validasi dan mencegah inkonsistensi saldo historis.

---

## ADR-007: Next.js Build-Time Reverse Proxy dan Isolasi Jaringan Internal Produksi

### Status
Accepted

### Konteks
Pada arsitektur produksi kontainer Docker, browser client berkomunikasi melalui same-origin relative path `/api/v1`. Next.js standalone menserialisasikan konfigurasi rewrites ke dalam `routes-manifest.json` saat proses `next build` dijalankan. Jika variabel `INTERNAL_BACKEND_URL` tidak tersedia saat build, konfigurasi akan menggunakan fallback `http://localhost:4000`, sehingga kontainer frontend produksi gagal meneruskan request ke backend. Selain itu, mengekspos port 4000 backend ke host publik melanggar prinsip defense-in-depth dan membocorkan arsitektur port internal.

### Keputusan
1. Meneruskan `INTERNAL_BACKEND_URL: http://backend:4000` secara eksplisit sebagai build argument dan builder environment variable pada `frontend/Dockerfile` dan `docker-compose.yml`.
2. Mengonfigurasi `frontend/next.config.ts` agar fallback produksi bernilai `http://backend:4000` (hanya menggunakan `http://localhost:4000` pada mode development non-produksi).
3. Menghapus publikasi host port untuk service backend (`ports: - "4000:4000"`) dan database pada `docker-compose.yml`. Komunikasi backend dan database dilakukan secara eksklusif melalui Docker internal network terisolasi (`stockflow_net`).
4. Membangun dedicated service `bootstrap` dengan profile `bootstrap` untuk menjalankan inisialisasi Administrator awal menggunakan production runtime image (`node dist/scripts/bootstrap.js`), dengan dukungan file secret (`INITIAL_ADMIN_PASSWORD_FILE`) dan tanpa development dependencies.

### Konsekuensi
- Positif: Isolasi jaringan internal sempurna, API path same-origin relatif tervalidasi pada build-time, port backend dan database tertutup rapat dari jaringan publik, proses bootstrap aman dan idempotent.
- Negatif: Pengujian langsung ke port 4000 dari host dinonaktifkan pada profil produksi; seluruh trafik web client wajib melalui reverse proxy Next.js pada port 3000.

---

## ADR-008: Localhost Portfolio Environment Architecture & Docker Compose Secrets

### Status
Accepted

### Konteks
Aplikasi StockFlow difokuskan sebagai Localhost Portfolio Edition yang berjalan secara mandiri dan optimal pada komputer lokal pengembang menggunakan Docker Compose tanpa memerlukan domain publik, VPS, atau sertifikat HTTPS publik. Penggunaan flag simulasi `ALLOW_LOCALHOST_SIMULATION` pada rilis sebelumnya berpotensi melemahkan kebijakan trusted origin ketika `NODE_ENV=production`. Selain itu, Docker Compose Secrets dibutuhkan agar pembacaan password awal administrator tidak mengandalkan environment variable biasa yang rentan terlihat di process table.

### Keputusan
1. Memisahkan konsep build mode (`NODE_ENV=production`) dan target deployment (`APP_DEPLOYMENT_MODE=local`).
2. Menghapus flag `ALLOW_LOCALHOST_SIMULATION` dari seluruh sistem.
3. Mengunci trusted origin secara kanonikal ke `http://localhost:3000` pada mode local, dan menolak port lain, IP 127.0.0.1, atau domain asing.
4. Mengimplementasikan file-backed Docker Compose Secrets (`initial_admin_password`) yang di-mount secara otomatis ke `/run/secrets/initial_admin_password` pada kontainer bootstrap.
5. Menolak pengiriman password administrator awal melalui environment variable biasa `INITIAL_ADMIN_PASSWORD` dan mewajibkan secret file.
6. Menyetel `COOKIE_SECURE=false` pada mode local agar sesi autentikasi browser bekerja secara native pada protokol HTTP localhost, dengan tetap mempertahankan seluruh kontrol keamanan session cookie (HttpOnly, SameSite=Lax, SHA-256 opaque token).

### Konsekuensi
- Positif: Keamanan origin deterministik tanpa flag simulasi ad-hoc, secret password terlindungi di luar Git/environment, siap didemokan secara instan dan andal sebagai proyek portofolio Full-Stack.
- Negatif: Pengujian origin tambahan di luar kanonikal `http://localhost:3000` harus melewati test configuration khusus.

---

## ADR-009: Localhost Loopback Interface Isolation dan Cryptographic Secret Generation

### Status
Accepted

### Konteks
Pemetaan port frontend menggunakan `"3000:3000"` pada Docker Compose mempublikasikan port ke seluruh host network interface (`0.0.0.0`), membuka kemungkinan akses tidak disengaja dari jaringan lokal (LAN). Selain itu, inisialisasi manual dari template `.env.example` rentan menggunakan nilai placeholder default. Di sisi lain, helper pengujian E2E sebelumnya memiliki toleransi fallback password hardcoded jika file secret tidak ditemukan.

### Keputusan
1. Mengikat port publikasi frontend secara eksplisit ke loopback interface host: `"127.0.0.1:3000:3000"` pada `docker-compose.yml`. Backend dan MySQL tetap 100% tertutup dari publikasi port host.
2. Mengembangkan skrip otomatis `scripts/init-local.ps1` berbasis API kriptografi .NET (`RandomNumberGenerator`) untuk menghasilkan seluruh nilai rahasia (`DB_ROOT_PASSWORD`, `DB_PASSWORD`, `SESSION_SECRET`, `CSRF_SECRET`, dan initial admin password 24 karakter) secara deterministik dan aman tanpa mencetak nilai ke terminal.
3. Menerapkan proteksi keamanan file Windows ACL (`icacls.exe`) pada file secret untuk membatasi akses hanya kepada pengguna aktif dan administrator sistem.
4. Menolak penimpaan otomatis jika `.env` atau secret file sudah ada demi menjaga keamanan data dan konsistensi operasional.
5. Memperketat validasi backend pada `backend/src/config/env.ts` dengan pola regex untuk secara tegas menolak nilai rahasia bertipe placeholder (`YOUR_`, `CHANGE_ME`, `REPLACE_`, `EXAMPLE_SECRET`, `PLACEHOLDER`).
6. Menghapus seluruh fallback credential hardcoded pada Playwright E2E (`getInitialAdminPassword()`). Test runner diwajibkan membaca file secret nyata dan melempar error eksplisit jika file tidak ditemukan.

### Konsekuensi
- Positif: Akses aplikasi terbatas secara ketat hanya pada komputer lokal pengembang (127.0.0.1), seluruh kredensial dihasilkan dengan standar kriptografi tinggi, risiko kebocoran placeholder dihilangkan, pengujian E2E sepenuhnya berbasis kredensial bootstrap nyata.
- Negatif: Pengguna pada sistem operasi Windows perlu menjalankan skrip PowerShell sebelum menjalankan Docker Compose untuk pertama kali.
