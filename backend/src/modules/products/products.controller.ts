import { Request, Response, NextFunction } from 'express';
import { productsService } from './products.service';
import { CreateProductSchema, UpdateProductSchema } from './products.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export class ProductsController {
  async listProducts(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await productsService.listProducts({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        search: req.query.search as string,
        categoryId: req.query.categoryId as string,
        isActive: req.query.isActive !== undefined ? req.query.isActive === 'true' : undefined,
        lowStock: req.query.lowStock !== undefined ? req.query.lowStock === 'true' : undefined,
        organizationId: req.user.organizationId,
        allowedWarehouseIds: req.allowedWarehouseIds,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async getProduct(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const product = await productsService.getProductById(
        req.params.id,
        req.user.organizationId,
        req.allowedWarehouseIds
      );

      return res.status(200).json({ data: product });
    } catch (err) {
      next(err);
    }
  }

  async createProduct(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = CreateProductSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data produk gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await productsService.createProduct(
        parsed.data,
        req.user.id,
        req.user.organizationId
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async updateProduct(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = UpdateProductSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi perbaruan produk gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await productsService.updateProduct(
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

  async deleteProduct(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await productsService.deleteProduct(
        req.params.id,
        req.user.organizationId
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const productsController = new ProductsController();
