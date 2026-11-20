# Modul Pembelajaran 04: Express.js Backend Architecture & Middleware Pipeline

## 1. Konsep yang Digunakan
- RESTful API Architecture.
- Middleware Chain (Global, Router-level, Error-handling).
- Request Validation dan Response Normalization.
- Separation of Concerns: Router -> Controller -> Service -> Repository/ORM.

## 2. Mengapa Konsep Ini Diperlukan
Tanpa struktur yang terorganisir, logika bisnis perputaran stok, kalkulasi saldo, dan otorisasi akan tercampur di dalam route handler. Memisahkan controller (penanganan HTTP) dan service (logika bisnis murni) membuat kode mudah diuji (unit testing) dan mudah dirawat.

## 3. Cara Kerja
Express.js memproses request melalui pipeline middleware berurutan:
`Request -> Helmet -> CORS -> Cookie Parser -> Body Parser -> Auth Middleware -> RBAC Middleware -> Controller -> Service -> Response`
Jika terjadi error di titik manapun, error diteruskan ke middleware penanganan error global via `next(err)`.

## 4. Contoh Kode dalam Konteks StockFlow
```typescript
// backend/src/middleware/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/app-error';
import { logger } from '../utils/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
) {
  const requestId = (req.headers['x-request-id'] as string) || 'unknown-req';

  if (err instanceof AppError) {
    logger.warn(`AppError [${err.code}]: ${err.message}`, { requestId });
    return res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        requestId,
      },
    });
  }

  // Error tidak terduga (500) disanitasi agar tidak membocorkan detail internal
  logger.error(`Unhandled Error: ${err.message}`, { stack: err.stack, requestId });
  return res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Terjadi kesalahan internal pada server.',
      requestId,
    },
  });
}
```

## 5. Penjelasan Bagian Penting Kode
1. Signature 4 Argumen: Express mengenali middleware error handler hanya jika fungsi menerima tepat 4 parameter `(err, req, res, next)`.
2. Sanitasi Response: Stack trace dan query SQL dicatat ke logger internal, namun tidak dikirim ke client browser demi keamanan.

## 6. Kesalahan Umum yang Perlu Dihindari
- Lupa memanggil `next()` di dalam custom middleware, menyebabkan request menggantung tanpa batas waktu.
- Mengirim response lebih dari satu kali (`Cannot set headers after they are sent to the client`). Selalu sertakan `return res.status(...).json(...)`.
