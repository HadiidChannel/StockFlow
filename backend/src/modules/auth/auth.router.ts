import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { authController } from './auth.controller';
import { requireAuth } from '../../middleware/auth';
import { verifyCsrf } from '../../middleware/csrf';

export const authRouter = Router();

// Rate limiting specifically for login to mitigate brute force attacks
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // max 10 failed/success attempts per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Terlalu banyak percobaan login. Silakan coba kembali dalam 15 menit.',
    },
  },
});

authRouter.post('/login', loginLimiter, (req, res, next) => authController.login(req, res, next));
authRouter.post('/logout', requireAuth, verifyCsrf, (req, res, next) => authController.logout(req, res, next));
authRouter.get('/me', requireAuth, (req, res, next) => authController.me(req, res, next));
authRouter.post('/change-password', requireAuth, verifyCsrf, (req, res, next) => authController.changePassword(req, res, next));
