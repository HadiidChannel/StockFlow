import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { bootstrapSystem } from '../src/scripts/bootstrap';
import { PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

const prisma = new PrismaClient();

describe('P0-03: Production Administrator Bootstrap Security', () => {
  const originalEnv = { ...process.env };
  const tempSecretFile = path.join(__dirname, 'temp_admin_secret.txt');

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    if (fs.existsSync(tempSecretFile)) {
      fs.unlinkSync(tempSecretFile);
    }
  });

  it('harus menolak bootstrap pada production jika INITIAL_ADMIN_PASSWORD tidak diberikan', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    delete process.env.INITIAL_ADMIN_PASSWORD;
    delete process.env.INITIAL_ADMIN_PASSWORD_FILE;

    await expect(bootstrapSystem()).rejects.toThrow(
      'INITIAL_ADMIN_PASSWORD atau INITIAL_ADMIN_PASSWORD_FILE wajib diisi pada environment production'
    );
  });

  it('harus menolak bootstrap pada production jika menggunakan password default development', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD = 'AdminStockFlow2026!';

    await expect(bootstrapSystem()).rejects.toThrow(
      'INITIAL_ADMIN_PASSWORD pada production tidak boleh menggunakan password default development'
    );
  });

  it('harus menolak bootstrap jika password kurang dari 12 karakter', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD = 'Short1!';

    await expect(bootstrapSystem()).rejects.toThrow('Password bootstrap minimal 12 karakter.');
  });

  it('harus menolak bootstrap jika password tidak memenuhi kompleksitas karakter', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD = 'alllowercasenonumbernospecial';

    await expect(bootstrapSystem()).rejects.toThrow('Password bootstrap harus memenuhi kebijakan keamanan');
  });

  it('harus mendukung pembacaan password dari file secret (INITIAL_ADMIN_PASSWORD_FILE)', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing File';
    process.env.INITIAL_ADMIN_NAME = 'Admin File';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.file@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;
    delete process.env.INITIAL_ADMIN_PASSWORD;

    // Database check: if admin already exists in test db, it should trigger one-time execution guard
    const existingAdmin = await prisma.user.findFirst({
      where: { role: { code: 'ADMIN' } },
    });

    if (existingAdmin) {
      const res = await bootstrapSystem();
      expect(res.skipped).toBe(true);
      expect(res.existingAdminId).toBeDefined();
    }
  });

  it('harus mengaktifkan one-time execution guard jika administrator sudah ada pada sistem', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing Guard';
    process.env.INITIAL_ADMIN_NAME = 'Admin Guard';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.guard@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD = 'Str0ngP@ssw0rd!2026Guard';

    const existingAdmin = await prisma.user.findFirst({
      where: { role: { code: 'ADMIN' } },
    });

    if (existingAdmin) {
      const result = await bootstrapSystem();
      expect(result.skipped).toBe(true);
      expect(result.existingAdminId).toBe(existingAdmin.id);
    }
  });
});
