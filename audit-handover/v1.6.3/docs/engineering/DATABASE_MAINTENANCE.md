# StockFlow Database Maintenance & Operations

## 1. Konvensi Database
- Engine: MySQL 8.4 LTS (InnoDB).
- Charset & Collation: `utf8mb4` dengan `utf8mb4_0900_as_ci`.
- UUID: `CHAR(36)` dengan collation `ascii_bin` untuk performa indexing yang optimal.
- Waktu: Seluruh timestamp transaksi dan log disimpan dalam format UTC (`DATETIME(3)`).
- Kuantitas: `DECIMAL(18,3)` untuk mendukung kuantitas desimal tanpa floating point rounding error.
- Nilai Uang: `DECIMAL(18,2)`.

## 2. Prosedur Backup Database
Backup dilakukan secara rutin menggunakan `mysqldump` dengan opsi transaksi yang konsisten:

```bash
# Backup database lengkap
docker compose exec db mysqldump -u stockflow_user -p \
  --single-transaction \
  --quick \
  --default-character-set=utf8mb4 \
  stockflow_db > backup_stockflow_$(date +%Y%m%d_%H%M%S).sql
```

## 3. Prosedur Restore Database
```bash
# Restore file backup ke database
docker compose exec -T db mysql -u stockflow_user -p stockflow_db < backup_file.sql
```

## 4. Manajemen Migrasi Prisma
1. Menambah atau mengubah model:
   - Modifikasi `backend/prisma/schema.prisma`.
   - Jalankan `npx prisma migrate dev --name deskripsi_perubahan` di development.
   - Periksa file migrasi SQL yang dihasilkan di `backend/prisma/migrations/`.
2. Menerapkan migrasi di production:
   - Jalankan `npx prisma migrate deploy`. Jangan pernah gunakan `migrate dev` di production.

## 5. Pemeliharaan Indeks dan Performa
- Indeks komposit penting:
  - `inventory_balances(product_id, warehouse_id)`: Pencarian saldo cepat dan locking.
  - `stock_transactions(posted_at)` dan `(warehouse_id, posted_at)`: Pemfilteran histori dan rentang tanggal dashboard.
  - `stock_movements(product_id, created_at)` dan `(warehouse_id, created_at)`: Ledger pergerakan barang.
- Analisis query lambat:
  - Aktifkan MySQL Slow Query Log jika waktu respon agregasi melebihi 200ms.
