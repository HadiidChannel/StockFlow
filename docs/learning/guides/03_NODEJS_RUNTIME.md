# Modul Pembelajaran 03: Node.js Runtime & Asynchronous Architecture

## 1. Konsep yang Digunakan
- Node.js Runtime Environment dan V8 Engine.
- Non-blocking I/O dan Libuv Thread Pool.
- Streams dan Buffers.
- Environment Configuration dan Process Lifecycle.

## 2. Mengapa Konsep Ini Diperlukan
Node.js dirancang khusus untuk aplikasi I/O-intensive seperti StockFlow yang menangani banyak transaksi HTTP secara simultan. Memahami siklus proses Node.js memastikan server dapat melakukan graceful shutdown saat terjadi restart container.

## 3. Cara Kerja
Node.js mengeksekusi JavaScript di thread utama (Single Thread). Ketika melakukan query ke MySQL atau membaca file konfigurasi, Node.js menginstruksikan sistem operasi atau thread worker libuv untuk menjalankan tugas tersebut. Saat data siap, event loop mengeksekusi callback pada fase polling/check.

## 4. Contoh Kode dalam Konteks StockFlow
```typescript
// backend/src/server.ts
import { app } from './app';
import { prisma } from './database/client';
import { logger } from './utils/logger';

const PORT = process.env.PORT || 4000;

const server = app.listen(PORT, () => {
  logger.info(`StockFlow Backend berjalan pada port ${PORT}`);
});

// Graceful Shutdown handling
async function handleShutdown(signal: string) {
  logger.info(`Menerima sinyal ${signal}, menutup koneksi server secara aman...`);
  server.close(async () => {
    logger.info('HTTP server ditutup.');
    await prisma.$disconnect();
    logger.info('Koneksi Prisma/MySQL diputus.');
    process.exit(0);
  });
}

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));
```

## 5. Penjelasan Bagian Penting Kode
1. `process.on('SIGTERM')`: Menangkap sinyal terminate dari Docker orchestrator saat container akan dimatikan.
2. `server.close()` & `prisma.$disconnect()`: Memastikan seluruh request yang sedang berjalan diselesaikan dan koneksi database ditutup dengan rapi sebelum proses mati.

## 6. Kesalahan Umum yang Perlu Dihindari
- Melakukan operasi CPU-heavy komputasi berat secara synchronous pada thread utama, yang dapat memblokir penanganan seluruh request pengguna lain.
- Tidak menangani event `unhandledRejection` atau `uncaughtException`, yang menyebabkan proses server crash seketika tanpa logging.
