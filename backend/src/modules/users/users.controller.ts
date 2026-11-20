import { Request, Response, NextFunction } from 'express';
import { usersService } from './users.service';
import {
  CreateUserSchema,
  UpdateUserSchema,
  AssignWarehousesSchema,
  ResetPasswordSchema,
} from './users.dto';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export class UsersController {
  async listUsers(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await usersService.listUsers({
        page: req.query.page ? Number(req.query.page) : undefined,
        pageSize: req.query.pageSize ? Number(req.query.pageSize) : undefined,
        search: req.query.search as string,
        roleCode: req.query.role as string,
        status: req.query.status as string,
      });

      return res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  }

  async getUser(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await usersService.getUserById(req.params.id);
      return res.status(200).json({ data: user });
    } catch (err) {
      next(err);
    }
  }

  async createUser(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = CreateUserSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi pembuatan pengguna gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await usersService.createUser(parsed.data, req.user.id);
      return res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async updateUser(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = UpdateUserSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi perbaruan pengguna gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await usersService.updateUser(req.params.id, parsed.data, req.user.id);
      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async assignWarehouses(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) throw new UnauthorizedError();

      const parsed = AssignWarehousesSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi penugasan gudang gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await usersService.assignWarehouses(req.params.id, parsed.data, req.user.id);
      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async resetPassword(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = ResetPasswordSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi reset password gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const result = await usersService.resetPassword(req.params.id, parsed.data);
      return res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const usersController = new UsersController();
