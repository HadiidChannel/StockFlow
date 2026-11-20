# StockFlow Design System & UI/UX Specification

**Dokumen:** Design System dan UI/UX Specification  
**Produk:** StockFlow  
**Versi:** 1.0  
**Status:** Design direction ditetapkan, siap menjadi acuan PRD dan FSD  
**Tanggal:** 12 November 2026

---

## 1. Ringkasan keputusan desain

Arah visual StockFlow ditetapkan berdasarkan pilihan berikut:

| Dimensi | Keputusan |
|---|---|
| Gaya visual | Creative Premium SaaS |
| Tema | Light mode dan dark mode dengan dukungan setara |
| Intensitas animasi | Immersive |
| Prioritas | Seimbang antara estetika dan produktivitas |
| Produk | B2B SaaS Inventory & Warehouse Management System |
| Bahasa antarmuka awal | Bahasa Indonesia |
| Format angka | Locale Indonesia, dapat dikonfigurasi |
| Platform utama | Web desktop, responsif untuk tablet dan smartphone |

StockFlow harus terasa seperti produk SaaS modern yang memiliki karakter visual kuat, bukan template dashboard generik. Inspirasi visual berasal dari pendekatan website kreatif yang mengutamakan komposisi, typography, motion, dan detail interaksi. Inspirasi tersebut diterjemahkan ke dalam kebutuhan produk operasional, bukan ditiru mentah-mentah.

### 1.1 Prinsip desain

1. **Distinctive, not decorative.** Setiap elemen visual memiliki tujuan. Karakter visual muncul dari layout, typography, komposisi, warna, dan motion, bukan dari dekorasi berlebihan.
2. **Operational clarity first.** Pengguna harus dapat menemukan stok, membuat transaksi, dan membaca status tanpa harus menafsirkan animasi atau visual yang rumit.
3. **Motion with meaning.** Animasi memberi feedback, menunjukkan hubungan antar-elemen, membantu orientasi, atau memperjelas perubahan status.
4. **Consistent across themes.** Light dan dark mode harus sama-sama dirancang, bukan sekadar membalik warna.
5. **Responsive by design.** Pengalaman smartphone dirancang secara sengaja, bukan hanya mengecilkan layout desktop.
6. **Accessible by default.** Kontras, keyboard navigation, focus state, reduced motion, dan ukuran target sentuh menjadi bagian dari spesifikasi.

### 1.2 Karakter merek

- **Precise:** informasi stok, angka, dan status mudah dibaca.
- **Confident:** antarmuka terasa stabil dan profesional.
- **Energetic:** motion dan aksen warna memberi kesan aktif tanpa mengganggu.
- **Approachable:** istilah dan alur kerja mudah dipahami staff operasional.

Tone of voice antarmuka: jelas, ringkas, langsung, dan tidak menggunakan istilah teknis jika istilah operasional lebih mudah dipahami.

---

## 2. Identitas visual

### 2.1 Konsep visual

**Creative Enterprise:** kombinasi editorial layout dan komponen SaaS yang rapi.

Karakter visual yang dituju:
- Headline landing page berukuran besar dengan komposisi asimetris yang terkontrol.
- Ruang kosong cukup luas agar konten memiliki fokus.
- Dashboard menggunakan panel, tabel, dan kartu dengan hierarki yang tegas.
- Bentuk geometris sederhana yang terinspirasi dari susunan kotak, rak, paket, dan alur pergerakan barang.
- Aksen indigo sebagai warna interaksi utama dan mint sebagai aksen pendukung.
- Ilustrasi produk berupa diagram, bentuk 3D sederhana, atau visual data. Hindari foto stok gudang generik sebagai dekorasi utama.

### 2.2 Logo dan penggunaan merek

Konsep logomark yang direkomendasikan adalah susunan tiga bentuk persegi atau kubus bertingkat yang membentuk simbol aliran barang. Logomark harus tetap mudah dikenali pada ukuran 20 sampai 24 px.

Aturan:
- Gunakan wordmark `StockFlow` dengan kapitalisasi S dan F.
- Jangan menambahkan tagline ke logo pada ukuran kecil.
- Sediakan varian untuk light background, dark background, dan monochrome.
- Jangan menggunakan efek glow sebagai bagian permanen logo.
- Hindari mengganti logo dengan emoji atau ikon Unicode.

Tagline yang dapat digunakan pada landing page: **Know your stock. Move with confidence.**

---

## 3. Design tokens

Seluruh warna, jarak, radius, elevation, dan motion harus dikelola sebagai design token. Komponen tidak boleh menggunakan nilai warna acak secara langsung. Token menjadi sumber tunggal untuk light mode dan dark mode.

### 3.1 Color palette: Light mode

| Token | Nilai | Pemakaian |
|---|---|---|
| `--sf-bg` | `#F6F7F9` | Background utama aplikasi |
| `--sf-surface` | `#FFFFFF` | Card, panel, modal |
| `--sf-surface-subtle` | `#F0F2F6` | Area sekunder, table header, input muted |
| `--sf-surface-hover` | `#F7F8FC` | Hover state |
| `--sf-text-primary` | `#171B25` | Heading dan teks utama |
| `--sf-text-secondary` | `#687181` | Deskripsi dan label sekunder |
| `--sf-text-muted` | `#8A93A2` | Placeholder dan metadata |
| `--sf-border` | `#E5E8EF` | Border standar |
| `--sf-border-strong` | `#D4D9E3` | Divider atau border yang lebih tegas |
| `--sf-primary` | `#5962D8` | CTA utama, link aktif, elemen interaktif |
| `--sf-primary-hover` | `#4C55C5` | Hover CTA utama |
| `--sf-primary-soft` | `#ECEEFF` | Selected background dan soft badge |
| `--sf-accent` | `#A9DCC4` | Aksen dekoratif dan visual pendukung |
| `--sf-accent-strong` | `#36775D` | Aksen mint untuk teks atau ikon yang bermakna |
| `--sf-success` | `#2F8966` | Status berhasil |
| `--sf-warning` | `#B87925` | Status membutuhkan perhatian |
| `--sf-danger` | `#C65360` | Error, stok habis, tindakan berisiko |
| `--sf-info` | `#477FB7` | Informasi dan status netral |

