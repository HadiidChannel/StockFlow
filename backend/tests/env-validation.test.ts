import { describe, it, expect } from 'vitest';
import { envSchema } from '../src/config/env';

describe('P0-02: Fail-Fast Production Environment Validation', () => {
  it('harus menolak SESSION_SECRET default pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongProdPass2026!@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'https://app.stockflow.com',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'super-secret-production-key-at-least-32-chars',
      CSRF_SECRET: 'custom-production-csrf-secret-random-hex-99999',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('SESSION_SECRET'));
      expect(issue).toBeDefined();
    }
  });

  it('harus menolak password default development pada DATABASE_URL mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_user:stockflow_pass123@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'https://app.stockflow.com',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'random-high-entropy-session-secret-key-prod-12345',
      CSRF_SECRET: 'random-high-entropy-csrf-secret-key-prod-12345',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('DATABASE_URL'));
      expect(issue).toBeDefined();
    }
  });

  it('harus menolak COOKIE_SECURE false pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongPassword987!@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'https://app.stockflow.com',
      COOKIE_SECURE: 'false',
      SESSION_SECRET: 'random-high-entropy-session-secret-key-prod-12345',
      CSRF_SECRET: 'random-high-entropy-csrf-secret-key-prod-12345',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('COOKIE_SECURE'));
      expect(issue).toBeDefined();
    }
  });

  it('harus menolak FRONTEND_URL default localhost pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongPassword987!@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'http://localhost:3000',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'random-high-entropy-session-secret-key-prod-12345',
      CSRF_SECRET: 'random-high-entropy-csrf-secret-key-prod-12345',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('FRONTEND_URL'));
      expect(issue).toBeDefined();
      expect(issue?.message).toContain('localhost');
    }
  });

  it('harus menolak FRONTEND_URL 127.0.0.1 pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongPassword987!@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'http://127.0.0.1:3000',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'random-high-entropy-session-secret-key-prod-12345',
      CSRF_SECRET: 'random-high-entropy-csrf-secret-key-prod-12345',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('FRONTEND_URL'));
      expect(issue).toBeDefined();
    }
  });

  it('harus menolak FRONTEND_URL tanpa protokol HTTPS pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongPassword987!@prod-db:3306/stockflow_db',
      FRONTEND_URL: 'http://app.stockflow.com',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'random-high-entropy-session-secret-key-prod-12345',
      CSRF_SECRET: 'random-high-entropy-csrf-secret-key-prod-12345',
    };

    const result = envSchema.safeParse(invalidProdEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('FRONTEND_URL'));
      expect(issue).toBeDefined();
      expect(issue?.message).toContain('HTTPS');
    }
  });

  it('harus meloloskan konfigurasi production yang aman dan ber-entropi tinggi dengan domain HTTPS', () => {
    const validProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_prod_app:K9#mQ2$xP8!vL5*wR7^tY4@nB1~jC6+e@prod-cluster:3306/stockflow_db',
      FRONTEND_URL: 'https://app.stockflow.com',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
      CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
    };

    const result = envSchema.safeParse(validProdEnv);
    expect(result.success).toBe(true);
  });
});
