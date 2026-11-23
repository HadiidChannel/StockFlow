import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import fs from 'fs';

const prisma = new PrismaClient();

const INSECURE_DEFAULT_PASSWORDS = [
  'AdminStockFlow2026!',
  'password',
  'changeme',
  'admin12345678',
  'Admin12345678!',
  'secret',
];

function readSecretFileOrEnv(envVar: string, fileEnvVar: string): string | undefined {
  const filePath = process.env[fileEnvVar];
  if (filePath && fs.existsSync(filePath)) {
    try {
      return fs.readFileSync(filePath, 'utf8').trim();
    } catch (err: any) {
      console.error(`Gagal membaca secret file dari ${filePath}: ${err.message}`);
    }
  }
  return process.env[envVar];
}

interface BootstrapArgs {
  orgName?: string;
  adminName?: string;
  adminEmail?: string;
  adminPassword?: string;
}

function validatePasswordPolicy(password: string): void {
  if (password.length < 12) {
    throw new Error('Password bootstrap minimal 12 karakter.');
  }
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);

  if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
    throw new Error(
      'Password bootstrap harus memenuhi kebijakan keamanan: memuat huruf besar, huruf kecil, angka, dan karakter khusus.'
    );
  }
}

export async function bootstrapSystem(args?: BootstrapArgs) {
  const isProduction = process.env.NODE_ENV === 'production';

  const orgName = args?.orgName || process.env.INITIAL_ORG_NAME || (isProduction ? undefined : 'PT StockFlow Logistik Nusantara');
  const adminName = args?.adminName || process.env.INITIAL_ADMIN_NAME || (isProduction ? undefined : 'Admin Utama');
  const rawEmail =
    args?.adminEmail ||
    readSecretFileOrEnv('INITIAL_ADMIN_EMAIL', 'INITIAL_ADMIN_EMAIL_FILE') ||
    (isProduction ? undefined : 'admin@stockflow.com');
  const adminEmail = rawEmail?.trim().toLowerCase();

  const rawPassword =
    args?.adminPassword ||
    readSecretFileOrEnv('INITIAL_ADMIN_PASSWORD', 'INITIAL_ADMIN_PASSWORD_FILE');

  if (isProduction) {
    if (!orgName) {
      throw new Error('INITIAL_ORG_NAME wajib diisi pada environment production.');
    }
    if (!adminName) {
      throw new Error('INITIAL_ADMIN_NAME wajib diisi pada environment production.');
    }
    if (!adminEmail) {
      throw new Error('INITIAL_ADMIN_EMAIL wajib diisi pada environment production.');
    }
    if (!rawPassword) {
      throw new Error(
        'INITIAL_ADMIN_PASSWORD atau INITIAL_ADMIN_PASSWORD_FILE wajib diisi pada environment production melalui secret aman.'
      );
    }
    if (INSECURE_DEFAULT_PASSWORDS.includes(rawPassword)) {
      throw new Error(
        'INITIAL_ADMIN_PASSWORD pada production tidak boleh menggunakan password default development.'
      );
    }
    validatePasswordPolicy(rawPassword);
  }

  const effectivePassword = rawPassword || 'AdminStockFlow2026!';
  validatePasswordPolicy(effectivePassword);

  console.log('Memulai proses inisialisasi (bootstrap) satu kali StockFlow...');

  return await prisma.$transaction(async (tx) => {
    // 1. One-time execution guard: Cek apakah sudah ada role ADMIN dan user ADMIN aktif
    const existingAdmin = await tx.user.findFirst({
      where: {
        role: { code: 'ADMIN' },
      },
    });

    if (existingAdmin) {
      console.log('Bootstrap dibatalkan: Akun Administrator sudah ada pada sistem.');
      return { skipped: true, existingAdminId: existingAdmin.id };
    }

    // 2. Pastikan role default ADMIN dan WAREHOUSE_STAFF tersedia
    let adminRole = await tx.role.findUnique({ where: { code: 'ADMIN' } });
    if (!adminRole) {
      adminRole = await tx.role.create({
        data: {
          id: '00000000-0000-4000-8000-000000000001',
          code: 'ADMIN',
          name: 'Administrator',
        },
      });
    }

    let staffRole = await tx.role.findUnique({ where: { code: 'WAREHOUSE_STAFF' } });
    if (!staffRole) {
      staffRole = await tx.role.create({
        data: {
          id: '00000000-0000-4000-8000-000000000002',
          code: 'WAREHOUSE_STAFF',
          name: 'Warehouse Staff',
        },
      });
    }

    // 3. Inisialisasi Organisasi
    let org = await tx.organization.findFirst();
    if (!org) {
      org = await tx.organization.create({
        data: {
          name: orgName!,
          code: 'ORG-MAIN',
          timezone: 'Asia/Makassar',
          currency: 'IDR',
        },
      });
      console.log(`Organisasi diinisialisasi: ${org.name}`);
    }

    // 4. Hash password dengan bcrypt cost factor 12
    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(effectivePassword, salt);

    // 5. Buat initial administrator dengan flag mustChangePassword: true
    const user = await tx.user.create({
      data: {
        organizationId: org.id,
        roleId: adminRole.id,
        name: adminName!,
        email: adminEmail!,
        passwordHash,
        status: 'ACTIVE',
        mustChangePassword: true,
        themePreference: 'SYSTEM',
      },
    });

    console.log(`Administrator awal berhasil dibuat: ${user.name} (${user.email})`);
    console.log('Status: must_change_password diaktifkan secara wajib demi keamanan akun awal.');

    return { skipped: false, organization: org, user };
  });
}

if (require.main === module) {
  bootstrapSystem()
    .then((result) => {
      console.log('Proses bootstrap selesai.', result.skipped ? '(Sudah pernah diinisialisasi)' : '(Inisialisasi berhasil)');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Proses bootstrap gagal:', err.message);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