### 3.2 Color palette: Dark mode

| Token | Nilai | Pemakaian |
|---|---|---|
| `--sf-bg` | `#10131A` | Background utama aplikasi |
| `--sf-surface` | `#171C25` | Card dan panel |
| `--sf-surface-subtle` | `#202735` | Area sekunder dan table header |
| `--sf-surface-hover` | `#242D3C` | Hover state |
| `--sf-text-primary` | `#EEF1F6` | Heading dan teks utama |
| `--sf-text-secondary` | `#A8B0BE` | Deskripsi dan label sekunder |
| `--sf-text-muted` | `#7E899A` | Placeholder dan metadata |
| `--sf-border` | `#2B3442` | Border standar |
| `--sf-border-strong` | `#3A4556` | Divider atau border yang lebih tegas |
| `--sf-primary` | `#969CFF` | CTA utama dan elemen interaktif |
| `--sf-primary-hover` | `#A9AEFF` | Hover CTA utama |
| `--sf-primary-soft` | `#2C3154` | Selected background dan soft badge |
| `--sf-accent` | `#9DDBBD` | Aksen dekoratif dan visual pendukung |
| `--sf-accent-strong` | `#9DDBBD` | Aksen mint untuk teks atau ikon bermakna |
| `--sf-success` | `#69C69B` | Status berhasil |
| `--sf-warning` | `#E5B566` | Status membutuhkan perhatian |
| `--sf-danger` | `#E27B85` | Error dan status berisiko |
| `--sf-info` | `#82B5E5` | Informasi dan status netral |

Nilai di atas merupakan palet awal. Sebelum implementasi final, pasangan warna foreground dan background harus diperiksa dengan contrast checker. Target minimum adalah WCAG 2.2 AA untuk teks normal dan komponen interaktif.

### 3.3 Semantic status colors

| Status | Token | Label contoh |
|---|---|---|
| Sukses / selesai | Success | Aktif, Diterima, Selesai |
| Perlu perhatian | Warning | Stok Menipis, Menunggu |
| Gagal / kritis | Danger | Stok Habis, Ditolak, Gagal |
| Informasi | Info | Draft, Dalam Proses |
| Netral | Muted | Diarsipkan, Tidak Aktif |

Warna tidak boleh menjadi satu-satunya pembeda status. Sertakan label teks dan, bila relevan, ikon.

### 3.4 Typography

Rekomendasi font:
- **Geist Sans** untuk heading, body, label, dan komponen umum.
- **Geist Mono** untuk SKU, kode transaksi, angka teknis, dan data yang memerlukan alignment karakter.
- Fallback: `Inter`, system sans-serif, dan monospace sistem.

Gunakan font lokal atau mekanisme self-hosting yang sesuai agar loading konsisten. Hindari lebih dari dua keluarga font.

| Style | Ukuran / line-height | Weight | Penggunaan |
|---|---:|---:|---|
| Display | 56 / 1.05 | 600 | Headline utama landing page desktop |
| Display mobile | 38 / 1.08 | 600 | Headline landing page mobile |
| H1 | 32 / 1.2 | 600 | Judul halaman utama |
| H2 | 24 / 1.3 | 600 | Judul section |
| H3 | 18 / 1.35 | 600 | Judul card atau panel |
| Body large | 16 / 1.6 | 400 | Intro dan deskripsi utama |
| Body | 14 / 1.5 | 400 | Konten aplikasi |
| Label | 13 / 1.4 | 500 | Label form dan tabel |
| Caption | 12 / 1.4 | 400 | Timestamp dan metadata |
| KPI | 30 / 1.1 | 600 | Nilai statistik dashboard |

Aturan typography:
- Gunakan sentence case untuk label dan judul.
- Hindari terlalu banyak uppercase.
- Angka KPI menggunakan tabular numerals.
- Jangan menggunakan font display untuk tabel operasional.
- Heading landing page boleh ekspresif, tetapi heading di dashboard harus ringkas.

### 3.5 Spacing scale

Gunakan basis 4 px.

| Token | Nilai |
|---|---:|
| `space-1` | 4 px |
| `space-2` | 8 px |
| `space-3` | 12 px |
| `space-4` | 16 px |
| `space-5` | 20 px |
| `space-6` | 24 px |
| `space-8` | 32 px |
| `space-10` | 40 px |
| `space-12` | 48 px |
| `space-16` | 64 px |
| `space-20` | 80 px |
| `space-24` | 96 px |

Jangan menggunakan spacing acak jika nilai token terdekat sudah mencukupi.

### 3.6 Radius

| Token | Nilai | Penggunaan |
|---|---:|---|
| `radius-sm` | 6 px | Badge kecil, compact input |
| `radius-md` | 10 px | Input, button, dropdown |
| `radius-lg` | 14 px | Card dan panel standar |
| `radius-xl` | 20 px | Hero card dan dialog besar |
| `radius-2xl` | 28 px | Visual landing page tertentu |
| `radius-full` | 999 px | Avatar, pill, status indicator |

Gunakan radius secara konsisten. Hindari setiap card memiliki radius berbeda tanpa alasan.

### 3.7 Elevation dan shadow

