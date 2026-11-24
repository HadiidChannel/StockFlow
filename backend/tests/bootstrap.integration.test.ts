import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { bootstrapSystem } from '../src/scripts/bootstrap';
import { assertBootstrapTestDatabaseSafe } from '../src/utils/bootstrap-guard';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

describe.skipIf(process.env.RUN_BOOTSTRAP_INTEGRATION_TEST !== 'true')(
  'Bootstrap Real Integration Tests (Disposable MySQL 8.4)',
  () => {
  let prisma: PrismaClient;
  const tempSecretFile = path.join(__dirname, 'temp_integration_admin_secret.txt');
  const generatedTestPassword = 'TestPass' + crypto.randomBytes(12).toString('hex') + '!2026';

  beforeAll(async () => {
    // 1. Fail-closed safety guard: strictly abort if not connected to verified disposable test DB
    assertBootstrapTestDatabaseSafe();

    // 2. Initialize Prisma client for the verified test database
    prisma = new PrismaClient();
    await prisma.$connect();

    // 3. Create temporary secret file with strong password
    fs.writeFileSync(tempSecretFile, generatedTestPassword, 'utf8');

    // 4. Configure test environment variables
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Bootstrap Verification';
    process.env.INITIAL_ADMIN_NAME = 'Disposable Bootstrap Admin';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.disposable@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;
  });

  afterAll(async () => {
    if (fs.existsSync(tempSecretFile)) {
      try {
        fs.unlinkSync(tempSecretFile);
      } catch {
        // Ignore cleanup error
      }
    }

    if (prisma) {
      await prisma.$disconnect();
    }
  });

  it('Langkah 1: Verifikasi kondisi awal database bersih (0 user dan 0 organisasi)', async () => {
    const userCount = await prisma.user.count({
      where: { email: 'admin.disposable@stockflow.com' },
    });
    expect(userCount).toBe(0);

    const orgCount = await prisma.organization.count({
      where: { name: 'PT StockFlow Bootstrap Verification' },
    });
    expect(orgCount).toBe(0);
  });

  it('Langkah 2: Menjalankan fresh bootstrap aktual dan memverifikasi pembuatan organisasi & admin', async () => {
    const result = await bootstrapSystem(undefined, prisma);

    expect(result.skipped).toBe(false);
    expect(result.user).toBeDefined();
    expect(result.user?.email).toBe('admin.disposable@stockflow.com');
    expect(result.user?.name).toBe('Disposable Bootstrap Admin');
    expect(result.user?.mustChangePassword).toBe(true);

    // Verify Organization exists in DB
    const org = await prisma.organization.findFirst({
      where: { name: 'PT StockFlow Bootstrap Verification' },
    });
    expect(org).toBeDefined();
    expect(org?.id).toBe(result.organization.id);

    // Verify Admin User exists in DB with role ADMIN
    const dbUser = await prisma.user.findUnique({
      where: { id: result.user!.id },
      include: { role: true },
    });
    expect(dbUser).toBeDefined();
    expect(dbUser?.role.code).toBe('ADMIN');
    expect(dbUser?.mustChangePassword).toBe(true);
    expect(dbUser?.status).toBe('ACTIVE');

    // Step 3: Verifikasi Keamanan Hash Password (bcrypt cost factor 12)
    expect(dbUser?.passwordHash).toBeDefined();
    expect(dbUser!.passwordHash).not.toBe(generatedTestPassword);
    expect(dbUser!.passwordHash).toMatch(/^\$2[aby]\$12\$/);
    expect(dbUser!.passwordHash.length).toBeGreaterThanOrEqual(60);

    // Verify bcrypt compare validates against plaintext password
    const isPasswordMatch = await bcrypt.compare(generatedTestPassword, dbUser!.passwordHash);
    expect(isPasswordMatch).toBe(true);

    // Verify incorrect password fails compare
    const isWrongMatch = await bcrypt.compare('WrongPassword123!', dbUser!.passwordHash);
    expect(isWrongMatch).toBe(false);
  });

  it('Langkah 3: Menjalankan bootstrap kedua untuk membuktikan idempotency dan one-time guard', async () => {
    const secondResult = await bootstrapSystem(undefined, prisma);

    expect(secondResult.skipped).toBe(true);
    expect(secondResult.existingAdminId).toBeDefined();

    // Verify user count did not duplicate
    const adminUsers = await prisma.user.findMany({
      where: { email: 'admin.disposable@stockflow.com' },
    });
    expect(adminUsers.length).toBe(1);

    // Verify organization count did not duplicate
    const orgs = await prisma.organization.findMany({
      where: { name: 'PT StockFlow Bootstrap Verification' },
    });
    expect(orgs.length).toBe(1);
  });
});
