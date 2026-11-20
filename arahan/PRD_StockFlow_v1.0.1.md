# Product Requirements Document (PRD)

## StockFlow

**Produk:** StockFlow  
**Dokumen:** Product Requirements Document  
**Versi:** 1.0.1  
**Status:** Revisi terarah untuk menyelaraskan scope akses gudang dan metrik dashboard dengan FSD v1.0.1  
**Tanggal:** 12 November 2026  
**Dokumen acuan desain:** `StockFlow_Design_System_UIUX_Spec_v1.0.md`  
**Platform:** Web application, responsive desktop, tablet, dan smartphone  
**Bahasa antarmuka awal:** Bahasa Indonesia

---

## 1. Ringkasan produk

StockFlow adalah aplikasi web B2B untuk membantu perusahaan dan tim operasional mengelola inventaris serta stok di beberapa gudang melalui satu sistem terpusat. Aplikasi menyediakan pencatatan produk, kategori, gudang, saldo stok, transaksi barang masuk, transaksi barang keluar, riwayat pergerakan stok, dan dashboard ringkasan inventaris.

StockFlow ditujukan untuk organisasi yang membutuhkan pencatatan stok lebih terstruktur dibandingkan spreadsheet atau pencatatan manual. Setiap perubahan stok harus mempunyai referensi transaksi, pengguna yang melakukan tindakan, waktu pencatatan, dan informasi produk serta gudang yang terkait.

Produk dikembangkan sebagai web application dengan frontend Next.js dan React, backend REST API menggunakan Node.js dan Express.js, serta database MySQL. Docker dan Docker Compose digunakan untuk menyediakan lingkungan development yang konsisten dan mendukung proses deployment.

### Riwayat revisi

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0.1 | 12 November 2026 | Penegasan penugasan gudang untuk Warehouse Staff, aturan deaktivasi gudang yang menjaga assignment aktif, dan perbaikan metrik dashboard agar tidak menjumlahkan kuantitas dengan satuan berbeda; diselaraskan dengan FSD v1.0.1. |

### 1.1 Ringkasan keputusan produk

| Aspek | Keputusan |
|---|---|
| Nama produk | StockFlow |
| Kategori | B2B SaaS Inventory & Warehouse Management System |
| Pengguna utama | Pemilik/Admin dan Warehouse Staff |
| Masalah utama | Pencatatan stok tersebar, tidak konsisten, dan sulit ditelusuri |
| Platform | Web responsif |
| Model organisasi MVP | Satu organisasi untuk satu instalasi aplikasi |
| Lokasi inventaris | Mendukung beberapa gudang dalam satu organisasi |
| Bahasa awal | Bahasa Indonesia |
| Frontend | Next.js, React, TypeScript |
| Backend | Node.js, Express.js, TypeScript |
| Database | MySQL 8.4 LTS |
| ORM | Prisma |
| Containerization | Docker dan Docker Compose |
| Prioritas produk | Akurasi stok, keterlacakan transaksi, kemudahan operasional |
| Design direction | Creative Premium SaaS, light dan dark mode, immersive motion dengan prioritas produktivitas |

### 1.2 Visi produk

Menjadi workspace inventaris yang membantu tim operasional mengetahui kondisi stok, memahami setiap perubahan, dan mengambil tindakan dengan percaya diri.

### 1.3 Pernyataan nilai produk

StockFlow membantu organisasi mengurangi ketergantungan pada pencatatan manual dengan menyediakan data inventaris yang terpusat, riwayat transaksi yang dapat ditelusuri, serta informasi stok yang mudah dipahami.

---

## 2. Latar belakang dan masalah

### 2.1 Kondisi yang ingin diperbaiki

Organisasi yang mengelola barang sering menghadapi beberapa masalah berikut:

1. Data produk dan jumlah stok tersimpan pada file atau media pencatatan yang berbeda.
2. Perubahan stok tidak selalu dicatat pada waktu yang sama dengan kejadian operasional.
3. Pengguna sulit mengetahui siapa yang mengubah stok dan kapan perubahan dilakukan.
4. Stok di beberapa gudang sulit dipantau melalui satu tampilan.
5. Informasi stok menipis terlambat diketahui karena pemeriksaan dilakukan secara manual.
6. Proses pencarian data produk dan riwayat transaksi membutuhkan waktu.
7. Perbedaan antara stok fisik dan catatan sistem sulit ditelusuri jika tidak ada riwayat transaksi yang konsisten.

### 2.2 Problem statement

Tim operasional membutuhkan satu sumber data inventaris yang mudah digunakan, mampu mencatat transaksi stok secara konsisten, serta memberikan visibilitas terhadap saldo dan riwayat stok per gudang. Tanpa sistem tersebut, organisasi berisiko mengambil keputusan berdasarkan data yang terlambat atau tidak akurat.

### 2.3 Hipotesis produk

Jika StockFlow menyediakan master data inventaris, transaksi barang masuk dan keluar, saldo stok per gudang, serta riwayat pergerakan yang konsisten, maka tim operasional dapat mencatat dan memeriksa perubahan stok dengan lebih terstruktur.

Hipotesis ini perlu divalidasi melalui penggunaan MVP oleh pengguna nyata. PRD ini tidak menganggap peningkatan efisiensi atau pengurangan kesalahan sebagai hasil yang sudah terbukti.

---

## 3. Tujuan dan indikator keberhasilan

### 3.1 Tujuan produk

1. Menyediakan pencatatan produk dan gudang yang terpusat.
2. Menyediakan saldo stok berdasarkan produk dan gudang.
3. Mencatat transaksi barang masuk dan barang keluar secara konsisten.
4. Menyediakan riwayat perubahan stok yang dapat ditelusuri.
5. Menunjukkan produk yang stoknya berada pada atau di bawah batas minimum.
6. Membatasi tindakan berdasarkan peran pengguna.
7. Menyediakan antarmuka yang jelas, responsif, dan nyaman untuk pekerjaan operasional.
8. Menyediakan fondasi teknis yang dapat dikembangkan ke modul inventaris lanjutan.

### 3.2 Indikator keberhasilan MVP

Indikator berikut digunakan untuk mengevaluasi MVP. Target angka dapat disesuaikan setelah pengujian dengan pengguna dan data operasional nyata.

| Area | Indikator | Kriteria awal |
|---|---|---|
| Setup | Environment dapat dijalankan | Frontend, backend, dan MySQL dapat dijalankan dengan Docker Compose |
| Authentication | Akses pengguna | Pengguna yang valid dapat login dan pengguna tanpa sesi tidak dapat mengakses halaman terlindungi |
| Master data | Kelola data utama | Admin dapat membuat, melihat, mengubah, dan menonaktifkan produk, kategori, serta gudang |
| Inventory | Akurasi saldo | Saldo berubah sesuai transaksi yang berhasil diposting dan tidak berubah jika transaksi gagal |
| Stock control | Pencegahan stok negatif | Stock Out yang melebihi stok tersedia ditolak oleh backend |
| Traceability | Riwayat transaksi | Setiap transaksi stok yang berhasil mempunyai nomor referensi, waktu, pengguna, produk, gudang, dan kuantitas |
| Low stock | Informasi stok minimum | Produk yang memenuhi kondisi stok minimum ditampilkan pada dashboard |
| Usability | Penyelesaian tugas utama | Pengguna uji dapat melakukan alur Stock In dan Stock Out tanpa bantuan teknis setelah onboarding |
| Responsive UI | Penggunaan lintas perangkat | Fungsi inti dapat digunakan pada desktop, tablet, dan smartphone |
| Visual quality | Konsistensi antarmuka | Halaman memenuhi design system dan quality gates pada dokumen UI/UX |

### 3.3 Metrik evaluasi setelah pilot

Setelah digunakan dalam pilot, evaluasi dapat mengukur:

- Waktu rata-rata untuk mencatat Stock In dan Stock Out.
- Jumlah transaksi yang gagal karena validasi atau masalah teknis.
- Jumlah koreksi pencatatan stok.
- Jumlah produk dengan saldo di bawah minimum.
- Frekuensi pengguna membuka riwayat pergerakan stok.
- Tingkat keberhasilan pengguna menyelesaikan tugas utama.

Pengukuran harus menggunakan data pilot yang benar-benar tersedia. Jangan mengisi laporan produk dengan angka estimasi yang tidak berasal dari penggunaan aktual.

---

## 4. Target pengguna dan persona

### 4.1 Segmen pengguna

StockFlow pada tahap awal ditujukan untuk bisnis kecil hingga menengah atau tim operasional yang mengelola persediaan barang dan membutuhkan pencatatan stok berbasis web.

Contoh konteks penggunaan:

- Distributor atau toko grosir.
- Perusahaan dengan gudang penyimpanan barang.
- Tim operasional yang menangani barang masuk dan keluar.
- Bisnis yang saat ini menggunakan spreadsheet untuk memantau inventaris.

