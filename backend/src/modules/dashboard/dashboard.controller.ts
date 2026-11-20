import { Request, Response, NextFunction } from 'express';
import { dashboardService } from './dashboard.service';
import { UnauthorizedError } from '../../utils/app-error';

export class DashboardController {
  async getSummary(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await dashboardService.getSummary(
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async getMovementChart(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const days = req.query.days ? Number(req.query.days) : 7;
      const warehouseId = req.query.warehouseId as string | undefined;
      const result = await dashboardService.getMovementChart(
        req.user.organizationId,
        req.allowedWarehouseIds,
        days,
        warehouseId
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async getRecentMovements(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const limit = req.query.limit ? Number(req.query.limit) : 10;
      const result = await dashboardService.getRecentMovements(
        req.user.organizationId,
        req.allowedWarehouseIds,
        limit
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async getAlerts(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await dashboardService.getAlerts(
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const dashboardController = new DashboardController();