- `shadow-sm`: border dan shadow sangat lembut untuk card.
- `shadow-md`: dropdown, popover, dan floating toolbar.
- `shadow-lg`: modal dan command palette.
- Dark mode: lebih mengandalkan perbedaan surface dan border daripada shadow hitam yang kuat.
- Hindari glow berwarna pada seluruh card.

---

## 4. Layout system

### 4.1 Breakpoints

| Breakpoint | Lebar | Perilaku |
|---|---:|---|
| `sm` | 640 px | Smartphone besar dan perubahan layout kecil |
| `md` | 768 px | Tablet portrait |
| `lg` | 1024 px | Tablet landscape dan laptop kecil |
| `xl` | 1280 px | Desktop standar |
| `2xl` | 1536 px | Desktop lebar |

Breakpoints menjadi panduan, bukan batas kaku. Perubahan layout harus didasarkan pada ruang konten yang dibutuhkan.

### 4.2 Marketing layout

- Max content width: 1200 sampai 1320 px.
- Horizontal padding desktop: 40 sampai 56 px.
- Horizontal padding tablet: 24 sampai 32 px.
- Horizontal padding mobile: 20 px.
- Hero boleh menggunakan komposisi asimetris.
- Section spacing desktop: 96 sampai 128 px.
- Section spacing mobile: 56 sampai 72 px.

### 4.3 Application shell

| Elemen | Ukuran desktop |
|---|---:|
| Sidebar expanded | 248 px |
| Sidebar collapsed | 76 px |
| Topbar | 68 px |
| Main content max width | 1440 px |
| Main content padding | 32 px |
| Tablet content padding | 24 px |
| Mobile content padding | 16 px |
| Standard card gap | 20 sampai 24 px |

Desktop layout terdiri dari sidebar kiri, topbar, dan content area. Sidebar dapat diciutkan. Topbar memuat breadcrumb atau judul konteks, global search, notification, theme switcher, dan profile menu.

### 4.4 Tablet layout

- Sidebar menjadi drawer atau rail yang lebih kecil.
- Grid KPI berubah dari empat kolom menjadi dua kolom.
- Filter tabel dapat dibuka melalui filter panel.
- Tabel lebar menggunakan horizontal scroll yang jelas atau tampilan card pada layar yang terlalu sempit.

### 4.5 Mobile layout

- Sidebar diganti dengan navigation drawer atau bottom navigation untuk area utama.
- Bottom navigation maksimal lima tujuan utama: Ringkasan, Produk, Stok, Aktivitas, Lainnya.
- Primary action tetap mudah dijangkau.
- Form panjang dibagi ke beberapa section atau step jika alurnya kompleks.
- Tabel kompleks berubah menjadi card list atau menampilkan kolom paling penting saja.
- Tidak boleh ada horizontal page overflow.
- Touch target minimum 44 x 44 px.

---

## 5. Navigation dan information architecture

### 5.1 Marketing navigation

1. Beranda
2. Fitur
3. Solusi
4. Cara Kerja
5. Harga (dapat ditunda bila model harga belum ditentukan)
6. Masuk
7. CTA utama: Coba StockFlow

### 5.2 Application navigation

**Ringkasan**
- Dashboard

**Inventaris**
- Produk
- Kategori
- Stok
- Pergerakan Stok
- Stock Opname

**Operasional**
- Gudang
- Transfer Stok
- Pemasok
- Purchase Order
- Penerimaan Barang

**Analitik**
- Laporan
- Audit Log

**Pengaturan**
- Pengguna
- Role dan Hak Akses
- Profil Organisasi
- Preferensi

Menu yang belum masuk MVP boleh disembunyikan atau diberi status coming later pada prototype, tetapi jangan membuat tombol fungsional palsu pada aplikasi produksi.

---

## 6. Page inventory dan spesifikasi UI

### 6.1 Public landing page

**Tujuan:** menjelaskan manfaat StockFlow dan mengarahkan pengunjung ke registrasi atau demo.

Urutan section:
1. Navigation bar.
2. Hero section.
3. Product preview interaktif.
4. Problem and solution.
5. Key capabilities.
6. Workflow overview.
7. Use cases.
8. Trust and security notes.
9. CTA final.
10. Footer.

**Hero specification:**
- Headline besar dengan 1 sampai 2 baris pada desktop.
- Subheadline menjelaskan manfaat secara konkret.
- Primary CTA: `Mulai Kelola Inventaris`.
- Secondary CTA: `Lihat Cara Kerja`.
- Product preview menampilkan dashboard StockFlow dalam komposisi visual yang khas.
- Animasi hero dapat menggunakan staggered text reveal, floating data card, dan subtle parallax.
- Hindari animasi yang menghalangi pengunjung melihat CTA.

Contoh pesan hero:
- Headline: `Inventory clarity for every move.`
- Deskripsi: `Pantau stok, kelola gudang, dan kendalikan pergerakan barang dari satu ruang kerja.`

### 6.2 Login page

Elemen:
- Brand mark dan wordmark.
- Headline singkat.
- Email.
- Password dengan show/hide.
- Remember me bila session design mendukung.
- Forgot password.
- Primary button.
- Error message inline.
- Link bantuan.

Layout desktop dapat menggunakan split composition: form di satu sisi dan visual abstrak produk di sisi lain. Mobile menggunakan satu kolom dengan form sebagai fokus utama.

Status wajib: idle, loading, invalid credentials, validation error, network error, success redirect.

### 6.3 Dashboard overview

**Tujuan:** menjawab empat pertanyaan utama dalam beberapa detik:
1. Berapa total produk dan nilai inventaris?
2. Produk mana yang membutuhkan perhatian?
3. Apa perubahan stok terbaru?
4. Gudang mana yang memiliki kondisi tidak normal?

