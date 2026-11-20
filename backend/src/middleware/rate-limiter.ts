import rateLimit from 'express-rate-limit';

export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Terlalu banyak percobaan login. Silakan coba kembali dalam 15 menit.',
    },
  },
});

export const passwordChangeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Terlalu banyak percobaan penggantian password. Silakan coba kembali dalam 15 menit.',
    },
  },
});

export const inventoryTransactionLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 120, // 120 stock transactions per minute
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Terlalu banyak transaksi inventaris dalam waktu singkat. Silakan tunggu sesaat.',
    },
  },
});

export const userManagementLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // 30 user management requests per minute
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => process.env.NODE_ENV === 'test',
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Terlalu banyak request manajemen pengguna. Silakan tunggu sesaat.',
    },
  },
});

export const globalApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // 1000 requests per 15 minutes
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === '/api/v1/health' || process.env.NODE_ENV === 'test',
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Batas permintaan API terlampaui. Silakan tunggu beberapa saat.',
    },
  },
});
