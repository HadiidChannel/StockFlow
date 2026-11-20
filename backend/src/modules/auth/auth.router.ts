import { Router } from 'express';
import { authController } from './auth.controller';
import { requireAuth } from '../../middleware/auth';
import { verifyCsrf } from '../../middleware/csrf';
import { loginLimiter, passwordChangeLimiter } from '../../middleware/rate-limiter';

export const authRouter = Router();

authRouter.post('/login', loginLimiter, (req, res, next) => authController.login(req, res, next));
authRouter.post('/logout', requireAuth, verifyCsrf, (req, res, next) => authController.logout(req, res, next));
authRouter.get('/me', requireAuth, (req, res, next) => authController.me(req, res, next));
authRouter.post('/change-password', requireAuth, verifyCsrf, passwordChangeLimiter, (req, res, next) => authController.changePassword(req, res, next));
