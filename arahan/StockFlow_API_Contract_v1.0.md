# StockFlow API Contract

**Versi:** 1.0.0  
**Status:** Draft implementasi untuk MVP  
**API style:** REST + JSON  
**OpenAPI:** 3.1.0  
**Base path:** `/api/v1`  
**Backend:** Express.js + TypeScript  
**Database:** MySQL 8.4 LTS melalui Prisma

---

## 1. Tujuan dan status dokumen

Dokumen ini menetapkan kontrak komunikasi antara frontend StockFlow dan backend. Kontrak diturunkan dari PRD StockFlow v1.0.1, FSD StockFlow v1.0.1, ERD & Database Specification StockFlow v1.0, dan MySQL Schema v1.0.

File `StockFlow_OpenAPI_v1.0.yaml` adalah representasi machine-readable untuk Swagger UI, code generation, dan validasi kontrak. Jika ada ketidaksesuaian antara contoh naratif dan schema OpenAPI, review harus dilakukan terhadap FSD dan keputusan API yang tercatat pada Bagian 16 dokumen ini.

### 1.1 Ruang lingkup

Termasuk dalam kontrak MVP:

- Authentication berbasis session cookie.
- User management dan warehouse assignment.
- Organization profile.
- Category, product, dan warehouse management.
- Inventory balance read APIs.
- Stock In, Stock Out, dan full reversal.
- Stock movement history.
- Dashboard summary, movement chart, recent movements, dan stock alerts.
- Personal preferences.

Tidak termasuk:

- Public self-registration.
- Forgot password melalui email.
- Multi-organization tenant switching.
- Partial reversal.
- Transfer antargudang sebagai tipe transaksi tersendiri.
- API untuk mengubah saldo secara langsung.
- Integrasi akuntansi atau multi-currency.

## 2. Dokumen acuan dan prioritas

| Dokumen | Penggunaan |
|---|---|
| PRD StockFlow v1.0.1 | Scope MVP, persona, kebutuhan produk, metrik, acceptance criteria |
| FSD StockFlow v1.0.1 | Proses bisnis, hak akses, route, payload contoh, validasi, error code, transaction flow |
| ERD & Database Specification StockFlow v1.0 | Struktur data, relasi, invariant, concurrency, idempotency |
| StockFlow MySQL Schema v1.0 | Nama tabel dan constraint database |

Urutan prioritas saat implementasi: kebutuhan dan keputusan yang sudah dikunci pada PRD/FSD, lalu kontrak API ini untuk melengkapi representasi teknis. Ambiguitas yang belum diputuskan tidak boleh dianggap sebagai aturan bisnis final.

## 3. Konvensi umum

### 3.1 Base URL dan versioning

Semua endpoint berada di bawah:

```text
/api/v1
```

File OpenAPI menggunakan server URL `/api/v1`; path di dalam file tidak mengulang prefix tersebut.

### 3.2 Format request dan response

- Request dan response menggunakan `application/json`, kecuali tidak ada body.
- Nama properti API menggunakan `camelCase`.
- Nama kolom database menggunakan `snake_case`.
- ID menggunakan UUID string.
- Timestamp dikirim sebagai ISO 8601 dengan timezone UTC, misalnya `2026-11-12T02:00:00.000Z`.
- Tanggal kalender dikirim sebagai `YYYY-MM-DD`.
- Kuantitas dan nilai uang dikirim sebagai string decimal, bukan JSON floating point.
- String wajib di-trim sebelum validasi dan penyimpanan.
- Field yang tidak tersedia atau memang kosong dapat dikirim sebagai `null` sesuai schema resource.
- Backend adalah sumber kebenaran untuk validasi, permission, business rules, saldo, nomor transaksi, dan timezone.

### 3.3 Format response sukses

Response tunggal:

```json
{
  "data": {
    "id": "3f0b8e20-05aa-4c3c-a3a0-6bf2b7d4c1aa"
  }
}
```

Response daftar:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 0,
    "totalPages": 0
  }
}
```

Response transaksi sukses:

```json
{
  "data": {
    "id": "3f0b8e20-05aa-4c3c-a3a0-6bf2b7d4c1aa",
    "referenceNumber": "IN-20261112-000001",
    "type": "IN",
    "status": "POSTED",
    "postedAt": "2026-11-12T02:00:00.000Z"
  }
}
```

### 3.4 Format error

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Stok tersedia tidak mencukupi.",
    "details": [
      {
        "field": "items[0].quantity",
        "message": "Jumlah yang diminta melebihi stok tersedia."
      }
    ],
    "requestId": "req_01J..."
  }
}
```

Ketentuan:

