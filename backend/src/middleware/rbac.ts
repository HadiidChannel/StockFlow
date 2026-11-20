import { Request, Response, NextFunction } from 'express';
import { ForbiddenError } from '../utils/app-error';

export function requireRole(...allowedRoles: Array<'ADMIN' | 'WAREHOUSE_STAFF'>) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new ForbiddenError('Otorisasi gagal: User belum login.'));
    }

    if (!allowedRoles.includes(req.user.role.code)) {
      return next(
        new ForbiddenError(
          `Akses ditolak: Memerlukan salah satu peran [${allowedRoles.join(', ')}].`
        )
      );
    }

    next();
  };
}
