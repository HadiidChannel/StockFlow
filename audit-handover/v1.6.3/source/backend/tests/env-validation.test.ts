import { describe, it, expect } from 'vitest';
import { envSchema } from '../src/config/env';

describe('P0-02: Localhost Portfolio & Production Environment Validation', () => {
  it('harus menolak SESSION_SECRET default pada mode production build', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus menolak password default development pada DATABASE_URL mode production build', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus menolak COOKIE_SECURE false pada mode APP_DEPLOYMENT_MODE=production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus menolak FRONTEND_URL localhost pada mode APP_DEPLOYMENT_MODE=production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus menolak FRONTEND_URL 127.0.0.1 pada mode APP_DEPLOYMENT_MODE=production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus menolak FRONTEND_URL tanpa protokol HTTPS pada mode APP_DEPLOYMENT_MODE=production', () => {
    const invalidProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  it('harus meloloskan konfigurasi production remote yang aman dan ber-entropi tinggi dengan domain HTTPS', () => {
    const validProdEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'production',
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

  // Test APP_DEPLOYMENT_MODE=local (Localhost Portfolio Edition)
  it('harus meloloskan konfigurasi localhost portfolio (NODE_ENV=production, APP_DEPLOYMENT_MODE=local) dengan canonical origin http://localhost:3000', () => {
    const validLocalEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'local',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_user:sf_prod_secure_pass_2026!@db:3306/stockflow_db',
      FRONTEND_URL: 'http://localhost:3000',
      COOKIE_SECURE: 'false',
      SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
      CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
    };

    const result = envSchema.safeParse(validLocalEnv);
    expect(result.success).toBe(true);
  });

  it('harus menolak FRONTEND_URL selain canonical http://localhost:3000 pada mode APP_DEPLOYMENT_MODE=local (misal port 8080)', () => {
    const invalidPortEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'local',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_user:sf_prod_secure_pass_2026!@db:3306/stockflow_db',
      FRONTEND_URL: 'http://localhost:8080',
      COOKIE_SECURE: 'false',
      SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
      CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
    };

    const result = envSchema.safeParse(invalidPortEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('FRONTEND_URL'));
      expect(issue).toBeDefined();
      expect(issue?.message).toContain('http://localhost:3000');
    }
  });

  it('harus menolak FRONTEND_URL 127.0.0.1 pada mode APP_DEPLOYMENT_MODE=local', () => {
    const invalidIpEnv = {
      NODE_ENV: 'production',
      APP_DEPLOYMENT_MODE: 'local',
      PORT: '4000',
      DATABASE_URL: 'mysql://stockflow_user:sf_prod_secure_pass_2026!@db:3306/stockflow_db',
      FRONTEND_URL: 'http://127.0.0.1:3000',
      COOKIE_SECURE: 'false',
      SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
      CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
    };

    const result = envSchema.safeParse(invalidIpEnv);
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.issues.find((i) => i.path.includes('FRONTEND_URL'));
      expect(issue).toBeDefined();
      expect(issue?.message).toContain('http://localhost:3000');
    }
  });

  it('harus menolak placeholder secrets pada SESSION_SECRET meskipun panjangnya memenuhi syarat 32 karakter', () => {
    const placeholders = [
      'your_high_entropy_session_secret_min_32_characters_here',
      'change_me_session_secret_min_32_chars_now',
      'replace_with_secure_production_secret_key_32',
      'example_secret_key_at_least_32_characters_long',
      'placeholder_session_secret_key_32_characters',
    ];

    for (const ph of placeholders) {
      const envObj = {
        NODE_ENV: 'production',
        APP_DEPLOYMENT_MODE: 'local',
        PORT: '4000',
        DATABASE_URL: 'mysql://stockflow_user:sf_prod_secure_pass_2026!@db:3306/stockflow_db',
        FRONTEND_URL: 'http://localhost:3000',
        COOKIE_SECURE: 'false',
        SESSION_SECRET: ph,
        CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
      };

      const result = envSchema.safeParse(envObj);
      expect(result.success).toBe(false);
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('SESSION_SECRET'));
        expect(issue).toBeDefined();
        expect(issue?.message).toContain('placeholder');
      }
    }
  });

  it('harus menolak placeholder secrets pada CSRF_SECRET meskipun panjangnya memenuhi syarat 32 karakter', () => {
    const placeholders = [
      'your_csrf_secret_min_32_characters_random_key_here',
      'change_me_csrf_secret_key_at_least_32_chars',
      'replace_with_csrf_production_key_32_characters',
      'example_secret_csrf_token_key_for_testing_only',
      'placeholder_csrf_secret_key_32_characters_ok',
    ];

    for (const ph of placeholders) {
      const envObj = {
        NODE_ENV: 'production',
        APP_DEPLOYMENT_MODE: 'local',
        PORT: '4000',
        DATABASE_URL: 'mysql://stockflow_user:sf_prod_secure_pass_2026!@db:3306/stockflow_db',
        FRONTEND_URL: 'http://localhost:3000',
        COOKIE_SECURE: 'false',
        SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
        CSRF_SECRET: ph,
      };

      const result = envSchema.safeParse(envObj);
      expect(result.success).toBe(false);
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('CSRF_SECRET'));
        expect(issue).toBeDefined();
        expect(issue?.message).toContain('placeholder');
      }
    }
  });

  it('harus menolak placeholder password pada DATABASE_URL', () => {
    const invalidDbUrls = [
      'mysql://stockflow_user:your_strong_password_here@db:3306/stockflow_db',
      'mysql://stockflow_user:change_me_database_pass@db:3306/stockflow_db',
      'mysql://stockflow_user:replace_with_real_pass@db:3306/stockflow_db',
      'mysql://stockflow_user:example_secret_db_pass@db:3306/stockflow_db',
      'mysql://stockflow_user:placeholder_password_db@db:3306/stockflow_db',
    ];

    for (const url of invalidDbUrls) {
      const envObj = {
        NODE_ENV: 'production',
        APP_DEPLOYMENT_MODE: 'local',
        PORT: '4000',
        DATABASE_URL: url,
        FRONTEND_URL: 'http://localhost:3000',
        COOKIE_SECURE: 'false',
        SESSION_SECRET: 'k9X2mQ8vL5wR7tY4nB1jC6eH3aF0sD9gP2oI5uY8rE1wQ4',
        CSRF_SECRET: 'z1A4sD7fG0hJ3kL6pQ9wE2rT5yU8iO1aB4cE7mK0xN3vP6',
      };

      const result = envSchema.safeParse(envObj);
      expect(result.success).toBe(false);
      if (!result.success) {
        const issue = result.error.issues.find((i) => i.path.includes('DATABASE_URL'));
        expect(issue).toBeDefined();
        expect(issue?.message).toContain('placeholder');
      }
    }
  });
});