Komposisi:
- Greeting dan tanggal.
- Global date filter.
- Quick action: Barang Masuk, Barang Keluar, Tambah Produk.
- KPI row: Total SKU, Total Unit, Nilai Inventaris, Low Stock.
- Inventory movement chart.
- Low stock panel.
- Recent movements.
- Warehouse summary.

KPI card menampilkan angka, label, period comparison bila data tersedia, dan icon sederhana. Jangan menggunakan delta persentase jika periode pembanding tidak valid.

### 6.4 Product list

Elemen:
- Page title dan deskripsi.
- CTA `Tambah Produk`.
- Search produk berdasarkan nama atau SKU.
- Filter kategori, status, dan gudang bila relevan.
- Sort dan pagination.
- Table columns: checkbox, produk, SKU, kategori, total stok, minimum stok, status, updated date, action.
- Bulk action hanya muncul setelah baris dipilih.

Row action: detail, edit, archive. Penghapusan permanen memerlukan konfirmasi dan hanya diperbolehkan jika aturan integritas data mengizinkan.

### 6.5 Product create/edit

Field minimum:
- Nama produk.
- SKU.
- Kategori.
- Satuan.
- Minimum stock.
- Harga beli.
- Harga jual jika memang diperlukan pada lingkup produk.
- Deskripsi.
- Status aktif.

Aturan UI:
- Label selalu terlihat, jangan hanya mengandalkan placeholder.
- Required field diberi penanda.
- Validasi muncul dekat field.
- SKU duplikat harus menghasilkan pesan yang jelas.
- Form mempertahankan input ketika validasi gagal.
- Setelah berhasil, tampilkan toast dan arahkan pengguna sesuai konteks.

### 6.6 Product detail

- Product identity: nama, SKU, kategori, status.
- Ringkasan stok total.
- Stok per gudang.
- Minimum stock.
- Harga dan informasi produk.
- Stock movement history yang terkait produk.
- CTA: Edit, Stock In, Stock Out.

### 6.7 Warehouse list and detail

Warehouse list menampilkan nama gudang, kode, lokasi, jumlah SKU, total unit, dan status.

Warehouse detail menampilkan:
- Informasi gudang.
- Ringkasan kapasitas bila kapasitas memang dicatat.
- Stok per produk.
- Aktivitas terbaru.
- CTA transfer stok.

Jangan menampilkan persentase kapasitas gudang jika aplikasi tidak memiliki data kapasitas yang dapat dipercaya.

### 6.8 Inventory movement

Halaman ini adalah area kerja utama staff gudang.

Tab atau filter:
- Semua pergerakan.
- Barang masuk.
- Barang keluar.
- Penyesuaian.
- Transfer.

Kolom utama: tanggal, nomor transaksi, produk, gudang, tipe aktivitas, kuantitas, pengguna, status.

Quick action harus mudah terlihat. Form transaksi harus membedakan tipe pergerakan dengan jelas dan memperlihatkan ringkasan dampaknya pada stok sebelum pengguna mengonfirmasi.

### 6.9 Stock In

Flow:
1. Pilih gudang tujuan.
2. Pilih satu atau beberapa produk.
3. Masukkan kuantitas.
4. Masukkan referensi atau catatan bila diperlukan.
5. Review ringkasan.
6. Konfirmasi transaksi.

UI harus mencegah double submission dan menampilkan status proses. Perubahan saldo dan pencatatan movement harus diproses sebagai satu transaksi backend.

### 6.10 Stock Out

Flow sama dengan Stock In, tetapi ringkasan harus menampilkan stok tersedia dan stok setelah transaksi. Jika kuantitas melebihi stok tersedia, tampilkan error yang spesifik dan jangan mengizinkan konfirmasi.

### 6.11 Stock Transfer

Flow:
1. Pilih gudang asal.
2. Pilih gudang tujuan.
3. Tambahkan produk dan kuantitas.
4. Review dampak stok asal dan tujuan.
5. Konfirmasi transfer.

Gudang asal dan tujuan tidak boleh sama. Pada versi lanjutan, status transfer dapat mencakup Draft, In Transit, Received, dan Cancelled. Status yang dipakai harus mengikuti aturan operasional yang nantinya didefinisikan di FSD.

### 6.12 Stock Opname

- Pilih gudang.
- Tampilkan stok sistem.
- Input hasil hitung fisik.
- Tampilkan selisih.
- Wajibkan alasan untuk selisih.
- Review dan submit hasil.

Perubahan stok dari stock opname harus menghasilkan stock movement dan audit trail.

### 6.13 Supplier

- Supplier list.
- Search dan filter status.
- Supplier detail.
- Kontak, alamat, catatan, dan riwayat purchase order.
- Tindakan tambah, edit, dan arsip.

Data kontak harus ditampilkan seperlunya berdasarkan hak akses.

### 6.14 Purchase Order

Daftar PO menampilkan nomor, supplier, tanggal, nilai, status, dan pembuat.

Detail PO menampilkan item, kuantitas, harga, subtotal, total, catatan, dan riwayat status.

Status yang disarankan untuk rancangan awal: Draft, Submitted, Approved, Partially Received, Received, Cancelled. Status final dan aturan transisinya ditentukan dalam FSD.

### 6.15 Reports

Jenis laporan awal:
- Stock on hand.
- Stock movement.
- Low stock.
- Inventory valuation bila data biaya memadai.
- Purchase summary pada fase lanjutan.

Filter tanggal, gudang, kategori, produk, dan jenis transaksi harus tersedia sesuai jenis laporan. Export CSV harus mengikuti filter aktif dan memberikan feedback proses.

