import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { prisma } from '../database/client';
import { ForbiddenError } from '../utils/app-error';

export async function verifyCsrf(req: Request, _res: Response, next: NextFunction) {
  try {
    const method = req.method.toUpperCase();
    // CSRF protection applies to state-mutating requests
    if (['GET', 'HEAD', 'OPTIONS'].includes(method)) {
      return next();
    }

    const csrfCookie = req.cookies?.sf_csrf;
    const csrfHeader = req.headers['x-csrf-token'];

    if (!csrfCookie || !csrfHeader || typeof csrfCookie !== 'string' || typeof csrfHeader !== 'string') {
      throw new ForbiddenError('Token CSRF tidak ditemukan.');
    }

    if (csrfCookie !== csrfHeader) {
      throw new ForbiddenError('Token CSRF tidak cocok.');
    }

    // Verify hash against session in DB if user is authenticated
    if (req.sessionId) {
      const headerHash = crypto.createHash('sha256').update(csrfHeader).digest('hex');
      const session = await prisma.session.findUnique({
        where: { id: req.sessionId },
        select: { csrfTokenHash: true },
      });

      if (!session || session.csrfTokenHash !== headerHash) {
        throw new ForbiddenError('Validasi integritas CSRF gagal.');
      }
    }

    next();
  } catch (err) {
    next(err);
  }
}