1. `error.code` stabil dan dapat dipakai frontend untuk menentukan UI state.
2. `error.message` menggunakan Bahasa Indonesia.
3. `details` bersifat opsional. Jika dikirim, setiap item berisi `message` dan `field` jika relevan.
4. `requestId` wajib dikembalikan agar masalah dapat ditelusuri pada log backend.
5. Stack trace, query SQL, credential, token, password, dan detail internal tidak boleh dikembalikan.
6. Server harus mengirim atau mencatat `X-Request-Id`. Client boleh mengirim header tersebut untuk correlation ID; server membuat ID baru bila tidak diberikan.

## 4. Authentication dan session

### 4.1 Mekanisme session

StockFlow menggunakan opaque random session token, bukan token session pada JSON response.

| Cookie | Atribut | Fungsi |
|---|---|---|
| `sf_session` | `HttpOnly`, `Secure` pada production, `SameSite=Lax`, Path yang sesuai | Session authentication |
| `sf_csrf` | Dapat dibaca frontend, `Secure` pada production, `SameSite=Lax` | Sumber nilai CSRF untuk header request |

Database hanya menyimpan hash token session dan hash CSRF token. Token mentah tidak disimpan pada database atau log.

### 4.2 Login

`POST /auth/login`

Request:

```json
{
  "email": "admin@example.com",
  "password": "example-password"
}
```

Response body:

```json
{
  "data": {
    "user": {
      "id": "3f0b8e20-05aa-4c3c-a3a0-6bf2b7d4c1aa",
      "name": "Admin StockFlow",
      "email": "admin@example.com",
      "role": {
        "code": "ADMIN",
        "name": "Administrator"
      },
      "mustChangePassword": false,
      "permissions": ["dashboard.read", "product.read"]
    }
  }
}
```

Response juga menetapkan `sf_session` dan `sf_csrf` melalui `Set-Cookie`. Session token tidak boleh muncul pada JSON body.

Ketentuan:

- Email dinormalisasi menjadi lowercase sebelum lookup.
- Login hanya berhasil untuk akun aktif.
- Password diverifikasi menggunakan Argon2id atau konfigurasi password hashing setara yang aman.
- Login gagal menggunakan pesan umum dan menerapkan rate limit.
- Request login memvalidasi Origin, Content-Type, dan kebijakan SameSite. Login tidak memerlukan CSRF header karena session belum dibuat.
- Tidak ada public self-registration.
- Jika `mustChangePassword=true`, frontend harus mengarahkan user ke alur ubah password sebelum membuka fitur operasional.

### 4.3 Request privat

Semua request selain login yang memerlukan identitas user harus membawa cookie `sf_session` yang valid. Request state-changing yang menggunakan session wajib memvalidasi:

- Cookie `sf_csrf`.
- Header `X-CSRF-Token`.
- Hash CSRF token yang terikat pada session.
- Origin yang diizinkan.

Validasi harus dilakukan backend. Frontend tidak boleh dianggap sebagai batas keamanan.

### 4.4 Logout dan perubahan password

- `POST /auth/logout`: mencabut session saat ini dan menghapus cookie session serta CSRF.
- `GET /auth/me`: mengembalikan identitas, role, permission, dan flag `mustChangePassword`.
- `POST /auth/change-password`: memverifikasi password saat ini, menyimpan hash password baru, dan menghapus flag `mustChangePassword` setelah berhasil.

## 5. Role, permission, dan data scope

### 5.1 Role MVP

Role yang didukung hanya `ADMIN` dan `WAREHOUSE_STAFF`.

| Permission | Admin | Warehouse Staff |
|---|---:|---:|
| `dashboard.read` | Ya | Ya |
| `product.read` | Ya | Ya |
| `product.create` | Ya | Tidak |
| `product.update` | Ya | Tidak |
| `product.deactivate` | Ya | Tidak |
| `category.read` | Ya | Ya |
| `category.manage` | Ya | Tidak |
| `warehouse.read` | Ya | Ya, assignment saja |
| `warehouse.manage` | Ya | Tidak |
| `inventory.read` | Ya | Ya, assignment saja |
| `stock_in.create` | Ya | Ya, gudang assignment yang aktif |
| `stock_out.create` | Ya | Ya, gudang assignment yang aktif |
| `movement.read` | Ya | Ya, assignment saja |
| `user.manage` | Ya | Tidak |
| `user.warehouse_assignment.manage` | Ya | Tidak |
| `organization.manage` | Ya | Tidak |
| `preference.manage_self` | Ya | Ya |

### 5.2 Aturan data scope

- Admin dapat membaca dan mengoperasikan seluruh gudang pada organisasi.
- Warehouse Staff hanya dapat membaca saldo, gudang, transaksi, movement, dan informasi operasional dari gudang yang ditugaskan.
- Warehouse Staff tidak boleh membuat transaksi pada gudang di luar assignment.
- Gudang nonaktif tetap dapat muncul dalam riwayat dan saldo historis jika termasuk assignment user, tetapi tidak dapat dipakai untuk transaksi baru.
- Metadata katalog produk, termasuk nama, SKU, kategori, satuan, minimum stock, dan status, dapat dibaca seluruh user terautentikasi dalam organisasi.
- Data saldo dan movement tetap dibatasi oleh scope gudang.
- `GET /dashboard/summary` mempunyai scope campuran: `totalSku` organisasi-wide, sedangkan KPI stok dan valuasi dibatasi oleh scope gudang pengguna.
- Assignment harus diperiksa ulang di backend pada setiap request berbasis gudang. Penyaringan UI bukan otorisasi.

