import { Router } from 'express';
import { categoriesController } from './categories.controller';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { verifyCsrf } from '../../middleware/csrf';

export const categoriesRouter = Router();

categoriesRouter.use(requireAuth);

categoriesRouter.get('/', (req, res, next) => categoriesController.listCategories(req, res, next));
categoriesRouter.get('/:id', (req, res, next) => categoriesController.getCategory(req, res, next));
categoriesRouter.post('/', requireRole('ADMIN'), verifyCsrf, (req, res, next) => categoriesController.createCategory(req, res, next));
categoriesRouter.put('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => categoriesController.updateCategory(req, res, next));
categoriesRouter.delete('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => categoriesController.deleteCategory(req, res, next));
