import { Request, Response, NextFunction } from 'express';
import { organizationService } from './organization.service';
import { UpdateOrganizationSchema } from './organization.dto';
import { ValidationError } from '../../utils/app-error';

export class OrganizationController {
  async getProfile(_req: Request, res: Response, next: NextFunction) {
    try {
      const org = await organizationService.getProfile();
      return res.status(200).json({
        data: org,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateProfile(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = UpdateOrganizationSchema.safeParse(req.body);
      if (!parsed.success) {
        throw new ValidationError('Validasi data organisasi gagal.', parsed.error.issues.map((i) => ({
          field: i.path.join('.'),
          message: i.message,
        })));
      }

      const updated = await organizationService.updateProfile(parsed.data);
      return res.status(200).json({
        data: updated,
      });
    } catch (err) {
      next(err);
    }
  }
}

export const organizationController = new OrganizationController();
