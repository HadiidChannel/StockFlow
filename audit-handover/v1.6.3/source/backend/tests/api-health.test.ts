import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';

describe('API Integration Health and Security Headers', () => {
  it('GET /api/v1/health harus mengembalikan status UP dan security headers', async () => {
    const res = await request(app).get('/api/v1/health');

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('UP');
    expect(res.body.data.service).toBe('StockFlow Backend API');
    expect(res.headers['x-request-id']).toBeDefined();
    // Helmet headers
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('GET /api/v1/unknown-endpoint harus mengembalikan 404 standard envelope', async () => {
    const res = await request(app).get('/api/v1/unknown-route-endpoint');

    expect(res.status).toBe(404);
    expect(res.body.error).toBeDefined();
    expect(res.body.error.code).toBe('NOT_FOUND');
    expect(res.body.error.requestId).toBeDefined();
  });

  it('POST /api/v1/auth/login dengan body kosong harus mengembalikan 400 VALIDATION_ERROR', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({});

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toBeDefined();
  });
});