Target segmen tersebut merupakan fokus awal produk, bukan klaim bahwa semua kebutuhan setiap industri telah tercakup.

### 4.2 Persona 1: Admin / Pemilik Organisasi

**Tujuan:** Memastikan data inventaris organisasi terkelola dan dapat dipantau.

**Tanggung jawab:**

- Mengelola data produk dan kategori.
- Mengelola lokasi gudang.
- Membuat akun pengguna dan menetapkan role.
- Melihat kondisi inventaris secara menyeluruh.
- Memantau transaksi dan stok menipis.

**Kebutuhan utama:**

- Dashboard ringkas.
- Pengaturan master data.
- Kontrol akses pengguna.
- Riwayat transaksi yang dapat ditelusuri.

**Hambatan:**

- Data stok tidak terkonsolidasi.
- Tidak mudah memastikan siapa yang melakukan perubahan.
- Sulit melihat produk yang membutuhkan perhatian.

### 4.3 Persona 2: Warehouse Staff

**Tujuan:** Mencatat dan memeriksa stok barang secara akurat dalam aktivitas harian.

**Tanggung jawab:**

- Melihat data produk.
- Melihat saldo produk hanya pada gudang yang ditugaskan.
- Mencatat barang masuk dan barang keluar pada gudang yang ditugaskan.
- Memeriksa riwayat pergerakan stok pada gudang yang ditugaskan.

**Kebutuhan utama:**

- Form transaksi yang ringkas.
- Informasi stok tersedia sebelum Stock Out.
- Validasi kuantitas yang jelas.
- Feedback ketika transaksi berhasil atau gagal.

**Hambatan:**

- Form terlalu panjang atau membingungkan.
- Tidak mengetahui saldo terkini.
- Kesalahan input sulit ditemukan setelah transaksi.

### 4.4 Persona di luar MVP

Supervisor, Purchasing Staff, Supplier, dan auditor eksternal dapat menjadi persona untuk pengembangan berikutnya. Kebutuhan mereka tidak menjadi dasar hak akses rilis MVP kecuali dinyatakan secara eksplisit pada FSD.

---

## 5. Ruang lingkup produk

### 5.1 Prinsip penentuan scope

MVP harus membuktikan alur dasar pengelolaan stok dari data master hingga pencatatan transaksi dan pemeriksaan saldo. Fitur lanjutan tidak boleh memperlambat penyelesaian dan pengujian fungsi inti.

### 5.2 Scope MVP

| Modul | Fitur | Prioritas |
|---|---|---|
| Application foundation | App shell, navigation, theme, responsive layout | Must Have |
| Authentication | Login, logout, session handling | Must Have |
| User management | Admin membuat, melihat, mengubah role, menonaktifkan akun pengguna | Must Have |
| Warehouse assignment | Admin menetapkan satu atau beberapa gudang aktif kepada setiap Warehouse Staff | Must Have |
| Authorization | Role Admin dan Warehouse Staff dengan pembatasan akses gudang | Must Have |
| Organization profile | Nama dan informasi dasar organisasi | Must Have |
| Product management | CRUD produk, SKU, kategori, satuan, minimum stock, harga pokok opsional, status | Must Have |
| Category management | CRUD kategori | Must Have |
| Warehouse management | CRUD gudang dan status aktif; deaktivasi tidak boleh membuat Warehouse Staff aktif kehilangan seluruh gudang aktif yang ditugaskan | Must Have |
| Inventory balance | Saldo produk per gudang dan total saldo produk | Must Have |
| Stock In | Pencatatan barang masuk | Must Have |
| Stock Out | Pencatatan barang keluar dengan validasi stok tersedia | Must Have |
| Stock movement history | Daftar dan detail transaksi pergerakan stok | Must Have |
| Dashboard | KPI dasar, low stock, pergerakan terkini, grafik sederhana | Must Have |
| Search and filtering | Search, filter, sorting, pagination pada daftar utama | Must Have |
| Theme | Light, Dark, System | Must Have |
| UI feedback | Loading, empty, error, success, permission denied, network state | Must Have |
| Docker environment | Dockerfile, Docker Compose, MySQL persistent volume | Must Have |
| API documentation | Dokumentasi endpoint untuk pengujian dan integrasi | Should Have |
| Automated tests | Unit dan integration test untuk alur kritis | Should Have |

### 5.3 Batasan MVP

Untuk menjaga ruang lingkup tetap terukur:

1. Satu deployment hanya digunakan oleh satu organisasi.
2. Satu organisasi dapat memiliki beberapa gudang.
3. Role awal hanya Admin dan Warehouse Staff.
4. Admin memiliki akses ke seluruh gudang. Setiap Warehouse Staff harus ditugaskan ke satu atau beberapa gudang aktif oleh Admin.
5. Warehouse Staff hanya dapat melihat saldo, transaksi, dan riwayat pada gudang yang ditugaskan. Transaksi baru hanya dapat dibuat pada gudang yang ditugaskan dan masih aktif.
6. Transaksi yang tersedia adalah Stock In dan Stock Out.
7. Saldo stok dikelola per kombinasi produk dan gudang.
8. Pengguna belum dapat membuat organisasi baru melalui self-service multi-tenant.
9. Tidak ada integrasi akuntansi atau sistem ERP eksternal.
10. Tidak ada aplikasi mobile native pada rilis awal.
11. Aplikasi web harus responsif pada smartphone, tetapi tidak menggantikan aplikasi native.

### 5.4 Fitur fase berikutnya

| Fitur | Deskripsi | Fase |
|---|---|---|
| Supplier management | Master pemasok dan detail kontak | V1.1 atau berikutnya |
| Purchase Order | Pembuatan dan pengelolaan pesanan pembelian | V1.1 atau berikutnya |
| Goods receiving | Penerimaan barang yang terhubung ke PO | V1.1 atau berikutnya |
| Stock Transfer | Pemindahan stok antar gudang | V1.1 atau berikutnya |
| Stock Opname | Pencatatan hasil penghitungan fisik dan selisih | V1.1 atau berikutnya |
| Stock Adjustment | Penyesuaian saldo dengan alasan dan otorisasi | V1.1 atau berikutnya |
| Reports and export | Laporan stok dan CSV export | V1.1 atau berikutnya |
| Audit log lengkap | Log perubahan master data dan aktivitas sensitif | V1.1 atau berikutnya |
| Notification center | Notifikasi kejadian inventaris dan operasional | V1.1 atau berikutnya |
| Barcode support | Input atau pencarian menggunakan barcode scanner | V1.2 atau berikutnya |
| Multi-tenant SaaS | Banyak organisasi dalam satu deployment dengan isolasi data | Fase lanjutan |
| Mobile application | Aplikasi Android/iOS menggunakan Flutter atau teknologi lain | Fase lanjutan |
| Integrasi eksternal | API atau integrasi dengan sistem lain | Berdasarkan kebutuhan |

### 5.5 Out of scope

Fitur berikut tidak termasuk dalam komitmen MVP:

- Akuntansi, general ledger, dan perhitungan COGS.
- Pengelolaan lot, batch, serial number, dan tanggal kedaluwarsa.
- Inventory reservation dan alokasi stok untuk order pelanggan.
- Marketplace atau penjualan online.
- Invoice dan pembayaran.
- Integrasi otomatis dengan supplier.
- Prediksi kebutuhan stok berbasis machine learning.
- Sinkronisasi offline penuh.
- Multi-currency dan multi-company consolidation.
- Workflow approval berlapis.

---

## 6. Konsep dan aturan produk

Bagian ini menjelaskan aturan produk pada tingkat kebutuhan. Detail teknis, struktur tabel, endpoint, algoritma, dan transaksi database akan ditetapkan di FSD serta dokumen arsitektur.

### 6.1 Organisasi dan gudang

1. Pada MVP terdapat satu organisasi untuk satu instalasi StockFlow.
2. Organisasi dapat mempunyai lebih dari satu gudang.
3. Setiap gudang memiliki nama, kode unik, informasi lokasi opsional, dan status aktif.
4. Gudang nonaktif tidak dapat dipilih untuk transaksi baru.
5. Setiap Warehouse Staff aktif wajib memiliki minimal satu gudang aktif yang ditugaskan.
6. Admin tidak dapat menonaktifkan gudang jika tindakan tersebut membuat Warehouse Staff aktif kehilangan seluruh gudang aktif yang ditugaskan.
7. Assignment ke gudang yang dinonaktifkan tetap disimpan agar pengguna yang masih ditugaskan dapat melihat saldo historis, tetapi gudang tersebut tidak dapat dipilih untuk transaksi baru.
8. Gudang yang memiliki riwayat transaksi tidak boleh dihapus permanen melalui alur normal. Gudang tersebut dapat dinonaktifkan.

### 6.2 Produk dan SKU

