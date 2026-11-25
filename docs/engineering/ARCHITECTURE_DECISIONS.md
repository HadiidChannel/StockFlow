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

---

## ADR-010: Isolasi Lingkungan Pengujian E2E dan Siklus Hidup Infrastruktur Sekali Pakai

### Status
Accepted

### Konteks
Sebelumnya, pengujian Playwright E2E dijalankan langsung terhadap aplikasi utama di port 3000 atau berbagi volume database produksi (`mysql_prod_data`). Hal ini menimbulkan risiko polusi data pengujian ke dalam database utama, potensi race condition dengan data demo, serta risiko reset database yang merusak integritas lingkungan lokal utama. Di samping itu, pengujian E2E membutuhkan jaminan lingkungan bersih (clean slate) pada setiap eksekusi agar pengujian 13 tahap daur hidup inventaris bersifat deterministik.

### Keputusan
1. Membuat konfigurasi Docker Compose terisolasi `docker-compose.e2e.yml` dengan nama project tersendiri: `stockflow-e2e-test`.
2. Mengikat ingress frontend pengujian E2E secara eksklusif ke port loopback terpisah: `127.0.0.1:3100:3000`. Port aplikasi utama `127.0.0.1:3000` tetap aktif dan tidak pernah diganggu.
3. Menyediakan jaringan Docker internal terisolasi: `stockflow_e2e_net` dan volume database sekali pakai: `mysql_e2e_data`.
4. Mengembangkan skrip orkestrasi otomatis `scripts/run-e2e.ps1` yang menjalankan siklus lengkap: pengecekan port, pembuatan kredensial dinamis, inisialisasi database fresh, migrasi skema Prisma, eksekusi bootstrap administrator satu kali, peluncuran frontend/backend, eksekusi Playwright E2E, serta pembersihan otomatis (`docker compose down -v`) pada blok finally.
5. Menghilangkan seluruh kredensial statis dan fallback hardcoded dari test suite Playwright (`stockflow-lifecycle.spec.ts`) dengan menggenerasi password dinamis secara kriptografis menggunakan `crypto.randomInt`.

### Konsekuensi
- Positif: Isolasi 100% antara database utama dan database pengujian, zero data pollution, pengujian dapat dijalankan berulang kali secara deterministik tanpa merusak data aplikasi utama, kredensial dinamis menghilangkan risiko paparan secret.
- Negatif: Eksekusi pengujian E2E memerlukan waktu beberapa puluh detik untuk proses inisialisasi kontainer database dan migrasi skema sekali pakai.

---

## ADR-011: Decoupled Bootstrap Testing with Fail-Closed Guard and Dynamic E2E Container Namespaces

### Status
Accepted & Implemented (v1.6.1)

### Konteks
Pada audit v1.6 ditemukan dua titik kerentanan arsitektural:
1. `backend/tests/bootstrap.test.ts` memanipulasi role pengguna pada database aktif menggunakan role dummy `TEMP_TEST_ROLE` demi menguji jalur fresh database. Jika terjadi interupsi, database pengembangan lokal dapat tertinggal dalam keadaan tidak konsisten.
2. Pengujian E2E pada `docker-compose.e2e.yml` menggunakan nama project statis `stockflow-e2e-test` dan container name tetap, menimbulkan risiko tubrukan resource dan kegagalan isolasi saat dijalankan berulang atau paralel.
3. Deklarasi healthcheck database pada Docker Compose mengekspansi nilai rahasia saat perintah `compose config` dijalankan.

### Keputusan
1. **Pemisahan Unit vs Integration Test Bootstrap**:
   - Memindahkan pengujian logika bootstrap ke `backend/tests/bootstrap.unit.test.ts` dengan mock Prisma in-memory, menguji 10 skenario bisnis tanpa koneksi database.
   - Menghapus sepenuhnya penggunaan dummy role `TEMP_TEST_ROLE`.
   - Mengimplementasikan `backend/tests/bootstrap.integration.test.ts` dengan Fail-Closed Guard yang secara eksplisit menolak berjalan jika target bukan database terisolasi `stockflow_bootstrap_test`.
2. **Dynamic Project Namespace untuk Disposable E2E Stack**:
   - Mengubah `docker-compose.e2e.yml` agar menggunakan nama project dinamis: `name: ${COMPOSE_PROJECT_NAME:-stockflow-e2e-test}` dan menghapus seluruh `container_name:` statis.
   - Menggenerasikan Run ID acak 8 karakter hex pada `scripts/run-e2e.ps1` (`stockflow-e2e-<runId>`).
   - Menambahkan Ownership Guard sebelum eksekusi `down -v`.