### 5.3 Permission untuk transaksi koreksi

Permission koreksi ditentukan dari arah reversal, bukan dari arah transaksi asal:

| Tipe transaksi asal | Tipe koreksi | Permission yang wajib |
|---|---|---|
| `IN` | `OUT` | `stock_out.create` |
| `OUT` | `IN` | `stock_in.create` |

User juga harus mempunyai akses ke gudang asal.

## 6. Endpoint catalog

Semua path di tabel berikut relatif terhadap `/api/v1`.

### 6.1 Authentication

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| POST | `/auth/login` | Public | Membuat session |
| POST | `/auth/logout` | Authenticated | Mencabut session aktif |
| GET | `/auth/me` | Authenticated | Profil user dan permission |
| POST | `/auth/change-password` | Authenticated | Mengubah password |

### 6.2 Users dan warehouse assignment

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/users` | `user.manage` | Daftar user |
| POST | `/users` | `user.manage` | Membuat user |
| GET | `/users/{id}` | `user.manage` | Detail user |
| PATCH | `/users/{id}` | `user.manage` | Mengubah data atau role |
| POST | `/users/{id}/deactivate` | `user.manage` | Menonaktifkan user dan mencabut session |
| POST | `/users/{id}/reset-password` | `user.manage` | Reset password, Should Have pada FSD |
| GET | `/users/{id}/warehouses` | `user.warehouse_assignment.manage` | Membaca assignment |
| PUT | `/users/{id}/warehouses` | `user.warehouse_assignment.manage` | Mengganti seluruh assignment secara atomik |

Payload assignment:

```json
{
  "warehouseIds": [
    "3f0b8e20-05aa-4c3c-a3a0-6bf2b7d4c1aa",
    "785bd2f8-92a2-4c2b-94cb-2e12b2d6e8e3"
  ]
}
```

Ketentuan assignment:

1. Target harus user ber-role `WAREHOUSE_STAFF`.
2. `warehouseIds` berisi UUID unik dan minimal satu gudang aktif.
3. Semua gudang harus berasal dari organisasi yang sama.
4. Seluruh penggantian assignment dilakukan atomik.
5. Assignment lama tidak dihapus saat gudang dinonaktifkan.
6. Perubahan role dari Admin menjadi Warehouse Staff dan pembuatan assignment aktif minimal satu gudang harus terjadi dalam satu operasi database.

### 6.3 Organization

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/organization` | Authenticated | Membaca profil organisasi |
| PATCH | `/organization` | `organization.manage` | Mengubah profil organisasi |

Field profil: `name`, `code`, `address`, `phone`, `email`, `timezone`, `currency`. Default timezone instalasi adalah `Asia/Makassar`; default currency MVP `IDR`.

### 6.4 Categories

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/categories` | `category.read` | Daftar kategori |
| POST | `/categories` | `category.manage` | Membuat kategori |
| GET | `/categories/{id}` | `category.read` | Detail kategori |
| PATCH | `/categories/{id}` | `category.manage` | Mengubah kategori |
| POST | `/categories/{id}/deactivate` | `category.manage` | Menonaktifkan kategori |

Field create: `name` wajib 2 sampai 100 karakter, `description` opsional maksimal 500 karakter, `isActive` default `true`.

### 6.5 Products

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/products` | `product.read` | Daftar produk |
| POST | `/products` | `product.create` | Membuat produk |
| GET | `/products/{id}` | `product.read` | Detail metadata produk |
| PATCH | `/products/{id}` | `product.update` | Mengubah produk |
| POST | `/products/{id}/deactivate` | `product.deactivate` | Menonaktifkan produk |
| GET | `/products/{productId}/movements` | `movement.read` | Riwayat movement produk |

Field create:

| Field | Tipe | Ketentuan |
|---|---|---|
| `name` | string | Wajib, 2 sampai 160 karakter |
| `sku` | string | Wajib, 1 sampai 64 karakter, dinormalisasi trim + uppercase |
| `categoryId` | UUID | Wajib, kategori harus aktif |
| `unit` | string | Wajib, 1 sampai 24 karakter, satu satuan dasar |
| `minimumStock` | decimal string | Default `0.000`, tidak negatif, maksimum 3 angka desimal |
| `costPrice` | decimal string atau null | Opsional, per satu satuan dasar, tidak negatif, maksimum 2 angka desimal |
| `description` | string | Opsional, maksimal 1.000 karakter |
| `isActive` | boolean | Default `true` |

