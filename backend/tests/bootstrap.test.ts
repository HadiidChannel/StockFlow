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

  it('harus berhasil mengeksekusi bootstrap pada database kosong, membuat admin dengan bcrypt hash dan mustChangePassword, serta menolak duplikasi pada pemanggilan kedua', async () => {
    const securePass = 'Str0ngP@ssw0rd!2026Secure';
    fs.writeFileSync(tempSecretFile, securePass, 'utf8');

    process.env.NODE_ENV = 'production';
    process.env.INITIAL_ORG_NAME = 'PT StockFlow Fresh Test';
    process.env.INITIAL_ADMIN_NAME = 'Admin Fresh Test';
    process.env.INITIAL_ADMIN_EMAIL = 'admin.fresh@stockflow.com';
    process.env.INITIAL_ADMIN_PASSWORD_FILE = tempSecretFile;

    // Cleanup lingering test admin if any
    await prisma.session.deleteMany({ where: { user: { email: 'admin.fresh@stockflow.com' } } });
    await prisma.user.deleteMany({ where: { email: 'admin.fresh@stockflow.com' } });

    // Pastikan ADMIN role ada
    const adminRole = await prisma.role.upsert({
      where: { code: 'ADMIN' },
      update: {},
      create: {
        id: '00000000-0000-4000-8000-000000000001',
        code: 'ADMIN',
        name: 'Administrator',
      },
    });

    // Kembalikan user yang mungkin sempat tertinggal di TEMP_TEST_ROLE dari kegagalan sebelumnya
    await prisma.user.updateMany({
      where: { role: { code: 'TEMP_TEST_ROLE' } },
      data: { roleId: adminRole.id },
    });

    // 1. Simpan backup user admin yang sudah ada agar database dapat dikembalikan utuh
    const existingAdmins = await prisma.user.findMany({
      where: { role: { code: 'ADMIN' } },
      select: { id: true, roleId: true },
    });

    // Buat temporary dummy role agar user lama sementara bukan ADMIN selama pengujian fresh bootstrap
    const dummyRole = await prisma.role.upsert({
      where: { code: 'TEMP_TEST_ROLE' },
      update: {},
      create: {
        id: '00000000-0000-4000-8000-000000000099',
        code: 'TEMP_TEST_ROLE',
        name: 'Temporary Test Role',
      },
    });

    // Pindahkan sementara admin lama ke dummy role
    if (existingAdmins.length > 0) {
      await prisma.user.updateMany({
        where: { id: { in: existingAdmins.map((a) => a.id) } },
        data: { roleId: dummyRole.id },
      });
    }

    try {
      // 2. Eksekusi bootstrap pertama kali saat tidak ada ADMIN di database
      const res1 = await bootstrapSystem();

      // Assertions untuk eksekusi pertama (fresh database condition)
      expect(res1.skipped).toBe(false);
      expect(res1.user).toBeDefined();
      expect(res1.user?.email).toBe('admin.fresh@stockflow.com');
      expect(res1.user?.mustChangePassword).toBe(true);
      expect(res1.organization).toBeDefined();
      expect(res1.organization?.id).toBeDefined();
      expect(res1.user?.organizationId).toBe(res1.organization?.id);

      // Verifikasi di database: password tersimpan dalam bentuk bcrypt hash, bukan plaintext
      const dbUser = await prisma.user.findUnique({
        where: { id: res1.user!.id },
      });

      expect(dbUser).toBeDefined();
      expect(dbUser?.passwordHash).not.toBe(securePass);
      expect(dbUser?.passwordHash.startsWith('$2')).toBe(true);

      // 3. Eksekusi bootstrap kedua kali (membuktikan one-time execution guard aktif dan tidak membuat duplikat)
      const res2 = await bootstrapSystem();
      expect(res2.skipped).toBe(true);
      expect(res2.existingAdminId).toBe(res1.user!.id);

      // Verifikasi jumlah admin tetap 1
      const currentAdminCount = await prisma.user.count({
        where: { role: { code: 'ADMIN' } },
      });
      expect(currentAdminCount).toBe(1);

    } finally {
      // 4. Cleanup: Hapus admin pengujian dan kembalikan role admin sebelumnya
      await prisma.session.deleteMany({ where: { user: { email: 'admin.fresh@stockflow.com' } } });
      await prisma.user.deleteMany({ where: { email: 'admin.fresh@stockflow.com' } });

      if (existingAdmins.length > 0) {
        await prisma.user.updateMany({
          where: { id: { in: existingAdmins.map((a) => a.id) } },
          data: { roleId: adminRole.id },
        });
      } else {
        await prisma.user.updateMany({
          where: { role: { code: 'TEMP_TEST_ROLE' } },
          data: { roleId: adminRole.id },
        });
      }

      await prisma.role.deleteMany({ where: { code: 'TEMP_TEST_ROLE' } });
    }
  });
});