3. **Double-Dollar Healthcheck Security**:
   - Menggunakan format `test: ["CMD-SHELL", "mysqladmin ping -h localhost -u root -p$${MYSQL_ROOT_PASSWORD} || exit 1"]` untuk menunda evaluasi password hingga runtime container, mencegah kebocoran password pada `docker compose config`.

### Konsekuensi
- Positif: Database lokal terlindungi 100% dari mutasi pengujian, unit test bootstrap berjalan secepat kilat (sub-detik), eksekusi E2E bebas dari konflik nama kontainer, dan konfigurasi Docker compose bersih tanpa kebocoran password.
- Negatif: Pengujian integrasi bootstrap nyata membutuhkan database uji terpisah yang harus dikonfigurasi secara eksplisit.

---

## ADR-012: Real Disposable MySQL 8.4 Container Architecture and Fail-Closed Guard for Bootstrap Integration Testing

### Status
Accepted & Implemented (v1.6.2)

### Konteks
Pada audit v1.6.1, pengujian integrasi bootstrap belum menyertakan harness database nyata sekali pakai yang terotomatisasi secara penuh. Selain itu, diperlukan mekanisme fail-closed yang memverifikasi database URL, run ID, protokol, dan hostname sebelum eksekusi bootstrap diperbolehkan, guna memastikan tidak ada mutasi yang menyentuh database operasional.

### Keputusan
1. **Containerized Disposable Database Harness (`docker-compose.bootstrap-test.yml`)**:
   - Menyediakan instance MySQL 8.4 terisolasi pada port loopback `127.0.0.1:3307:3306`.
   - Menggunakan volume sementara `mysql_bootstrap_test_data` dan network terisolasi `stockflow_bootstrap_test_net`.
   - Menyediakan service `migrator` di dalam Compose untuk menjalankan migrasi Prisma tanpa ketergantungan pada environment host.
2. **Fail-Closed Bootstrap Guard (`backend/src/utils/bootstrap-guard.ts`)**:
   - Memvalidasi skema koneksi `DATABASE_URL`:
     - Wajib protokol `mysql:`
     - Hostname terbatas pada `127.0.0.1`, `localhost`, atau `db`
     - Nama database wajib memuat run ID yang cocok (`stockflow_test_<runId>` atau `stockflow_bootstrap_<runId>`)
     - Larangan mutlak terhadap database operasional (`stockflow_db`, `stockflow_dev_db`, `stockflow_prod`, `stockflow_e2e_db`)
   - Melempar exception fail-closed dan menghentikan proses jika ada ketidaksesuaian.
3. **Automated Test Orchestrator (`scripts/run-bootstrap-test.ps1`)**:
   - Menghasilkan Run ID kriptografis unik.
   - Menjalankan kontainer, menunggu healthcheck, menerapkan migrasi Prisma, mengeksekusi pengujian integrasi Vitest, dan menghapus kontainer beserta volume secara bersih (`down -v`).

### Konsekuensi
- Positif: Pengujian integrasi bootstrap dilakukan terhadap database MySQL 8.4 murni yang identik dengan produksi, membuktikan pembuatan admin baru, hash bcrypt cost 12, dan idempotensi penolakan kedua run tanpa sedikit pun risiko mutasi terhadap database utama atau development.
- Negatif: Memerlukan alokasi port loopback 3307 selama masa pengujian integrasi.

---

## ADR-013: Deterministic Docker Resource Ownership Labels, Tag Fallbacks, and Comprehensive Secret Scanner

### Status
Accepted & Implemented (v1.6.2)

### Konteks
Audit independen menemukan bahwa resource Docker pengujian (container, volume, network) belum memiliki pelabelan kepemilikan eksplisit yang membedakannya dari resource lain. Selain itu, ketergantungan build saat eksekusi E2E offline dapat menyebabkan kegagalan jika image registry tidak dapat dijangkau. Scanner rahasia juga memerlukan penyempurnaan deteksi regex dan modul pengujian mandiri.

### Keputusan
1. **Docker Resource Ownership Labels**:
   - Menambahkan label standar `stockflow.e2e.run_id` dan `stockflow.e2e.owner` pada seluruh resource E2E.
   - Menambahkan label serupa `stockflow.test.run_id` pada bootstrap test harness.
   - Memastikan proses teardown memverifikasi label sebelum menghapus resource.