### 6.16 Users and roles

- User list.
- Invite atau tambah pengguna.
- Status akun.
- Role assignment.
- Reset atau revoke akses sesuai alur keamanan.

Permission tidak cukup disembunyikan dari UI. Semua tindakan harus tetap divalidasi pada backend.

### 6.17 Notifications

Jenis notifikasi:
- Low stock.
- Purchase order membutuhkan tindakan.
- Penerimaan barang.
- Transfer stok.
- Aktivitas penting.

Notifikasi harus memiliki kategori, timestamp, status read/unread, dan tautan ke konteks terkait. Jangan mengirim notifikasi untuk setiap perubahan kecil yang tidak relevan.

### 6.18 Settings

- Profil organisasi.
- Preferensi pengguna.
- Theme preference: Light, Dark, System.
- Bahasa.
- Format tanggal dan angka.
- Zona waktu organisasi.
- Manajemen pengguna dan akses sesuai izin.

---

## 7. Component design specification

### 7.1 Buttons

Variants:
- Primary.
- Secondary.
- Tertiary / Ghost.
- Destructive.
- Link.

Sizes:
- Small: tinggi 32 px.
- Medium: tinggi 40 px.
- Large: tinggi 48 px.

States wajib: default, hover, active, focus-visible, disabled, loading.

Aturan:
- Satu primary action utama per area visual.
- Loading button tidak boleh menerima klik berulang.
- Icon-only button harus memiliki accessible name dan tooltip bila maknanya tidak jelas.

### 7.2 Form controls

Komponen: text input, password input, number input, select, combobox, checkbox, radio, switch, date picker, textarea, file input.

- Tinggi kontrol standar: 40 px.
- Label berada di atas kontrol.
- Helper text dan error text memiliki posisi konsisten.
- Focus ring terlihat jelas.
- Error tidak hanya ditandai border merah, tetapi juga teks penjelasan.
- Number input menggunakan validasi angka dan batas minimum yang sesuai.

### 7.3 Cards

Jenis:
- KPI card.
- Chart card.
- Content card.
- Alert card.
- Empty-state card.

Card standar menggunakan surface, border subtle, radius 14 px, dan padding 20 sampai 24 px. Hindari shadow besar pada semua card.

### 7.4 Data tables

- Header memiliki kontras cukup dari body.
- Row height standar 52 sampai 56 px.
- Nomor dan nilai kuantitas rata kanan.
- SKU dan kode transaksi dapat menggunakan Geist Mono.
- Sort indicator hanya tampil pada kolom sortable.
- Pagination menampilkan jumlah data dan posisi halaman.
- Bulk action tidak menggeser layout secara mendadak.
- Mobile menggunakan card list atau kolom prioritas.

### 7.5 Dialog dan drawer

- Dialog konfirmasi untuk tindakan berisiko.
- Drawer untuk detail cepat atau form sekunder.
- Dialog memiliki title, deskripsi, tombol aksi, dan close control.
- Focus trap dan focus return harus berjalan.
- Klik di luar modal tidak boleh menghilangkan data form yang belum disimpan tanpa konfirmasi.

### 7.6 Badge dan status indicator

Gunakan badge untuk status, bukan untuk dekorasi. Setiap badge memiliki teks yang dapat dipahami tanpa melihat warna.

### 7.7 Toast dan inline feedback

- Success: tindakan berhasil.
- Error: tindakan gagal dan langkah berikutnya bila tersedia.
- Warning: tindakan membutuhkan perhatian.
- Info: informasi netral.

Toast tidak boleh menjadi satu-satunya tempat menampilkan error validasi penting. Error form harus tetap terlihat pada field atau form summary.

### 7.8 Search, filter, dan command actions

- Global search berada di topbar.
- Search halaman berada dekat title dan toolbar tabel.
- Filter aktif tampil sebagai removable chip.
- Sediakan clear all bila filter banyak.
- Keyboard shortcut boleh ditambahkan setelah fungsi utama stabil.

---

## 8. Motion and interaction system

Intensitas animasi ditetapkan **Immersive**, dengan batasan bahwa produktivitas dan performa tetap menjadi prioritas. Motion paling ekspresif digunakan pada landing page. Dashboard menggunakan motion yang lebih pendek dan fungsional.

### 8.1 Motion principles

1. Animasi harus menjelaskan perubahan, bukan sekadar membuat elemen bergerak.
2. Interaksi penting harus memberi feedback dalam waktu singkat.
3. Animasi tidak boleh menunda pengguna menyelesaikan transaksi.
4. Animasi tidak boleh menyebabkan layout shift atau mengubah posisi kontrol saat pengguna akan mengkliknya.
5. Animasi dekoratif tidak boleh terus berjalan tanpa kebutuhan.
6. Semua motion harus menghormati `prefers-reduced-motion`.

### 8.2 Duration tokens

| Token | Durasi | Penggunaan |
|---|---:|---|
| `motion-instant` | 100 ms | Press feedback |
| `motion-fast` | 150 ms | Hover, focus, icon state |
| `motion-base` | 220 ms | Dropdown, tooltip, small modal |
| `motion-standard` | 320 ms | Card entrance, tab transition |
| `motion-expressive` | 480 ms | Landing section reveal |
| `motion-story` | 650 ms | Hero sequence atau scroll storytelling |

Durasi bukan aturan mutlak. Jangan menggunakan durasi panjang pada aksi yang harus terasa langsung, seperti submit transaksi.

### 8.3 Easing tokens

- `ease-standard`: ease-out lembut untuk mayoritas UI.
- `ease-emphasized`: kurva lebih ekspresif untuk hero dan panel besar.
- `ease-enter`: elemen masuk dengan perlambatan di akhir.
- `ease-exit`: elemen keluar lebih cepat agar UI terasa responsif.
- Spring motion digunakan untuk gesture dan elemen yang memang terasa fisik, bukan untuk seluruh komponen.

