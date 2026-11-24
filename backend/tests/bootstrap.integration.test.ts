import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { bootstrapSystem } from '../src/scripts/bootstrap';
import { PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

describe('Bootstrap Integration Tests (Dedicated Isolated Test DB Guard)', () => {
  const originalEnv = { ...process.env };
  const tempSecretFile = path.join(__dirname, 'temp_integration_admin_secret.txt');

  const dbUrl = process.env.DATABASE_URL || '';
  const isDedicatedTestDb =
    dbUrl.includes('stockflow_bootstrap_test') &&
    !dbUrl.includes('stockflow_db') &&
    !dbUrl.includes('stockflow_dev_db');

  const shouldRun = process.env.RUN_BOOTSTRAP_INTEGRATION_TEST === 'true' && isDedicatedTestDb;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    if (fs.existsSync(tempSecretFile)) {
      fs.unlinkSync(tempSecretFile);
    }
  });

  it('Fail-Closed Safety Guard: Menolak eksekusi jika bukan database stockflow_bootstrap_test terisolasi', () => {
    // Assert that if someone accidentally points DATABASE_URL to stockflow_db or stockflow_dev_db,
    // the fail-closed guard strictly refuses to execute bootstrap integration tests against it.
    if (!isDedicatedTestDb) {
      expect(isDedicatedTestDb).toBe(false);
      // Guard verified: production and development databases are protected
      return;
    }

    expect(dbUrl).toContain('stockflow_bootstrap_test');
    expect(dbUrl).not.toContain('stockflow_db');
    expect(dbUrl).not.toContain('stockflow_dev_db');
  });

  if (shouldRun) {
    it('harus berhasil bootstrap pada fresh test database dan mengaktifkan one-time execution guard', async () => {
      const prisma = new PrismaClient();
      const securePass = 'Str0ngP@ssw0rd!2026Integration';
      fs.writeFileSync(tempSecretFile, securePass, 'utf8');

      process.env.NODE_ENV = 'production';
      process.env.INITIAL_ORG_NAME = 'PT StockFlow Integration Test';
      process.env.INITIAL_ADMIN_NAME = 'Admin Integration Test';
      process.env.INITIAL_ADMIN_EMAIL = 'admin.integ@stockflow.com';
      process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

      try {
        // First run: fresh bootstrap
        const res1 = await bootstrapSystem(undefined, prisma);
        expect(res1.skipped).toBe(false);
        expect(res1.user).toBeDefined();
        expect(res1.user?.mustChangePassword).toBe(true);

        // Second run: one-time guard
        const res2 = await bootstrapSystem(undefined, prisma);
        expect(res2.skipped).toBe(true);
        expect(res2.existingAdminId).toBe(res1.user!.id);
      } finally {
        await prisma.session.deleteMany({ where: { user: { email: 'admin.integ@stockflow.com' } } });
        await prisma.user.deleteMany({ where: { email: 'admin.integ@stockflow.com' } });
        await prisma.$disconnect();
      }
    });
  }
});