1. Setiap produk memiliki nama dan SKU.
2. SKU harus unik dalam organisasi.
3. Produk dapat terhubung ke satu kategori.
4. Setiap produk memiliki satu satuan dasar, misalnya pcs, box, kg, atau liter.
5. MVP tidak menyediakan konversi otomatis antar satuan.
6. Minimum stock ditetapkan pada tingkat produk. Admin membandingkannya dengan total saldo seluruh gudang, sedangkan Warehouse Staff membandingkannya dengan agregat saldo pada gudang yang ditugaskan.
7. Harga pokok dapat diisi secara opsional per satuan dasar produk untuk estimasi nilai stok, bukan untuk pembukuan akuntansi.
8. Produk nonaktif tidak dapat digunakan pada transaksi baru.
9. Produk dengan riwayat transaksi tidak boleh dihapus permanen melalui alur normal. Produk dapat diarsipkan atau dinonaktifkan.

### 6.3 Saldo inventaris

1. Saldo disimpan atau dihitung untuk setiap kombinasi produk dan gudang.
2. Total saldo untuk Admin merupakan jumlah saldo produk pada seluruh gudang. Untuk Warehouse Staff, saldo agregat hanya menjumlahkan gudang yang ditugaskan, termasuk saldo historis pada gudang nonaktif yang assignment-nya masih berlaku.
3. Stock In menambah saldo pada gudang yang dipilih.
4. Stock Out mengurangi saldo pada gudang yang dipilih.
5. Stock Out tidak boleh menyebabkan saldo menjadi negatif.
6. Perubahan saldo dan pencatatan riwayat transaksi harus berhasil atau gagal sebagai satu kesatuan.
7. Kegagalan validasi atau kegagalan penyimpanan tidak boleh meninggalkan perubahan saldo parsial.
8. Saldo tidak boleh diedit langsung melalui tampilan master produk.

### 6.4 Transaksi stok

1. Setiap transaksi memiliki nomor referensi unik.
2. Transaksi mencatat jenis transaksi, produk, gudang, kuantitas, waktu, pengguna, dan catatan opsional.
3. Satu transaksi dapat memuat satu atau beberapa baris produk jika rancangan FSD mendukungnya.
4. Kuantitas harus lebih besar dari nol.
5. Transaksi yang berhasil diposting tidak dapat diedit atau dihapus melalui alur normal.
6. Koreksi atas kesalahan pencatatan pada MVP dilakukan melalui transaksi kompensasi yang berlawanan, disertai catatan referensi transaksi sebelumnya. Mekanisme pembatalan formal dapat ditambahkan pada fase berikutnya.
7. Pengguna harus mendapatkan ringkasan perubahan stok sebelum mengonfirmasi transaksi.
8. Sistem harus mencegah pengiriman transaksi yang sama berulang akibat double click atau retry yang tidak terkendali.

### 6.5 Low stock

1. Minimum stock ditetapkan pada tingkat produk.
2. Produk masuk kondisi Low Stock ketika saldo agregat dalam lingkup akses pengguna lebih besar dari nol dan sama dengan atau lebih kecil dari nilai minimum stock.
3. Produk masuk kondisi Out of Stock ketika saldo agregat dalam lingkup akses pengguna sama dengan nol.
4. Produk dengan minimum stock nol tidak menghasilkan alert Low Stock hanya karena saldonya positif.
5. Kondisi low stock dihitung berdasarkan saldo sistem, bukan perkiraan atau data yang belum disimpan.
6. Dashboard harus membedakan Low Stock dan Out of Stock.

### 6.6 Estimasi nilai inventaris

1. Harga pokok produk bersifat opsional dan menyatakan biaya per satu satuan dasar produk.
2. Jika harga pokok tersedia, aplikasi dapat menampilkan estimasi nilai stok berdasarkan saldo saat ini dikalikan harga pokok yang tersimpan pada master produk dalam lingkup gudang pengguna.
3. Nilai tersebut harus diberi label **Estimasi Nilai Stok**, bukan nilai akuntansi resmi.
4. Produk tanpa harga pokok tidak boleh diam-diam dianggap bernilai nol untuk menyatakan total nilai akurat.
5. Jika ada produk yang belum mempunyai harga pokok, dashboard harus menjelaskan bahwa estimasi nilai belum mencakup seluruh produk.
6. Penilaian persediaan berbasis FIFO, weighted average, atau metode akuntansi lainnya berada di luar MVP.

### 6.7 Pengguna dan hak akses

1. Akun awal dibuat melalui proses bootstrap administrator atau disiapkan saat instalasi.
2. Admin dapat membuat dan menonaktifkan akun pengguna.
3. Public self-registration tidak tersedia pada MVP.
4. Admin dapat menetapkan role Admin atau Warehouse Staff.
5. Warehouse Staff tidak dapat mengubah role atau mengelola akun pengguna.
6. Hak akses harus diperiksa pada backend untuk setiap tindakan yang dilindungi.
7. Menyembunyikan tombol pada frontend tidak dianggap sebagai kontrol keamanan yang cukup.

---

## 7. Kebutuhan fungsional

Setiap kebutuhan diberi ID agar dapat ditelusuri pada FSD, test case, dan implementasi.

### 7.1 Authentication

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-AUTH-001 | Sistem menyediakan halaman login menggunakan identitas akun dan password. | Must Have |
| FR-AUTH-002 | Sistem memvalidasi kredensial pada backend sebelum membuat sesi pengguna. | Must Have |
| FR-AUTH-003 | Pengguna dapat logout dan sesi aktif harus diakhiri. | Must Have |
| FR-AUTH-004 | Halaman dashboard dan endpoint terlindungi hanya dapat diakses oleh pengguna yang terautentikasi. | Must Have |
| FR-AUTH-005 | Sistem menampilkan pesan error yang aman dan tidak membocorkan detail internal saat login gagal. | Must Have |
| FR-AUTH-006 | Sistem menangani sesi kedaluwarsa dengan mengarahkan pengguna ke proses login kembali. | Must Have |
| FR-AUTH-007 | Sistem tidak menyediakan registrasi publik pada MVP. | Must Have |
| FR-AUTH-008 | Admin dapat melakukan reset password pengguna melalui mekanisme administrasi yang ditetapkan di FSD. | Should Have |

### 7.2 User and role management

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-USER-001 | Admin dapat melihat daftar pengguna. | Must Have |
| FR-USER-002 | Admin dapat membuat akun pengguna. | Must Have |
| FR-USER-003 | Admin dapat mengubah nama, identitas login, dan role pengguna sesuai aturan validasi. | Must Have |
| FR-USER-004 | Admin dapat menonaktifkan akun pengguna. | Must Have |
| FR-USER-005 | Sistem menyediakan role Admin dan Warehouse Staff. | Must Have |
| FR-USER-006 | Warehouse Staff tidak dapat mengakses fungsi pengelolaan pengguna. | Must Have |
| FR-USER-007 | Sistem mencegah admin menonaktifkan atau menghilangkan satu-satunya akun administrator aktif tanpa mekanisme pemulihan. | Must Have |
| FR-USER-008 | Admin dapat menetapkan, melihat, dan memperbarui satu atau beberapa gudang aktif yang menjadi akses Warehouse Staff. | Must Have |

### 7.3 Organization profile

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-ORG-001 | Admin dapat melihat profil organisasi. | Must Have |
| FR-ORG-002 | Admin dapat mengubah nama dan informasi dasar organisasi. | Must Have |
| FR-ORG-003 | Informasi organisasi digunakan pada konteks aplikasi dan dokumen transaksi. | Should Have |

### 7.4 Category management

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-CAT-001 | Admin dapat melihat daftar kategori. | Must Have |
| FR-CAT-002 | Admin dapat membuat kategori. | Must Have |
| FR-CAT-003 | Admin dapat mengubah nama dan deskripsi kategori. | Must Have |
| FR-CAT-004 | Admin dapat menonaktifkan kategori. | Must Have |
| FR-CAT-005 | Sistem mencegah penghapusan kategori jika masih digunakan oleh produk, kecuali produk telah dipindahkan ke kategori lain. | Must Have |

### 7.5 Product management

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-PROD-001 | Admin dapat melihat daftar produk dengan pagination. | Must Have |
| FR-PROD-002 | Admin dapat membuat produk dengan nama, SKU, kategori, dan satuan dasar. | Must Have |
| FR-PROD-003 | Admin dapat menetapkan minimum stock. | Must Have |
| FR-PROD-004 | Admin dapat mengisi harga pokok opsional. | Should Have |
| FR-PROD-005 | Admin dapat mengubah informasi produk yang tidak mengubah histori transaksi. | Must Have |
| FR-PROD-006 | Admin dapat menonaktifkan produk. | Must Have |
| FR-PROD-007 | Sistem memvalidasi SKU agar unik. | Must Have |
| FR-PROD-008 | Pengguna dapat mencari produk berdasarkan nama atau SKU sesuai hak akses. | Must Have |
| FR-PROD-009 | Pengguna dapat memfilter produk berdasarkan kategori dan status. | Should Have |
| FR-PROD-010 | Detail produk menampilkan informasi produk, saldo agregat, saldo per gudang, dan riwayat transaksi dalam lingkup akses pengguna. | Must Have |
| FR-PROD-011 | Penghapusan permanen produk yang mempunyai riwayat transaksi tidak tersedia melalui alur normal. | Must Have |

