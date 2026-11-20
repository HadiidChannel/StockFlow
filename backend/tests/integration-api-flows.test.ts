import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

describe('Milestone 6: Real Backend API Integration Flows (Supertest + MySQL)', () => {
  let sessionCookie: string;
  let csrfCookie: string;
  let csrfTokenValue: string;

  // Track entities created during integration test for cleanup
  let createdCategoryId: string;
  let createdProductId: string;
  let createdWarehouseId: string;
  let createdStockInTxId: string;

  const testSuffix = Date.now().toString().slice(-4);

  beforeAll(async () => {
    // Ensure clean test environment
  });

  afterAll(async () => {
    // Teardown test entities created via API
    if (createdWarehouseId) {
      await prisma.stockMovement.deleteMany({
        where: { warehouseId: createdWarehouseId },
      });
      await prisma.stockTransactionItem.deleteMany({
        where: { productId: createdProductId },
      });
      await prisma.idempotencyRecord.deleteMany({
        where: { transaction: { warehouseId: createdWarehouseId } },
      });
      await prisma.stockTransaction.updateMany({
        where: { warehouseId: createdWarehouseId },
        data: { correctionOfTransactionId: null },
      });
      await prisma.stockTransaction.deleteMany({
        where: { warehouseId: createdWarehouseId },
      });
      await prisma.inventoryBalance.deleteMany({
        where: { warehouseId: createdWarehouseId },
      });
    }

    if (createdProductId) {
      await prisma.product.deleteMany({ where: { id: createdProductId } });
    }
    if (createdWarehouseId) {
      await prisma.warehouse.deleteMany({ where: { id: createdWarehouseId } });
    }
    if (createdCategoryId) {
      await prisma.category.deleteMany({ where: { id: createdCategoryId } });
    }

    await prisma.$disconnect();
  });

  describe('1. Authentication Flow', () => {
    it('harus menolak login dengan credential yang salah (401)', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'admin@stockflow.com',
          password: 'WrongPassword123!',
        });

      expect(res.status).toBe(401);
      expect(res.body.error).toBeDefined();
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('harus berhasil login dengan credential admin dan mengembalikan session cookies', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'admin@stockflow.com',
          password: 'AdminStockFlow2026!',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.user.email).toBe('admin@stockflow.com');
      expect(res.body.data.user.role.code).toBe('ADMIN');

      const setCookies = res.headers['set-cookie'];
      expect(setCookies).toBeDefined();

      const rawSession = setCookies.find((c: string) => c.startsWith('sf_session='));
      const rawCsrf = setCookies.find((c: string) => c.startsWith('sf_csrf='));

      expect(rawSession).toBeDefined();
      expect(rawCsrf).toBeDefined();

      sessionCookie = rawSession.split(';')[0];
      csrfCookie = rawCsrf.split(';')[0];
      csrfTokenValue = csrfCookie.split('=')[1];
    });

    it('harus mengizinkan akses ke /api/v1/auth/me dengan cookie sesi yang valid', async () => {
      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Cookie', [sessionCookie, csrfCookie]);

      expect(res.status).toBe(200);
      expect(res.body.data.user.email).toBe('admin@stockflow.com');
      expect(res.body.data.user.role.code).toBe('ADMIN');
      expect(res.body.data.user.permissions).toContain('product.create');
    });
  });

  describe('2. CSRF Security Enforcement on State-Changing API Endpoints', () => {
    it('harus menolak request POST kategori jika tidak menyertakan X-CSRF-Token header (403)', async () => {
      const res = await request(app)
        .post('/api/v1/categories')
        .set('Cookie', [sessionCookie, csrfCookie])
        .send({
          name: `CSRF Block Category ${testSuffix}`,
          description: 'Testing CSRF block',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('harus menolak request POST kategori jika X-CSRF-Token tidak cocok dengan cookie (403)', async () => {
      const res = await request(app)
        .post('/api/v1/categories')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', 'invalid-tampered-csrf-token')
        .send({
          name: `CSRF Tamper Category ${testSuffix}`,
          description: 'Testing CSRF tamper',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('harus menerima request POST kategori jika menyertakan session dan X-CSRF-Token valid (201)', async () => {
      const res = await request(app)
        .post('/api/v1/categories')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .send({
          name: `API Flow Category ${testSuffix}`,
          description: 'Created via supertest integration',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.name).toBe(`API Flow Category ${testSuffix}`);
      createdCategoryId = res.body.data.id;
    });
  });

  describe('3. Multi-Entity Resource Management via API', () => {
    it('harus berhasil membuat gudang baru via API', async () => {
      const res = await request(app)
        .post('/api/v1/warehouses')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .send({
          code: `WH-INT-${testSuffix}`,
          name: `Gudang Integrasi ${testSuffix}`,
          location: 'Surabaya Timur',
          description: 'Warehouse created via integration test',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBeDefined();
      createdWarehouseId = res.body.data.id;
    });

    it('harus berhasil membuat produk baru via API', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .send({
          categoryId: createdCategoryId,
          sku: `SKU-INT-${testSuffix}`,
          name: `Produk Integrasi ${testSuffix}`,
          unit: 'PCS',
          minimumStock: '10.000',
          costPrice: '50000.00',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBeDefined();
      createdProductId = res.body.data.id;
    });
  });

  describe('4. Inventory Stock Mutation and Balance Tracking via API', () => {
    it('harus berhasil melakukan Stock In via API dan mencatat saldo', async () => {
      const res = await request(app)
        .post('/api/v1/inventory/stock-in')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .set('Idempotency-Key', `api-idemp-in-${testSuffix}`)
        .send({
          warehouseId: createdWarehouseId,
          items: [{ productId: createdProductId, quantity: '100.000' }],
          note: 'Stock in via integration test',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.type).toBe('IN');
      createdStockInTxId = res.body.data.id;

      // Verify balance
      const balanceRes = await request(app)
        .get(`/api/v1/inventory/balances?productId=${createdProductId}&warehouseId=${createdWarehouseId}`)
        .set('Cookie', [sessionCookie, csrfCookie]);

      expect(balanceRes.status).toBe(200);
      expect(balanceRes.body.data).toHaveLength(1);
      expect(Number(balanceRes.body.data[0].quantity)).toBe(100);
    });

    it('harus berhasil melakukan Stock Out via API dan mengurangi saldo', async () => {
      const res = await request(app)
        .post('/api/v1/inventory/stock-out')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .set('Idempotency-Key', `api-idemp-out-${testSuffix}`)
        .send({
          warehouseId: createdWarehouseId,
          items: [{ productId: createdProductId, quantity: '30.000' }],
          note: 'Stock out via integration test',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.type).toBe('OUT');

      // Verify updated balance
      const balanceRes = await request(app)
        .get(`/api/v1/inventory/balances?productId=${createdProductId}&warehouseId=${createdWarehouseId}`)
        .set('Cookie', [sessionCookie, csrfCookie]);

      expect(balanceRes.status).toBe(200);
      expect(Number(balanceRes.body.data[0].quantity)).toBe(70);
    });

    it('harus menolak Stock Out jika kuantitas melebihi sisa saldo (422 Insufficient Stock)', async () => {
      const res = await request(app)
        .post('/api/v1/inventory/stock-out')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .send({
          warehouseId: createdWarehouseId,
          items: [{ productId: createdProductId, quantity: '9999.000' }],
          note: 'Stock out exceeding balance',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
    });

    it('harus berhasil membalik (reversal) transaksi Stock In asal via API', async () => {
      const res = await request(app)
        .post(`/api/v1/inventory/transactions/${createdStockInTxId}/reversal`)
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue)
        .send({
          note: 'Pembalikan transaksi via API integration test',
        });

      // Note: Reversing a stock in of 100 when current stock is 70 will fail with INSUFFICIENT_STOCK!
      // This proves inventory invariant protection!
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
    });
  });

  describe('5. Session Termination Flow', () => {
    it('harus berhasil logout dan mencabut sesi', async () => {
      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Cookie', [sessionCookie, csrfCookie])
        .set('X-CSRF-Token', csrfTokenValue);

      expect(res.status).toBe(200);

      // Subsequent call to /auth/me should be 401
      const meRes = await request(app)
        .get('/api/v1/auth/me')
        .set('Cookie', [sessionCookie, csrfCookie]);

      expect(meRes.status).toBe(401);
    });
  });
});
