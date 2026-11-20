import { describe, it, expect } from 'vitest';
import { z } from 'zod';

describe('P0-02: Fail-Fast Production Environment Validation', () => {
  const INSECURE_DEFAULT_SECRETS = [
    'stockflow-session-secret-key-development-32chars',
    'super-secret-production-key-at-least-32-chars',
    'stockflow-csrf-secret-key-development-32chars',
    'csrf-secret-production-key-at-least-32-chars',
  ];

  const envSchema = z.object({
    NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
    PORT: z.coerce.number().default(4000),
    DATABASE_URL: z.string().min(1),
    COOKIE_SECURE: z
      .union([z.boolean(), z.enum(['true', 'false']).transform((v) => v === 'true')])
      .default(false),
    SESSION_SECRET: z.string().min(32),
    CSRF_SECRET: z.string().min(32),
  }).superRefine((data, ctx) => {
    if (data.NODE_ENV === 'production') {
      if (INSECURE_DEFAULT_SECRETS.includes(data.SESSION_SECRET)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['SESSION_SECRET'],
          message: 'SESSION_SECRET pada production tidak boleh menggunakan nilai default.',
        });
      }
      if (INSECURE_DEFAULT_SECRETS.includes(data.CSRF_SECRET)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['CSRF_SECRET'],
          message: 'CSRF_SECRET pada production tidak boleh menggunakan nilai default.',
        });
      }
      if (!data.COOKIE_SECURE) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['COOKIE_SECURE'],
          message: 'COOKIE_SECURE wajib bernilai true pada production.',
        });
      }
      if (data.DATABASE_URL.includes('stockflow_pass123')) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['DATABASE_URL'],
          message: 'DATABASE_URL pada production tidak boleh menggunakan password default development.',
        });
      }
    }
  });

  it('harus menolak SESSION_SECRET default pada mode production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://prod_user:StrongProdPass2026!@prod-db:3306/stockflow_db',
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
      DATABASE_URL: 'mysql://stockflow_user:stockflow_pass123@localhost:3306/stockflow_db',
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

  it('harus meloloskan konfigurasi production yang aman dan ber-entropi tinggi', () => {
    const validProdEnv = {
      NODE_ENV: 'production',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_prod_app:K9#mQ2$xP8!vL5*wR7^tY4@nB1~jC6+e@prod-cluster:3306/stockflow_db',
      COOKIE_SECURE: 'true',
      SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
      CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
    };

    const result = envSchema.safeParse(validProdEnv);
    expect(result.success).toBe(true);
  });
});