### 7.6 Warehouse management

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-WH-001 | Admin dapat melihat daftar gudang. | Must Have |
| FR-WH-002 | Admin dapat membuat gudang dengan nama dan kode unik. | Must Have |
| FR-WH-003 | Admin dapat mengubah informasi gudang. | Must Have |
| FR-WH-004 | Admin dapat menonaktifkan gudang. | Must Have |
| FR-WH-005 | Sistem mencegah gudang nonaktif dipilih untuk transaksi baru. | Must Have |
| FR-WH-006 | Admin dapat melihat seluruh gudang; Warehouse Staff hanya dapat melihat detail gudang dan saldo pada gudang yang ditugaskan. | Must Have |
| FR-WH-007 | Gudang yang memiliki riwayat transaksi tidak dapat dihapus permanen melalui alur normal. | Must Have |

### 7.7 Inventory balance

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-INV-001 | Sistem menyediakan saldo stok untuk setiap produk pada setiap gudang. | Must Have |
| FR-INV-002 | Sistem menampilkan saldo agregat produk dalam lingkup gudang yang dapat diakses pengguna: seluruh gudang untuk Admin dan gudang yang ditugaskan untuk Warehouse Staff. | Must Have |
| FR-INV-003 | Pengguna dapat melihat stok berdasarkan gudang yang berada dalam lingkup aksesnya. | Must Have |
| FR-INV-004 | Saldo diperbarui berdasarkan transaksi Stock In dan Stock Out yang berhasil diposting. | Must Have |
| FR-INV-005 | Saldo tidak dapat diedit langsung melalui form master produk. | Must Have |
| FR-INV-006 | Sistem mencegah saldo stok menjadi negatif. | Must Have |

### 7.8 Stock In

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-IN-001 | Admin dan Warehouse Staff dapat membuka form Stock In. | Must Have |
| FR-IN-002 | Pengguna memilih gudang tujuan yang aktif. | Must Have |
| FR-IN-003 | Pengguna memilih satu atau beberapa produk aktif. | Must Have |
| FR-IN-004 | Pengguna memasukkan kuantitas positif untuk setiap produk. | Must Have |
| FR-IN-005 | Pengguna dapat menambahkan catatan atau referensi eksternal opsional. | Should Have |
| FR-IN-006 | Sistem menampilkan ringkasan transaksi dan dampak terhadap saldo sebelum konfirmasi. | Must Have |
| FR-IN-007 | Setelah transaksi berhasil, sistem menambah saldo dan mencatat stock movement. | Must Have |
| FR-IN-008 | Sistem menampilkan nomor referensi dan konfirmasi transaksi berhasil. | Must Have |
| FR-IN-009 | Sistem mencegah transaksi ganda akibat pengiriman request yang sama berulang. | Must Have |

### 7.9 Stock Out

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-OUT-001 | Admin dan Warehouse Staff dapat membuka form Stock Out. | Must Have |
| FR-OUT-002 | Pengguna memilih gudang asal yang aktif. | Must Have |
| FR-OUT-003 | Pengguna memilih satu atau beberapa produk aktif. | Must Have |
| FR-OUT-004 | Sistem menampilkan saldo tersedia pada gudang yang dipilih. | Must Have |
| FR-OUT-005 | Pengguna memasukkan kuantitas positif untuk setiap produk. | Must Have |
| FR-OUT-006 | Sistem menolak transaksi jika kuantitas melebihi saldo tersedia. | Must Have |
| FR-OUT-007 | Sistem menampilkan saldo setelah transaksi pada ringkasan konfirmasi. | Must Have |
| FR-OUT-008 | Setelah transaksi berhasil, sistem mengurangi saldo dan mencatat stock movement. | Must Have |
| FR-OUT-009 | Sistem menampilkan nomor referensi dan hasil transaksi. | Must Have |
| FR-OUT-010 | Sistem mencegah transaksi ganda akibat pengiriman request yang sama berulang. | Must Have |

### 7.10 Stock movement history

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-MOV-001 | Pengguna yang berwenang dapat melihat daftar pergerakan stok. | Must Have |
| FR-MOV-002 | Daftar menampilkan tanggal, nomor referensi, produk, gudang, tipe, kuantitas, dan pengguna. | Must Have |
| FR-MOV-003 | Pengguna dapat memfilter riwayat berdasarkan periode, tipe transaksi, produk, dan gudang. | Should Have |
| FR-MOV-004 | Pengguna dapat membuka detail transaksi. | Must Have |
| FR-MOV-005 | Setiap transaksi yang berhasil diposting tidak dapat diubah atau dihapus melalui antarmuka MVP. | Must Have |
| FR-MOV-006 | Sistem menyediakan pencarian berdasarkan nomor referensi atau SKU. | Should Have |
| FR-MOV-007 | Detail transaksi menampilkan catatan dan informasi pengguna pembuat jika tersedia. | Must Have |

### 7.11 Dashboard

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-DASH-001 | Dashboard menampilkan jumlah seluruh produk aktif dalam katalog organisasi. | Must Have |
| FR-DASH-002 | Dashboard menampilkan jumlah produk aktif yang memiliki saldo positif dalam lingkup gudang yang dapat diakses pengguna, tanpa menjumlahkan kuantitas dari satuan yang berbeda. | Must Have |
| FR-DASH-003 | Dashboard menampilkan jumlah produk Low Stock dan Out of Stock secara terpisah dalam lingkup gudang yang dapat diakses pengguna. | Must Have |
| FR-DASH-004 | Dashboard dapat menampilkan estimasi nilai stok terdata jika informasi harga pokok tersedia, disertai cakupan data harga pokok. | Should Have |
| FR-DASH-005 | Dashboard menampilkan jumlah transaksi Stock In dan Stock Out per hari untuk periode dan gudang yang dipilih. | Must Have |
| FR-DASH-006 | Dashboard menampilkan transaksi stok terbaru. | Must Have |
| FR-DASH-007 | Dashboard menyediakan tautan menuju daftar produk atau transaksi terkait. | Should Have |
| FR-DASH-008 | Nilai dashboard mengikuti data transaksi yang sudah berhasil disimpan. | Must Have |
| FR-DASH-009 | Dashboard tidak menampilkan angka persentase perubahan jika data pembanding tidak tersedia atau tidak valid. | Must Have |

### 7.12 Search, filter, sort, dan pagination

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-LIST-001 | Daftar produk menyediakan search berdasarkan nama atau SKU. | Must Have |
| FR-LIST-002 | Daftar produk menyediakan filter kategori dan status. | Should Have |
| FR-LIST-003 | Daftar transaksi menyediakan filter tipe, periode, produk, dan gudang. | Should Have |
| FR-LIST-004 | Daftar utama mendukung pagination. | Must Have |
| FR-LIST-005 | Sistem menampilkan empty state ketika hasil pencarian kosong. | Must Have |
| FR-LIST-006 | Pengguna dapat menghapus filter aktif dan kembali ke daftar awal. | Should Have |

### 7.13 Preferences and visual system

| ID | Kebutuhan | Prioritas |
|---|---|---|
| FR-UI-001 | Aplikasi menyediakan Light, Dark, dan System theme. | Must Have |
| FR-UI-002 | Preferensi tema pengguna dipertahankan sesuai mekanisme penyimpanan yang aman. | Should Have |
| FR-UI-003 | Aplikasi responsif pada desktop, tablet, dan smartphone. | Must Have |
| FR-UI-004 | Aplikasi menyediakan loading, empty, error, success, dan permission states. | Must Have |
| FR-UI-005 | Animasi menghormati preferensi reduced motion dari sistem operasi. | Must Have |
| FR-UI-006 | Pengguna dapat menyelesaikan fungsi inti tanpa bergantung pada animasi dekoratif. | Must Have |
| FR-UI-007 | UI menggunakan Bahasa Indonesia pada rilis awal. | Must Have |

---

## 8. Hak akses pengguna

### 8.1 Matriks role MVP

| Modul / Tindakan | Admin | Warehouse Staff |
|---|---:|---:|
| Melihat dashboard | Ya | Ya |
| Melihat produk | Ya | Ya |
| Membuat / mengubah produk | Ya | Tidak |
| Menonaktifkan produk | Ya | Tidak |
| Mengelola kategori | Ya | Tidak |
| Melihat gudang | Ya, semua gudang | Ya, hanya gudang yang ditugaskan |
| Menetapkan gudang untuk Warehouse Staff | Ya | Tidak |
| Membuat / mengubah gudang | Ya | Tidak |
| Menonaktifkan gudang | Ya | Tidak |
| Melihat saldo stok | Ya | Ya |
| Membuat Stock In | Ya | Ya |
| Membuat Stock Out | Ya | Ya |
| Melihat riwayat pergerakan | Ya | Ya |
| Melihat detail transaksi | Ya | Ya |
| Mengelola pengguna | Ya | Tidak |
| Mengubah profil organisasi | Ya | Tidak |
| Mengubah preferensi tema pribadi | Ya | Ya |