### 8.4 Motion matrix

| Elemen | Trigger | Motion | Durasi rekomendasi |
|---|---|---|---:|
| Hero headline | Page load | Split/staggered reveal | 480-650 ms |
| Hero product preview | Page load | Fade, translate, subtle scale | 650 ms |
| Landing feature blocks | Scroll into view | Staggered reveal | 400-500 ms |
| Navbar | Scroll | Background/elevation transition | 220 ms |
| KPI cards | Initial load | Fade + short translate | 320 ms |
| KPI number | Data ready | Count-up singkat | 500-800 ms |
| Chart | Data ready | Line/bar reveal | 500-700 ms |
| Sidebar active item | Navigation | Sliding indicator | 220 ms |
| Dropdown | Open/close | Fade + scale | 150-220 ms |
| Modal | Open/close | Fade + scale | 220 ms |
| Toast | New message | Slide + fade | 220 ms |
| Button | Hover/press | Color, scale sangat kecil | 100-150 ms |
| Table row | Hover | Surface tint | 120 ms |
| Theme switch | User action | Color interpolation | 180-250 ms |

### 8.5 Landing page motion

Boleh menggunakan Motion dan GSAP ScrollTrigger untuk bagian yang memerlukan kontrol scroll lebih kompleks.

Animasi yang diperbolehkan:
- Text reveal pada hero.
- Subtle parallax pada visual produk.
- Staggered feature reveal.
- Pinned section yang singkat untuk menjelaskan alur kerja.
- Animated connector atau garis alur inventory.
- Product mockup yang menunjukkan state perubahan stok.

Batasan:
- Jangan membuat seluruh halaman bergantung pada scroll hijacking.
- Jangan menggunakan horizontal scroll sebagai satu-satunya cara membaca konten.
- Jangan memaksa pengguna menunggu animasi selesai untuk mengakses CTA.
- Hindari video background berat.
- Jangan menjalankan animasi parallax berat pada perangkat low-power.

### 8.6 Dashboard motion

- Entrance animation hanya untuk elemen utama ketika halaman pertama kali dibuka.
- Navigasi antarhalaman menggunakan transisi singkat.
- Data refresh tidak boleh mengulang seluruh entrance animation.
- Count-up hanya digunakan saat nilai KPI pertama kali dimuat atau saat perubahan memang relevan.
- Table row tidak perlu bergerak setiap kali data diperbarui.
- Perubahan status menggunakan color transition dan icon feedback yang singkat.
- Modal form tidak boleh menggeser fokus atau kehilangan input.

### 8.7 Reduced motion

Saat `prefers-reduced-motion: reduce` aktif:
- Nonaktifkan parallax dan scroll storytelling.
- Hilangkan looping decorative animation.
- Ganti translate atau scale besar dengan fade singkat atau perubahan state langsung.
- Hindari auto-playing animation yang tidak dapat dihentikan.
- Tetap berikan feedback melalui perubahan warna, teks, dan status.

Sediakan juga preferensi motion di dalam pengaturan pengguna jika implementasi mendukungnya.

### 8.8 Motion technology usage

- **Motion for React:** interaksi komponen, entrance, layout transition, gesture, modal, drawer, dan toast.
- **GSAP + ScrollTrigger:** hanya untuk storytelling atau sequence landing page yang kompleks.
- **CSS transitions:** hover, focus, border, warna, dan perubahan kecil.
- Hindari mengimplementasikan satu elemen dengan beberapa animation engine sekaligus.
- GSAP harus di-load secara terpisah bila hanya diperlukan pada halaman marketing.

---

## 9. Data visualization system

Dashboard menggunakan warna grafik yang konsisten pada kedua tema.

Rekomendasi urutan warna:
1. Primary indigo.
2. Teal atau mint.
3. Muted blue.
4. Amber.
5. Muted coral.

Aturan:
- Gunakan maksimal lima warna seri dalam satu chart bila memungkinkan.
- Gridline harus halus.
- Label sumbu tidak boleh terlalu kecil.
- Tooltip menampilkan nilai eksak dan konteks tanggal.
- Legend dapat digunakan untuk mengaktifkan atau menonaktifkan seri.
- Jangan menggunakan pie chart untuk terlalu banyak kategori.
- Jangan menggunakan visual 3D yang mengaburkan perbandingan data.
- Sediakan ringkasan teks atau tabel jika informasi chart penting bagi keputusan operasional.
- Empty chart harus menjelaskan mengapa belum ada data.

Jenis chart yang direkomendasikan:
- Line chart untuk tren stock movement.
- Bar chart untuk perbandingan antar gudang atau kategori.
- Donut chart hanya untuk komposisi sederhana dengan sedikit kategori.
- Horizontal bar untuk ranking low stock atau produk dengan aktivitas tertinggi.

---

## 10. Responsive behavior per modul

| Modul | Desktop | Tablet | Mobile |
|---|---|---|---|
| Dashboard | KPI 4 kolom, chart 2 kolom | KPI 2 kolom | KPI 1 atau 2 kolom, chart bertumpuk |
| Product list | Data table penuh | Table dengan kolom prioritas | Product card list |
| Product form | Dua kolom bila sesuai | Satu atau dua kolom | Satu kolom |
| Warehouse | Grid dan detail panel | Grid 2 kolom | List card |
| Stock movement | Table dan filter toolbar | Filter drawer | Card list dan quick filter |
| Stock transaction | Form + summary side panel | Summary di bawah form | Step-by-step form |
| Reports | Chart dan table berdampingan | Vertikal | Chart ringkas, table card |
| User management | Table | Table ringkas | Card list |

