import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { prisma } from '../database/client';
import { UnauthorizedError } from '../utils/app-error';

export interface AuthenticatedUser {
  id: string;
  name: string;
  email: string;
  role: {
    id: string;
    code: 'ADMIN' | 'WAREHOUSE_STAFF';
    name: string;
  };
  organizationId: string;
  mustChangePassword: boolean;
  sessionId: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
      sessionId?: string;
      allowedWarehouseIds?: string[];
    }
  }
}

export async function requireAuth(req: Request, _res: Response, next: NextFunction) {
  try {
    const rawSessionToken = req.cookies?.sf_session;
    if (!rawSessionToken || typeof rawSessionToken !== 'string') {
      throw new UnauthorizedError('Sesi tidak ditemukan atau belum login.');
    }

    const tokenHash = crypto.createHash('sha256').update(rawSessionToken).digest('hex');

    const session = await prisma.session.findUnique({
      where: { tokenHash },
      include: {
        user: {
          include: {
            role: true,
          },
        },
      },
    });

    if (!session) {
      throw new UnauthorizedError('Sesi tidak valid.');
    }

    if (session.revokedAt) {
      throw new UnauthorizedError('Sesi telah dicabut.');
    }

    if (new Date() > session.expiresAt) {
      throw new UnauthorizedError('Sesi telah kedaluwarsa.');
    }

    if (session.user.status !== 'ACTIVE') {
      throw new UnauthorizedError('Akun pengguna tidak aktif.');
    }

    req.user = {
      id: session.user.id,
      name: session.user.name,
      email: session.user.email,
      role: {
        id: session.user.role.id,
        code: session.user.role.code as 'ADMIN' | 'WAREHOUSE_STAFF',
        name: session.user.role.name,
      },
      organizationId: session.user.organizationId,
      mustChangePassword: session.user.mustChangePassword,
      sessionId: session.id,
    };
    req.sessionId = session.id;

    // Asynchronously update lastSeenAt without blocking the request
    prisma.session.update({
      where: { id: session.id },
      data: { lastSeenAt: new Date() },
    }).catch(() => {});

    next();
  } catch (err) {
    next(err);
  }
}