Produk yang memiliki saldo nonzero tidak dapat dinonaktifkan. SKU harus unik secara case-insensitive dalam organisasi. Perubahan master tidak mengubah snapshot item transaksi historis.

Catatan komposisi halaman detail: FSD mensyaratkan tampilan saldo agregat, saldo per gudang, status stok, dan riwayat. Data tersebut diambil dari `GET /products/{id}`, `GET /inventory/products/{productId}/balances`, serta `GET /products/{productId}/movements`. Backend harus menerapkan data scope pada dua endpoint yang mengandung data saldo atau movement.

### 6.6 Warehouses

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/warehouses` | `warehouse.read` | Daftar gudang dalam scope pengguna |
| POST | `/warehouses` | `warehouse.manage` | Membuat gudang |
| GET | `/warehouses/{id}` | `warehouse.read` | Detail gudang dalam scope pengguna |
| PATCH | `/warehouses/{id}` | `warehouse.manage` | Mengubah gudang |
| POST | `/warehouses/{id}/deactivate` | `warehouse.manage` | Menonaktifkan gudang |

Field create: `name` wajib 2 sampai 160 karakter, `code` wajib 1 sampai 32 karakter, `location` opsional maksimal 255 karakter, `description` opsional maksimal 500 karakter, `isActive` default `true`.

Gudang dengan saldo nonzero tidak dapat dinonaktifkan. Deaktivasi juga ditolak jika akan membuat Warehouse Staff aktif kehilangan seluruh assignment gudang aktif.

### 6.7 Inventory balances

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/inventory/balances` | `inventory.read` | Daftar saldo dalam scope pengguna |
| GET | `/inventory/products/{productId}/balances` | `inventory.read` | Saldo satu produk untuk gudang yang dapat diakses |
| GET | `/inventory/warehouses/{warehouseId}/balances` | `inventory.read` | Saldo produk pada gudang tertentu |

Tidak tersedia endpoint untuk mengubah saldo langsung. Saldo hanya berubah melalui Stock In, Stock Out, atau koreksi yang sukses.

### 6.8 Stock transactions dan correction

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| POST | `/stock-transactions` | `stock_in.create` atau `stock_out.create` sesuai `type` | Membuat transaksi stok |
| GET | `/stock-transactions` | `movement.read` | Daftar transaksi/movement dalam scope pengguna |
| GET | `/stock-transactions/{id}` | `movement.read` | Detail transaksi |
| POST | `/stock-transactions/{id}/correction` | Permission berdasarkan arah reversal | Membuat full reversal satu kali |

Request Stock In:

```json
{
  "type": "IN",
  "warehouseId": "3f0b8e20-05aa-4c3c-a3a0-6bf2b7d4c1aa",
  "note": "Penerimaan barang",
  "externalReference": "REF-PO-001",
  "items": [
    {
      "productId": "785bd2f8-92a2-4c2b-94cb-2e12b2d6e8e3",
      "quantity": "10.000"
    }
  ]
}
```

Stock Out menggunakan struktur yang sama dengan `type: "OUT"`.

Aturan payload transaksi:

- `type` harus `IN` atau `OUT`.
- `warehouseId` wajib dan gudang harus aktif.
- Warehouse Staff hanya dapat memakai gudang aktif yang ditugaskan.
- `items` minimal satu baris.
- `productId` tidak boleh berulang dalam satu transaksi.
- Produk harus aktif.
- `quantity` harus positif dengan maksimum 3 angka desimal.
- `note` opsional maksimal 1.000 karakter.
- `externalReference` opsional maksimal 120 karakter.
- `Idempotency-Key` wajib.
- Header, item, update saldo, movement, sequence, dan idempotency response diproses dalam satu database transaction.
- Transaksi yang berhasil selalu berstatus `POSTED` dan immutable.

Correction request:

```json
{
  "note": "Koreksi transaksi karena pencatatan penerimaan sebelumnya keliru."
}
```

Header `Idempotency-Key` wajib. Client tidak boleh mengirim `type`, `warehouseId`, `productId`, atau `quantity` untuk menentukan isi reversal. Backend mengambil seluruh item dari transaksi asal dan membuat reversal penuh dengan gudang, produk, dan kuantitas yang sama.

Ketentuan correction:

1. Transaksi asal harus berstatus `POSTED`.
2. Transaksi koreksi tidak dapat menjadi sumber koreksi berikutnya.
3. Satu transaksi asal hanya mempunyai satu koreksi penuh.
4. Koreksi untuk transaksi asal `IN` adalah `OUT`; saldo tersedia harus mencukupi untuk semua item.
5. Koreksi untuk transaksi asal `OUT` adalah `IN`.
6. Produk dan gudang asal harus aktif ketika koreksi dilakukan.
7. Alasan koreksi wajib, setelah trim tidak boleh kosong, maksimal 1.000 karakter.
8. Koreksi, update saldo, item, movement, relasi ke transaksi asal, dan idempotency record commit atau rollback bersama.

