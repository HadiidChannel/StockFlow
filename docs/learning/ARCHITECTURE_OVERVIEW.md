# StockFlow System Architecture Overview

## 1. Arsitektur Komponen Tingkat Tinggi

StockFlow dibangun dengan pola 3-Tier Web Architecture yang memisahkan Presentation Layer, Application Business Logic Layer, dan Data Persistence Layer.

```text
+-------------------------------------------------------------------+
|                        CLIENT BROWSER                             |
|  - Desktop / Tablet / Smartphone Responsive View                  |
|  - HTML5, CSS3 (Tailwind), React 19 Client Components             |
|  - Motion Animations, Recharts Visualizations                     |
+----------------------------------+--------------------------------+
                                   |
                       HTTP / JSON | (Port 3000 / 4000)
                                   v
+----------------------------------+--------------------------------+
|                   FRONTEND TIER (Next.js 15)                      |
|  - Server-Side Rendering (SSR) & Layout Rendering                 |
|  - Client State Management & Interactive Form Handling            |
|  - Theme Management (Light, Dark, System)                         |
|  - Static Asset Delivery                                          |
+----------------------------------+--------------------------------+
                                   |
                       REST API v1 | Cookie: sf_session, sf_csrf
                                   v
+----------------------------------+--------------------------------+
|                    BACKEND TIER (Express.js)                      |
|  - Authentication & Session Verification (bcrypt cost 12, SHA-256) |
|  - Role-Based Access Control (Admin vs Warehouse Staff)           |
|  - Warehouse Scoping & Multi-Warehouse Access Control             |
|  - Zod Request Input Sanitization & Validation                    |
|  - Business Services (Stock In, Stock Out, Reversal)              |
|  - Concurrency Lock Manager (Row-level Locking)                   |
|  - Sequence Number Generator (Transactional)                      |
+----------------------------------+--------------------------------+
                                   |
                        Prisma ORM | MySQL Protocol (Port 3306)
                                   v
+----------------------------------+--------------------------------+
|                  DATABASE TIER (MySQL 8.4 LTS)                    |
|  - Storage Engine: InnoDB (ACID Compliant)                        |
|  - Collation: utf8mb4_0900_as_ci, UUID ascii_bin                  |
|  - Check Constraints (quantity >= 0, balance >= 0)                |
|  - Master Data: Organizations, Users, Roles, Warehouses, Products |
|  - Ledger & Transaction: Balances, Transactions, Movements        |
+-------------------------------------------------------------------+
```

## 2. Alur Mutasi Inventaris (Stock In & Stock Out)

```text
[ Staff / Admin ]
        │
        ├── 1. Submit Transaksi (Gudang, Item, Kuantitas)
        ▼
[ Backend Express Router & Middleware ]
        │
        ├── 2. Verifikasi Session Cookie & CSRF Token
        ├── 3. Verifikasi Role & Scope Penugasan Gudang
        ├── 4. Validasi Skema Input (Zod: kuantitas > 0, 3 desimal)
        ▼
[ Inventory Transaction Service ]
        │
        ├── 5. Buka Database Transaction (BEGIN TRANSACTION)
        ├── 6. Kunci Baris Saldo: SELECT ... FOR UPDATE pada inventory_balances
        ├── 7. Jika Stock Out: Validasi balance_before >= kuantitas_diminta
        │      └─ Jika kurang: ROLLBACK & kembalikan 422 INSUFFICIENT_STOCK
        ├── 8. Dapatkan Nomor Transaksi Baru (IN-YYYYMMDD-X / OUT-YYYYMMDD-X)
        ├── 9. Hitung balance_after dan Perbarui inventory_balances
        ├── 10. Insert Header stock_transactions
        ├── 11. Insert Detail stock_transaction_items
        ├── 12. Insert Ledger stock_movements
        ├── 13. Catat Idempotency Record (jika key disediakan)
        ├── 14. Simpan Transaksi (COMMIT TRANSACTION)
        ▼
[ Response JSON ]
        │
        └── 15. Kembalikan Status 201 Created dengan Data Referensi
```
