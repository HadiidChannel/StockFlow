import { PrismaClient, TransactionType } from '@prisma/client';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { InventoryService } from '../src/modules/inventory/inventory.service';

const prisma = new PrismaClient();
const inventoryService = new InventoryService();

async function main() {
  console.log('--- Memulai Seeding Data Demo StockFlow ---');

  // 1. Seed Roles
  const adminRole = await prisma.role.upsert({
    where: { code: 'ADMIN' },
    update: { name: 'Administrator' },
    create: {
      id: '00000000-0000-4000-8000-000000000001',
      code: 'ADMIN',
      name: 'Administrator',
    },
  });

  const staffRole = await prisma.role.upsert({
    where: { code: 'WAREHOUSE_STAFF' },
    update: { name: 'Warehouse Staff' },
    create: {
      id: '00000000-0000-4000-8000-000000000002',
      code: 'WAREHOUSE_STAFF',
      name: 'Warehouse Staff',
    },
  });

  // 2. Organization
  let org = await prisma.organization.findFirst();
  if (!org) {
    org = await prisma.organization.create({
      data: {
        name: 'PT StockFlow Logistik Nusantara',
        code: 'ORG-STOKFLOW',
        address: 'Jl. Raya Industri Pergudangan No. 88, Cakung, Jakarta Timur',
        phone: '+62 21 88997700',
        email: 'ops@stockflow.com',
        timezone: 'Asia/Jakarta',
        currency: 'IDR',
      },
    });
    console.log(`Organisasi dibuat: ${org.name}`);
  }

  // 3. Demo Users
  const salt = await bcrypt.genSalt(12);
  const adminPassHash = await bcrypt.hash('AdminStockFlow2026!', salt);
  const staffPassHash = await bcrypt.hash('StaffStockFlow2026!', salt);

  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@stockflow.com' },
    update: {
      name: 'Budi Santoso (Admin)',
      passwordHash: adminPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
    },
    create: {
      organizationId: org.id,
      roleId: adminRole.id,
      name: 'Budi Santoso (Admin)',
      email: 'admin@stockflow.com',
      passwordHash: adminPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
      themePreference: 'SYSTEM',
    },
  });

  const staffJkt = await prisma.user.upsert({
    where: { email: 'staff.jakarta@stockflow.com' },
    update: {
      name: 'Ahmad Fauzi (Staff JKT)',
      passwordHash: staffPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
    },
    create: {
      organizationId: org.id,
      roleId: staffRole.id,
      name: 'Ahmad Fauzi (Staff JKT)',
      email: 'staff.jakarta@stockflow.com',
      passwordHash: staffPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
      themePreference: 'SYSTEM',
      createdBy: adminUser.id,
    },
  });

  const staffSub = await prisma.user.upsert({
    where: { email: 'staff.surabaya@stockflow.com' },
    update: {
      name: 'Rian Hidayat (Staff SUB)',
      passwordHash: staffPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
    },
    create: {
      organizationId: org.id,
      roleId: staffRole.id,
      name: 'Rian Hidayat (Staff SUB)',
      email: 'staff.surabaya@stockflow.com',
      passwordHash: staffPassHash,
      status: 'ACTIVE',
      mustChangePassword: false,
      themePreference: 'SYSTEM',
      createdBy: adminUser.id,
    },
  });

  console.log('User demo siap: admin@stockflow.com, staff.jakarta@stockflow.com, staff.surabaya@stockflow.com');

  // 4. Warehouses
  const whJkt = await prisma.warehouse.upsert({
    where: { organizationId_code: { organizationId: org.id, code: 'WH_JKT_01' } },
    update: { name: 'Gudang Utama Cakung Jakarta', isActive: true },
    create: {
      organizationId: org.id,
      name: 'Gudang Utama Cakung Jakarta',
      code: 'WH_JKT_01',
      location: 'Kawasan Industri Cakung, Jakarta Timur',
      description: 'Pusat distribusi barang regional barat',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  const whSub = await prisma.warehouse.upsert({
    where: { organizationId_code: { organizationId: org.id, code: 'WH_SUB_01' } },
    update: { name: 'Gudang Hub Rungkut Surabaya', isActive: true },
    create: {
      organizationId: org.id,
      name: 'Gudang Hub Rungkut Surabaya',
      code: 'WH_SUB_01',
      location: 'SIER Rungkut Industri, Surabaya',
      description: 'Pusat distribusi barang regional timur',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  const whBdg = await prisma.warehouse.upsert({
    where: { organizationId_code: { organizationId: org.id, code: 'WH_BDG_01' } },
    update: { name: 'Gudang Transit Gedebage Bandung', isActive: true },
    create: {
      organizationId: org.id,
      name: 'Gudang Transit Gedebage Bandung',
      code: 'WH_BDG_01',
      location: 'Kawasan Petikemas Gedebage, Bandung',
      description: 'Fasilitas buffer dan transit stok Jawa Barat',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  // Assign staff to warehouses
  await prisma.userWarehouseAssignment.deleteMany({
    where: { userId: { in: [staffJkt.id, staffSub.id] } },
  });

  await prisma.userWarehouseAssignment.createMany({
    data: [
      { userId: staffJkt.id, warehouseId: whJkt.id, assignedBy: adminUser.id },
      { userId: staffJkt.id, warehouseId: whBdg.id, assignedBy: adminUser.id },
      { userId: staffSub.id, warehouseId: whSub.id, assignedBy: adminUser.id },
    ],
  });

  // 5. Categories
  const catNetwork = await prisma.category.upsert({
    where: { organizationId_name: { organizationId: org.id, name: 'Hardware & Komponen Jaringan' } },
    update: { isActive: true },
    create: {
      organizationId: org.id,
      name: 'Hardware & Komponen Jaringan',
      description: 'Switch, Router, Access Point, SFP Module',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  const catCables = await prisma.category.upsert({
    where: { organizationId_name: { organizationId: org.id, name: 'Kabel & Aksesoris Transmisi' } },
    update: { isActive: true },
    create: {
      organizationId: org.id,
      name: 'Kabel & Aksesoris Transmisi',
      description: 'Kabel UTP, Fiber Optic, Patch Cord, Modular Jack',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  const catServer = await prisma.category.upsert({
    where: { organizationId_name: { organizationId: org.id, name: 'Server & Rack Infrastructure' } },
    update: { isActive: true },
    create: {
      organizationId: org.id,
      name: 'Server & Rack Infrastructure',
      description: 'Rackmount Server, PDU, UPS, Cabinet Rack',
      isActive: true,
      createdBy: adminUser.id,
      updatedBy: adminUser.id,
    },
  });

  // 6. Products
  const productsData = [
    {
      name: 'Kabel UTP Cat6 305m High Speed LSZH',
      sku: 'KBL-UTP-CAT6',
      categoryId: catCables.id,
      unit: 'ROLL',
      minimumStock: '10.000',
      costPrice: '1850000.00',
      description: 'Kabel twisted pair 23 AWG tembaga murni untuk instalasi gigabit indoor',
    },
    {
      name: 'Managed Switch 24-Port Gigabit PoE+ 370W',
      sku: 'SW-MNG-24P',
      categoryId: catNetwork.id,
      unit: 'UNIT',
      minimumStock: '5.000',
      costPrice: '4500000.00',
      description: 'Layer 2+ managed switch dengan 24 port PoE+ dan 4 port 10G SFP+ uplink',
    },
    {
      name: 'Enterprise Router Multi-WAN Failover 10G',
      sku: 'RTR-ENT-X1',
      categoryId: catNetwork.id,
      unit: 'UNIT',
      minimumStock: '3.000',
      costPrice: '8200000.00',
      description: 'Core gateway router throughput 10 Gbps dengan hardware acceleration',
    },
    {
      name: 'Server Rackmount 2U Dual Xeon Scalable',
      sku: 'SRV-RACK-2U',
      categoryId: catServer.id,
      unit: 'UNIT',
      minimumStock: '2.000',
      costPrice: '35000000.00',
      description: 'Dual Intel Xeon Silver 4314, 128GB ECC DDR4, Redundant PSU 800W',
    },
    {
      name: 'Patch Cord RJ45 Cat6 2 Meter Snagless Blue',
      sku: 'PATCH-CRD-2M',
      categoryId: catCables.id,
      unit: 'PCS',
      minimumStock: '50.000',
      costPrice: '35000.00',
      description: 'Kabel patch cord pabrikan dengan konektor gold plated 50 micron',
    },
    {
      name: 'SFP+ 10GBASE-LR Transceiver Module 1310nm',
      sku: 'SFP-10G-LR',
      categoryId: catNetwork.id,
      unit: 'PCS',
      minimumStock: '8.000',
      costPrice: '950000.00',
      description: 'Single-mode optical transceiver jarak jangkauan 10 kilometer LC Duplex',
    },
  ];

  const createdProducts: any[] = [];
  for (const p of productsData) {
    const prod = await prisma.product.upsert({
      where: { organizationId_sku: { organizationId: org.id, sku: p.sku } },
      update: {
        name: p.name,
        minimumStock: p.minimumStock,
        costPrice: p.costPrice,
      },
      create: {
        organizationId: org.id,
        categoryId: p.categoryId,
        name: p.name,
        sku: p.sku,
        unit: p.unit,
        minimumStock: p.minimumStock,
        costPrice: p.costPrice,
        description: p.description,
        isActive: true,
        createdBy: adminUser.id,
        updatedBy: adminUser.id,
      },
    });
    createdProducts.push(prod);
  }

  console.log(`Produk demo berhasil dibuat: ${createdProducts.length} produk.`);

  // 7. Initial Inventory Transactions if none exist
  const existingTxCount = await prisma.stockTransaction.count();
  if (existingTxCount === 0) {
    console.log('Membuat transaksi awal untuk data demo visual dan laporan...');

    // Product map by SKU
    const pBySku = new Map<string, any>(createdProducts.map((p) => [p.sku, p]));

    // Transaction 1: Initial Stock In Jakarta (4 days ago)
    const inJkt = await inventoryService.processStockIn(
      {
        warehouseId: whJkt.id,
        note: 'Penerimaan stok batch awal dari supplier pusat',
        externalReference: 'PO-2026-001',
        items: [
          { productId: pBySku.get('KBL-UTP-CAT6').id, quantity: '50.000' },
          { productId: pBySku.get('SW-MNG-24P').id, quantity: '15.000' },
          { productId: pBySku.get('RTR-ENT-X1').id, quantity: '8.000' },
          { productId: pBySku.get('SFP-10G-LR').id, quantity: '25.000' },
          { productId: pBySku.get('PATCH-CRD-2M').id, quantity: '200.000' },
          { productId: pBySku.get('SRV-RACK-2U').id, quantity: '4.000' },
        ],
      },
      adminUser.id,
      adminUser.name,
      org.id
    );

    // Transaction 2: Initial Stock In Surabaya (3 days ago)
    const inSub = await inventoryService.processStockIn(
      {
        warehouseId: whSub.id,
        note: 'Pengiriman batch inventaris cabang Jawa Timur',
        externalReference: 'PO-2026-002',
        items: [
          { productId: pBySku.get('KBL-UTP-CAT6').id, quantity: '30.000' },
          { productId: pBySku.get('SW-MNG-24P').id, quantity: '10.000' },
          { productId: pBySku.get('PATCH-CRD-2M').id, quantity: '100.000' },
          { productId: pBySku.get('SFP-10G-LR').id, quantity: '12.000' },
        ],
      },
      staffSub.id,
      staffSub.name,
      org.id,
      [whSub.id]
    );

    // Transaction 3: Stock Out Jakarta (2 days ago)
    const outJkt = await inventoryService.processStockOut(
      {
        warehouseId: whJkt.id,
        note: 'Pengeluaran material proyek ekspansi data center klien',
        externalReference: 'DO-2026-015',
        items: [
          { productId: pBySku.get('KBL-UTP-CAT6').id, quantity: '15.000' },
          { productId: pBySku.get('SW-MNG-24P').id, quantity: '8.000' },
          { productId: pBySku.get('PATCH-CRD-2M').id, quantity: '80.000' },
        ],
      },
      staffJkt.id,
      staffJkt.name,
      org.id,
      [whJkt.id, whBdg.id]
    );

    // Transaction 4: Stock Out Surabaya (1 day ago)
    const outSub = await inventoryService.processStockOut(
      {
        warehouseId: whSub.id,
        note: 'Fasilitasi instalasi jaringan kampus mitra Surabaya',
        externalReference: 'DO-2026-018',
        items: [
          { productId: pBySku.get('SW-MNG-24P').id, quantity: '4.000' },
          { productId: pBySku.get('SFP-10G-LR').id, quantity: '5.000' },
        ],
      },
      staffSub.id,
      staffSub.name,
      org.id,
      [whSub.id]
    );

    // Transaction 5: Stock In Bandung (today)
    const inBdg = await inventoryService.processStockIn(
      {
        warehouseId: whBdg.id,
        note: 'Alokasi stok transit koridor Priangan Barat',
        externalReference: 'PO-2026-003',
        items: [
          { productId: pBySku.get('KBL-UTP-CAT6').id, quantity: '20.000' },
          { productId: pBySku.get('PATCH-CRD-2M').id, quantity: '50.000' },
          { productId: pBySku.get('SRV-RACK-2U').id, quantity: '2.000' },
        ],
      },
      adminUser.id,
      adminUser.name,
      org.id
    );

    const daysAgo = (d: number) => {
      const date = new Date();
      date.setDate(date.getDate() - d);
      return date;
    };

    const updateDates = async (txId: string, d: number) => {
      const targetDate = daysAgo(d);
      await prisma.stockTransaction.update({
        where: { id: txId },
        data: { postedAt: targetDate, createdAt: targetDate },
      });
      await prisma.stockMovement.updateMany({
        where: { transactionId: txId },
        data: { createdAt: targetDate },
      });
    };

    await updateDates(inJkt.id, 4);
    await updateDates(inSub.id, 3);
    await updateDates(outJkt.id, 2);
    await updateDates(outSub.id, 1);
    await updateDates(inBdg.id, 0);

    console.log('Transaksi demo awal dan pergerakan stok berhasil dimuat.');
  }

  console.log('--- Selesai Seeding Data Demo ---');
}

main()
  .catch((e) => {
    console.error('Error saat seeding data:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