### 6.9 Dashboard

| Method | Path | Permission | Ringkasan |
|---|---|---|---|
| GET | `/dashboard/summary` | `dashboard.read` | KPI utama dan valuasi |
| GET | `/dashboard/movements` | `dashboard.read` | Jumlah transaksi IN/OUT per hari |
| GET | `/dashboard/recent-movements` | `dashboard.read` | Aktivitas terbaru |
| GET | `/dashboard/stock-alerts` | `dashboard.read` | Low Stock dan Out of Stock |

`GET /dashboard/summary` mengembalikan:

- `warehouseAccess.mode`: `ALL` untuk Admin atau `ASSIGNED` untuk Warehouse Staff.
- `warehouseAccess.activeWarehouseCount`.
- `totalSku`: seluruh produk aktif katalog organisasi, tanpa dibatasi assignment.
- `productsWithStock`, `lowStock`, `outOfStock`: berdasarkan saldo agregat dalam lingkup gudang pengguna.
- `valuation.amount`: estimasi nilai stok yang mempunyai cost price.
- `valuation.pricedStockProductCount`, `stockedProductCount`, `coveragePercent`, `isComplete`.

`GET /dashboard/movements` dan `/dashboard/recent-movements` menerima `from`, `to`, dan `warehouseId` opsional. `from` dan `to` harus dipasangkan. Default adalah 30 hari terakhir berdasarkan timezone organisasi. `warehouseId` pada Warehouse Staff harus termasuk assignment.

Grafik berisi `date`, `stockInTransactionCount`, dan `stockOutTransactionCount`. Angka tersebut menghitung header transaksi, bukan menjumlahkan kuantitas lintas satuan. Filter periode dan gudang tidak mengubah KPI utama serta stock alerts.

## 7. Query, filter, sorting, dan pagination

### 7.1 Pagination

| Parameter | Default | Batas |
|---|---:|---:|
| `page` | 1 | Minimal 1 |
| `pageSize` | 20 | 1 sampai 100 |
| `search` | kosong | Maksimal 120 karakter |

Daftar yang menggunakan pagination mengembalikan `meta.page`, `meta.pageSize`, `meta.totalItems`, dan `meta.totalPages`.

### 7.2 Filter yang ditetapkan pada FSD

| Endpoint | Filter |
|---|---|
| `GET /products` | `search`, `categoryId`, `status`, `sortBy`, `sortOrder` |
| `GET /stock-transactions` | `type`, `warehouseId`, `productId`, `from`, `to`, `search`, pagination |
| `GET /products/{productId}/movements` | Periode, tipe, gudang, search, pagination |
| `GET /dashboard/movements` | `from`, `to`, `warehouseId` |
| `GET /dashboard/recent-movements` | `from`, `to`, `warehouseId`, pagination |

Filter lain hanya boleh ditambahkan setelah disetujui dan dicatat pada revisi kontrak.

### 7.3 Sorting

Backend wajib memakai allowlist kolom per endpoint. Input `sortBy` tidak boleh diteruskan ke query SQL secara langsung. FSD menetapkan pola `sortBy` dan `sortOrder`, tetapi belum menetapkan daftar nilai `sortBy` final per modul. Daftar final menjadi keputusan implementasi yang harus disepakati sebelum UI dan API dikunci.

### 7.4 Validasi tanggal

- `from` dan `to` wajib dikirim berpasangan.
- Format `YYYY-MM-DD`.
- `to` tidak boleh lebih awal dari `from`.
- Interpretasi batas hari menggunakan timezone organisasi.
- Timestamp yang disimpan pada database tetap UTC.

## 8. Decimal, quantity, dan money

| Jenis | Format kontrak | Presisi |
|---|---|---|
| Quantity | String decimal, contoh `"10.000"` | `DECIMAL(18,3)` |
| Minimum stock | String decimal | `DECIMAL(18,3)` |
| Cost price | String decimal, contoh `"12500.00"` | `DECIMAL(18,2)` |
| Valuation amount | String decimal | `DECIMAL(18,2)` |

Ketentuan:

1. Quantity tidak boleh dikirim sebagai floating point JSON.
2. Maksimum 3 angka desimal untuk quantity dan minimum stock.
3. Nilai lebih dari 3 angka desimal ditolak, tidak boleh dibulatkan diam-diam.
4. Cost price maksimum 2 angka desimal dan tidak boleh negatif.
5. Nilai uang dan kuantitas tidak boleh memakai format pemisah ribuan pada payload API.
6. Perhitungan saldo menggunakan decimal arithmetic pada backend.

## 9. HTTP status code

