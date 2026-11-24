# Modul Pembelajaran 06: Prisma ORM & Database Access Layer

## 1. Konsep yang Digunakan
- Schema-First Data Modeling (`schema.prisma`).
- Type-safe Query Generation (`@prisma/client`).
- Relational Navigation and Eager Loading (`include`, `select`).
- Interactive Transactions (`prisma.$transaction(async (tx) => { ... })`).
- Mapping Nama Fisik Tabel dan Kolom (`@@map`, `@map`).

## 2. Mengapa Konsep Ini Diperlukan
Prisma menjembatani kode TypeScript berorientasi objek dengan model tabel relasional MySQL. Dengan Prisma, setiap query database secara otomatis memiliki tipe return yang strictly typed, mencegah runtime typo pada nama kolom atau relasi yang hilang.

## 3. Cara Kerja
Prisma CLI membaca `schema.prisma` dan men-generate engine query Rust yang terintegrasi ke dalam paket TypeScript. Saat kita menjalankan `prisma.product.findMany()`, Prisma Query Engine mengompilasi method call tersebut menjadi query SQL yang dioptimalkan dengan parameter binding.

## 4. Contoh Kode dalam Konteks StockFlow
```typescript
// backend/src/modules/inventory/stock-in.service.ts
import { prisma } from '../../database/client';

export async function processStockIn(data: StockInPayload, userId: string) {
  return await prisma.$transaction(async (tx) => {
    // 1. Dapatkan nomor sequence transaksi secara aman
    const referenceNumber = await getNextSequenceNumber(tx, 'IN');

    // 2. Buat header transaksi
    const transaction = await tx.stockTransaction.create({
      data: {
        organizationId: data.organizationId,
        warehouseId: data.warehouseId,
        type: 'IN',
        referenceNumber,
        status: 'POSTED',
        note: data.note,
        createdBy: userId,
        createdByNameSnapshot: data.userNameSnapshot,
        warehouseNameSnapshot: data.warehouseNameSnapshot,
        warehouseCodeSnapshot: data.warehouseCodeSnapshot,
        postedAt: new Date(),
      },
    });

    // 3. Proses tiap item
    for (const item of data.items) {
      // Upsert saldo inventaris dan catat movement
      const balance = await tx.inventoryBalance.upsert({
        where: {
          productId_warehouseId: {
            productId: item.productId,
            warehouseId: data.warehouseId,
          },
        },
        create: {
          productId: item.productId,
          warehouseId: data.warehouseId,
          quantity: item.quantity,
        },
        update: {
          quantity: { increment: item.quantity },
        },
      });

      // Catat detail transaksi dan movement...
    }

    return transaction;
  });
}
```

## 5. Penjelasan Bagian Penting Kode
1. `prisma.$transaction`: Memastikan bahwa jika salah satu item gagal disimpan, seluruh operasi dibatalkan (rollback otomatis) tanpa meninggalkan data yatim (orphan data).
2. `increment`: Melakukan pembaruan atomik di level SQL (`quantity = quantity + ?`).

## 6. Kesalahan Umum yang Perlu Dihindari
- Memanggil operasi asynchronous di luar callback transaksi interactive (`tx`), yang menyebabkan operasi tersebut tidak tercakup dalam rollback jika terjadi kegagalan.
- Mengambil terlalu banyak data yang tidak diperlukan (N+1 query problem). Gunakan `select` spesifik untuk membatasi kolom yang ditarik dari database.
