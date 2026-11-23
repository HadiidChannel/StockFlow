# StockFlow Security Review & Threat Mitigation Plan

## 1. Pendekatan Keamanan
StockFlow menerapkan filosofi Security by Design dan Defense in Depth. Keamanan bukan merupakan lapisan tambahan yang dipasang di akhir, melainkan diintegrasikan ke dalam setiap layer arsitektur: browser, network, routing, middleware, business logic, dan database.

## 2. Threat Modeling (STRIDE Analysis)

| Ancaman (STRIDE) | Risiko Spesifik pada StockFlow | Mitigasi yang Diterapkan |
|---|---|---|
| **Spoofing** (Pemalsuan Identitas) | Penyerang memalsukan identitas staf gudang atau admin | - Password di-hash menggunakan bcrypt dengan work factor (cost) 12.<br>- Session cookie bertipe opaque token acak 256-bit.<br>- Hanya hash SHA-256 yang disimpan di database.<br>- Rate limiting pada endpoint login untuk mencegah brute-force. |
| **Tampering** (Manipulasi Data) | Pengguna memanipulasi kuantitas stok atau ID gudang pada request | - Validasi ketat pada backend dengan Zod schema.<br>- Perhitungan saldo dilakukan 100% di database transaction.<br>- Double-submit CSRF token untuk setiap mutasi data.<br>- Snapshot harga, SKU, dan nama saat transaksi dicatat. |
| **Repudiation** (Penyangkalan Tindakan) | Pengguna menyangkal telah melakukan pengeluaran barang | - Setiap mutasi stok tercatat dalam `stock_movements` yang immutable.<br>- Snapshot `created_by` dan nama user disimpan permanen.<br>- Audit trail mencatat timestamp UTC presisi milidetik. |
| **Information Disclosure** (Kebocoran Informasi) | Warehouse Staff melihat data stok gudang yang bukan haknya | - Service-layer data scoping wajib memvalidasi tabel `user_warehouse_assignments`.<br>- Global error handler membersihkan stack trace dan detail database sebelum response dikirim ke client. |
| **Denial of Service** (Penolakan Layanan) | Penyerang membombardir endpoint pembuatan transaksi atau login | - Rate limiting berbasis IP dan user ID pada endpoint autentikasi dan mutasi inventaris.<br>- Request body size limited hingga 100kb.<br>- Connection pooling yang terkontrol pada Prisma. |
| **Elevation of Privilege** (Peningkatan Hak Akses) | Warehouse Staff memanipulasi parameter role untuk menjadi Admin | - Otorisasi berbasis RBAC diuji di backend pada setiap protected route.<br>- Pembuatan/perubahan user hanya dapat dilakukan oleh role ADMIN.<br>- Default permission bersifat deny unless explicitly allowed. |

## 3. Checklist Hardening OWASP Top 10

### A01: Broken Access Control
- Setiap endpoint privat memeriksa session dan role.
- Warehouse Staff dibatasi hanya pada gudang yang ditugaskan.
- IDOR dicegah dengan selalu memvalidasi kepemilikan organisasi dan assignment gudang.

### A02: Cryptographic Failures
- Password di-hash dengan bcrypt (cost factor 12, memory-hardened salt per user, NIST SP 800-63B compliant).
- Cookie session menggunakan flag `HttpOnly`, `SameSite=Lax`, dan `Secure` pada mode production.
- Token autentikasi dan CSRF di-hash dengan SHA-256 sebelum disimpan di database.

### A03: Injection (SQL & XSS)
- Menggunakan Prisma ORM dengan parameterized queries secara default untuk mencegah SQL Injection.
- Penggunaan raw SQL hanya jika diperlukan untuk locking, dan selalu menggunakan tagged template literals `$queryRaw` dengan parameter aman.
- Output teks di frontend di-escape secara otomatis oleh React/JSX untuk mencegah Cross-Site Scripting (XSS).

### A04: Insecure Design
- Prinsip pemisahan tugas (Separation of Concerns).
- Saldo inventaris tidak dapat bernilai negatif berkat database CHECK constraint dan validasi transaksional.
- Transaksi stok berstatus `POSTED` bersifat immutable.

### A05: Security Misconfiguration
- Helmet middleware diaktifkan untuk mengatur HTTP security headers (HSTS, Content Security Policy, X-Content-Type-Options, dll.).
- CORS dibatasi hanya untuk origin frontend yang terdaftar dalam allowlist.
- Environment variables dipisahkan antara development dan production.

### A06: Vulnerable and Outdated Components
- Audit dependency secara rutin menggunakan `npm audit`.
- Mengunci versi dependency dengan package-lock.json.

### A07: Identification and Authentication Failures
- Sesi diakhiri secara menyeluruh saat logout atau saat akun dinonaktifkan (`revoked_at` diisi timestamp UTC).
- Mekanisme `must_change_password` memaksa penggantian password sementara setelah bootstrap atau reset oleh admin.

