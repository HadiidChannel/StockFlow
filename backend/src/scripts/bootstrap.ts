import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

interface BootstrapArgs {
  orgName?: string;
  adminName?: string;
  adminEmail?: string;
  adminPassword?: string;
}

export async function bootstrapSystem(args?: BootstrapArgs) {
  const orgName = args?.orgName || process.env.INITIAL_ORG_NAME || 'PT StockFlow Distribusi Utama';
  const adminName = args?.adminName || process.env.INITIAL_ADMIN_NAME || 'Admin StockFlow';
  const adminEmail = (args?.adminEmail || process.env.INITIAL_ADMIN_EMAIL || 'admin@stockflow.com').trim().toLowerCase();
  const rawPassword = args?.adminPassword || process.env.INITIAL_ADMIN_PASSWORD || 'AdminStockFlow2026!';

  console.log('Memulai proses bootstrap sistem StockFlow...');

  return await prisma.$transaction(async (tx) => {
    // 1. Pastikan role ADMIN tersedia
    let adminRole = await tx.role.findUnique({
      where: { code: 'ADMIN' },
    });

    if (!adminRole) {
      adminRole = await tx.role.create({
        data: {
          id: '00000000-0000-4000-8000-000000000001',
          code: 'ADMIN',
          name: 'Administrator',
        },
      });
    }

    // 2. Periksa apakah organisasi sudah ada
    let org = await tx.organization.findFirst();
    if (!org) {
      org = await tx.organization.create({
        data: {
          name: orgName,
          code: 'ORG-MAIN',
          timezone: 'Asia/Makassar',
          currency: 'IDR',
        },
      });
      console.log(`Organisasi dibuat: ${org.name} (${org.id})`);
    } else {
      console.log(`Organisasi sudah ada: ${org.name} (${org.id})`);
    }

    // 3. Periksa apakah user dengan email tersebut sudah ada
    const existingUser = await tx.user.findUnique({
      where: { email: adminEmail },
    });

    if (existingUser) {
      console.log(`User admin dengan email ${adminEmail} sudah terdaftar.`);
      return { organization: org, user: existingUser };
    }

    // 4. Hash password
    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(rawPassword, salt);

    // 5. Buat user Admin
    const user = await tx.user.create({
      data: {
        organizationId: org.id,
        roleId: adminRole.id,
        name: adminName,
        email: adminEmail,
        passwordHash,
        status: 'ACTIVE',
        mustChangePassword: true,
        themePreference: 'SYSTEM',
      },
    });

    console.log(`User Admin berhasil dibuat: ${user.name} (${user.email})`);
    console.log('Flag must_change_password diaktifkan secara default.');

    return { organization: org, user };
  });
}

// Eksekusi langsung jika dipanggil via CLI
if (require.main === module) {
  bootstrapSystem()
    .then(() => {
      console.log('Bootstrap selesai dengan sukses.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Bootstrap gagal:', err);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
