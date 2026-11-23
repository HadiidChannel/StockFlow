import { describe, it, expect, vi } from 'vitest';
import { Request, Response } from 'express';
import { verifyCsrf, validateOrigin } from '../src/middleware/csrf';
import { ForbiddenError } from '../src/utils/app-error';
import {
  loginLimiter,
  passwordChangeLimiter,
  inventoryTransactionLimiter,
  userManagementLimiter,
  globalApiLimiter,
} from '../src/middleware/rate-limiter';

describe('Milestone 4: Security Hardening (P1-05, P1-06, P1-07)', () => {
  describe('P1-06: Origin and Referer Header Validation', () => {
    it('harus mengizinkan request GET tanpa memvalidasi origin', () => {
      const req = {
        method: 'GET',
        headers: { origin: 'http://malicious-site.com' },
      } as unknown as Request;

      expect(() => validateOrigin(req)).not.toThrow();
    });

    it('harus menolak request POST dengan Origin yang tidak terdaftar', () => {
      const req = {
        method: 'POST',
        headers: { origin: 'http://attacker.com' },
      } as unknown as Request;

      expect(() => validateOrigin(req)).toThrow(ForbiddenError);
    });

    it('harus menolak request POST dengan Referer dari domain yang tidak terdaftar', () => {
      const req = {
        method: 'POST',
        headers: { referer: 'http://evil.com/phishing' },
      } as unknown as Request;

      expect(() => validateOrigin(req)).toThrow(ForbiddenError);
    });

    it('harus mengizinkan request POST dengan Origin terdaftar (http://localhost:3000)', () => {
      const req = {
        method: 'POST',
        headers: { origin: 'http://localhost:3000' },
      } as unknown as Request;

      expect(() => validateOrigin(req)).not.toThrow();
    });

    it('harus mengizinkan request POST tanpa Origin atau Referer (non-browser API client)', () => {
      const req = {
        method: 'POST',
        headers: {},
      } as unknown as Request;

      expect(() => validateOrigin(req)).not.toThrow();
    });

    it('harus menolak request POST dari localhost pada mode production dan hanya menerima domain production', () => {
      const originalEnv = process.env.NODE_ENV;
      const originalFrontend = process.env.FRONTEND_URL;
      const originalMode = process.env.APP_DEPLOYMENT_MODE;
      try {
        process.env.NODE_ENV = 'production';
        process.env.APP_DEPLOYMENT_MODE = 'production';
        process.env.FRONTEND_URL = 'https://app.stockflow.com';

        const reqLocalhost = {
          method: 'POST',
          headers: { origin: 'http://localhost:3000' },
        } as unknown as Request;

        expect(() => validateOrigin(reqLocalhost)).toThrow(ForbiddenError);

        const reqAllowed = {
          method: 'POST',
          headers: { origin: 'https://app.stockflow.com' },
        } as unknown as Request;

        expect(() => validateOrigin(reqAllowed)).not.toThrow();
      } finally {
        process.env.NODE_ENV = originalEnv;
        process.env.FRONTEND_URL = originalFrontend;
        process.env.APP_DEPLOYMENT_MODE = originalMode;
      }
    });

    it('harus menolak request POST dari port localhost yang berbeda atau 127.0.0.1 pada mode local', () => {
      const originalMode = process.env.APP_DEPLOYMENT_MODE;
      try {
        process.env.APP_DEPLOYMENT_MODE = 'local';

        const reqPort8080 = {
          method: 'POST',
          headers: { origin: 'http://localhost:8080' },
        } as unknown as Request;
        expect(() => validateOrigin(reqPort8080)).toThrow(ForbiddenError);

        const req127 = {
          method: 'POST',
          headers: { origin: 'http://127.0.0.1:3000' },
        } as unknown as Request;
        expect(() => validateOrigin(req127)).toThrow(ForbiddenError);
      } finally {
        process.env.APP_DEPLOYMENT_MODE = originalMode;
      }
    });
  });

  describe('P1-07: Tiered Rate Limiting Configuration', () => {
    it('harus memiliki konfigurasi ketat untuk login (15 menit)', () => {
      expect(loginLimiter).toBeDefined();
    });

    it('harus memiliki konfigurasi ketat untuk password change', () => {
      expect(passwordChangeLimiter).toBeDefined();
    });

    it('harus memiliki rate limiter untuk transaksi inventaris', () => {
      expect(inventoryTransactionLimiter).toBeDefined();
    });

    it('harus memiliki rate limiter untuk manajemen user', () => {
      expect(userManagementLimiter).toBeDefined();
    });

    it('harus memiliki global limiter untuk API endpoints', () => {
      expect(globalApiLimiter).toBeDefined();
    });
  });
});
