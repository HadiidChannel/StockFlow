import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../database/client';
import {
  NotFoundError,
  ValidationError,
  InsufficientStockError,
  ConflictError,
  ForbiddenError,
} from '../../utils/app-error';
import { getNextSequenceNumber } from '../../utils/sequence';
import { StockInInput, StockOutInput, ReversalInput } from './inventory.dto';

async function withDeadlockRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  let attempt = 0;
  while (true) {
    try {
      return await fn();
    } catch (err: any) {
      attempt++;
      const isDeadlock =
        err?.code === 'P2034' ||
        err?.message?.includes('Deadlock') ||
        err?.message?.includes('1213') ||
        err?.meta?.code === 1213 ||
        err?.meta?.code === '1213';

      if (isDeadlock && attempt <= maxRetries) {
        const jitter = Math.random() * 50;
        const delay = Math.pow(2, attempt) * 50 + jitter;
        await new Promise((resolve) => setTimeout(resolve, delay));
        continue;
      }
      throw err;
    }
  }
}

async function executeWithIdempotencyCatch<T>(
  action: () => Promise<T>,
  userId: string,
  idempotencyKey: string | undefined,
  currentHash: string
): Promise<T> {
  try {
    return await withDeadlockRetry(action);
  } catch (err: any) {
    if (
      idempotencyKey &&
      err?.code === 'P2002' &&
      (err?.meta?.target?.includes('idempotency') ||
        err?.message?.includes('idempotency') ||
        err?.meta?.modelName === 'IdempotencyRecord')
    ) {
      const record = await prisma.idempotencyRecord.findUnique({
        where: {
          userId_idempotencyKey: { userId, idempotencyKey },
        },
        include: { transaction: true },
      });
      if (record) {
        if (record.requestHash !== currentHash) {
          throw new ConflictError(
            'Idempotency key telah digunakan untuk payload transaksi yang berbeda.',
            'IDEMPOTENCY_CONFLICT'
          );
        }
        if (record.responseBody) {
          return {
            ...(record.responseBody as any),
            isIdempotentReplay: true,
          } as T;
        }
        if (record.transaction) {
          return {
            id: record.transaction.id,
            referenceNumber: record.transaction.referenceNumber,
            type: record.transaction.type,
            status: record.transaction.status,
            postedAt: record.transaction.postedAt,
            isIdempotentReplay: true,
          } as T;
        }
      }
    }
    throw err;
  }
}

function validateUniqueProductLines(items: Array<{ productId: string }>) {
  const ids = items.map((i) => i.productId);
  if (new Set(ids).size !== ids.length) {
    throw new ValidationError(
      'Terdapat duplikasi produk pada baris transaksi. Gabungkan kuantitas dalam satu baris item.',
      [{ field: 'items', message: 'Setiap produk hanya boleh dicatat satu kali per transaksi.' }]
    );
  }
}

function canonicalize(obj: any): any {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(canonicalize);
  }
  const sortedKeys = Object.keys(obj).sort();
  const result: Record<string, any> = {};
  for (const key of sortedKeys) {
    result[key] = canonicalize(obj[key]);
  }
  return result;
}

function normalizePayload(payload: any): any {
  if (!payload || typeof payload !== 'object') return payload;
  const copy = { ...payload };
  if (Array.isArray(copy.items)) {
    copy.items = [...copy.items].sort((a: any, b: any) =>
      String(a?.productId || '').localeCompare(String(b?.productId || ''))
    );
  }
  return canonicalize(copy);
}

function computePayloadHash(
  organizationId: string,
  userId: string,
  operationType: 'IN' | 'OUT' | 'REVERSAL',
  payload: any
): string {
  const canonicalData = {
    organizationId,
    userId,
    operationType,
    payload: normalizePayload(payload),
  };
  return crypto.createHash('sha256').update(JSON.stringify(canonicalData)).digest('hex');
}

