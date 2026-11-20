# Modul Pembelajaran 02: TypeScript Engineering & Strict Typing

## 1. Konsep yang Digunakan
- Strict Compiler Configuration (`"strict": true`).
- Discriminated Unions dan Type Guards.
- Utility Types (`Pick`, `Omit`, `Partial`, `Record`).
- Runtime Schema Validation dengan Zod yang di-infer ke TypeScript types.

## 2. Mengapa Konsep Ini Diperlukan
Dalam sistem inventaris, perbedaan kecil antara tipe data (misal `string` vs `number` pada kuantitas stok atau `undefined` vs `null` pada harga pokok) dapat merusak kalkulasi saldo. TypeScript mendeteksi potensi error tipe saat compile-time sebelum kode sempat dijalankan di production.

## 3. Cara Kerja
TypeScript melakukan static analysis pada kode sumber berdasarkan deklarasi tipe. Saat proses build, TypeScript compiler (`tsc`) memeriksa konsistensi tipe dan kemudian menghapus seluruh anotasi tipe untuk menghasilkan JavaScript murni.

## 4. Contoh Kode dalam Konteks StockFlow
```typescript
import { z } from 'zod';

// 1. Definisikan Schema Zod untuk validasi runtime
export const StockInItemSchema = z.object({
  productId: z.string().uuid({ message: 'Product ID harus berupa UUID valid' }),
  quantity: z.string().regex(/^\d+(\.\d{1,3})?$/, {
    message: 'Kuantitas harus berupa angka positif hingga 3 angka desimal',
  }),
});

// 2. Inferensi tipe TypeScript statis secara otomatis
export type StockInItemInput = z.infer<typeof StockInItemSchema>;

// 3. Tipe discriminated union untuk tipe transaksi
export type StockTransactionType = 'IN' | 'OUT';

export interface StockTransactionHeader {
  id: string;
  type: StockTransactionType;
  referenceNumber: string;
  warehouseId: string;
  postedAt: Date;
}
```

## 5. Penjelasan Bagian Penting Kode
1. `z.infer`: Menghilangkan duplikasi penulisan antarmuka TypeScript dan schema runtime. Schema menjadi single source of truth.
2. Discriminated Union: Membatasi tipe mutasi hanya pada string literal `'IN'` atau `'OUT'`.

## 6. Kesalahan Umum yang Perlu Dihindari
- Penggunaan tipe `any`: Menggunakan `any` menonaktifkan seluruh perlindungan compiler. Gunakan `unknown` jika tipe belum diketahui, lalu validasi dengan Type Guard.
- Type assertion yang tidak aman (`as string`): Jangan memaksa compiler mempercayai tipe data tanpa pemeriksaan runtime.
