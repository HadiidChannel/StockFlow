import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const INSECURE_DEFAULT_SECRETS = [
  'stockflow-session-secret-key-development-32chars',
  'super-secret-production-key-at-least-32-chars',
  'stockflow-csrf-secret-key-development-32chars',
  'csrf-secret-production-key-at-least-32-chars',
  'dev_session_secret_key_32_characters_minimum',
  'dev_csrf_secret_key_32_characters_minimum',
  'your_session_secret_min_32_chars_random_string',
  'your_csrf_secret_min_32_chars_random_string',
  'secret',
  'changeme',
  'password',
];

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  APP_DEPLOYMENT_MODE: z.enum(['local', 'production']).default('local'),
  PORT: z.coerce.number().default(4000),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL wajib diisi'),
  FRONTEND_URL: z.string().url('FRONTEND_URL harus berupa URL yang valid').default('http://localhost:3000'),
  COOKIE_DOMAIN: z.string().optional(),
  COOKIE_SECURE: z
    .union([z.boolean(), z.enum(['true', 'false']).transform((v) => v === 'true')])
    .default(false),
  COOKIE_SAME_SITE: z.enum(['lax', 'strict', 'none']).default('lax'),
  SESSION_SECRET: z.string().min(32, 'SESSION_SECRET minimal 32 karakter'),
  CSRF_SECRET: z.string().min(32, 'CSRF_SECRET minimal 32 karakter'),
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  INITIAL_ORG_NAME: z.string().optional(),
  INITIAL_ADMIN_NAME: z.string().optional(),
  INITIAL_ADMIN_EMAIL: z.string().email().optional(),
  INITIAL_ADMIN_PASSWORD_FILE: z.string().optional(),
}).superRefine((data, ctx) => {
  // 1. Validasi saat NODE_ENV === 'production' (berlaku untuk mode local maupun production)
  if (data.NODE_ENV === 'production') {
    // Session secret tidak boleh menggunakan default
    if (INSECURE_DEFAULT_SECRETS.includes(data.SESSION_SECRET)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['SESSION_SECRET'],
        message: 'SESSION_SECRET pada production build tidak boleh menggunakan nilai default yang tidak aman.',
      });
    }

    // CSRF secret tidak boleh menggunakan default
    if (INSECURE_DEFAULT_SECRETS.includes(data.CSRF_SECRET)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CSRF_SECRET'],
        message: 'CSRF_SECRET pada production build tidak boleh menggunakan nilai default yang tidak aman.',
      });
    }

    // Database password tidak boleh menggunakan default development
    if (data.DATABASE_URL.includes('stockflow_pass123') || data.DATABASE_URL.includes('root:root')) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['DATABASE_URL'],
        message: 'DATABASE_URL pada production build tidak boleh menggunakan password default development.',
      });
    }
  }

  // 2. Validasi spesifik target deployment: APP_DEPLOYMENT_MODE
  if (data.APP_DEPLOYMENT_MODE === 'production') {
    // Mode deployment publik / production:
    // a. Cookie secure wajib aktif
    if (!data.COOKIE_SECURE) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['COOKIE_SECURE'],
        message: 'COOKIE_SECURE wajib bernilai true pada deployment target production.',
      });
    }

    // b. FRONTEND_URL wajib HTTPS dan tidak boleh localhost / 127.0.0.1
    if (!data.FRONTEND_URL || data.FRONTEND_URL.includes('localhost') || data.FRONTEND_URL.includes('127.0.0.1')) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['FRONTEND_URL'],
        message: 'FRONTEND_URL pada deployment target production tidak boleh kosong, menggunakan localhost, atau 127.0.0.1.',
      });
    } else if (!data.FRONTEND_URL.startsWith('https://')) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['FRONTEND_URL'],
        message: 'FRONTEND_URL pada deployment target production wajib menggunakan protokol HTTPS.',
      });
    }
  } else if (data.APP_DEPLOYMENT_MODE === 'local') {
    // Mode deployment local portfolio:
    // FRONTEND_URL harus tepat canonical http://localhost:3000
    if (data.FRONTEND_URL !== 'http://localhost:3000') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['FRONTEND_URL'],
        message: 'FRONTEND_URL pada mode APP_DEPLOYMENT_MODE=local harus tepat http://localhost:3000.',
      });
    }
  }
});

export type EnvConfig = z.infer<typeof envSchema>;

let parsedEnv: EnvConfig;

export function validateEnv(): EnvConfig {
  if (parsedEnv) {
    return parsedEnv;
  }

  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const errorDetails = result.error.issues
      .map((i) => ` - [${i.path.join('.')}]: ${i.message}`)
      .join('\n');
    console.error('FATAL: Validasi environment variables gagal:\n' + errorDetails);
    throw new Error('Validasi environment variables gagal. Server menolak untuk start.');
  }

  parsedEnv = result.data;
  return parsedEnv;
}

export const env = validateEnv();
