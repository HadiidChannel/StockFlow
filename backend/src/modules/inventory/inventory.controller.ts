import { Request, Response, NextFunction } from 'express';
import { inventoryService } from './inventory.service';
import { StockInSchema, StockOutSchema, ReversalSchema } from './inventory.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export class InventoryController {
  async stockIn(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = StockInSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data barang masuk gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const idempotencyKey = req.headers['idempotency-key'] as string | undefined;

      const result = await inventoryService.processStockIn(
        parsed.data,
        req.user.id,
        req.user.name,
        req.user.organizationId,
        req.allowedWarehouseIds,
        idempotencyKey
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async stockOut(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = StockOutSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data barang keluar gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const idempotencyKey = req.headers['idempotency-key'] as string | undefined;

      const result = await inventoryService.processStockOut(
        parsed.data,
        req.user.id,
        req.user.name,
        req.user.organizationId,
        req.allowedWarehouseIds,
        idempotencyKey
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async reverseTransaction(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = ReversalSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data pembalikan gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await inventoryService.processReversal(
        req.params.id,
        parsed.data,
        req.user.id,
        req.user.name,
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async listBalances(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await inventoryService.listBalances({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        warehouseId: req.query.warehouseId as string,
        productId: req.query.productId as string,
        organizationId: req.user.organizationId,
        allowedWarehouseIds: req.allowedWarehouseIds,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async listTransactions(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await inventoryService.listTransactions({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        warehouseId: req.query.warehouseId as string,
        type: req.query.type as string,
        organizationId: req.user.organizationId,
        allowedWarehouseIds: req.allowedWarehouseIds,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async getTransaction(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await inventoryService.getTransactionById(
        req.params.id,
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const inventoryController = new InventoryController();
