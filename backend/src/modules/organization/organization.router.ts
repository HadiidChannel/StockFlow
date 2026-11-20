import { Router } from 'express';
import { organizationController } from './organization.controller';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { verifyCsrf } from '../../middleware/csrf';

export const organizationRouter = Router();

organizationRouter.use(requireAuth);

organizationRouter.get('/', (req, res, next) => organizationController.getProfile(req, res, next));
organizationRouter.put('/', requireRole('ADMIN'), verifyCsrf, (req, res, next) => organizationController.updateProfile(req, res, next));