### 8.2 Ketentuan role

- Admin memiliki kewenangan pengelolaan master data, akun pengguna, dan penugasan gudang.
- Setiap Warehouse Staff aktif wajib memiliki minimal satu gudang aktif yang ditugaskan Admin. Admin tidak dapat menonaktifkan gudang jika tindakan tersebut membuat Warehouse Staff aktif kehilangan seluruh gudang aktif yang ditugaskan; Admin harus memindahkan assignment atau menonaktifkan akun staff terlebih dahulu.
- Warehouse Staff dapat membaca metadata katalog produk dan kategori organisasi. Saldo, detail gudang, transaksi, nilai stok, alert, serta riwayat pergerakan hanya dapat dibaca pada gudang yang ditugaskan. Admin dapat melihat seluruh gudang.
- Penugasan gudang diperiksa pada backend untuk setiap request yang membawa konteks gudang.
- Hak akses diperiksa pada backend, bukan hanya pada navigasi frontend.
- Jika pengguna tidak berwenang, sistem harus menolak tindakan dan memberikan respons yang sesuai.
- Perubahan role harus berlaku pada permintaan berikutnya atau setelah sesi diperbarui sesuai mekanisme autentikasi.

---

## 9. Alur pengguna utama

### 9.1 Setup awal organisasi

1. Aplikasi dijalankan dan akun Admin awal dibuat melalui bootstrap instalasi.
2. Admin login.
3. Admin melengkapi profil organisasi.
4. Admin membuat gudang pertama.
5. Admin membuat kategori produk.
6. Admin membuat produk.
7. Admin mencatat saldo awal melalui Stock In dengan referensi atau catatan `Saldo Awal`.
8. Admin membuat akun Warehouse Staff.
9. Warehouse Staff login dan mulai mencatat transaksi.

Catatan: detail mekanisme bootstrap akun awal dan pengelolaan kredensial awal ditetapkan dalam FSD dan panduan deployment. Kredensial default tidak boleh dibiarkan aktif pada lingkungan production.

### 9.2 Alur Stock In

1. Pengguna membuka menu Stock In.
2. Pengguna memilih gudang tujuan.
3. Pengguna memilih produk.
4. Pengguna memasukkan kuantitas.
5. Pengguna dapat menambahkan produk lain dan catatan transaksi.
6. Sistem menampilkan ringkasan jumlah barang dan gudang tujuan.
7. Pengguna memeriksa ringkasan dan mengonfirmasi.
8. Backend memvalidasi dan menyimpan transaksi.
9. Sistem memperbarui saldo dan menambahkan riwayat pergerakan dalam satu transaksi yang konsisten.
10. UI menampilkan nomor referensi dan status berhasil.

### 9.3 Alur Stock Out

1. Pengguna membuka menu Stock Out.
2. Pengguna memilih gudang asal.
3. Pengguna memilih produk.
4. Sistem menampilkan saldo tersedia.
5. Pengguna memasukkan kuantitas.
6. Sistem memvalidasi kuantitas dan memperlihatkan estimasi saldo setelah transaksi.
7. Pengguna memeriksa ringkasan dan mengonfirmasi.
8. Backend memvalidasi ulang saldo pada saat pemrosesan.
9. Jika saldo cukup, sistem mengurangi saldo dan membuat movement secara atomik.
10. Jika saldo tidak cukup, transaksi ditolak dan saldo tidak berubah.
11. UI menampilkan hasil transaksi atau pesan validasi.

### 9.4 Alur pemeriksaan stok

1. Pengguna membuka daftar produk atau detail gudang.
2. Pengguna mencari produk berdasarkan nama atau SKU.
3. Sistem menampilkan saldo total dan saldo per gudang.
4. Pengguna membuka riwayat produk untuk menelusuri perubahan.
5. Pengguna dapat membuka detail transaksi untuk melihat informasi yang terkait.

### 9.5 Alur penanganan Low Stock

1. Admin atau Warehouse Staff melihat indikator Low Stock pada dashboard.
2. Pengguna membuka daftar produk terkait.
3. Pengguna memeriksa saldo produk per gudang.
4. Pengguna dapat melakukan Stock In jika barang telah tersedia.
5. Proses pembelian formal belum tersedia pada MVP.

---

## 10. Kebutuhan non-fungsional

### 10.1 Performance

1. Halaman utama dan daftar data harus menampilkan state awal dengan cepat pada koneksi dan perangkat yang wajar.
2. Endpoint daftar harus menggunakan pagination agar seluruh data tidak dikirim sekaligus.
3. Query dashboard harus dibatasi pada agregasi dan periode yang diperlukan.
4. Animasi tidak boleh memblokir interaksi utama atau menunda pengiriman transaksi.
5. Target awal pengujian: endpoint baca umum memiliki p95 di bawah 1,5 detik dan endpoint transaksi umum p95 di bawah 2 detik pada environment uji yang terdokumentasi. Target ini harus dievaluasi kembali berdasarkan hardware, ukuran data, dan beban nyata.
6. Pengujian performa harus mencatat spesifikasi environment, ukuran dataset, dan jumlah pengguna bersamaan agar hasilnya dapat diulang.

### 10.2 Reliability and data integrity

1. Perubahan saldo dan pencatatan stock movement harus atomik.
2. Backend harus melakukan validasi ulang terhadap saldo pada saat Stock Out diproses.
3. Sistem harus menangani request duplikat untuk transaksi agar tidak terjadi pencatatan ganda.
4. Kegagalan proses tidak boleh menghasilkan saldo dan movement yang berbeda.
5. Database harus menggunakan persistent volume pada deployment Docker.
6. Backup dan restore database harus didokumentasikan sebelum penggunaan production.
7. Error database tidak boleh ditampilkan sebagai stack trace kepada pengguna.

### 10.3 Security

1. Password tidak boleh disimpan dalam bentuk plaintext.
2. Password harus diproses dengan algoritma password hashing yang sesuai.
3. Sesi dan kredensial harus dikelola dengan mekanisme yang aman.
4. Endpoint yang membutuhkan autentikasi harus menolak request tanpa sesi atau token yang valid.
5. Backend harus memeriksa role dan hak akses pada setiap endpoint yang relevan.
6. Input dari pengguna harus divalidasi di frontend dan backend. Validasi backend menjadi kontrol utama.
7. API harus menerapkan rate limiting pada endpoint yang sesuai, khususnya autentikasi.
8. CORS harus dibatasi pada origin yang diizinkan.
9. Secret, password database, dan credential tidak boleh dimasukkan ke repository.
10. File `.env` production tidak boleh disertakan dalam repository publik.
11. Lingkungan production harus menggunakan HTTPS.
12. Error response tidak boleh membocorkan stack trace, query database, secret, atau informasi internal.
13. Dependency harus diperiksa dan diperbarui secara terkontrol.
14. Operasi database harus menggunakan parameterization atau mekanisme ORM yang aman.
15. Jika autentikasi menggunakan cookie, proteksi CSRF dan konfigurasi cookie harus ditetapkan dalam FSD dan technical architecture.
16. Jika autentikasi menggunakan bearer token, penyimpanan token pada browser harus ditinjau terhadap risiko XSS dan strategi refresh/revocation harus ditetapkan.

### 10.4 Usability

1. Label form harus selalu terlihat dan tidak hanya mengandalkan placeholder.
2. Error validasi ditampilkan dekat field terkait.
3. Tindakan sukses atau gagal harus memberikan feedback.
4. Tindakan destruktif memerlukan konfirmasi.
5. Fungsi inti harus dapat digunakan dengan keyboard.
6. Istilah operasional menggunakan Bahasa Indonesia yang konsisten.
7. Tindakan utama harus mudah ditemukan tanpa membuat tampilan padat.

### 10.5 Accessibility

1. Implementasi menargetkan WCAG 2.2 AA sejauh relevan.
2. Focus state harus terlihat.
3. Kontras teks dan kontrol harus diperiksa.
4. Informasi status tidak boleh hanya disampaikan melalui warna.
5. Komponen penting memiliki accessible name.
6. Dialog mengelola fokus dengan benar.
7. Target sentuh mobile minimal 44 x 44 px.
8. Animasi menghormati `prefers-reduced-motion`.
9. Layout tetap dapat digunakan pada zoom browser 200 persen tanpa kehilangan fungsi inti.

### 10.6 Compatibility and responsive behavior

1. Aplikasi mendukung versi stabil browser modern yang masih mendapatkan pembaruan keamanan.
2. Layout mendukung desktop, tablet, dan smartphone.
3. Tidak boleh ada horizontal page overflow yang tidak disengaja.
4. Tabel kompleks harus memiliki pola mobile berupa card list atau tampilan kolom prioritas.
5. Fitur Stock In, Stock Out, pencarian, dan pemeriksaan saldo tetap dapat digunakan di smartphone.

