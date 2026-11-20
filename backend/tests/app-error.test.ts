import { describe, it, expect } from 'vitest';
import {
  AppError,
  NotFoundError,
  UnauthorizedError,
  ForbiddenError,
  ValidationError,
  InsufficientStockError,
  ConflictError,
} from '../src/utils/app-error';

describe('AppError Suite', () => {
  it('harus membuat AppError standar dengan status 400 default', () => {
    const err = new AppError('Bad request message');
    expect(err.statusCode).toBe(400);
    expect(err.code).toBe('BAD_REQUEST');
    expect(err.message).toBe('Bad request message');
    expect(err.isOperational).toBe(true);
  });

  it('harus membuat NotFoundError dengan status 404', () => {
    const err = new NotFoundError('Barang tidak ditemukan.');
    expect(err.statusCode).toBe(404);
    expect(err.code).toBe('NOT_FOUND');
    expect(err.message).toBe('Barang tidak ditemukan.');
  });

  it('harus membuat UnauthorizedError dengan status 401', () => {
    const err = new UnauthorizedError();
    expect(err.statusCode).toBe(401);
    expect(err.code).toBe('UNAUTHORIZED');
  });

  it('harus membuat ForbiddenError dengan status 403', () => {
    const err = new ForbiddenError();
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('FORBIDDEN');
  });

  it('harus membuat ValidationError dengan status 400 dan field details', () => {
    const details = [{ field: 'email', message: 'Email tidak valid' }];
    const err = new ValidationError('Validasi gagal.', details);
    expect(err.statusCode).toBe(400);
    expect(err.code).toBe('VALIDATION_ERROR');
    expect(err.details).toEqual(details);
  });

  it('harus membuat InsufficientStockError dengan status 422', () => {
    const err = new InsufficientStockError('Stok tidak mencukupi.');
    expect(err.statusCode).toBe(422);
    expect(err.code).toBe('INSUFFICIENT_STOCK');
  });

  it('harus membuat ConflictError dengan status 409', () => {
    const err = new ConflictError('SKU sudah digunakan.');
    expect(err.statusCode).toBe(409);
    expect(err.code).toBe('CONFLICT');
  });
});
