const { PrismaClient } = require('../backend/node_modules/@prisma/client');
const bcrypt = require('../backend/node_modules/bcryptjs');

const prisma = new PrismaClient();

async function setup() {
  console.log('--- Setting up E2E Test Environment ---');
  
  // 1. Ensure Roles exist
  await prisma.role.upsert({
    where: { code: 'ADMIN' },
    update: {},
    create: { code: 'ADMIN', name: 'Administrator' },
  });
  await prisma.role.upsert({
    where: { code: 'WAREHOUSE_STAFF' },
    update: {},
    create: { code: 'WAREHOUSE_STAFF', name: 'Warehouse Staff' },
  });

  // 2. Ensure Organization exists
  let org = await prisma.organization.findFirst();
  if (!org) {
    org = await prisma.organization.create({
      data: {
        name: 'StockFlow Logistics PT',
        code: 'SFL',
        timezone: 'Asia/Jakarta',
      },
    });
    console.log('Created organization:', org.id);
  } else {
    console.log('Existing organization:', org.id);
  }

  // 3. Ensure Admin User exists with known test credentials
  const adminEmail = 'admin@stockflow.com';
  const adminPassword = 'AdminPassword2026!';
  const hashedPassword = await bcrypt.hash(adminPassword, 12);

  const adminRole = await prisma.role.findUnique({ where: { code: 'ADMIN' } });

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {
      passwordHash: hashedPassword,
      status: 'ACTIVE',
      mustChangePassword: false,
      roleId: adminRole.id,
    },
    create: {
      email: adminEmail,
      name: 'Super Admin',
      passwordHash: hashedPassword,
      roleId: adminRole.id,
      organizationId: org.id,
      status: 'ACTIVE',
      mustChangePassword: false,
    },
  });

  console.log('Verified Admin user:', admin.email, 'Role ID:', admin.roleId);
}

setup()
  .catch((err) => {
    console.error('E2E setup failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