### 10.7 Maintainability

1. Frontend dan backend dipisahkan sebagai aplikasi berbeda dalam satu repository.
2. Kode menggunakan TypeScript.
3. Konfigurasi environment didokumentasikan melalui `.env.example` tanpa secret.
4. Database schema dikelola melalui migration yang dapat dilacak.
5. Endpoint API didokumentasikan.
6. Perubahan penting menggunakan Git commit yang terdeskripsi.
7. Modul aplikasi mengikuti domain dan tanggung jawab yang jelas.
8. Automated test diprioritaskan pada autentikasi, otorisasi, transaksi stok, dan konsistensi saldo.

---

## 11. Persyaratan UI/UX dan visual

Dokumen `StockFlow_Design_System_UIUX_Spec_v1.0.md` merupakan acuan visual utama. PRD ini menetapkan kebutuhan produk yang harus dipenuhi oleh antarmuka.

### 11.1 Design direction yang dikunci

| Dimensi | Keputusan |
|---|---|
| Gaya visual | Creative Premium SaaS |
| Tema | Light dan Dark dengan dukungan setara |
| Motion | Immersive |
| Prioritas | Seimbang antara estetika dan produktivitas |
| Tipografi | Geist Sans dan Geist Mono dengan fallback yang sesuai |
| UI framework | Tailwind CSS dan komponen shadcn/ui yang dikustomisasi |
| Motion library | Motion for React |
| Advanced marketing motion | GSAP + ScrollTrigger secara selektif |
| Chart library | Recharts |

### 11.2 Pembagian karakter visual

**Marketing pages**

- Boleh menggunakan headline besar dan komposisi asimetris.
- Menampilkan product preview yang menunjukkan kemampuan StockFlow.
- Menggunakan text reveal, subtle parallax, dan scroll-triggered animation secara selektif.
- CTA harus langsung terlihat dan dapat digunakan tanpa menunggu animasi.

**Application dashboard**

- Mengutamakan keterbacaan tabel, angka, status, dan form transaksi.
- Menggunakan micro-interaction dan transisi halaman singkat.
- KPI dan chart boleh memiliki animasi masuk ketika pertama kali dimuat.
- Refresh data tidak boleh mengulang animasi besar yang mengganggu.
- Tidak menggunakan scroll hijacking.

### 11.3 Halaman MVP

| Halaman | Tujuan | Akses |
|---|---|---|
| Public landing page | Menjelaskan produk dan manfaat | Publik |
| Login | Autentikasi pengguna | Publik |
| Dashboard | Ringkasan kondisi inventaris | Admin, Warehouse Staff |
| Product list | Melihat dan mencari produk | Admin, Warehouse Staff |
| Product create/edit | Mengelola master produk | Admin |
| Product detail | Melihat informasi dan saldo produk | Admin, Warehouse Staff |
| Category management | Mengelola kategori | Admin |
| Warehouse list/detail | Mengelola dan melihat gudang | Admin, Warehouse Staff |
| Stock In | Mencatat barang masuk | Admin, Warehouse Staff |
| Stock Out | Mencatat barang keluar | Admin, Warehouse Staff |
| Stock movement list/detail | Menelusuri transaksi stok | Admin, Warehouse Staff |
| User management | Mengelola akun dan role | Admin |
| Organization settings | Mengatur profil organisasi | Admin |
| Personal preferences | Mengubah tema dan preferensi pribadi | Admin, Warehouse Staff |

### 11.4 Motion requirements

1. Landing page dapat menggunakan animasi yang lebih ekspresif dibandingkan dashboard.
2. Dashboard memakai animasi singkat dan fungsional.
3. Animasi tidak boleh menghalangi CTA atau proses konfirmasi transaksi.
4. Loading state tidak boleh membuat pengguna mengira transaksi sudah berhasil.
5. Transisi theme harus menjaga keterbacaan dan tidak menghasilkan flash yang mengganggu.
6. Animasi tidak boleh menyebabkan layout shift besar.
7. Konten inti tetap tersedia ketika reduced motion aktif.

### 11.5 UI states wajib

Setiap halaman data dan form harus mendukung state yang relevan:

- Loading.
- Empty.
- Error.
- Success.
- Validation error.
- Permission denied.
- Session expired.
- Network error.
- Disabled state.
- Destructive confirmation.

---

## 12. Informasi dan data utama

Bagian ini adalah daftar entitas bisnis pada tingkat produk, bukan ERD final.

| Entitas | Deskripsi | Data utama |
|---|---|---|
| Organization | Identitas organisasi pada instalasi | Nama, kode atau informasi organisasi |
| User | Pengguna aplikasi | Nama, identitas login, status, role |
| Role | Kumpulan hak akses | Nama role dan permission |
| Category | Kategori produk | Nama, deskripsi, status |
| Product | Master barang | Nama, SKU, kategori, satuan, minimum stock, harga pokok opsional, status |
| Warehouse | Lokasi penyimpanan | Nama, kode, lokasi, status |
| Inventory Balance | Saldo produk pada gudang | Product, warehouse, quantity |
| Stock Transaction | Header transaksi stok | Nomor referensi, tipe, tanggal, pembuat, catatan |
| Stock Transaction Item | Baris produk dalam transaksi | Produk, kuantitas, gudang terkait |
| Stock Movement | Dampak transaksi terhadap stok | Produk, gudang, tipe movement, quantity, referensi transaksi |

ERD final, constraints, index, aturan penghapusan, tipe kuantitas, precision angka, serta strategi penyimpanan saldo akan dirumuskan pada dokumen ERD dan FSD.

---

## 13. Integrasi dan batas teknis

### 13.1 Technology baseline

| Layer | Teknologi |
|---|---|
| Frontend framework | Next.js dengan React |
| Frontend language | TypeScript |
| Styling | Tailwind CSS dan design tokens |
| UI primitives | shadcn/ui yang dikustomisasi |
| Animation | Motion for React |
| Marketing animation | GSAP + ScrollTrigger secara selektif |
| Charts | Recharts |
| Backend runtime | Node.js |
| Backend framework | Express.js |
| Backend language | TypeScript |
| API style | REST API dengan JSON |
| Database | MySQL 8.4 LTS |
| ORM | Prisma |
| API documentation | OpenAPI / Swagger |
| Containerization | Docker dan Docker Compose |
| Version control | Git dan GitHub |
| API testing | Postman atau tool setara |

Versi dependency selain MySQL harus dipilih dan dikunci pada saat inisialisasi repository berdasarkan versi stabil yang kompatibel. Hindari mengandalkan tag dependency yang tidak dipin untuk lingkungan production.

### 13.2 Pemisahan aplikasi

- Next.js bertanggung jawab atas UI, navigasi, interaksi, dan konsumsi API.
- Express.js bertanggung jawab atas autentikasi, otorisasi, validasi server, business logic, dan akses database.
- MySQL menjadi penyimpanan data utama.
- Prisma digunakan untuk akses data dan migration sesuai kebutuhan.
- Frontend tidak boleh mengakses database secara langsung.
- Business rule yang menentukan saldo dan hak akses harus diterapkan pada backend.

### 13.3 Docker requirements

1. Frontend, backend, dan database dijalankan sebagai service terpisah.
2. Docker Compose menyediakan satu perintah untuk menjalankan lingkungan development.
3. Database menggunakan named volume atau mekanisme persistent storage yang setara.
4. Secret dikelola melalui environment variable dan tidak disimpan dalam image.
5. Backend menggunakan hostname service database pada jaringan Docker, bukan `localhost`.
6. Service database memiliki health check.
7. Backend harus mempunyai mekanisme retry atau menunggu database siap sebelum menjalankan proses yang membutuhkan koneksi.
8. File `.dockerignore` tersedia untuk mencegah file yang tidak diperlukan masuk ke build context.
9. Production image menggunakan pendekatan multi-stage build bila sesuai.
10. Dokumentasi menyediakan instruksi start, stop, log, migration, backup, dan restore.

### 13.4 API requirements

1. Endpoint menggunakan pola resource yang konsisten.
2. API menggunakan HTTP status code yang sesuai.
3. Request dan response menggunakan format JSON yang terdokumentasi.
4. Validasi server menjadi sumber kebenaran.
5. Error response mempunyai struktur konsisten dan tidak membocorkan detail internal.
6. Endpoint yang memodifikasi data memerlukan autentikasi dan otorisasi.
7. Endpoint transaksi harus aman dari request duplikat dan race condition.
8. Dokumentasi API harus menyediakan contoh request dan response yang relevan.

---

## 14. Analitik dan definisi metrik

Agar angka pada dashboard memiliki arti yang konsisten, metrik awal didefinisikan sebagai berikut.