Semua fitur penting harus tetap dapat dilakukan di smartphone. Jika fitur tertentu membutuhkan layar lebih lebar, tampilkan alasan dan alternatif yang jelas, bukan kontrol yang terpotong.

---

## 11. UX flows utama

### 11.1 First-time organization setup

1. Pengguna membuka halaman registrasi atau menerima undangan.
2. Pengguna membuat akun atau masuk.
3. Admin mengisi profil organisasi.
4. Admin membuat gudang pertama.
5. Admin menambahkan kategori dan produk awal.
6. Admin mengundang staff.
7. Dashboard menampilkan checklist setup yang tersisa.

Progress setup harus dapat dilewati bila langkah tidak wajib untuk memulai penggunaan.

### 11.2 Receive stock

1. Pengguna membuka menu Barang Masuk.
2. Memilih gudang.
3. Memilih produk.
4. Memasukkan kuantitas.
5. Memeriksa ringkasan.
6. Mengonfirmasi transaksi.
7. Sistem menampilkan nomor referensi dan hasil transaksi.

### 11.3 Issue stock

1. Pengguna membuka menu Barang Keluar.
2. Memilih gudang dan produk.
3. Sistem menampilkan stok tersedia.
4. Pengguna memasukkan kuantitas.
5. Sistem menghitung sisa stok.
6. Pengguna memeriksa ringkasan dan konfirmasi.
7. Sistem menampilkan hasil transaksi.

### 11.4 Transfer stock

1. Pengguna memilih gudang asal dan tujuan.
2. Pengguna memilih produk dan kuantitas.
3. Sistem menampilkan saldo asal dan perkiraan saldo tujuan.
4. Pengguna melakukan review.
5. Pengguna mengonfirmasi transfer.
6. Sistem mencatat pergerakan sesuai aturan status transfer.

### 11.5 Resolve low stock

1. Pengguna melihat alert stok menipis.
2. Pengguna membuka detail produk.
3. Pengguna melihat stok per gudang dan riwayat.
4. Pengguna memilih tindakan lanjutan, seperti membuat purchase request atau mencatat barang masuk.

---

## 12. UX states yang wajib dirancang

Setiap halaman dan komponen data harus memiliki state berikut sesuai konteks:

- **Loading:** skeleton yang mengikuti bentuk konten.
- **Empty:** menjelaskan belum ada data dan tindakan yang dapat dilakukan.
- **Error:** menjelaskan masalah dan opsi retry jika aman.
- **Success:** memberikan konfirmasi yang jelas.
- **Partial data:** menjelaskan data yang berhasil dan yang gagal dimuat.
- **Permission denied:** memberi penjelasan bahwa pengguna tidak memiliki akses.
- **Offline / network issue:** menunjukkan bahwa koneksi bermasalah dan tindakan mana yang belum tersimpan.
- **Destructive confirmation:** menjelaskan dampak tindakan sebelum pengguna menyetujui.

Contoh empty state produk:

**Belum ada produk**  
Tambahkan produk pertama agar stok dapat mulai dikelola.  
CTA: `Tambah Produk`

Contoh low stock alert:

**Stok perlu diperhatikan**  
Ada 8 produk yang berada di bawah batas minimum.  
CTA: `Lihat Produk`

---

## 13. Accessibility dan usability

Target implementasi: WCAG 2.2 AA sejauh relevan untuk aplikasi web.

Checklist:
- Semua fungsi dapat diakses menggunakan keyboard.
- Focus ring jelas dan tidak dihilangkan.
- Urutan tab mengikuti urutan visual dan logis.
- Dialog mengelola focus trap dan focus return.
- Form memiliki label yang terhubung dengan kontrol.
- Error dapat dibaca oleh assistive technology.
- Ikon-only action memiliki accessible name.
- Status tidak hanya dibedakan melalui warna.
- Kontras teks dan komponen diperiksa.
- Touch target mobile minimal 44 x 44 px.
- Konten tetap dapat digunakan pada zoom browser 200 persen.
- Motion menghormati reduced motion.
- Tabel kompleks memiliki struktur header yang benar.

---

## 14. Content design dan localization

Bahasa antarmuka awal adalah Bahasa Indonesia. Nama produk dan istilah teknologi dapat tetap menggunakan istilah umum yang dipahami pengguna.

Contoh istilah:

| Gunakan | Hindari bila tidak perlu |
|---|---|
| Barang Masuk | Inbound transaction |
| Barang Keluar | Outbound transaction |
| Pergerakan Stok | Stock movement |
| Gudang | Warehouse |
| Stok Menipis | Low inventory threshold breach |
| Pemasok | Vendor, bila pengguna lebih akrab dengan pemasok |
| Riwayat Aktivitas | Audit trail, untuk label yang dilihat pengguna umum |

Aturan format:
- Angka menggunakan locale `id-ID` secara default.
- Mata uang default dapat menggunakan IDR, dengan dukungan konfigurasi organisasi.
- Format tanggal disepakati konsisten, misalnya `12 Nov 2026` pada tampilan ringkas.
- Zona waktu menggunakan pengaturan organisasi, bukan asumsi browser semata.
- SKU dan nomor transaksi tidak dilokalkan.
- Hindari pesan error yang hanya menampilkan kode teknis.

---

## 15. UX security states

Desain harus membantu pengguna memahami kondisi keamanan tanpa membocorkan detail sensitif.

