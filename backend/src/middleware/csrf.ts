import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { prisma } from '../database/client';
import { ForbiddenError } from '../utils/app-error';

function getAllowedOrigins(): string[] {
  const envUrl = process.env.FRONTEND_URL;
  const origins = ['http://localhost:3000', 'http://127.0.0.1:3000'];
  if (envUrl && !origins.includes(envUrl)) {
    origins.push(envUrl);
  }
  return origins;
}

export function validateOrigin(req: Request) {
  const method = req.method.toUpperCase();
  if (['GET', 'HEAD', 'OPTIONS'].includes(method)) {
    return;
  }

  const origin = req.headers['origin'] as string | undefined;
  const referer = req.headers['referer'] as string | undefined;

  let requestOrigin: string | null = null;
  if (origin) {
    requestOrigin = origin;
  } else if (referer) {
    try {
      requestOrigin = new URL(referer).origin;
    } catch {
      requestOrigin = null;
    }
  }

  if (requestOrigin) {
    const allowed = getAllowedOrigins();
    if (!allowed.includes(requestOrigin)) {
      throw new ForbiddenError('Origin request tidak diizinkan.');
    }
  }
}

export async function verifyCsrf(req: Request, _res: Response, next: NextFunction) {
  try {
    const method = req.method.toUpperCase();
    // CSRF protection applies to state-mutating requests
    if (['GET', 'HEAD', 'OPTIONS'].includes(method)) {
      return next();
    }

    // P1-06: Validasi ketat Origin/Referer browser
    validateOrigin(req);

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
