import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { PrismaClient } from '@prisma/client';
import { inventoryService } from '../src/modules/inventory/inventory.service';
import { productsService } from '../src/modules/products/products.service';
import { warehousesService } from '../src/modules/warehouses/warehouses.service';
import { ValidationError, ConflictError } from '../src/utils/app-error';

const prisma = new PrismaClient();

describe('Milestone 2 & 3: Inventory Integrity and Concurrency Hardening', () => {
  let orgId: string;
  let adminUserId: string;
  let testWarehouseId: string;
  let testProductId1: string;
  let testProductId2: string;
  let inactiveWarehouseId: string;
  let inactiveProductId: string;

  beforeAll(async () => {
    // Retrieve existing organization and admin user
    const org = await prisma.organization.findFirst();
    if (!org) throw new Error('Organization not found in test db');
    orgId = org.id;

    const admin = await prisma.user.findFirst({
      where: { organizationId: orgId, role: { code: 'ADMIN' } },
    });
    if (!admin) throw new Error('Admin user not found in test db');
    adminUserId = admin.id;

    // Retrieve or create a category
    let category = await prisma.category.findFirst({ where: { organizationId: orgId, isActive: true } });
    if (!category) {
      category = await prisma.category.create({
        data: {
          organizationId: orgId,
          name: 'Integrity Test Category',
          isActive: true,
          createdBy: adminUserId,
          updatedBy: adminUserId,
        },
      });
    }

    // Create active test warehouse
    const activeWh = await warehousesService.createWarehouse(
      {
        code: `WH-TEST-${Date.now().toString().slice(-4)}`,
        name: 'Active Test Warehouse',
        location: 'Surabaya',
        description: 'Test warehouse',
      },
      adminUserId,
      orgId
    );
    testWarehouseId = activeWh.id;

    // Create inactive test warehouse
    const inactWh = await warehousesService.createWarehouse(
      {
        code: `WH-INACT-${Date.now().toString().slice(-4)}`,
        name: 'Inactive Test Warehouse',
        location: 'Bandung',
      },
      adminUserId,
      orgId
    );
    await prisma.warehouse.update({
      where: { id: inactWh.id },
      data: { isActive: false },
    });
    inactiveWarehouseId = inactWh.id;

    // Create test products
    const p1 = await productsService.createProduct(
      {
        categoryId: category.id,
        sku: `SKU-INT1-${Date.now().toString().slice(-4)}`,
        name: 'Test Product 1',
        unit: 'PCS',
        minimumStock: 5,
      },
      adminUserId,
      orgId
    );
    testProductId1 = p1.id;

    const p2 = await productsService.createProduct(
      {
        categoryId: category.id,
        sku: `SKU-INT2-${Date.now().toString().slice(-4)}`,
        name: 'Test Product 2',
        unit: 'PCS',
        minimumStock: 5,
      },
      adminUserId,
      orgId
    );
    testProductId2 = p2.id;

    const pInact = await productsService.createProduct(
      {
        categoryId: category.id,
        sku: `SKU-INACT-${Date.now().toString().slice(-4)}`,
        name: 'Inactive Test Product',
        unit: 'PCS',
        minimumStock: 5,
      },
      adminUserId,
      orgId
    );
    await prisma.product.update({
      where: { id: pInact.id },
      data: { isActive: false },
    });
    inactiveProductId = pInact.id;
  });

  afterAll(async () => {
    // Cleanup created test records
    const whIds = [testWarehouseId, inactiveWarehouseId].filter(Boolean);
    const prodIds = [testProductId1, testProductId2, inactiveProductId].filter(Boolean);

    if (whIds.length > 0) {
      await prisma.stockMovement.deleteMany({
        where: { warehouseId: { in: whIds } },
      });
      await prisma.stockTransactionItem.deleteMany({
        where: { productId: { in: prodIds } },
      });
      await prisma.idempotencyRecord.deleteMany({
        where: { userId: adminUserId },
      });
      await prisma.stockTransaction.updateMany({
        where: { warehouseId: { in: whIds } },
        data: { correctionOfTransactionId: null },
      });
      await prisma.stockTransaction.deleteMany({
        where: { warehouseId: { in: whIds } },
      });
      await prisma.inventoryBalance.deleteMany({
        where: { warehouseId: { in: whIds } },
      });
      await prisma.warehouse.deleteMany({
        where: { id: { in: whIds } },
      });
    }

    if (prodIds.length > 0) {
      await prisma.product.deleteMany({
        where: { id: { in: prodIds } },
      });
    }

    await prisma.$disconnect();
  });

  describe('1. Duplicate Product Lines Validation (P1-10)', () => {
    it('harus menolak transaksi Stock In dengan produk duplikat', async () => {
      await expect(
        inventoryService.processStockIn(
          {
            warehouseId: testWarehouseId,
            items: [
              { productId: testProductId1, quantity: 10 },
              { productId: testProductId1, quantity: 5 },
            ],
            note: 'Duplicate test',
          },
          adminUserId,
          'Admin',
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });

    it('harus menolak transaksi Stock Out dengan produk duplikat', async () => {
      await expect(
        inventoryService.processStockOut(
          {
            warehouseId: testWarehouseId,
            items: [
              { productId: testProductId1, quantity: 2 },
              { productId: testProductId1, quantity: 3 },
            ],
            note: 'Duplicate test',
          },
          adminUserId,
          'Admin',
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });
  });

  describe('2. Active Status Enforcement on Transactions (P1-08)', () => {
    it('harus menolak Stock In pada gudang yang nonaktif', async () => {
      await expect(
        inventoryService.processStockIn(
          {
            warehouseId: inactiveWarehouseId,
            items: [{ productId: testProductId1, quantity: 10 }],
          },
          adminUserId,
          'Admin',
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });

    it('harus menolak Stock In pada produk yang nonaktif', async () => {
      await expect(
        inventoryService.processStockIn(
          {
            warehouseId: testWarehouseId,
            items: [{ productId: inactiveProductId, quantity: 10 }],
          },
          adminUserId,
          'Admin',
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });
  });

  describe('3. Positive Balance Deactivation Guards (P1-08)', () => {
    beforeAll(async () => {
      // Put positive stock on testProductId1 in testWarehouseId
      await inventoryService.processStockIn(
        {
          warehouseId: testWarehouseId,
          items: [{ productId: testProductId1, quantity: 50 }],
          note: 'Stock for deactivation guard test',
        },
        adminUserId,
        'Admin',
        orgId
      );
    });

    it('harus menolak penonaktifan produk yang masih memiliki saldo stok positif', async () => {
      await expect(
        productsService.updateProduct(
          testProductId1,
          {
            isActive: false,
          },
          adminUserId,
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });

    it('harus menolak penonaktifan gudang yang masih memiliki saldo stok positif', async () => {
      await expect(
        warehousesService.updateWarehouse(
          testWarehouseId,
          {
            isActive: false,
          },
          adminUserId,
          orgId
        )
      ).rejects.toThrow(ValidationError);
    });
  });

  describe('4. Idempotency Key Semantics (P1-09)', () => {
    const key = `test-idemp-${Date.now()}`;
    let firstResult: any;

    it('harus memproses request pertama kali dan menyimpan idempotency record', async () => {
      firstResult = await inventoryService.processStockIn(
        {
          warehouseId: testWarehouseId,
          items: [{ productId: testProductId2, quantity: 20 }],
          note: 'Idempotency stock in test',
        },
        adminUserId,
        'Admin',
        orgId,
        undefined,
        key
      );

      expect(firstResult).toBeDefined();
      expect(firstResult.id).toBeDefined();
      expect(firstResult.referenceNumber).toBeDefined();
    });

    it('harus mengembalikan response yang sama persis jika dipanggil ulang dengan payload identik (replay)', async () => {
      const secondResult = await inventoryService.processStockIn(
        {
          warehouseId: testWarehouseId,
          items: [{ productId: testProductId2, quantity: 20 }],
          note: 'Idempotency stock in test',
        },
        adminUserId,
        'Admin',
        orgId,
        undefined,
        key
      );

      expect(secondResult.id).toBe(firstResult.id);
      expect(secondResult.referenceNumber).toBe(firstResult.referenceNumber);
    });

    it('harus melempar 409 Conflict jika key yang sama digunakan dengan payload berbeda', async () => {
      await expect(
        inventoryService.processStockIn(
          {
            warehouseId: testWarehouseId,
            items: [{ productId: testProductId2, quantity: 99 }],
            note: 'Idempotency stock in test',
          },
          adminUserId,
          'Admin',
          orgId,
          undefined,
          key
        )
      ).rejects.toThrow(ConflictError);
    });
  });

  describe('5. Full Reversal and Reversal Idempotency', () => {
    let txToReverse: any;
    const reversalKey = `test-rev-idemp-${Date.now()}`;

    beforeAll(async () => {
      txToReverse = await inventoryService.processStockIn(
        {
          warehouseId: testWarehouseId,
          items: [{ productId: testProductId2, quantity: 15 }],
          note: 'Transaction to be reversed',
        },
        adminUserId,
        'Admin',
        orgId
      );
    });

    it('harus membalik transaksi dengan benar dan membuat header reversal berkait', async () => {
      const reversalResult = await inventoryService.processReversal(
        txToReverse.id,
        { note: 'Test pembatalan transaksi' },
        adminUserId,
        'Admin',
        orgId,
        undefined,
        reversalKey
      );

      expect(reversalResult).toBeDefined();
      expect(reversalResult.correctionOfTransactionId).toBe(txToReverse.id);
      expect(reversalResult.type).toBe('OUT');
    });

    it('harus replay pembalikan jika dipanggil ulang dengan idempotency key dan payload identik', async () => {
      const replayResult = await inventoryService.processReversal(
        txToReverse.id,
        { note: 'Test pembatalan transaksi' },
        adminUserId,
        'Admin',
        orgId,
        undefined,
        reversalKey
      );

      expect(replayResult.correctionOfTransactionId).toBe(txToReverse.id);
    });

    it('harus menolak pembalikan kedua jika dipanggil tanpa idempotency key', async () => {
      await expect(
        inventoryService.processReversal(
          txToReverse.id,
          { note: 'Pembalikan ulang tanpa key' },
          adminUserId,
          'Admin',
          orgId
        )
      ).rejects.toThrow(ConflictError);
    });
  });

  describe('6. Database CHECK Constraints (P0-04)', () => {
    it('harus menolak kuantitas negatif pada inventory_balances di level MySQL InnoDB', async () => {
      await expect(
        prisma.$executeRaw`
          INSERT INTO inventory_balances (id, product_id, warehouse_id, quantity, created_at, updated_at)
          VALUES (UUID(), ${testProductId1}, ${testWarehouseId}, -10, NOW(3), NOW(3))
        `
      ).rejects.toThrow();
    });

    it('harus menolak kuantitas nol atau negatif pada stock_transaction_items di level MySQL InnoDB', async () => {
      await expect(
        prisma.$executeRaw`
          INSERT INTO stock_transaction_items (id, transaction_id, product_id, product_name_snapshot, sku_snapshot, unit_snapshot, quantity, balance_before, balance_after)
          VALUES (UUID(), UUID(), ${testProductId1}, 'Snapshot', 'SKU-TEST', 'PCS', -5, 0, 0)
        `
      ).rejects.toThrow();
    });
  });

  describe('7. Concurrency and Deterministic Lock Ordering (P1-10)', () => {
    it('harus dapat mengeksekusi multi-item transactions secara paralel tanpa deadlock', async () => {
      const promises = [
        inventoryService.processStockIn(
          {
            warehouseId: testWarehouseId,
            items: [
              { productId: testProductId2, quantity: 1 },
              { productId: testProductId1, quantity: 2 },
            ],
            note: 'Concurrent 1',
          },
          adminUserId,
          'Admin',
          orgId
        ),
        inventoryService.processStockIn(
          {
            warehouseId: testWarehouseId,
            items: [
              { productId: testProductId1, quantity: 3 },
              { productId: testProductId2, quantity: 1 },
            ],
            note: 'Concurrent 2',
          },
          adminUserId,
          'Admin',
          orgId
        ),
        inventoryService.processStockOut(
          {
            warehouseId: testWarehouseId,
            items: [
              { productId: testProductId2, quantity: 1 },
              { productId: testProductId1, quantity: 1 },
            ],
            note: 'Concurrent 3',
          },
          adminUserId,
          'Admin',
          orgId
        ),
      ];

      const results = await Promise.all(promises);
      expect(results).toHaveLength(3);
      for (const res of results) {
        expect(res.id).toBeDefined();
      }
    });
  });
});
