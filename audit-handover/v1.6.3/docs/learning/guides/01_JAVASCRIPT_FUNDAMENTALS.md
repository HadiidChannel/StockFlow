# Modul Pembelajaran 01: JavaScript Fundamentals untuk Skala Enterprise

## 1. Konsep yang Digunakan
JavaScript modern (ES2022+) dengan fokus pada:
- Asynchronous programming (Promises, async/await).
- Immutability dan functional operators (`map`, `filter`, `reduce`).
- Scope, Closures, dan Execution Context.
- Error handling dengan Custom Error objects.

## 2. Mengapa Konsep Ini Diperlukan
Pada aplikasi seperti StockFlow, ribuan transaksi stok diproses secara non-blocking. Pemahaman mendalam mengenai bagaimana Promise dan event loop menangani operasi I/O database mencegah terjadinya callback hell, unhandled promise rejections, dan race conditions pada level proses aplikasi.

## 3. Cara Kerja
JavaScript berjalan di atas single-threaded event loop. Ketika request HTTP masuk atau query database dijalankan via Prisma, operasi I/O didelegasikan ke thread pool libuv di latar belakang. Thread utama JavaScript bebas memproses request lain hingga I/O selesai dan callback/promise resolution dimasukkan ke dalam Microtask Queue.

## 4. Contoh Kode dalam Konteks StockFlow
```javascript
// Penanganan kalkulasi total nilai inventaris secara immutable
export function calculateInventoryValuation(items) {
  return items.reduce((totalValuation, item) => {
    const costPrice = Number(item.product.costPrice ?? 0);
    const quantity = Number(item.quantity);
    return totalValuation + (costPrice * quantity);
  }, 0);
}
```

## 5. Penjelasan Bagian Penting Kode
1. `reduce`: Melakukan akumulasi nilai secara murni tanpa memodifikasi array asal (immutable pattern).
2. `??` (Nullish Coalescing): Memastikan nilai default `0` hanya digunakan jika `costPrice` adalah `null` atau `undefined`, bukan saat bernilai `0`.

## 6. Kesalahan Umum yang Perlu Dihindari
- Mengabaikan `await` pada panggilan fungsi asynchronous, yang menyebabkan eksekusi berlanjut sebelum database commit selesai.
- Menggunakan `forEach` dengan fungsi `async`: `array.forEach(async (item) => ...)` tidak menunggu promise selesai. Gunakan `for...of` atau `Promise.all` dengan `map`.