| Metrik | Definisi produk |
|---|---|
| Total SKU | Jumlah seluruh produk aktif dalam katalog organisasi; metrik katalog ini tidak dibatasi penugasan gudang karena metadata produk dapat dibaca oleh seluruh Warehouse Staff |
| Produk dengan stok | Jumlah produk aktif yang memiliki saldo positif pada satu atau beberapa gudang dalam lingkup akses pengguna. Kuantitas dari satuan berbeda tidak dijumlahkan menjadi satu angka. |
| Low Stock | Jumlah produk aktif dengan saldo agregat dalam lingkup akses lebih besar dari nol dan sama dengan atau di bawah minimum stock produk |
| Out of Stock | Jumlah produk aktif dengan saldo agregat dalam lingkup akses sama dengan nol |
| Pergerakan hari ini | Jumlah header transaksi Stock In dan Stock Out yang berhasil diposting pada tanggal lokal organisasi, ditampilkan terpisah menurut tipe |
| Grafik pergerakan | Jumlah transaksi Stock In dan Stock Out per hari, bukan penjumlahan kuantitas lintas produk dengan satuan berbeda |
| Estimasi nilai stok terdata | Jumlah saldo produk dikalikan harga pokok master untuk produk yang mempunyai harga pokok. Nilai harus disertai jumlah dan persentase cakupan produk bersaldo yang mempunyai harga pokok. |
| Recent movements | Daftar transaksi stok terbaru yang berhasil diposting dan berada dalam lingkup akses pengguna |

Admin melihat seluruh gudang. Warehouse Staff hanya melihat gudang yang ditugaskan. Metadata katalog produk dan kategori dapat dibaca oleh semua pengguna terautentikasi, tetapi saldo, nilai stok, status stok, aktivitas transaksi, dan ringkasan gudang Warehouse Staff hanya dihitung dari gudang yang ditugaskan. Total SKU tetap menghitung seluruh produk aktif organisasi karena merupakan metrik katalog. Filter gudang pada grafik dan daftar aktivitas tidak mengubah KPI saldo utama. Semua perhitungan tanggal mengikuti zona waktu organisasi. Jika zona waktu belum diatur, gunakan konfigurasi default instalasi yang terdokumentasi dan tampilkan tanggal secara konsisten. Jika Warehouse Staff tidak memiliki gudang aktif yang dapat diakses akibat kondisi data yang tidak normal, KPI stok dan aktivitas gudang menampilkan nilai nol atau daftar kosong, sedangkan Total SKU tetap menampilkan jumlah seluruh produk aktif organisasi.

---

## 15. Risiko dan mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Saldo dan movement tidak sinkron | Data inventaris tidak dapat dipercaya | Gunakan transaksi database atomik dan integration test |
| Dua pengguna melakukan Stock Out bersamaan | Saldo berpotensi negatif | Validasi ulang saldo dan kontrol konkurensi di backend |
| Transaksi terkirim dua kali | Saldo berubah lebih dari sekali | Idempotency atau mekanisme deduplikasi request |
| Penghapusan master data yang memiliki histori | Riwayat transaksi rusak | Gunakan status aktif/nonaktif dan aturan referential integrity |
| Hak akses hanya diperiksa di frontend | Pengguna dapat memanggil API secara langsung | Validasi authorization pada setiap endpoint |
| Scope creep ke fitur ERP | MVP tertunda | Gunakan daftar out of scope dan change control |
| Animasi memperlambat pekerjaan | Produktivitas turun | Batasi motion dashboard dan sediakan reduced motion |
| UI tidak nyaman di smartphone | Fungsi inti sulit digunakan | Rancang responsive behavior sejak awal dan uji perangkat |
| Kehilangan data database container | Data operasional hilang | Persistent volume serta prosedur backup dan restore |
| Credential masuk ke repository | Risiko kompromi sistem | `.env.example`, secret management, review Git diff |
| Perbedaan environment developer | Aplikasi tidak konsisten dijalankan | Docker Compose dan dependency version lock |
| Harga pokok tidak lengkap | Estimasi nilai stok menyesatkan | Tandai nilai sebagai estimasi dan tampilkan coverage data |

---

## 16. Dependencies dan asumsi

### 16.1 Dependencies

- Node.js dan package manager tersedia pada lingkungan pengembangan.
- Docker Engine atau Docker Desktop tersedia.
- MySQL image yang sesuai dapat diunduh atau tersedia pada registry yang digunakan.
- Repository Git dapat diakses oleh developer.
- Library UI dan motion kompatibel dengan versi Next.js yang dipilih.
- Environment deployment menyediakan storage persisten untuk database.

### 16.2 Asumsi

1. MVP digunakan untuk satu organisasi per deployment.
2. Organisasi mempunyai satu atau beberapa lokasi gudang.
3. Pengguna mempunyai akses internet saat menggunakan aplikasi.
4. Produk memiliki satu satuan dasar pada MVP.
5. Organisasi menetapkan batas minimum stok pada tingkat produk.
6. Transaksi Stock In dan Stock Out dicatat oleh pengguna yang telah login.
7. Admin menjadi pihak yang bertanggung jawab atas konfigurasi awal dan manajemen user.
8. Penggunaan awal berfokus pada pencatatan barang, bukan sistem akuntansi.
9. Tidak ada integrasi perangkat barcode khusus pada rilis pertama.
10. Tidak ada dukungan offline transaction pada MVP.

---

## 17. Acceptance criteria tingkat produk

MVP dinyatakan memenuhi kebutuhan produk apabila seluruh kondisi berikut tercapai:

### 17.1 Environment

- [ ] Frontend, backend, dan database dapat dijalankan melalui Docker Compose.
- [ ] Database tetap menyimpan data setelah container dihentikan dan dijalankan kembali.
- [ ] Konfigurasi environment dijelaskan dalam README dan `.env.example`.
- [ ] Backend dapat memeriksa kesiapan database sebelum menerima traffic yang membutuhkan koneksi database.

### 17.2 Authentication and access

- [ ] Admin dapat login dan logout.
- [ ] Warehouse Staff dapat login dan logout.
- [ ] Pengguna tanpa sesi tidak dapat mengakses halaman terlindungi atau endpoint privat.
- [ ] Warehouse Staff tidak dapat menjalankan fungsi administrasi melalui pemanggilan API langsung.
- [ ] Admin dapat membuat dan menonaktifkan akun Warehouse Staff.

### 17.3 Master data

- [ ] Admin dapat membuat, melihat, mengubah, dan menonaktifkan kategori.
- [ ] Admin dapat membuat, melihat, mengubah, dan menonaktifkan produk.
- [ ] Sistem menolak SKU duplikat.
- [ ] Admin dapat membuat, melihat, mengubah, dan menonaktifkan gudang.
- [ ] Admin dapat menetapkan minimal satu gudang aktif kepada setiap Warehouse Staff.
- [ ] Warehouse Staff hanya dapat mengakses gudang yang ditugaskan, termasuk melalui pemanggilan API langsung.
- [ ] Deaktivasi gudang ditolak jika akan membuat Warehouse Staff aktif kehilangan seluruh gudang aktif yang ditugaskan.
- [ ] Master data yang mempunyai riwayat transaksi tidak dapat dihapus secara permanen melalui alur normal.

### 17.4 Stock In and Stock Out

- [ ] Admin dan Warehouse Staff dapat mencatat Stock In.
- [ ] Admin dan Warehouse Staff dapat mencatat Stock Out.
- [ ] Kuantitas nol atau negatif ditolak.
- [ ] Stock Out melebihi saldo tersedia ditolak.
- [ ] Transaksi yang gagal tidak mengubah saldo.
- [ ] Transaksi yang berhasil memperbarui saldo dan movement secara konsisten.
- [ ] Request duplikat tidak menyebabkan transaksi stok tercatat lebih dari sekali.
- [ ] Setiap transaksi yang berhasil memiliki nomor referensi dan identitas pembuat.

### 17.5 Dashboard and history

- [ ] Dashboard menampilkan Total SKU dari katalog aktif organisasi dan KPI stok berdasarkan data tersimpan dalam lingkup gudang yang dapat diakses pengguna.
- [ ] Dashboard tidak menjumlahkan kuantitas produk dengan satuan berbeda menjadi satu metrik unit.
- [ ] Grafik pergerakan menampilkan jumlah transaksi Stock In dan Stock Out per hari.
- [ ] Produk Low Stock dan Out of Stock dapat dibedakan.
- [ ] Pengguna dapat mencari produk berdasarkan nama atau SKU.
- [ ] Pengguna dapat melihat saldo per gudang.
- [ ] Pengguna dapat melihat daftar dan detail pergerakan stok.
- [ ] Filter periode dan gudang bekerja sesuai kriteria yang dipilih.

### 17.6 UI/UX

- [ ] Light mode dan Dark mode dapat digunakan.
- [ ] Theme System mengikuti preferensi sistem operasi.
- [ ] Halaman utama, daftar, dan form responsif.
- [ ] Loading, empty, error, success, dan permission states tersedia.
- [ ] Reduced motion didukung.
- [ ] Form dapat dioperasikan dengan keyboard.
- [ ] Tidak ada tombol yang terlihat aktif tetapi tidak mempunyai tindakan.
- [ ] Visual sesuai dokumen Design System dan UI/UX Specification.