2. **Deterministic Pre-Built Image Fallbacks**:
   - Menambahkan tag fallback `${E2E_*_IMAGE:-stockflow-e2e-test-*:latest}` pada `docker-compose.e2e.yml` agar Compose langsung memanfaatkan image lokal yang telah di-build sebelumnya dan tidak memicu build ulang offline.
3. **Multi-Vector Secret Scanner with Self-Test (`scripts/scan-secrets.ps1`)**:
   - Menggunakan 6 pola regex deteksi mendalam (CLI arguments, connection strings, assignment secrets, bearer tokens, private keys, legacy test passwords).
   - Menyediakan fitur `-SelfTest` yang mengevaluasi fixture positif dan negatif secara deterministik.

### Konsekuensi
- Positif: Resource Docker terlacak secara transparan dan aman dari benturan nama, eksekusi E2E handal secara offline, dan pemindaian keamanan repositori dapat diverifikasi secara mandiri.
- Negatif: Skrip pemindaian memerlukan sedikit waktu tambahan untuk membaca konten file teks secara teliti.

---

## ADR-014: Windows NTFS Modify Permission Model, Fail-Closed E2E Teardown, and Staged Release Packaging Integrity

### Status
Accepted & Implemented (v1.6.3)

### Konteks
Pada audit v1.6.2, tiga temuan teknis utama masih terbuka:
1. Skrip inisialisasi lokal `scripts/init-local.ps1` memberikan hak akses `(R,W)` pada file rahasia Windows NTFS. Hak akses ini tidak menyertakan izin Delete `(D)`, sehingga operasi pembersihan file staging saat fault rollback atau penghapusan secret E2E memicu `UnauthorizedAccessException`.
2. Skrip pengujian E2E `scripts/run-e2e.ps1` menyembunyikan kegagalan penghapusan file secret sementara dengan `-ErrorAction SilentlyContinue`, membiarkan secret tertinggal di folder `.secrets/`.
3. Pembuatan manifest rilis yang mencatat commit hash git rentan memicu status git dirty jika file rilis atau manifest dibuat di dalam direktori kerja yang sedang dilacak.

### Keputusan
1. **Penerapan Model Izin Windows NTFS Modify (M)**:
   - Memperbarui `scripts/init-local.ps1` dan `scripts/run-e2e.ps1` untuk memberikan izin Modify `(M)` kepada pengguna pemilik (`*${userSid}:(M)`). Hak akses Modify memberikan izin Read, Write, dan Delete kepada pemilik tanpa memberikan Full Control kepada entitas lain.
   - Menambahkan fungsi `Remove-SafeRollbackFile` yang memberikan izin Modify sebelum menghapus file sementara pada blok catch rollback transaksional.
2. **Pembersihan Fail-Closed Secret E2E**:
   - Menghilangkan `-ErrorAction SilentlyContinue` pada `scripts/run-e2e.ps1`.
   - Mengaplikasikan izin `(M)` sebelum penghapusan, mengeksekusi `Remove-Item -Force -ErrorAction Stop`, memvalidasi ketiadaan file rahasia, dan memverifikasi 0 kontainer, 0 volume, dan 0 network tersisa sebelum menandai status `100% VERIFIED_CLEAN`.
3. **Rekayasa Staged Packaging Bebas Circular Dependency**:
   - Menambahkan `release-output/`, `audit/`, `*.zip`, dan `StockFlow_Release_Checksums_*.txt` ke `.gitignore`.
   - Mengarahkan `scripts/package-release.ps1` untuk menempatkan artefak rilis ke direktori terisolasi `release-output/v1.6.3/` dan `audit/v8_3/`.
   - Menegakkan 10 Gerbang Kualitas Rilis pada `scripts/verify-release.ps1` yang mengevaluasi status branch git, 40-karakter commit hash manifest, 3 paket ZIP, checksum SHA-256 dan ukuran byte, integritas ekstraksi arsip, kehadiran `.env.example`, isolasi rahasia aktif, loopback binding 127.0.0.1, pemindaian menyeluruh bebas rahasia, dan writing constraint 0 en/em dash.

### Konsekuensi
- Positif: Operasi rollback transaksional dan pembersihan secret E2E berjalan 100% andal tanpa permission error, ketiadaan silent failure menjamin zero secret residue, dan siklus commit git bersih sebelum pemaketan rilis deterministik.
- Negatif: Memerlukan tahapan komit git terlebih dahulu sebelum menjalankan skrip pemaketan rilis final.