| HTTP | Penggunaan |
|---:|---|
| 200 | Request sukses |
| 201 | Resource atau transaksi berhasil dibuat |
| 204 | Sukses tanpa response body, misalnya logout |
| 400 | Payload/query tidak valid secara sintaks atau schema |
| 401 | Session tidak ada atau tidak valid |
| 403 | Permission, warehouse scope, atau CSRF ditolak |
| 404 | Resource tidak ditemukan |
| 409 | Konflik data, idempotency conflict, atau koreksi sudah dibuat |
| 422 | Business rule tidak terpenuhi |
| 429 | Rate limit terlampaui |
| 500 | Internal server error |
| 503 | Dependency atau service tidak tersedia sementara |

## 10. Domain error code

| Error code | HTTP | Kondisi |
|---|---:|---|
| `VALIDATION_ERROR` | 400 | Input tidak sesuai schema |
| `UNAUTHENTICATED` | 401 | Session tidak valid |
| `PERMISSION_DENIED` | 403 | Tidak mempunyai permission |
| `RESOURCE_NOT_FOUND` | 404 | Record tidak ditemukan |
| `DUPLICATE_EMAIL` | 409 | Email sudah digunakan |
| `DUPLICATE_SKU` | 409 | SKU sudah digunakan |
| `DUPLICATE_CATEGORY_NAME` | 409 | Nama kategori sudah digunakan |
| `DUPLICATE_WAREHOUSE_CODE` | 409 | Kode gudang sudah digunakan |
| `INSUFFICIENT_STOCK` | 422 | Saldo Stock Out tidak cukup |
| `INACTIVE_PRODUCT` | 422 | Produk nonaktif |
| `INACTIVE_WAREHOUSE` | 422 | Gudang nonaktif |
| `PRODUCT_HAS_STOCK` | 422 | Produk masih memiliki saldo ketika akan dinonaktifkan |
| `WAREHOUSE_HAS_STOCK` | 422 | Gudang masih memiliki saldo ketika akan dinonaktifkan |
| `WAREHOUSE_HAS_LAST_ACTIVE_STAFF_ASSIGNMENT` | 422 | Deaktivasi gudang menghilangkan gudang aktif terakhir yang ditugaskan pada Warehouse Staff aktif |
| `LAST_ACTIVE_ADMIN` | 422 | Operasi meniadakan Admin aktif terakhir |
| `WAREHOUSE_ACCESS_DENIED` | 403 | Warehouse Staff mengakses gudang di luar assignment |
| `WAREHOUSE_ASSIGNMENT_REQUIRED` | 422 | Warehouse Staff aktif tidak mempunyai assignment aktif yang dipersyaratkan |
| `INVALID_CORRECTION_SOURCE` | 422 | Transaksi asal tidak dapat dikoreksi atau bukan transaksi sumber |
| `CORRECTION_ALREADY_EXISTS` | 409 | Transaksi asal sudah memiliki koreksi penuh |
| `CORRECTION_STOCK_UNAVAILABLE` | 422 | Saldo tidak cukup untuk membalik transaksi Stock In asal |
| `IDEMPOTENCY_KEY_REUSED` | 409 | Key digunakan dengan payload berbeda |
| `IDEMPOTENCY_REQUEST_IN_PROGRESS` | 409 | Request dengan key yang sama masih diproses |
| `CSRF_VALIDATION_FAILED` | 403 | CSRF token atau Origin tidak valid |
| `RATE_LIMIT_EXCEEDED` | 429 | Rate limit terlampaui |
| `INTERNAL_ERROR` | 500 | Kesalahan internal |

Backend boleh memetakan variasi kasus ke error code yang sama hanya jika makna yang diterima frontend tetap konsisten. Jangan mengembalikan pesan SQL atau exception mentah.

## 11. Idempotency dan transaksi stok

### 11.1 Header

Semua request `POST /stock-transactions` dan `POST /stock-transactions/{id}/correction` wajib membawa:

```text
Idempotency-Key: <unique-key-up-to-128-characters>
```

### 11.2 Perilaku key

| Kondisi | Perilaku |
|---|---|
| Key baru + payload valid | Request diproses |
| Key sama + payload sama + request sukses | Response sebelumnya dikembalikan |
| Key sama + payload berbeda | `409 IDEMPOTENCY_KEY_REUSED` |
| Request dengan key sama masih diproses | Menunggu atau `409 IDEMPOTENCY_REQUEST_IN_PROGRESS` sesuai implementasi backend |
| Request pertama rollback | Retry dapat diproses kembali |
| Client timeout setelah commit | Retry dengan key yang sama mengembalikan transaksi pertama |

Frontend membuat satu key ketika user memulai konfirmasi transaksi. Key yang sama digunakan pada retry request yang sama. Key baru dibuat saat user memulai transaksi baru atau mengubah payload transaksi.

### 11.3 Atomicity

Stock In, Stock Out, dan full reversal harus mengubah header transaksi, item, saldo, movement, sequence nomor referensi, dan idempotency response dalam satu database transaction InnoDB. Jika satu langkah gagal, semua perubahan bisnis harus rollback.

