import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { AppError } from './utils/app-error';
import { logger } from './utils/logger';

// Module routers
import { authRouter } from './modules/auth/auth.router';
import { organizationRouter } from './modules/organization/organization.router';
import { usersRouter } from './modules/users/users.router';
import { categoriesRouter } from './modules/categories/categories.router';
import { warehousesRouter } from './modules/warehouses/warehouses.router';
import { productsRouter } from './modules/products/products.router';
import { inventoryRouter } from './modules/inventory/inventory.router';
import { movementsRouter } from './modules/movements/movements.router';
import { dashboardRouter } from './modules/dashboard/dashboard.router';
import { preferencesRouter } from './modules/preferences/preferences.router';

export const app = express();

// 1. Basic security headers
app.use(helmet());

// 2. CORS allowlist
const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
app.use(
  cors({
    origin: [frontendUrl, 'http://localhost:3000', 'http://127.0.0.1:3000'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token', 'X-Request-Id', 'Idempotency-Key'],
  })
);

// 3. Body and cookie parsing
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));
app.use(cookieParser());

// 4. Request ID tagging and logger middleware
app.use((req: Request, res: Response, next: NextFunction) => {
  const reqId = (req.headers['x-request-id'] as string) || `req_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  req.headers['x-request-id'] = reqId;
  res.setHeader('X-Request-Id', reqId);
  next();
});

// 5. Healthcheck endpoint
app.get('/api/v1/health', (_req: Request, res: Response) => {
  res.status(200).json({
    data: {
      status: 'UP',
      timestamp: new Date().toISOString(),
      service: 'StockFlow Backend API',
    },
  });
});

// 6. Mount domain route handlers
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/organization', organizationRouter);
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/categories', categoriesRouter);
app.use('/api/v1/warehouses', warehousesRouter);
app.use('/api/v1/products', productsRouter);
app.use('/api/v1/inventory', inventoryRouter);
app.use('/api/v1/movements', movementsRouter);
app.use('/api/v1/dashboard', dashboardRouter);
app.use('/api/v1/preferences', preferencesRouter);

// 7. 404 handler for unknown routes
app.use('/api/v1', (_req: Request, _res: Response, next: NextFunction) => {
  next(new AppError('Endpoint tidak ditemukan.', 404, 'NOT_FOUND'));
});

// 8. Global centralized error handler
app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
  const requestId = (req.headers['x-request-id'] as string) || 'unknown-req';

  if (err instanceof AppError) {
    if (err.statusCode < 500) {
      logger.warn(`AppError [${err.code}]: ${err.message}`, { requestId, details: err.details });
    } else {
      logger.error(`AppError Server [${err.code}]: ${err.message}`, { requestId, stack: err.stack });
    }

    return res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        requestId,
      },
    });
  }

  logger.error(`Unhandled Exception: ${err.message}`, { stack: err.stack, requestId });
  return res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Terjadi kesalahan internal pada server.',
      requestId,
    },
  });
});