---

## ADR-015: Anti-Circular Post-Commit Release Pipeline, Fail-Closed Verifier, and Complete Archive Handover

### Status
Accepted & Implemented (v1.6.4)

### Konteks
Audit independen terhadap v1.6.3 mengidentifikasi empat masalah integritas rilis:
1. Skrip verifikasi `scripts/verify-release.ps1` memperlakukan ketidakcocokan commit hash secara fail-open (hanya warning dan tetap menambah hitungan lulus), serta tidak memeriksa kebersihan working tree.
2. Bukti Git di dalam Audit Handover dibuat sebelum commit final sehingga mencatat hash yang berbeda dengan manifest eksternal.
3. Manifest checksum lama terbawa ke dalam Source ZIP akibat file terlacak lama dan penyalinan output rilis ke root proyek.
4. Paket Audit Handover menyalin file secara selektif parsial dan mencantumkan file tidak ada pada manifest sebagai Verified Present.

### Keputusan
1. **Urutan Eksekusi Rilis Anti-Sirkular di Lokasi Resmi Tunggal**:
   - Seluruh perubahan kode sumber, skrip, pengujian, dan dokumentasi terlacak diselesaikan dan dikomit bersih terlebih dahulu pada branch `fix/stockflow-v16-4-release-integrity`.
   - Seluruh artefak keluaran rilis (`StockFlow_Final_v8_4.zip`, `StockFlow_Final_Verification_v8_4.zip`, `StockFlow_Audit_Handover_v8_4.zip`, `StockFlow_Release_Checksums_v8_4.txt`, `FINAL_RELEASE_REPORT_V1_6_4.md`, dan bukti verifikasi pasca-commit) dihasilkan khusus di dalam direktori `.gitignore` tunggal `release-output/v1.6.4/`, tanpa menyalin artefak ke root proyek atau direktori `audit/`.
2. **Pemaketan Source ZIP Deterministik Berbasis `git archive HEAD`**:
   - Mengganti penyalinan langsung folder kerja pada `scripts/package-release.ps1` dengan ekspor `git archive --format=zip HEAD` disertai aturan eksklusi eksplisit untuk manifest checksum (`StockFlow_Release_Checksums_*.txt`), riwayat bukti, rahasia lokal, dan artefak build.
3. **Verifikator Rilis Fail-Closed (13 Gerbang) dan Negative Testing**:
   - Memperketat `scripts/verify-release.ps1` dengan fungsi `Fail-Gate` yang menghentikan eksekusi dengan exit code non-zero pada setiap kegagalan (Git binary, branch, full 40-char commit exact match, clean `git status --porcelain --untracked-files=all`, ukuran dan SHA-256, integritas arsip, template `.env.example`, ketiadaan manifest checksum tertanam, akurasi 1-to-1 `AUDIT_FILE_MANIFEST.md`, loopback port 127.0.0.1, pemindaian rahasia, konsistensi bukti Git di dalam arsip, dan larangan en/em dash).
   - Menambahkan suite pengujian terisolasi `tests/test-verify-release.ps1` (13 skenario) untuk membuktikan perilaku fail-closed di repository sementara `%TEMP%`.
4. **Perakitan Audit Handover Lengkap Berbasis Inventaris Programatis**:
   - Memperbarui `scripts/assemble-handover.ps1` untuk menyertakan keseluruhan implementasi backend dan frontend, Prisma migrations, lockfiles, Dockerfiles, skrip, dan seluruh berkas pengujian dari committed `HEAD`, memvalidasi berkas wajib, menyusun tabel `AUDIT_FILE_MANIFEST.md` lengkap dengan SHA-256 setiap file, lalu mengekstrak ulang ZIP untuk memverifikasi kelengkapan 100%.

### Konsekuensi
- Positif: Konsistensi 100% antara Git HEAD, Git evidence, ketiga ZIP, external manifest, dan laporan akhir; mustahil meloloskan commit mismatch atau manifest tidak akurat; serta tidak ada lagi circular dependency atau manifest historis bocor ke Source ZIP.
- Negatif: Laporan akhir `FINAL_RELEASE_REPORT_V1_6_4.md` dan `StockFlow_Release_Checksums_v8_4.txt` ditempatkan di `release-output/v1.6.4/` di luar pelacakan Git agar hash kriptografis tidak memicu perubahan commit tambahan.