### 11.4 Locking

- Lock row saldo di dalam database transaction.
- Jika lebih dari satu produk, lock berdasarkan urutan product ID yang konsisten.
- Stock Out memeriksa saldo pada row yang telah dikunci.
- Jika salah satu item tidak cukup, seluruh transaksi gagal.
- Backend dapat melakukan retry terbatas untuk deadlock yang teridentifikasi, dengan Idempotency-Key yang sama.

## 12. Mapping API ke database

| Data API | Tabel sumber utama |
|---|---|
| Organization | `organizations` |
| User, role, status, preference | `users`, `roles` |
| Session | `sessions` |
| Category | `categories` |
| Product | `products`, `categories` |
| Warehouse | `warehouses` |
| Warehouse assignment | `user_warehouse_assignments` |
| Inventory balance | `inventory_balances`, `products`, `warehouses` |
| Stock transaction header | `stock_transactions` |
| Transaction item | `stock_transaction_items` |
| Movement | `stock_movements` |
| Transaction number | `stock_transaction_sequences` |
| Idempotency | `idempotency_records` |

Penting: `stock_movements` bersifat append-only pada alur aplikasi normal. Tidak ada endpoint edit atau delete untuk movement dan transaksi yang sudah `POSTED`.

## 13. Checklist implementasi backend

### 13.1 Foundation

- [ ] Express router diprefix `/api/v1`.
- [ ] Request validation menggunakan schema validator terpusat.
- [ ] Response serializer mengikuti envelope `data` dan `meta`.
- [ ] Error handler terpusat memetakan domain error ke HTTP status.
- [ ] Request ID dibuat atau diteruskan ke structured logging.
- [ ] CORS hanya mengizinkan origin frontend yang dikonfigurasi.
- [ ] Session cookie, CSRF validation, Origin validation, dan rate limit tersedia.
- [ ] Tidak ada public registration atau bootstrap endpoint publik.

### 13.2 Authorization

- [ ] Setiap endpoint privat memvalidasi session.
- [ ] Permission diperiksa pada backend.
- [ ] Scope gudang Admin dan Warehouse Staff diterapkan pada setiap query operasional.
- [ ] Produk dan kategori dapat dibaca sebagai metadata katalog organisasi.
- [ ] Semua request yang menyebut warehouse ID diverifikasi terhadap organisasi dan assignment.
- [ ] Assignment serta perubahan role diproses atomik.
- [ ] Gudang nonaktif masih dapat dibaca untuk histori jika assignment masih ada, tetapi tidak dapat dipakai transaksi baru.

### 13.3 Inventory transaction

- [ ] `Idempotency-Key` diwajibkan untuk transaksi dan koreksi.
- [ ] Duplicate product ID dalam satu payload ditolak.
- [ ] Kuantitas diproses sebagai decimal.
- [ ] Semua saldo terkait di-lock dengan urutan deterministik.
- [ ] Stock Out tidak dapat membuat saldo negatif.
- [ ] Header, item, balance, movement, sequence, dan idempotency response commit bersama.
- [ ] Nomor referensi mengikuti timezone organisasi dan sequence yang aman terhadap concurrency.
- [ ] Transaksi posted immutable.
- [ ] Full reversal hanya sekali dan harus membalik seluruh item.

### 13.4 Testing contract

- [ ] Contract test untuk seluruh operationId pada OpenAPI.
- [ ] Response success dan error sesuai envelope.
- [ ] Semua endpoint list menerapkan pagination maksimum 100.
- [ ] Request invalid tidak diteruskan ke Prisma/database.
- [ ] User tanpa permission mendapat 403.
- [ ] Warehouse Staff mengakses gudang di luar assignment mendapat 403 `WAREHOUSE_ACCESS_DENIED`.
- [ ] Retry transaksi menggunakan idempotency key yang sama tidak menggandakan saldo.
- [ ] Dua Stock Out bersamaan tidak membuat saldo negatif.
- [ ] Koreksi ganda ditolak oleh service dan unique constraint.
- [ ] Semua request mutation yang memakai session memvalidasi CSRF.

## 14. Checklist frontend integration

- [ ] Semua request API memakai base path `/api/v1`.
- [ ] Browser mengirim cookie session dengan credential mode yang benar sesuai konfigurasi origin.
- [ ] Frontend membaca cookie CSRF yang tidak HttpOnly dan mengirim nilainya melalui `X-CSRF-Token`.
- [ ] Frontend tidak menyimpan session token pada localStorage atau sessionStorage.
- [ ] Frontend menangani 401 dengan alur login/expired session.
- [ ] Frontend menangani 403 dengan state permission atau akses gudang ditolak.
- [ ] Form quantity dan cost price menggunakan string decimal.
- [ ] Frontend mempertahankan Idempotency-Key ketika melakukan retry request yang sama.
- [ ] Setelah assignment berubah, frontend memuat ulang data operasional.
- [ ] UI tidak mengasumsikan bahwa menyembunyikan tombol berarti backend sudah aman.

