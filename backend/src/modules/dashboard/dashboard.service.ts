import { Prisma } from '@prisma/client';
import { prisma } from '../../database/client';
import { ForbiddenError } from '../../utils/app-error';

export class DashboardService {
  async getSummary(organizationId: string, allowedWarehouseIds?: string[]) {
    const warehouseWhere: any = { organizationId, isActive: true };
    if (allowedWarehouseIds !== undefined) {
      warehouseWhere.id = { in: allowedWarehouseIds };
    }

    const [totalProducts, totalWarehouses] = await Promise.all([
      prisma.product.count({ where: { organizationId, isActive: true } }),
      prisma.warehouse.count({ where: warehouseWhere }),
    ]);

    // Calculate product stock status per allowed warehouses
    const products = await prisma.product.findMany({
      where: { organizationId, isActive: true },
      include: {
        balances: {
          where: allowedWarehouseIds !== undefined ? { warehouseId: { in: allowedWarehouseIds } } : {},
        },
      },
    });

    let lowStockCount = 0;
    let outOfStockCount = 0;

    for (const p of products) {
      let totalQty = new Prisma.Decimal(0);
      for (const b of p.balances) {
        totalQty = totalQty.plus(b.quantity);
      }

      if (totalQty.equals(0)) {
        outOfStockCount++;
      } else if (totalQty.lessThanOrEqualTo(p.minimumStock)) {
        lowStockCount++;
      }
    }

    // 30 days threshold for recent transactions
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const txWhere: any = {
      organizationId,
      postedAt: { gte: thirtyDaysAgo },
    };
    if (allowedWarehouseIds !== undefined) {
      txWhere.warehouseId = { in: allowedWarehouseIds };
    }

    const [recentIn, recentOut] = await Promise.all([
      prisma.stockTransaction.count({ where: { ...txWhere, type: 'IN' } }),
      prisma.stockTransaction.count({ where: { ...txWhere, type: 'OUT' } }),
    ]);

    return {
      totalProducts,
      totalWarehouses,
      lowStockCount,
      outOfStockCount,
      recentStockInCount: recentIn,
      recentStockOutCount: recentOut,
    };
  }

  async getMovementChart(
    organizationId: string,
    allowedWarehouseIds?: string[],
    days = 7,
    warehouseId?: string
  ) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const where: any = {
      organizationId,
      status: 'POSTED',
      postedAt: { gte: startDate },
    };

    if (warehouseId) {
      if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(warehouseId)) {
        throw new ForbiddenError('Akses ditolak: Anda tidak memiliki akses ke gudang ini.');
      }
      where.warehouseId = warehouseId;
    } else if (allowedWarehouseIds !== undefined) {
      where.warehouseId = { in: allowedWarehouseIds };
    }

    const transactions = await prisma.stockTransaction.findMany({
      where,
      select: {
        type: true,
        postedAt: true,
      },
      orderBy: { postedAt: 'asc' },
    });

    // Group by date (YYYY-MM-DD)
    const map = new Map<string, { date: string; inCount: number; outCount: number }>();

    for (let i = 0; i <= days; i++) {
      const d = new Date(startDate);
      d.setDate(d.getDate() + i);
      const dateKey = d.toISOString().split('T')[0];
      map.set(dateKey, { date: dateKey, inCount: 0, outCount: 0 });
    }

    for (const tx of transactions) {
      if (tx.postedAt) {
        const dateKey = tx.postedAt.toISOString().split('T')[0];
        const entry = map.get(dateKey);
        if (entry) {
          if (tx.type === 'IN') entry.inCount++;
          else if (tx.type === 'OUT') entry.outCount++;
        }
      }
    }

    return Array.from(map.values());
  }

  async getRecentMovements(organizationId: string, allowedWarehouseIds?: string[], limit = 10) {
    const where: any = {
      product: { organizationId },
    };
    if (allowedWarehouseIds !== undefined) {
      where.warehouseId = { in: allowedWarehouseIds };
    }

    const movements = await prisma.stockMovement.findMany({
      where,
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: {
        product: {
          select: {
            name: true,
            sku: true,
            unit: true,
          },
        },
        warehouse: {
          select: {
            name: true,
            code: true,
          },
        },
        transaction: {
          select: {
            referenceNumber: true,
            createdByNameSnapshot: true,
          },
        },
      },
    });

    return movements.map((m) => ({
      id: m.id,
      type: m.type,
      referenceNumber: m.transaction.referenceNumber,
      productName: m.product.name,
      sku: m.product.sku,
      unit: m.product.unit,
      warehouseName: m.warehouse.name,
      warehouseCode: m.warehouse.code,
      quantity: m.quantity.toString(),
      createdByName: m.transaction.createdByNameSnapshot,
      createdAt: m.createdAt,
    }));
  }

  async getAlerts(organizationId: string, allowedWarehouseIds?: string[]) {
    const products = await prisma.product.findMany({
      where: { organizationId, isActive: true },
      include: {
        category: true,
        balances: {
          where: allowedWarehouseIds !== undefined ? { warehouseId: { in: allowedWarehouseIds } } : {},
          include: {
            warehouse: {
              select: { name: true, code: true },
            },
          },
        },
      },
    });

    const alerts = [];

    for (const p of products) {
      let totalQty = new Prisma.Decimal(0);
      for (const b of p.balances) {
        totalQty = totalQty.plus(b.quantity);
      }

      if (totalQty.lessThanOrEqualTo(p.minimumStock)) {
        alerts.push({
          productId: p.id,
          name: p.name,
          sku: p.sku,
          unit: p.unit,
          categoryName: p.category.name,
          minimumStock: p.minimumStock.toString(),
          currentQuantity: totalQty.toString(),
          severity: totalQty.equals(0) ? ('OUT_OF_STOCK' as const) : ('LOW_STOCK' as const),
        });
      }
    }

    return alerts;
  }
}

export const dashboardService = new DashboardService();
