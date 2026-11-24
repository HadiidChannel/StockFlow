# Modul Pembelajaran 05: MySQL Relational Database, ACID, & Concurrency

## 1. Konsep yang Digunakan
- MySQL 8.4 LTS dengan Storage Engine InnoDB.
- Karakteristik ACID (Atomicity, Consistency, Isolation, Durability).
- Normalisasi Data hingga Third Normal Form (3NF).
- Row-Level Pessimistic Locking (`SELECT ... FOR UPDATE`).
- Integrity Constraints (Foreign Keys, Unique Indexes, CHECK Constraints).

## 2. Mengapa Konsep Ini Diperlukan
Inventaris adalah domain finansial dan logistik di mana integritas data tidak boleh dikompromikan. Stok tidak boleh bernilai negatif, dan transaksi tidak boleh hilang atau tersimpan sebagian saat server mengalami gangguan daya.

## 3. Cara Kerja
InnoDB mencatat perubahan data ke Write-Ahead Log (WAL / redo log) sebelum menulis ke tablespace disk, menjamin Durability. Ketika transaksi dibuka (`START TRANSACTION`), modifikasi data diisolasi hingga `COMMIT`. Penggunaan `SELECT ... FOR UPDATE` menempatkan exclusive lock pada baris indeks yang dibaca, memaksa transaksi lain yang ingin memodifikasi baris tersebut untuk menunggu.

## 4. Contoh Kode dalam Konteks StockFlow
```sql
-- Transaksi mutasi Stock Out yang aman terhadap race condition
START TRANSACTION;

-- 1. Kunci baris saldo inventaris secara eksklusif
SELECT id, quantity 
FROM inventory_balances 
WHERE product_id = 'prod-uuid-123' AND warehouse_id = 'wh-uuid-456' 
FOR UPDATE;

-- 2. Aplikasi memverifikasi: quantity (10.000) >= request (4.000)
-- 3. Jika cukup, lakukan update
UPDATE inventory_balances 
SET quantity = quantity - 4.000, updated_at = NOW(3)
WHERE product_id = 'prod-uuid-123' AND warehouse_id = 'wh-uuid-456';

-- 4. Catat riwayat pergerakan stok (ledger)
INSERT INTO stock_movements (id, transaction_id, transaction_item_id, product_id, warehouse_id, type, quantity, balance_before, balance_after, created_at)
VALUES (UUID(), 'tx-1', 'item-1', 'prod-uuid-123', 'wh-uuid-456', 'OUT', 4.000, 10.000, 6.000, NOW(3));

COMMIT;
```

## 5. Penjelasan Bagian Penting Kode
1. `FOR UPDATE`: Mengunci baris saldo produk di gudang tersebut sehingga pembacaan konkurensi dari request lain akan mengantre hingga commit.
2. Konsistensi `balance_before` dan `balance_after`: Memberikan riwayat mutasi yang dapat diverifikasi oleh auditor eksternal.

## 6. Kesalahan Umum yang Perlu Dihindari
- Memperbarui saldo tanpa locking: Dua request paralel membaca saldo 5, masing-masing mengurangi 4, sehingga saldo akhir tersimpan 1 padahal seharusnya transaksi kedua ditolak karena total yang diminta adalah 8.
- Mengabaikan CHECK constraint di level database: Mengandalkan validasi aplikasi saja rentan ditembus jika ada eksekusi query langsung atau skrip migrasi.
