import dotenv from 'dotenv';
dotenv.config();

// Fail-fast environment validation
import { env } from './config/env';

import { app } from './app';
import { prisma } from './database/client';
import { logger } from './utils/logger';

const PORT = env.PORT;

const server = app.listen(PORT, () => {
  logger.info(`StockFlow Backend REST API berjalan pada port ${PORT} [${env.NODE_ENV}]`);
});

async function gracefulShutdown(signal: string) {
  logger.info(`Sinyal ${signal} diterima. Menghentikan server secara aman...`);

  server.close(async () => {
    logger.info('HTTP server listener telah dihentikan.');
    try {
      await prisma.$disconnect();
      logger.info('Koneksi Prisma / MySQL berhasil diputus.');
      process.exit(0);
    } catch (err) {
      logger.error('Error saat memutuskan koneksi database:', { err });
      process.exit(1);
    }
  });

  setTimeout(() => {
    logger.error('Force shutdown setelah timeout 10 detik.');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
