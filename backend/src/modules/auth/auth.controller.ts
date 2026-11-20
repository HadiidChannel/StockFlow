import { Request, Response, NextFunction } from 'express';
import { authService } from './auth.service';
import { LoginSchema, ChangePasswordSchema } from './auth.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

const isProduction = process.env.NODE_ENV === 'production';
const cookieSecure = process.env.COOKIE_SECURE === 'true' || isProduction;
const cookieDomain = process.env.COOKIE_DOMAIN || undefined;

export class AuthController {
  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = LoginSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi input login gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await authService.login(parsed.data);

      // Set HttpOnly session cookie
      res.cookie('sf_session', result.rawSessionToken, {
        httpOnly: true,
        secure: cookieSecure,
        sameSite: 'lax',
        domain: cookieDomain,
        expires: result.expiresAt,
        path: '/',
      });

      // Set readable CSRF cookie
      res.cookie('sf_csrf', result.rawCsrfToken, {
        httpOnly: false,
        secure: cookieSecure,
        sameSite: 'lax',
        domain: cookieDomain,
        expires: result.expiresAt,
        path: '/',
      });

      return res.status(200).json({
        data: {
          user: result.user,
        },
      });
    } catch (err) {
      next(err);
    }
  }

  async logout(req: Request, res: Response, next: NextFunction) {
    try {
      if (req.sessionId) {
        await authService.logout(req.sessionId);
      }

      res.clearCookie('sf_session', { path: '/' });
      res.clearCookie('sf_csrf', { path: '/' });

      return res.status(200).json({
        data: {
          success: true,
        },
      });
    } catch (err) {
      next(err);
    }
  }

  async me(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) {
        throw new UnauthorizedError('Belum terautentikasi.');
      }

      const user = await authService.getMe(req.user.id);

      return res.status(200).json({
        data: {
          user,
        },
      });
    } catch (err) {
      next(err);
    }
  }

  async changePassword(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) {
        throw new UnauthorizedError('Belum terautentikasi.');
      }

      const parsed = ChangePasswordSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi password baru gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await authService.changePassword(req.user.id, parsed.data);

      return res.status(200).json({
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

export const authController = new AuthController();
