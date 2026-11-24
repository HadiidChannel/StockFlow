import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { bootstrapSystem } from '../src/scripts/bootstrap';
import fs from 'fs';
import path from 'path';

describe('Bootstrap Unit Tests (In-Memory Prisma Mock)', () => {
  const originalEnv = { ...process.env };
  const tempSecretFile = path.join(__dirname, 'temp_unit_admin_secret.txt');

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

  it('harus menolak bootstrap pada production jika variabel organisasi atau admin belum ditentukan', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;
    delete process.env.INITIAL_ORG_NAME;
    delete process.env.INITIAL_ADMIN_NAME;
    delete process.env.INITIAL_ADMIN_EMAIL;

    await expect(bootstrapSystem()).rejects.toThrow('INITIAL_ORG_NAME wajib diisi pada environment production.');
  });

  it('harus berhasil mengeksekusi bootstrap pada database kosong dengan mock Prisma', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Unit Test';
    process.env.INITIAL_ADMIN_NAME = 'Admin Unit Test';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.unit@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    const mockAdminRole = {
      id: '00000000-0000-4000-8000-000000000001',
      code: 'ADMIN',
      name: 'Administrator',
    };
    const mockStaffRole = {
      id: '00000000-0000-4000-8000-000000000002',
      code: 'WAREHOUSE_STAFF',
      name: 'Warehouse Staff',
    };
    const mockOrg = {
      id: 'org-uuid-1234',
      name: 'PT StockFlow Unit Test',
      code: 'ORG-MAIN',
      timezone: 'Asia/Makassar',
      currency: 'IDR',
    };
    let createdUserData: any = null;

    const mockTx = {
      user: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockImplementation(async ({ data }) => {
          createdUserData = { id: 'user-uuid-5678', ...data };
          return createdUserData;
        }),
      },
      role: {
        findUnique: vi.fn().mockImplementation(async ({ where }) => {
          if (where.code === 'ADMIN') return mockAdminRole;
          if (where.code === 'WAREHOUSE_STAFF') return mockStaffRole;
          return null;
        }),
        create: vi.fn().mockImplementation(async ({ data }) => data),
      },
      organization: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue(mockOrg),
      },
    };

    const mockPrisma = {
      $transaction: vi.fn().mockImplementation(async (callback) => {
        return await callback(mockTx);
      }),
    };

    const result = await bootstrapSystem(undefined, mockPrisma);

    expect(result.skipped).toBe(false);
    expect(result.organization).toEqual(mockOrg);
    expect(result.user).toBeDefined();
    expect(result.user?.email).toBe('admin.unit@stockflow.com');
    expect(result.user?.mustChangePassword).toBe(true);
    expect(createdUserData).toBeDefined();
    expect(createdUserData.passwordHash).not.toBe(securePass);
    expect(createdUserData.passwordHash.startsWith('$2')).toBe(true);
  });

  it('harus mengaktifkan one-time execution guard jika akun Administrator sudah ada di database', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Unit Test';
    process.env.INITIAL_ADMIN_NAME = 'Admin Unit Test';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.unit@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    const existingAdmin = {
      id: 'existing-admin-uuid-9999',
      email: 'admin.existing@stockflow.com',
      role: { code: 'ADMIN' },
    };

    const mockTx = {
      user: {
        findFirst: vi.fn().mockResolvedValue(existingAdmin),
        create: vi.fn(),
      },
      role: {
        findUnique: vi.fn(),
        create: vi.fn(),
      },
      organization: {
        findFirst: vi.fn(),
        create: vi.fn(),
      },
    };

    const mockPrisma = {
      $transaction: vi.fn().mockImplementation(async (callback) => {
        return await callback(mockTx);
      }),
    };

    const result = await bootstrapSystem(undefined, mockPrisma);

    expect(result.skipped).toBe(true);
    expect(result.existingAdminId).toBe('existing-admin-uuid-9999');
    expect(mockTx.user.create).not.toHaveBeenCalled();
    expect(mockTx.organization.create).not.toHaveBeenCalled();
  });
});
