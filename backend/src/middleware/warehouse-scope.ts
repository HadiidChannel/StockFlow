import { Request, Response, NextFunction } from 'express';
import { prisma } from '../database/client';
import { ForbiddenError } from '../utils/app-error';

export async function warehouseScope(req: Request, _res: Response, next: NextFunction) {
  try {
    if (!req.user) {
      return next();
    }

    if (req.user.role.code === 'ADMIN') {
      // Admin has access to all warehouses
      req.allowedWarehouseIds = undefined; // undefined indicates all
      return next();
    }

    // Warehouse Staff: Query active assignments
    const assignments = await prisma.userWarehouseAssignment.findMany({
      where: {
        userId: req.user.id,
        warehouse: {
          isActive: true,
        },
      },
      select: {
        warehouseId: true,
      },
    });

    const allowedIds = assignments.map((a) => a.warehouseId);
    req.allowedWarehouseIds = allowedIds;

    // If request specifies warehouseId in params, query, or body, validate immediately
    const targetWarehouseId =
      (req.params.warehouseId as string) ||
      (req.query.warehouseId as string) ||
      (req.body?.warehouseId as string);

    if (targetWarehouseId && !allowedIds.includes(targetWarehouseId)) {
      throw new ForbiddenError(
        'Akses ditolak: Anda tidak memiliki penugasan aktif pada gudang ini.'
      );
    }

    next();
  } catch (err) {
    next(err);
  }
}