## 15. Acceptance criteria Tahap 5

Tahap 5 dinyatakan selesai secara dokumentasi jika:

1. Semua route REST pada FSD direpresentasikan dalam OpenAPI.
2. Request dan response utama memiliki schema.
3. Authentication cookie dan CSRF dijelaskan.
4. Hak akses role dan data scope dijelaskan untuk setiap modul.
5. Decimal contract menggunakan string.
6. Pagination, filter, date range, dan sorting dijelaskan.
7. Error response dan domain error code tercantum.
8. Idempotency dan atomicity transaksi dijelaskan.
9. OpenAPI berhasil diparse sebagai YAML dan seluruh internal `$ref` valid.
10. Kontrak sudah siap dipakai sebagai dasar implementasi backend dan Postman/contract testing.

## 16. Keputusan yang perlu dikunci sebelum implementasi

FSD menyediakan alur dan aturan bisnis utama, tetapi beberapa detail transport API belum ditentukan. Item berikut harus disepakati sebagai keputusan implementasi sebelum frontend dan backend menganggap kontrak final.

| ID | Topik | Kondisi dari dokumen sumber | Rekomendasi untuk dikunci |
|---|---|---|---|
| API-DEC-001 | Password awal user | Admin mengisi password awal atau mekanisme password sementara; field API menyebut password sesuai mekanisme | Gunakan `password` pada `POST /users`; jangan kirim password lewat URL, query, atau log. Tandai `mustChangePassword=true` jika password bersifat sementara. |
| API-DEC-002 | Reset password | Endpoint `POST /users/{id}/reset-password` berstatus Should Have pada FSD; backend dapat membuat atau menerima password sementara | Jadikan endpoint opsional fase MVP akhir atau 1.1. Bila diaktifkan, generate password sementara di backend dan tampilkan sekali saja. |
| API-DEC-003 | Sort allowlist | FSD menetapkan `sortBy`, `sortOrder`, dan allowlist backend, tetapi tidak menetapkan nilai setiap modul | Tetapkan enum sort per endpoint dan uji agar field tidak menjadi raw SQL input. |
| API-DEC-004 | Response deactivate | FSD menetapkan aksi deactivate dan error bisnis, belum menetapkan response body secara eksplisit | Gunakan HTTP 200 dengan resource ringkas yang sudah berstatus nonaktif. |
| API-DEC-005 | Representasi list movement | FSD mencampur konteks daftar transaksi dan kolom per movement item | Kontrak saat ini memakai `MovementRow` untuk list activity dan `StockTransaction` untuk detail transaksi. Validasi dengan desain tabel UI sebelum frontend codegen. |
| API-DEC-006 | Empty list inventory | Database boleh tidak memiliki row balance sebelum Stock In pertama | Endpoint saldo perlu mengembalikan kombinasi produk/gudang yang relevan dengan saldo `0.000` atau frontend memperlakukan row yang tidak ada sebagai nol. Pilih satu semantik konsisten. |
| API-DEC-007 | CORS credentials | Origin frontend dan domain deployment final belum ditentukan | Konfigurasi allowlist origin eksplisit dan credentials enabled; jangan gunakan wildcard origin dengan credential cookies. |

Semua rekomendasi di atas merupakan keputusan implementasi yang diusulkan untuk melengkapi kontrak, bukan kutipan aturan eksplisit dari PRD/FSD.

## 17. Traceability dan file terkait

| Kebutuhan | Sumber |
|---|---|
| API conventions dan response envelope | FSD 11.1 sampai 11.3 |
| Auth, session, CSRF | FSD 6.2 dan 13 |
| User dan warehouse assignment | FSD 6.4 dan 6.4.1 |
| Organization | FSD 6.5 |
| Category | FSD 6.6 |
| Product | FSD 6.7 |
| Warehouse | FSD 6.8 |
| Inventory | FSD 6.9 |
| Stock In / Stock Out | FSD 6.10 dan 6.11 |
| Movement history dan correction | FSD 6.12 dan 6.13 |
| Dashboard | FSD 6.14 dan 11.12 |
| Pagination dan validasi | FSD 6.15 dan 8 |
| Transaction atomicity, locking, idempotency | FSD 10 dan ERD Database Specification 10 |
| Database mapping | ERD Database Specification 6 sampai 10 |

Dokumen terkait:

- `PRD_StockFlow_v1.0.1.md`
- `FSD_StockFlow_v1.0.1.md`
- `ERD_Database_Specification_StockFlow_v1.0.md`
- `StockFlow_MySQL_Schema_v1.0.sql`
- `StockFlow_OpenAPI_v1.0.yaml`

---

**Akhir dokumen API Contract StockFlow v1.0.0.**
