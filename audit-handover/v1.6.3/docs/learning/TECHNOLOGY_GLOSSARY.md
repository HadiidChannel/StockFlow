# StockFlow Technology Glossary

Daftar istilah dan konsep teknis yang digunakan dalam ekosistem pengembangan StockFlow beserta penjelasannya:

---

### B
- **Balance Before / Balance After**: Snapshot saldo inventaris sebelum dan sesudah suatu transaksi terjadi. Wajib dicatat di ledger untuk keperluan rekonsiliasi audit trail.
- **bcrypt**: Algoritma hashing password adaptif berbasis Blowfish cipher dengan work factor (cost) yang dapat disesuaikan (StockFlow menggunakan cost factor 12), salt acak per pengguna, serta standar industri yang diakui NIST untuk perlindungan brute-force.
- **Bootstrap**: Proses inisialisasi awal sistem untuk membuat entitas organisasi pertama dan akun pengguna Admin pertama sebelum sistem dapat digunakan secara normal.

### C
- **CHECK Constraint**: Aturan integritas pada database MySQL yang membatasi nilai yang dapat disimpan dalam kolom, misalnya `quantity >= 0`.
- **CSRF (Cross-Site Request Forgery)**: Serangan web di mana situs pihak ketiga yang berbahaya memaksa browser pengguna yang sudah terautentikasi untuk mengirimkan request tidak sah ke aplikasi target.
- **Concurrency Control**: Teknik yang digunakan untuk mengelola akses simultan ke data yang sama oleh beberapa proses tanpa menimbulkan inkonsistensi data.

### D
- **DECIMAL(18,3)**: Tipe data numerik fixed-point presisi tinggi pada SQL yang menyimpan angka eksak tanpa error pembulatan floating point (18 digit total, 3 digit desimal).
- **Defense in Depth**: Strategi keamanan berlapis di mana jika satu lapisan pertahanan gagal, lapisan berikutnya akan mencegah atau memitigasi kompromi sistem.

### H
- **Helmet**: Middleware keamanan Express.js yang mengatur berbagai header respons HTTP (seperti CSP, HSTS, X-Frame-Options) untuk melindungi aplikasi dari kerentanan umum.
- **HttpOnly**: Atribut pada cookie HTTP yang mencegah cookie tersebut diakses melalui JavaScript di browser, memitigasi risiko pencurian token via XSS.

### I
- **IDOR (Insecure Direct Object Reference)**: Kerentanan kontrol akses di mana penyerang dapat mengakses atau memodifikasi objek data milik pengguna lain dengan memanipulasi parameter ID.
- **Idempotency**: Properti dari suatu operasi di mana mengeksekusi operasi tersebut beberapa kali dengan parameter yang sama menghasilkan efek yang persis sama dengan mengeksekusinya satu kali.
- **InnoDB**: Storage engine default MySQL yang mendukung transaksi ACID, foreign keys, dan row-level locking.

### P
- **Pessimistic Locking**: Strategi penguncian baris data pada database (`SELECT ... FOR UPDATE`) sebelum melakukan perubahan untuk mencegah proses lain membaca atau mengubah baris tersebut sampai transaksi selesai.
- **Prisma ORM**: Object-Relational Mapping generasi baru untuk Node.js dan TypeScript yang menyediakan deklarasi skema bersih, migrasi otomatis, dan tipe data query yang strictly typed.

### R
- **RBAC (Role-Based Access Control)**: Mekanisme kontrol akses berbasis peran di mana izin operasi diberikan berdasarkan peran yang dimiliki pengguna (misalnya ADMIN vs WAREHOUSE_STAFF).
- **Reversal (Full Reversal)**: Proses pembatalan transaksi dengan membuat transaksi pembalik baru yang memulihkan saldo dan mencatat pergerakan stok penyeimbang, tanpa menghapus data transaksi asal.

### S
- **SameSite Cookie**: Atribut cookie yang mengontrol apakah cookie dikirimkan bersama permintaan lintas situs (cross-site requests), membantu mencegah serangan CSRF.
- **SKU (Stock Keeping Unit)**: Kode unik pengenal produk yang digunakan untuk membedakan dan melacak barang dalam manajemen inventaris.
