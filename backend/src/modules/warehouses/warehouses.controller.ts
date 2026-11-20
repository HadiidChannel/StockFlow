import { Request, Response, NextFunction } from 'express';
import { warehousesService } from './warehouses.service';
import { CreateWarehouseSchema, UpdateWarehouseSchema } from './warehouses.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export class WarehousesController {
  async listWarehouses(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await warehousesService.listWarehouses({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        search: req.query.search as string,
        isActive: req.query.isActive !== undefined ? req.query.isActive === 'true' : undefined,
        organizationId: req.user.organizationId,
        allowedWarehouseIds: req.allowedWarehouseIds,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async getWarehouse(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const warehouse = await warehousesService.getWarehouseById(
        req.params.id,
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(200).json({ data: warehouse });
    } catch (err) {
      next(err);
    }
  }

  async createWarehouse(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = CreateWarehouseSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data gudang gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await warehousesService.createWarehouse(
        parsed.data,
        req.user.id,
        req.user.organizationId
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async updateWarehouse(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = UpdateWarehouseSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi perbaruan gudang gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await warehousesService.updateWarehouse(
        req.params.id,
        parsed.data,
        req.user.id,
        req.user.organizationId
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async deleteWarehouse(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await warehousesService.deleteWarehouse(
        req.params.id,
        req.user.organizationId
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const warehousesController = new WarehousesController();