- Password selalu masked secara default.
- Konfirmasi ulang untuk tindakan sensitif yang ditetapkan pada FSD.
- Session expired menampilkan pesan dan jalur login ulang yang jelas.
- Akses ditolak tidak boleh menampilkan informasi data yang tidak boleh dilihat.
- Tampilkan siapa yang melakukan perubahan dan kapan pada riwayat aktivitas sesuai permission.
- Jangan meletakkan token, credential, atau informasi rahasia pada URL atau tampilan UI.
- Jangan menampilkan stack trace atau pesan database mentah kepada pengguna.

---

## 16. Frontend implementation guidance

### 16.1 Struktur tanggung jawab

- `app/`: routing, layout, loading, error, dan page composition.
- `components/ui/`: primitive dan komponen visual reusable.
- `components/layout/`: sidebar, topbar, app shell, navigation.
- `components/dashboard/`: komponen dashboard khusus.
- `components/animations/`: wrapper atau pattern motion reusable.
- `features/` atau route modules: komponen dan logic berdasarkan domain bila kompleksitas meningkat.
- `lib/`: API client, formatter, constants, theme utilities.
- `hooks/`: custom hooks.
- `types/`: shared frontend types.

### 16.2 Component boundaries

- Gunakan Server Components untuk konten yang tidak membutuhkan interaksi client.
- Gunakan Client Components hanya ketika membutuhkan state, event handler, browser API, atau animation library client-side.
- Jangan menjadikan seluruh layout sebagai Client Component hanya karena satu komponen memiliki animasi.
- Pisahkan data fetching dari presentational components jika meningkatkan testability.
- Komponen harus memiliki props yang jelas dan tidak terlalu banyak conditional flags.

### 16.3 Theme implementation

- Gunakan CSS custom properties sebagai sumber token.
- Gunakan theme provider untuk pilihan Light, Dark, dan System.
- Simpan preferensi sesuai pola penyimpanan yang aman dan konsisten.
- Hindari flash of incorrect theme saat initial render.
- Uji seluruh komponen pada kedua tema.

### 16.4 Styling rules

- Gunakan design token untuk warna, spacing, radius, shadow, dan typography.
- Hindari inline color values yang tidak berasal dari token.
- Hindari penggunaan gradient sebagai background default.
- Gunakan gradient secara terbatas untuk hero atau visual marketing.
- Jangan membuat satu komponen memiliki styling berbeda tanpa kebutuhan konteks yang jelas.

---

## 17. Design and frontend quality gates

Sebuah halaman dianggap siap ketika:

1. Hierarki informasi jelas dan sesuai tujuan halaman.
2. Seluruh state utama telah dirancang.
3. Light dan dark mode telah diuji.
4. Desktop, tablet, dan mobile telah diuji.
5. Semua interaksi memiliki feedback.
6. Animasi tidak menghambat tugas utama.
7. Reduced motion berjalan.
8. Keyboard navigation berjalan.
9. Tidak ada horizontal overflow yang tidak disengaja.
10. Tidak ada layout shift besar saat konten dimuat.
11. Empty, loading, error, dan permission states tersedia.
12. Copy menggunakan istilah yang konsisten.
13. Tidak ada tombol atau link yang terlihat aktif tetapi tidak melakukan tindakan.
14. Kontras dan focus state telah diperiksa.

---

## 18. Out of scope untuk dokumen desain ini

Dokumen ini menetapkan arah visual dan perilaku UI/UX. Dokumen ini belum menetapkan secara final:

- Business rules untuk seluruh transaksi inventaris.
- Detail skema database dan relasi final.
- Kontrak request dan response API.
- Aturan status dan transisi Purchase Order.
- Strategi deployment production.
- Detail keamanan backend dan threat model.
- Perhitungan inventory valuation secara akuntansi.
- Multi-tenancy.
- Integrasi barcode scanner atau perangkat gudang.

Hal tersebut akan ditentukan melalui PRD dan FSD setelah spesifikasi UI/UX disetujui.

---

## 19. Keputusan desain yang sudah dikunci

| Item | Keputusan |
|---|---|
| Nama produk | StockFlow |
| Product category | B2B SaaS Inventory & Warehouse Management |
| Visual direction | Creative Premium SaaS |
| Theme | Light + Dark |
| Motion | Immersive, dengan prioritas produktivitas |
| Frontend | Next.js + React + TypeScript |
| Styling | Tailwind CSS dengan design tokens |
| UI primitives | shadcn/ui yang dikustomisasi, bukan dipakai tanpa perubahan |
| UI motion | Motion for React |
| Advanced marketing motion | GSAP + ScrollTrigger secara selektif |
| Charts | Recharts |
| Backend | Node.js + Express.js |
| Database | MySQL |
| ORM | Prisma |
| Containerization | Docker + Docker Compose |
| Bahasa UI | Bahasa Indonesia pada rilis awal |

## 20. Langkah berikutnya

Urutan dokumen dan implementasi setelah spesifikasi ini:

1. **PRD StockFlow:** masalah, target pengguna, tujuan, scope MVP, kebutuhan fungsional tingkat produk, dan acceptance criteria.
2. **FSD StockFlow:** detail alur, business rules, permission matrix, validasi, state transition, dan acceptance criteria per fitur.
3. **ERD dan Database Specification:** entitas, relasi, constraints, indexes, dan aturan konsistensi transaksi.
4. **Technical Architecture:** struktur aplikasi, API contract, authentication flow, error handling, logging, Docker development dan production.
5. **UI Implementation:** implementasi design tokens, shell, halaman, komponen, dan motion.

Dokumen ini menjadi sumber acuan visual. Jika ada kebutuhan produk yang mengharuskan perubahan desain, perubahan harus dicatat agar PRD, FSD, dan implementasi tetap konsisten.

---

**Akhir dokumen**  
**StockFlow Design System & UI/UX Specification v1.0**
