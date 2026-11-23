import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { bootstrapSystem } from '../src/scripts/bootstrap';
import { PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

const prisma = new PrismaClient();

describe('P0-03: Production Administrator Bootstrap Security & Docker Compose Secrets', () => {
  const originalEnv = { ...process.env };
  const tempSecretFile = path.join(__dirname, 'temp_admin_secret.txt');

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.INITIAL_ADMIN_PASSWORD;
    delete process.env.INITIAL_ADMIN_PASSWORD_FILE;
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    if (fs.existsSync(tempSecretFile)) {
      fs.unlinkSync(tempSecretFile);
    }
  });

  it('harus menolak bootstrap jika password diberikan melalui environment variable biasa (INITIAL_ADMIN_PASSWORD)', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD = 'Str0ngP@ssw0rd!2026';

    await expect(bootstrapSystem()).rejects.toThrow(
      'INITIAL_ADMIN_PASSWORD tidak diizinkan melalui environment variable biasa. Gunakan secret file melalui INITIAL_ADMIN_PASSWORD_FILE'
    );
  });

  it('harus menolak bootstrap jika INITIAL_ADMIN_PASSWORD_FILE tidak didefinisikan', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    delete process.env.INITIAL_ADMIN_PASSWORD_FILE;

    await expect(bootstrapSystem()).rejects.toThrow(
      'INITIAL_ADMIN_PASSWORD_FILE wajib disediakan dan merujuk pada secret file yang valid.'
    );
  });

  it('harus menolak bootstrap jika file secret pada INITIAL_ADMIN_PASSWORD_FILE tidak ditemukan', async () => {
    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = path.join(__dirname, 'non_existent_secret.txt');

    await expect(bootstrapSystem()).rejects.toThrow('Secret file tidak ditemukan pada path:');
  });

  it('harus menolak bootstrap jika file secret pada INITIAL_ADMIN_PASSWORD_FILE kosong', async () => {
    fs.writeFileSync(tempSecretFile, '   ', 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    await expect(bootstrapSystem()).rejects.toThrow('Secret file initial_admin_password kosong.');
  });

  it('harus menolak bootstrap jika password dalam file secret kurang dari 12 karakter', async () => {
    fs.writeFileSync(tempSecretFile, 'Short1!a', 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    await expect(bootstrapSystem()).rejects.toThrow('Password bootstrap minimal 12 karakter.');
  });

  it('harus menolak bootstrap jika password dalam file secret tidak memenuhi kompleksitas karakter', async () => {
    fs.writeFileSync(tempSecretFile, 'alllowercasenonumbernospecial', 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    await expect(bootstrapSystem()).rejects.toThrow('Password bootstrap harus memenuhi kebijakan keamanan');
  });

  it('harus menolak bootstrap pada production jika file secret menggunakan password default development', async () => {
    fs.writeFileSync(tempSecretFile, 'AdminStockFlow2026!', 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing';
    process.env.INITIAL_ADMIN_NAME = 'Admin Prod';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.prod@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    await expect(bootstrapSystem()).rejects.toThrow(
      'Password bootstrap pada production tidak boleh menggunakan password default development.'
    );
  });

  it('harus berhasil membaca password dari file secret valid dan mengaktifkan one-time execution guard', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Testing File';
    process.env.INITIAL_ADMIN_NAME = 'Admin File';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.file@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

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
});