### 17.7 Testing and documentation

- [ ] Unit test tersedia untuk business logic penting.
- [ ] Integration test mencakup autentikasi, hak akses, Stock In, Stock Out, dan konsistensi saldo.
- [ ] API terdokumentasi.
- [ ] README menjelaskan instalasi, menjalankan aplikasi, migration, seed, troubleshooting, backup, dan restore.
- [ ] Tidak ada secret production yang disimpan di repository.

---

## 18. Release plan

### Release 0: Foundation

Deliverables:
- Repository dan struktur monorepo.
- Next.js application.
- Express API.
- MySQL dan Prisma.
- Dockerfile dan Docker Compose.
- Design tokens, theme, app shell, dan komponen dasar.
- Health check frontend/API/database sesuai kebutuhan.

### Release 1: MVP Inventory Core

Deliverables:
- Authentication dan role Admin/Warehouse Staff.
- Penugasan gudang kepada Warehouse Staff.
- Organization profile.
- Category management.
- Product management.
- Warehouse management.
- Inventory balance.
- Stock In.
- Stock Out.
- Stock movement history.
- Dashboard ringkasan.
- Responsive UI dan light/dark mode.

### Release 1.1: Operational expansion

Kandidat deliverables:
- Supplier management.
- Purchase Order.
- Goods receiving.
- Transfer antar gudang.
- Stock Opname dan Stock Adjustment.
- Export laporan.
- Audit log lebih lengkap.
- Notification center.

### Release 2: SaaS expansion

Kandidat deliverables:
- Multi-tenant architecture.
- Subscription dan billing jika model bisnis ditetapkan.
- Onboarding organisasi secara mandiri.
- Permission lebih granular.
- Integrasi eksternal.
- Mobile application.

Release plan ini merupakan urutan kandidat pengembangan. Fitur fase lanjutan harus melalui evaluasi kebutuhan pengguna dan tidak otomatis menjadi komitmen rilis.

---

## 19. Keputusan implementasi yang dikunci pada v1.0.1

Default implementasi berikut telah ditetapkan pada FSD StockFlow v1.0.1. Perubahan terhadap keputusan ini harus melalui revisi PRD/FSD dan memperbarui ERD, API contract, serta test case yang terdampak.

| Topik | Keputusan v1.0.1 |
|---|---|
| Identitas login | Email saja; dinormalisasi lowercase |
| Bootstrap organisasi dan Admin | Satu command CLI membuat record organisasi dan akun Admin secara atomik setelah role di-seed; tidak ada public registration |
| Session strategy | Opaque server-side session dengan HttpOnly cookie, CSRF token, Origin validation, expiry, logout, dan revocation |
| Password hashing | Argon2id; parameter dikonfigurasi saat implementasi |
| Password reset | Admin reset password sementara dan force change; fitur Should Have, tanpa email reset mandiri |
| Kuantitas | `DECIMAL(18,3)`, maksimal tiga angka desimal, tanpa pembulatan diam-diam |
| Unit of measure | Satu satuan dasar berupa string per produk; tidak ada konversi satuan otomatis |
| Minimum stock | Ambang di tingkat produk; Admin mengevaluasi seluruh gudang dan Warehouse Staff mengevaluasi agregat gudang yang ditugaskan |
| Warehouse assignment | Setiap Warehouse Staff aktif wajib memiliki minimal satu gudang aktif; deaktivasi gudang tidak boleh menghilangkan assignment aktif terakhir seorang staff |
| Transaction numbering | `IN-YYYYMMDD-000001` dan `OUT-YYYYMMDD-000001`, tanggal lokal organisasi |
| Initial stock | Stock In dengan catatan atau referensi `Saldo Awal` |
| Correction | Full reversal satu kali untuk seluruh transaksi asal, tipe berlawanan, gudang sama, alasan wajib; tanpa partial reversal |
| Concurrent Stock Out | Row-level locking, urutan lock konsisten, validasi saldo ulang, retry deadlock terbatas |
| Request deduplication | `Idempotency-Key` per user dan payload hash; response sukses direplay untuk retry identik |
| Estimasi nilai stok | Saldo saat ini dikalikan cost price master yang tersedia; bukan nilai akuntansi |
| Zona waktu | Default `Asia/Makassar`, dapat diubah Admin; timestamp disimpan UTC |
| Currency | Default `IDR`; multi-currency di luar MVP |
| Dashboard | Total SKU menghitung seluruh produk aktif organisasi; KPI stok dan aktivitas stok mengikuti scope gudang pengguna; grafik menghitung jumlah transaksi, bukan kuantitas lintas satuan |
| Filter dashboard | Periode default 30 hari; filter periode/gudang berlaku pada chart dan daftar aktivitas, bukan KPI saldo utama |
| API versioning | Prefix `/api/v1` |

---

## 20. Traceability ke dokumen berikutnya

| Area PRD | Dokumen lanjutan | Hasil yang diharapkan |
|---|---|---|
| Kebutuhan fungsional | FSD | Flow, aturan bisnis, validasi, exception, acceptance criteria per modul |
| Role dan akses | FSD / Security Specification | Permission matrix dan aturan otorisasi setiap endpoint |
| Saldo dan transaksi | FSD / ERD | Data model, atomic transaction, concurrency, idempotency |
| Informasi produk dan gudang | ERD | Tabel, relasi, constraint, index, dan migration |
| REST API | API Specification | Endpoint, request, response, status code, dan error contract |
| Design direction | Design System & UI/UX Specification | Komponen, tokens, responsive behavior, motion, dan UI states |
| Docker | Technical Architecture | Service, network, volume, health check, environment, dan deployment |
| Security | Security Specification | Threat considerations, session strategy, validation, rate limiting, secret handling |
| Testing | Test Plan | Unit, integration, end-to-end, acceptance, dan test data |

### 20.1 Aturan konsistensi dokumentasi

1. PRD menjadi sumber kebutuhan dan ruang lingkup produk.
2. Design System dan UI/UX Specification menjadi acuan visual serta perilaku antarmuka.
3. FSD menerjemahkan kebutuhan PRD menjadi aturan dan alur sistem yang rinci.
4. ERD dan API Specification menjabarkan struktur data dan kontrak integrasi.
5. Jika terdapat konflik, konflik harus dicatat dan diputuskan sebelum implementasi terkait dilanjutkan.
6. Perubahan scope harus memperbarui PRD dan dokumen turunannya yang terdampak.
7. Fitur yang berada di luar MVP tidak boleh diimplementasikan hanya karena sudah muncul sebagai konsep visual atau menu pada design reference.

---

## 21. Glossary

| Istilah | Definisi |
|---|---|
| SKU | Stock Keeping Unit, kode unik untuk mengidentifikasi produk |
| Inventory | Persediaan barang yang dikelola organisasi |
| Warehouse | Lokasi penyimpanan barang |
| Stock In | Transaksi penambahan stok |
| Stock Out | Transaksi pengurangan stok |
| Stock Movement | Catatan perubahan stok yang disebabkan transaksi |
| Inventory Balance | Jumlah stok suatu produk pada lokasi tertentu |
| Low Stock | Kondisi stok berada pada atau di bawah batas minimum, tetapi masih lebih dari nol |
| Out of Stock | Kondisi saldo stok sama dengan nol |
| RBAC | Role-Based Access Control, kontrol akses berdasarkan role |
| REST API | Antarmuka komunikasi berbasis HTTP dengan pola resource |
| ORM | Object Relational Mapper untuk membantu interaksi aplikasi dengan database relasional |
| Container | Lingkungan terisolasi untuk menjalankan aplikasi dan dependency |
| Idempotency | Sifat operasi yang tidak menghasilkan efek ganda ketika request yang sama diproses ulang sesuai aturan sistem |

---

## 22. Penutup

StockFlow MVP berfokus pada fondasi pengelolaan inventaris yang dapat dipercaya: master data, multi-warehouse balance, transaksi Stock In dan Stock Out, serta riwayat pergerakan stok. Pengalaman pengguna dirancang dengan identitas Creative Premium SaaS, dukungan light dan dark mode, serta animasi immersive yang tetap menjaga produktivitas.

Keberhasilan MVP tidak ditentukan oleh jumlah menu atau banyaknya animasi, melainkan oleh kemampuan pengguna menyelesaikan pekerjaan inventaris dengan alur yang jelas, data yang konsisten, hak akses yang benar, dan sistem yang dapat dijalankan secara stabil melalui Docker.

Dokumen turunan yang digunakan bersama PRD ini adalah **FSD StockFlow v1.0.1**, yang menerjemahkan kebutuhan dan aturan produk menjadi spesifikasi implementasi yang dapat diuji.

---

**Akhir dokumen**  
**StockFlow Product Requirements Document v1.0.1**
