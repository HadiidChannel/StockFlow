import { Request, Response, NextFunction } from 'express';
import { movementsService } from './movements.service';
import { UnauthorizedError } from '../../utils/app-error';

export class MovementsController {
  async listMovements(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await movementsService.listMovements({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        productId: req.query.productId as string,
        warehouseId: req.query.warehouseId as string,
        type: req.query.type as string,
        startDate: req.query.startDate as string,
        endDate: req.query.endDate as string,
        organizationId: req.user.organizationId,
        allowedWarehouseIds: req.allowedWarehouseIds,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }
}

export const movementsController = new MovementsController();