### A08: Software and Data Integrity Failures
- Idempotency key (`Idempotency-Key` header) mencegah eksekusi transaksi berulang akibat retry jaringan.

### A09: Security Logging and Monitoring Failures
- Request ID (`X-Request-Id`) disertakan pada setiap request dan dicatat di log.
- Data sensitif (password, token sesi, nomor kartu) disaring sebelum masuk ke log.

### A10: Server-Side Request Forgery (SSRF)
- Backend StockFlow tidak melakukan fetch request ke URL eksternal yang diinput oleh pengguna.

---

## 4. Hardening Rilis Produksi v1.3

### A. Isolasi Penuh Jaringan Host (Host Port Removal)
- Port 4000 (Backend Express) dan Port 3306 (MySQL) tidak dipublikasikan ke host publik pada konfigurasi `docker-compose.yml`.
- Seluruh komunikasi backend dan database berlangsung secara eksklusif di dalam Docker bridge network internal (`stockflow_net`).
- Satu-satunya ingress yang terbuka ke host publik adalah frontend Next.js pada port 3000, yang mengalirkan request API browser melalui same-origin relative path `/api/v1`.

### B. Dedicated Administrator Bootstrap Service
- Inisialisasi akun Administrator awal dipisahkan dari service operasional yang berjalan reguler.
- Service `bootstrap` menggunakan compiled production image (`node dist/scripts/bootstrap.js`) tanpa ketergantungan pada tool development (`tsx`).
- Mendukung pemuatan credential melalui file rahasia (`INITIAL_ADMIN_PASSWORD_FILE`) untuk mencegah kebocoran password pada process arguments atau environment dump.
- Dilengkapi one-time execution guard yang menolak pembuatan admin duplikat jika akun Administrator sudah ada di sistem.

### C. Rotasi Kredensial dan Sanitasi Bukti Audit
- Seluruh credential baseline dan development password telah dirotasi secara penuh.
- File konfigurasi dan bukti audit pada `audit/evidence/` disanitasi secara ketat sehingga tidak menyimpan raw password atau session secret nyata.

---

## 5. Hardening Rilis Portofolio Lokal v1.4

### A. Eliminasi Total Mekanisme ALLOW_LOCALHOST_SIMULATION
- Toggle `ALLOW_LOCALHOST_SIMULATION` yang sebelumnya mengizinkan simulasi origin secara kondisional telah dihapus sepenuhnya dari codebase.
- Pemisahan tanggung jawab konfigurasi dibuat eksplisit:
  - `NODE_ENV=production`: Mengatur optimasi build, logging, dan kompilasi production image.
  - `APP_DEPLOYMENT_MODE`: Menentukan target environment aktual (`local` untuk portofolio lokal pada komputer pengguna, atau `production` untuk cloud/VPS publik).
- Pada mode `APP_DEPLOYMENT_MODE=local`, origin tepercaya tunggal (canonical trusted origin) dikunci secara ketat ke `http://localhost:3000`.

### B. Validasi Ketat Origin CORS dan CSRF pada Localhost
- CORS allowlist dan CSRF middleware memvalidasi `Origin` dan `Referer` secara presisi.
- Permintaan dari IP langsung seperti `http://127.0.0.1:3000` atau port localhost lain (misal `http://localhost:8080`) secara eksplisit ditolak dengan status HTTP 403 Forbidden.
- Mengeliminasi risiko Cross-Origin Request Forgery dan serangan DNS rebinding lokal.

### C. File-Backed Docker Compose Secrets untuk Administrator Bootstrap
- Password akun Administrator awal tidak lagi diperbolehkan disuplai melalui ordinary environment variable (`INITIAL_ADMIN_PASSWORD`).
- Menggunakan top-level Docker Compose Secrets (`initial_admin_password`) yang di-mount secara aman dan read-only ke `/run/secrets/initial_admin_password` di dalam container.
- Skrip `bootstrap.ts` memvalidasi keberadaan file secret dan menolak eksekusi jika variabel environment biasa digunakan.
- Password wajib memenuhi standar kompleksitas NIST (minimal 12 karakter, mengandung huruf besar, huruf kecil, angka, dan simbol).
- One-time execution guard memastikan eksekusi kedua diabaikan dengan aman tanpa mengubah data.
- Akun Administrator awal dibuat dengan status `must_change_password = 1`, mewajibkan admin memperbarui password pada login pertama sebelum dapat membuka dashboard.

### D. Verifikasi Siklus Hidup Database Bersih & E2E Testing
- Siklus inisialisasi dari database kosong telah diverifikasi pada stack MySQL 8.4.13 terisolasi: migrasi 14 tabel relasional, 9 CHECK constraints aktif, dan 2 composite foreign keys.
- Pengujian Playwright E2E 13 tahap diverifikasi secara live terhadap container produksi yang berjalan, membuktikan alur login bootstrap admin, forced password change, pemeliharaan sesi cookie, transaksi stok, RBAC, dan audit trail tanpa simulasi mock.
