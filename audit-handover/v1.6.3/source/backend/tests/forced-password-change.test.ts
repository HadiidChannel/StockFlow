import { describe, it, expect, vi } from 'vitest';
import { enforcePasswordChange, AuthenticatedUser } from '../src/middleware/auth';
import { Request, Response } from 'express';
import { ForbiddenError } from '../src/utils/app-error';

describe('P0-03: Backend Forced Password Change Enforcement', () => {
  const userMustChange: AuthenticatedUser = {
    id: 'user-001',
    name: 'Initial Admin',
    email: 'admin@stockflow.com',
    role: { id: 'role-1', code: 'ADMIN', name: 'Administrator' },
    organizationId: 'org-1',
    mustChangePassword: true,
    sessionId: 'sess-1',
  };

  const userNormal: AuthenticatedUser = {
    ...userMustChange,
    mustChangePassword: false,
  };

  it('harus mengizinkan akses ke /api/v1/auth/me bagi user yang wajib ganti password', () => {
    const req = {
      user: userMustChange,
      originalUrl: '/api/v1/auth/me',
      path: '/auth/me',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    enforcePasswordChange(req, res, next);
    expect(next).toHaveBeenCalledWith();
  });

  it('harus mengizinkan akses ke /api/v1/auth/change-password bagi user yang wajib ganti password', () => {
    const req = {
      user: userMustChange,
      originalUrl: '/api/v1/auth/change-password',
      path: '/auth/change-password',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    enforcePasswordChange(req, res, next);
    expect(next).toHaveBeenCalledWith();
  });

  it('harus mengizinkan akses ke /api/v1/auth/logout bagi user yang wajib ganti password', () => {
    const req = {
      user: userMustChange,
      originalUrl: '/api/v1/auth/logout',
      path: '/auth/logout',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    enforcePasswordChange(req, res, next);
    expect(next).toHaveBeenCalledWith();
  });

  it('harus MENOLAK akses ke endpoint operasional (/api/v1/inventory/stock-in) dengan status 403 jika mustChangePassword=true', () => {
    const req = {
      user: userMustChange,
      originalUrl: '/api/v1/inventory/stock-in',
      path: '/api/v1/inventory/stock-in',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    expect(() => enforcePasswordChange(req, res, next)).toThrowError(ForbiddenError);
    try {
      enforcePasswordChange(req, res, next);
    } catch (err: any) {
      expect(err.statusCode).toBe(403);
      expect(err.code).toBe('FORCED_PASSWORD_CHANGE_REQUIRED');
    }
  });

  it('harus MENOLAK akses ke endpoint produk (/api/v1/products) dengan 403 jika mustChangePassword=true', () => {
    const req = {
      user: userMustChange,
      originalUrl: '/api/v1/products',
      path: '/api/v1/products',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    expect(() => enforcePasswordChange(req, res, next)).toThrowError(ForbiddenError);
  });

  it('harus mengizinkan seluruh endpoint operasional jika user sudah mengubah password (mustChangePassword=false)', () => {
    const req = {
      user: userNormal,
      originalUrl: '/api/v1/inventory/stock-in',
      path: '/api/v1/inventory/stock-in',
    } as unknown as Request;
    const res = {} as Response;
    const next = vi.fn();

    enforcePasswordChange(req, res, next);
    expect(next).toHaveBeenCalledWith();
  });
});
