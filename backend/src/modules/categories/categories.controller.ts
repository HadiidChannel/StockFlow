import { Request, Response, NextFunction } from 'express';
import { categoriesService } from './categories.service';
import { CreateCategorySchema, UpdateCategorySchema } from './categories.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export class CategoriesController {
  async listCategories(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await categoriesService.listCategories({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        search: req.query.search as string,
        isActive: req.query.isActive !== undefined ? req.query.isActive === 'true' : undefined,
        organizationId: req.user.organizationId,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async getCategory(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const category = await categoriesService.getCategoryById(
        req.params.id,
        req.user.organizationId
      );

      return res.status(200).json({ data: category });
    } catch (err) {
      next(err);
    }
  }

  async createCategory(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = CreateCategorySchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data kategori gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await categoriesService.createCategory(
        parsed.data,
        req.user.id,
        req.user.organizationId
      );

      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async updateCategory(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = UpdateCategorySchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi perbaruan kategori gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await categoriesService.updateCategory(
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

  async deleteCategory(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const result = await categoriesService.deleteCategory(
        req.params.id,
        req.user.organizationId
      );

      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const categoriesController = new CategoriesController();