export class InventoryService {
  async processStockIn(
    input: StockInInput,
    userId: string,
    userName: string,
    organizationId: string,
    allowedWarehouseIds?: string[],
    idempotencyKey?: string
  ) {
    if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(input.warehouseId)) {
      throw new ForbiddenError('Akses ditolak: Anda tidak memiliki akses ke gudang ini.');
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { id: input.warehouseId, organizationId },
    });

    if (!warehouse) {
      throw new NotFoundError('Gudang tidak ditemukan.');
    }

    if (!warehouse.isActive) {
      throw new ValidationError('Gudang tidak aktif. Transaksi barang masuk ditolak.');
    }

    validateUniqueProductLines(input.items);
    const currentHash = idempotencyKey
      ? computePayloadHash(organizationId, userId, 'IN', input)
      : '';

    // Idempotency check if key provided
    if (idempotencyKey) {
      const existingRecord = await prisma.idempotencyRecord.findUnique({
        where: {
          userId_idempotencyKey: {
            userId,
            idempotencyKey,
          },
        },
        include: {
          transaction: true,
        },
      });

      if (existingRecord) {
        if (existingRecord.requestHash !== currentHash) {
          throw new ConflictError(
            'Idempotency key telah digunakan untuk payload transaksi yang berbeda.',
            'IDEMPOTENCY_CONFLICT'
          );
        }

        if (existingRecord.responseBody) {
          return {
            ...(existingRecord.responseBody as any),
            isIdempotentReplay: true,
          };
        }

        if (existingRecord.transaction) {
          return {
            id: existingRecord.transaction.id,
            referenceNumber: existingRecord.transaction.referenceNumber,
            type: existingRecord.transaction.type,
            status: existingRecord.transaction.status,
            postedAt: existingRecord.transaction.postedAt,
            isIdempotentReplay: true,
          };
        }
      }
    }

    const org = await prisma.organization.findUnique({
      where: { id: organizationId },
      select: { timezone: true },
    });
    const timeZone = org?.timezone || 'Asia/Makassar';

    return await executeWithIdempotencyCatch(
      async () => {
        return await prisma.$transaction(async (tx) => {
        // 1. Generate sequence number with organization timezone
        const referenceNumber = await getNextSequenceNumber(tx, 'IN', timeZone);

        // 2. Create Header
        const header = await tx.stockTransaction.create({
          data: {
            organizationId,
            warehouseId: warehouse.id,
            createdBy: userId,
            createdByNameSnapshot: userName,
            type: 'IN',
            referenceNumber,
            status: 'POSTED',
            note: input.note,
            externalReference: input.externalReference,
            warehouseNameSnapshot: warehouse.name,
            warehouseCodeSnapshot: warehouse.code,
            postedAt: new Date(),
          },
        });

        // Sort items deterministically by productId to prevent deadlocks
        const sortedItems = [...input.items].sort((a, b) => a.productId.localeCompare(b.productId));

        // 3. Process each item
        for (const item of sortedItems) {
          const product = await tx.product.findFirst({
            where: { id: item.productId, organizationId },
          });

          if (!product) {
            throw new NotFoundError(`Produk dengan ID ${item.productId} tidak ditemukan.`);
          }

          if (!product.isActive) {
            throw new ValidationError(
              `Produk '${product.name}' (${product.sku}) berstatus tidak aktif. Transaksi barang masuk ditolak.`,
              [{ field: `items.${item.productId}`, message: 'Produk tidak aktif tidak dapat digunakan untuk transaksi baru.' }]
            );
          }

          const quantityDecimal = new Prisma.Decimal(item.quantity);

          // Lock row in inventory_balances using raw query for pessimistic concurrency
          const lockQuery = await tx.$queryRaw<Array<{ id: string; quantity: string }>>`
            SELECT id, quantity FROM inventory_balances
            WHERE product_id = ${product.id} AND warehouse_id = ${warehouse.id}
            FOR UPDATE
          `;

          let balanceBefore = new Prisma.Decimal(0);
          let balanceAfter = quantityDecimal;

          if (lockQuery.length > 0) {
            balanceBefore = new Prisma.Decimal(lockQuery[0].quantity);
            balanceAfter = balanceBefore.plus(quantityDecimal);

            await tx.$executeRaw`
              UPDATE inventory_balances
              SET quantity = ${balanceAfter}, updated_at = NOW(3)
              WHERE id = ${lockQuery[0].id}
            `;
          } else {
            const balanceId = crypto.randomUUID();
            await tx.$executeRaw`
              INSERT INTO inventory_balances (id, product_id, warehouse_id, quantity, created_at, updated_at)
              VALUES (${balanceId}, ${product.id}, ${warehouse.id}, ${balanceAfter}, NOW(3), NOW(3))
            `;
          }

          // Insert Transaction Item
          const txItem = await tx.stockTransactionItem.create({
            data: {
              transactionId: header.id,
              productId: product.id,
              productNameSnapshot: product.name,
              skuSnapshot: product.sku,
              unitSnapshot: product.unit,
              quantity: quantityDecimal,
              balanceBefore,
              balanceAfter,
            },
          });

          // Insert Stock Movement Ledger
          await tx.stockMovement.create({
            data: {
              transactionId: header.id,
              transactionItemId: txItem.id,
              productId: product.id,
              warehouseId: warehouse.id,
              type: 'IN',
              quantity: quantityDecimal,
              balanceBefore,
              balanceAfter,
            },
          });
        }

        // Record idempotency atomically if key provided
        if (idempotencyKey) {
          const expiresAt = new Date();
          expiresAt.setHours(expiresAt.getHours() + 24);

          await tx.idempotencyRecord.create({
            data: {
              userId,
              idempotencyKey,
              requestHash: currentHash,
              transactionId: header.id,
              responseStatus: 201,
              responseBody: {
                id: header.id,
                referenceNumber: header.referenceNumber,
                type: header.type,
                status: header.status,
                postedAt: header.postedAt,
              },
              expiresAt,
            },
          });
        }

        return {
          id: header.id,
          referenceNumber: header.referenceNumber,
          type: header.type,
          status: header.status,
          postedAt: header.postedAt,
        };
      });
    }, userId, idempotencyKey, currentHash);
  }

  async processStockOut(
    input: StockOutInput,
    userId: string,
    userName: string,
    organizationId: string,
    allowedWarehouseIds?: string[],
    idempotencyKey?: string
  ) {
    if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(input.warehouseId)) {
      throw new ForbiddenError('Akses ditolak: Anda tidak memiliki akses ke gudang ini.');
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { id: input.warehouseId, organizationId },
    });

    if (!warehouse) {
      throw new NotFoundError('Gudang tidak ditemukan.');
    }

    if (!warehouse.isActive) {
      throw new ValidationError('Gudang tidak aktif. Transaksi barang keluar ditolak.');
    }

    validateUniqueProductLines(input.items);
    const currentHash = idempotencyKey
      ? computePayloadHash(organizationId, userId, 'OUT', input)
      : '';

    // Idempotency check if key provided
    if (idempotencyKey) {
      const existingRecord = await prisma.idempotencyRecord.findUnique({
        where: {
          userId_idempotencyKey: {
            userId,
            idempotencyKey,
          },
        },
        include: {
          transaction: true,
        },
      });

      if (existingRecord) {
        if (existingRecord.requestHash !== currentHash) {
          throw new ConflictError(
            'Idempotency key telah digunakan untuk payload transaksi yang berbeda.',
            'IDEMPOTENCY_CONFLICT'
          );
        }

        if (existingRecord.responseBody) {
          return {
            ...(existingRecord.responseBody as any),
            isIdempotentReplay: true,
          };
        }

        if (existingRecord.transaction) {
          return {
            id: existingRecord.transaction.id,
            referenceNumber: existingRecord.transaction.referenceNumber,
            type: existingRecord.transaction.type,
            status: existingRecord.transaction.status,
            postedAt: existingRecord.transaction.postedAt,
            isIdempotentReplay: true,
          };
        }
      }
    }

    const org = await prisma.organization.findUnique({
      where: { id: organizationId },
      select: { timezone: true },
    });
    const timeZone = org?.timezone || 'Asia/Makassar';

    return await executeWithIdempotencyCatch(
      async () => {
        return await prisma.$transaction(async (tx) => {
        // 1. Validate available stock for ALL items first with pessimistic lock in deterministic sorted order
        const sortedItems = [...input.items].sort((a, b) => a.productId.localeCompare(b.productId));
        const processedItems = [];

        for (const item of sortedItems) {
          const product = await tx.product.findFirst({
            where: { id: item.productId, organizationId },
          });

          if (!product) {
            throw new NotFoundError(`Produk dengan ID ${item.productId} tidak ditemukan.`);
          }

          if (!product.isActive) {
            throw new ValidationError(
              `Produk '${product.name}' (${product.sku}) berstatus tidak aktif. Transaksi barang keluar ditolak.`,
              [{ field: `items.${item.productId}`, message: 'Produk tidak aktif tidak dapat digunakan untuk transaksi baru.' }]
            );
          }

          const quantityDecimal = new Prisma.Decimal(item.quantity);

          // Pessimistic Lock on balance row
          const lockQuery = await tx.$queryRaw<Array<{ id: string; quantity: string }>>`
            SELECT id, quantity FROM inventory_balances
            WHERE product_id = ${product.id} AND warehouse_id = ${warehouse.id}
            FOR UPDATE
          `;

          if (lockQuery.length === 0) {
            throw new InsufficientStockError(
              `Stok untuk produk '${product.name}' tidak tersedia di gudang ${warehouse.name}.`,
              [{ field: `items.${item.productId}`, message: 'Saldo awal adalah 0.000.' }]
            );
          }

          const balanceBefore = new Prisma.Decimal(lockQuery[0].quantity);

          if (balanceBefore.lessThan(quantityDecimal)) {
            throw new InsufficientStockError(
              `Stok untuk produk '${product.name}' tidak mencukupi di gudang ${warehouse.name}. Tersedia: ${balanceBefore}, Diminta: ${quantityDecimal}.`,
              [
                {
                  field: `items.${item.productId}`,
                  message: `Stok tersedia (${balanceBefore}) kurang dari kuantitas diminta (${quantityDecimal}).`,
                },
              ]
            );
          }

          const balanceAfter = balanceBefore.minus(quantityDecimal);

          // Update balance atomically
          await tx.$executeRaw`
            UPDATE inventory_balances
            SET quantity = ${balanceAfter}, updated_at = NOW(3)
            WHERE id = ${lockQuery[0].id}
          `;

          processedItems.push({
            product,
            quantityDecimal,
            balanceBefore,
            balanceAfter,
          });
        }

        // 2. Generate sequence number with organization timezone
        const referenceNumber = await getNextSequenceNumber(tx, 'OUT', timeZone);

        // 3. Create Transaction Header
        const header = await tx.stockTransaction.create({
          data: {
            organizationId,
            warehouseId: warehouse.id,
            createdBy: userId,
            createdByNameSnapshot: userName,
            type: 'OUT',
            referenceNumber,
            status: 'POSTED',
            note: input.note,
            externalReference: input.externalReference,
            warehouseNameSnapshot: warehouse.name,
            warehouseCodeSnapshot: warehouse.code,
            postedAt: new Date(),
          },
        });

        // 4. Create Transaction Items & Movements
        for (const p of processedItems) {
          const txItem = await tx.stockTransactionItem.create({
            data: {
              transactionId: header.id,
              productId: p.product.id,
              productNameSnapshot: p.product.name,
              skuSnapshot: p.product.sku,
              unitSnapshot: p.product.unit,
              quantity: p.quantityDecimal,
              balanceBefore: p.balanceBefore,
              balanceAfter: p.balanceAfter,
            },
          });

          await tx.stockMovement.create({
            data: {
              transactionId: header.id,
              transactionItemId: txItem.id,
              productId: p.product.id,
              warehouseId: warehouse.id,
              type: 'OUT',
              quantity: p.quantityDecimal,
              balanceBefore: p.balanceBefore,
              balanceAfter: p.balanceAfter,
            },
          });
        }

        // Record idempotency atomically inside the transaction
        if (idempotencyKey) {
          const expiresAt = new Date();
          expiresAt.setHours(expiresAt.getHours() + 24);

          await tx.idempotencyRecord.create({
            data: {
              userId,
              idempotencyKey,
              requestHash: currentHash,
              transactionId: header.id,
              responseStatus: 201,
              responseBody: {
                id: header.id,
                referenceNumber: header.referenceNumber,
                type: header.type,
                status: header.status,
                postedAt: header.postedAt,
              },
              expiresAt,
            },
          });
        }

        return {
          id: header.id,
          referenceNumber: header.referenceNumber,
          type: header.type,
          status: header.status,
          postedAt: header.postedAt,
        };
      });
    }, userId, idempotencyKey, currentHash);
  }

  async processReversal(
    transactionId: string,
    input: ReversalInput,
    userId: string,
    userName: string,
    organizationId: string,
    allowedWarehouseIds?: string[],
    idempotencyKey?: string
  ) {
    const currentHash = idempotencyKey
      ? computePayloadHash(organizationId, userId, 'REVERSAL', { transactionId, note: input.note })
      : null;

    if (idempotencyKey) {
      const existingRecord = await prisma.idempotencyRecord.findUnique({
        where: {
          userId_idempotencyKey: {
            userId,
            idempotencyKey,
          },
        },
      });

      if (existingRecord) {
        if (existingRecord.requestHash !== currentHash) {
          throw new ConflictError(
            'Idempotency key telah digunakan dengan payload berbeda.',
            'IDEMPOTENCY_CONFLICT'
          );
        }
        return {
          ...(existingRecord.responseBody as any),
          isIdempotentReplay: true,
        };
      }
    }

    const original = await prisma.stockTransaction.findFirst({
      where: { id: transactionId, organizationId },
      include: {
        items: true,
        correctionTransaction: true,
      },
    });

    if (!original) {
      throw new NotFoundError('Transaksi tidak ditemukan.');
    }

    if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(original.warehouseId)) {
      throw new ForbiddenError('Akses ditolak: Anda tidak memiliki akses ke gudang transaksi ini.');
    }

    if (original.correctionOfTransactionId) {
      throw new ValidationError('Transaksi koreksi tidak dapat dibatalkan kembali.');
    }

    if (original.correctionTransaction) {
      throw new ConflictError('Transaksi ini sudah pernah dibatalkan (dibalik) sebelumnya.');
    }

    const reversalType = original.type === 'IN' ? 'OUT' : 'IN';

    // Deterministic item sorting by productId to prevent deadlocks
    const sortedItems = [...original.items].sort((a, b) =>
      a.productId.localeCompare(b.productId)
    );

    const org = await prisma.organization.findUnique({
      where: { id: organizationId },
      select: { timezone: true },
    });
    const timeZone = org?.timezone || 'Asia/Makassar';

    return await executeWithIdempotencyCatch(
      async () => {
        return await prisma.$transaction(async (tx) => {
        // Double check if original transaction was reversed concurrently inside transaction
        const freshOriginal = await tx.stockTransaction.findUnique({
          where: { id: transactionId },
          include: { correctionTransaction: true },
        });

        if (freshOriginal?.correctionTransaction) {
          throw new ConflictError('Transaksi ini sudah pernah dibatalkan (dibalik) sebelumnya.');
        }

        const itemsToProcess = [];

        for (const item of sortedItems) {
          const lockQuery = await tx.$queryRaw<Array<{ id: string; quantity: string }>>`
            SELECT id, quantity FROM inventory_balances
            WHERE product_id = ${item.productId} AND warehouse_id = ${original.warehouseId}
            FOR UPDATE
          `;

          let balanceBefore = new Prisma.Decimal(0);
          let balanceAfter = new Prisma.Decimal(0);

          if (reversalType === 'OUT') {
            if (lockQuery.length === 0) {
              throw new InsufficientStockError(
                `Gagal membalik transaksi: Saldo produk '${item.productNameSnapshot}' tidak ditemukan.`
              );
            }
            balanceBefore = new Prisma.Decimal(lockQuery[0].quantity);
            if (balanceBefore.lessThan(item.quantity)) {
              throw new InsufficientStockError(
                `Gagal membalik transaksi: Saldo produk '${item.productNameSnapshot}' tidak mencukupi untuk dibatalkan (Tersedia: ${balanceBefore}, Diperlukan: ${item.quantity}).`
              );
            }
            balanceAfter = balanceBefore.minus(item.quantity);

            await tx.$executeRaw`
              UPDATE inventory_balances
              SET quantity = ${balanceAfter}, updated_at = NOW(3)
              WHERE id = ${lockQuery[0].id}
            `;
          } else {
            // Reversing an 'OUT' transaction adds stock back
            if (lockQuery.length > 0) {
              balanceBefore = new Prisma.Decimal(lockQuery[0].quantity);
              balanceAfter = balanceBefore.plus(item.quantity);
              await tx.$executeRaw`
                UPDATE inventory_balances
                SET quantity = ${balanceAfter}, updated_at = NOW(3)
                WHERE id = ${lockQuery[0].id}
              `;
            } else {
              const balanceId = crypto.randomUUID();
              balanceAfter = item.quantity;
              await tx.$executeRaw`
                INSERT INTO inventory_balances (id, product_id, warehouse_id, quantity, created_at, updated_at)
                VALUES (${balanceId}, ${item.productId}, ${original.warehouseId}, ${balanceAfter}, NOW(3), NOW(3))
              `;
            }
          }

          itemsToProcess.push({
            item,
            balanceBefore,
            balanceAfter,
          });
        }

        // Generate sequence number for reversal with organization timezone
        const referenceNumber = await getNextSequenceNumber(tx, reversalType, timeZone);

        // Create Reversal Transaction Header linked to original
        const reversalHeader = await tx.stockTransaction.create({
          data: {
            organizationId,
            warehouseId: original.warehouseId,
            createdBy: userId,
            createdByNameSnapshot: userName,
            type: reversalType,
            referenceNumber,
            status: 'POSTED',
            note: input.note || `Pembalikan penuh atas transaksi ${original.referenceNumber}`,
            correctionOfTransactionId: original.id,
            warehouseNameSnapshot: original.warehouseNameSnapshot,
            warehouseCodeSnapshot: original.warehouseCodeSnapshot,
            postedAt: new Date(),
          },
        });

        // Create Reversal Items & Movements
        for (const p of itemsToProcess) {
          const txItem = await tx.stockTransactionItem.create({
            data: {
              transactionId: reversalHeader.id,
              productId: p.item.productId,
              productNameSnapshot: p.item.productNameSnapshot,
              skuSnapshot: p.item.skuSnapshot,
              unitSnapshot: p.item.unitSnapshot,
              quantity: p.item.quantity,
              balanceBefore: p.balanceBefore,
              balanceAfter: p.balanceAfter,
            },
          });

          await tx.stockMovement.create({
            data: {
              transactionId: reversalHeader.id,
              transactionItemId: txItem.id,
              productId: p.item.productId,
              warehouseId: original.warehouseId,
              type: reversalType,
              quantity: p.item.quantity,
              balanceBefore: p.balanceBefore,
              balanceAfter: p.balanceAfter,
            },
          });
        }

        // Record idempotency atomically inside the transaction
        if (idempotencyKey) {
          const expiresAt = new Date();
          expiresAt.setHours(expiresAt.getHours() + 24);

          await tx.idempotencyRecord.create({
            data: {
              userId,
              idempotencyKey,
              requestHash: currentHash!,
              transactionId: reversalHeader.id,
              responseStatus: 201,
              responseBody: {
                id: reversalHeader.id,
                referenceNumber: reversalHeader.referenceNumber,
                type: reversalHeader.type,
                status: reversalHeader.status,
                correctionOfTransactionId: original.id,
                postedAt: reversalHeader.postedAt,
              },
              expiresAt,
            },
          });
        }

        return {
          id: reversalHeader.id,
          referenceNumber: reversalHeader.referenceNumber,
          type: reversalHeader.type,
          status: reversalHeader.status,
          correctionOfTransactionId: original.id,
          postedAt: reversalHeader.postedAt,
        };
      });
    }, userId, idempotencyKey, currentHash || '');
  }

  async listBalances(params: {
    page?: number;
    pageSize?: number;
    warehouseId?: string;
    productId?: string;
    organizationId: string;
    allowedWarehouseIds?: string[];
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 50));
    const skip = (page - 1) * pageSize;

    const where: any = {
      product: {
        organizationId: params.organizationId,
      },
    };

    if (params.productId) {
      where.productId = params.productId;
    }

    if (params.warehouseId) {
      if (params.allowedWarehouseIds !== undefined && !params.allowedWarehouseIds.includes(params.warehouseId)) {
        throw new ForbiddenError('Akses ditolak ke gudang ini.');
      }
      where.warehouseId = params.warehouseId;
    } else if (params.allowedWarehouseIds !== undefined) {
      where.warehouseId = { in: params.allowedWarehouseIds };
    }

    const [totalItems, balances] = await Promise.all([
      prisma.inventoryBalance.count({ where }),
      prisma.inventoryBalance.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: [{ warehouse: { name: 'asc' } }, { product: { name: 'asc' } }],
        include: {
          product: {
            include: { category: true },
          },
          warehouse: true,
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: balances.map((b) => ({
        id: b.id,
        productId: b.productId,
        warehouseId: b.warehouseId,
        quantity: b.quantity.toString(),
        product: {
          id: b.product.id,
          name: b.product.name,
          sku: b.product.sku,
          unit: b.product.unit,
          minimumStock: b.product.minimumStock.toString(),
          costPrice: b.product.costPrice ? b.product.costPrice.toString() : null,
          categoryName: b.product.category.name,
        },
        warehouse: {
          id: b.warehouse.id,
          name: b.warehouse.name,
          code: b.warehouse.code,
        },
        updatedAt: b.updatedAt,
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async listTransactions(params: {
    page?: number;
    pageSize?: number;
    warehouseId?: string;
    type?: string;
    organizationId: string;
    allowedWarehouseIds?: string[];
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 20));
    const skip = (page - 1) * pageSize;

    const where: any = {
      organizationId: params.organizationId,
    };

    if (params.type && ['IN', 'OUT'].includes(params.type)) {
      where.type = params.type;
    }

    if (params.warehouseId) {
      if (params.allowedWarehouseIds !== undefined && !params.allowedWarehouseIds.includes(params.warehouseId)) {
        throw new ForbiddenError('Akses ditolak ke gudang ini.');
      }
      where.warehouseId = params.warehouseId;
    } else if (params.allowedWarehouseIds !== undefined) {
      where.warehouseId = { in: params.allowedWarehouseIds };
    }

    const [totalItems, transactions] = await Promise.all([
      prisma.stockTransaction.count({ where }),
      prisma.stockTransaction.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { postedAt: 'desc' },
        include: {
          items: true,
          correctionTransaction: {
            select: { id: true, referenceNumber: true },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: transactions.map((t) => ({
        id: t.id,
        referenceNumber: t.referenceNumber,
        type: t.type,
        status: t.status,
        warehouseId: t.warehouseId,
        warehouseName: t.warehouseNameSnapshot,
        warehouseCode: t.warehouseCodeSnapshot,
        createdByName: t.createdByNameSnapshot,
        note: t.note,
        externalReference: t.externalReference,
        correctionOfTransactionId: t.correctionOfTransactionId,
        isReversed: t.correctionTransaction !== null,
        reversedByReferenceNumber: t.correctionTransaction?.referenceNumber,
        postedAt: t.postedAt,
        itemCount: t.items.length,
        items: t.items.map((i) => ({
          id: i.id,
          productId: i.productId,
          productName: i.productNameSnapshot,
          sku: i.skuSnapshot,
          unit: i.unitSnapshot,
          quantity: i.quantity.toString(),
          balanceBefore: i.balanceBefore.toString(),
          balanceAfter: i.balanceAfter.toString(),
        })),
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async getTransactionById(id: string, organizationId: string, allowedWarehouseIds?: string[]) {
    const transaction = await prisma.stockTransaction.findFirst({
      where: { id, organizationId },
      include: {
        items: true,
        correctionTransaction: true,
        originalTransaction: true,
      },
    });

    if (!transaction) {
      throw new NotFoundError('Transaksi tidak ditemukan.');
    }

    if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(transaction.warehouseId)) {
      throw new ForbiddenError('Akses ditolak ke transaksi gudang ini.');
    }

    return {
      id: transaction.id,
      referenceNumber: transaction.referenceNumber,
      type: transaction.type,
      status: transaction.status,
      warehouseId: transaction.warehouseId,
      warehouseName: transaction.warehouseNameSnapshot,
      warehouseCode: transaction.warehouseCodeSnapshot,
      createdByName: transaction.createdByNameSnapshot,
      note: transaction.note,
      externalReference: transaction.externalReference,
      correctionOfTransactionId: transaction.correctionOfTransactionId,
      originalReferenceNumber: transaction.originalTransaction?.referenceNumber,
      isReversed: transaction.correctionTransaction !== null,
      reversedByReferenceNumber: transaction.correctionTransaction?.referenceNumber,
      postedAt: transaction.postedAt,
      items: transaction.items.map((i) => ({
        id: i.id,
        productId: i.productId,
        productName: i.productNameSnapshot,
        sku: i.skuSnapshot,
        unit: i.unitSnapshot,
        quantity: i.quantity.toString(),
        balanceBefore: i.balanceBefore.toString(),
        balanceAfter: i.balanceAfter.toString(),
      })),
    };
  }
}

export const inventoryService = new InventoryService();
