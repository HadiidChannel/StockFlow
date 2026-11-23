import express, { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { globalApiLimiter } from './middleware/rate-limiter';
import { prisma } from './database/client';
import { AppError, ForbiddenError } from './utils/app-error';
import { logger } from './utils/logger';
import { requireAuth, enforcePasswordChange } from './middleware/auth';

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
const isProduction = process.env.NODE_ENV === 'production';
const rawFrontendUrl = process.env.FRONTEND_URL;
const frontendUrl = rawFrontendUrl ? rawFrontendUrl.replace(/\/+$/, '') : (isProduction ? '' : 'http://localhost:3000');
const allowLocalhostSimulation = process.env.ALLOW_LOCALHOST_SIMULATION === 'true';
const allowedOrigins = isProduction
  ? (frontendUrl ? (allowLocalhostSimulation ? [frontendUrl, 'http://localhost:3000', 'http://127.0.0.1:3000'] : [frontendUrl]) : [])
  : [frontendUrl, 'http://localhost:3000', 'http://127.0.0.1:3000'].filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new ForbiddenError('Origin request tidak diizinkan oleh kebijakan CORS StockFlow.'));
    },
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

// P1-07: Global rate limiter for API endpoints
app.use('/api', globalApiLimiter);

// 5. Healthcheck endpoint with real database readiness check
app.get('/api/v1/health', async (_req: Request, res: Response) => {
  let isDbOk = true;
  try {
    const pingPromise = prisma.$queryRaw`SELECT 1`;
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Database ping timeout')), 1500)
    );
    await Promise.race([pingPromise, timeoutPromise]);
  } catch (err: any) {
    isDbOk = false;
    logger.warn('Healthcheck database ping tidak merespons:', { message: err.message });
  }

  if (isDbOk) {
    return res.status(200).json({
      data: {
        status: 'UP',
        database: 'CONNECTED',
        timestamp: new Date().toISOString(),
        service: 'StockFlow Backend API',
      },
    });
  }

  return res.status(503).json({
    error: {
      code: 'SERVICE_UNAVAILABLE',
      message: 'Koneksi database tidak tersedia.',
      status: 'DOWN',
      database: 'DISCONNECTED',
      timestamp: new Date().toISOString(),
    },
  });
});

// 6. Mount domain route handlers
// Auth router handles login, session me, change-password, and logout
app.use('/api/v1/auth', authRouter);

// Operational routes require valid authentication AND completed password change
const operationalMiddlewares = [requireAuth, enforcePasswordChange];

app.use('/api/v1/organization', operationalMiddlewares, organizationRouter);
app.use('/api/v1/users', operationalMiddlewares, usersRouter);
app.use('/api/v1/categories', operationalMiddlewares, categoriesRouter);
app.use('/api/v1/warehouses', operationalMiddlewares, warehousesRouter);
app.use('/api/v1/products', operationalMiddlewares, productsRouter);
app.use('/api/v1/inventory', operationalMiddlewares, inventoryRouter);
app.use('/api/v1/movements', operationalMiddlewares, movementsRouter);
app.use('/api/v1/dashboard', operationalMiddlewares, dashboardRouter);
app.use('/api/v1/preferences', operationalMiddlewares, preferencesRouter);

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
