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

    const isReadOperation = req.method === 'GET' || req.method === 'HEAD';

    // Warehouse Staff: Query assignments
    // P1-08: Untuk operasi pembacaan (GET), staf tetap dapat mengakses histori gudang yang pernah ditugaskan meskipun gudang nonaktif.
    // Untuk mutasi transaksi (POST/PUT/DELETE), gudang wajib berstatus aktif.
    const assignments = await prisma.userWarehouseAssignment.findMany({
      where: {
        userId: req.user.id,
        ...(isReadOperation ? {} : { warehouse: { isActive: true } }),
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
        isReadOperation
          ? 'Akses ditolak: Anda tidak memiliki akses ke histori gudang ini.'
          : 'Akses ditolak: Anda tidak memiliki penugasan aktif pada gudang ini atau gudang berstatus tidak aktif.'
      );
    }

    next();
  } catch (err) {
    next(err);
  }
}
