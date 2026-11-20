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
