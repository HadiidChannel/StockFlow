import { prisma } from '../../database/client';
import { ForbiddenError } from '../../utils/app-error';

export class MovementsService {
  async listMovements(params: {
    page?: number;
    pageSize?: number;
    productId?: string;
    warehouseId?: string;
    type?: string;
    startDate?: string;
    endDate?: string;
    organizationId: string;
    allowedWarehouseIds?: string[];
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 20));
    const skip = (page - 1) * pageSize;

    const where: any = {
      product: {
        organizationId: params.organizationId,
      },
    };

    if (params.productId) {
      where.productId = params.productId;
    }

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

    if (params.startDate || params.endDate) {
      where.createdAt = {};
      if (params.startDate) {
        where.createdAt.gte = new Date(params.startDate);
      }
      if (params.endDate) {
        where.createdAt.lte = new Date(params.endDate);
      }
    }

    const [totalItems, movements] = await Promise.all([
      prisma.stockMovement.count({ where }),
      prisma.stockMovement.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        include: {
          product: {
            select: {
              id: true,
              name: true,
              sku: true,
              unit: true,
            },
          },
          warehouse: {
            select: {
              id: true,
              name: true,
              code: true,
            },
          },
          transaction: {
            select: {
              referenceNumber: true,
              createdByNameSnapshot: true,
              note: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: movements.map((m) => ({
        id: m.id,
        transactionId: m.transactionId,
        referenceNumber: m.transaction.referenceNumber,
        createdByName: m.transaction.createdByNameSnapshot,
        type: m.type,
        productId: m.productId,
        productName: m.product.name,
        sku: m.product.sku,
        unit: m.product.unit,
        warehouseId: m.warehouseId,
        warehouseName: m.warehouse.name,
        warehouseCode: m.warehouse.code,
        quantity: m.quantity.toString(),
        balanceBefore: m.balanceBefore.toString(),
        balanceAfter: m.balanceAfter.toString(),
        note: m.transaction.note,
        createdAt: m.createdAt,
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }
}

export const movementsService = new MovementsService();
