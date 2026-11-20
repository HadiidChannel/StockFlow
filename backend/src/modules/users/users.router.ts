import { Router } from 'express';
import { usersController } from './users.controller';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { verifyCsrf } from '../../middleware/csrf';

export const usersRouter = Router();

usersRouter.use(requireAuth);
usersRouter.use(requireRole('ADMIN'));

usersRouter.get('/', (req, res, next) => usersController.listUsers(req, res, next));
usersRouter.post('/', verifyCsrf, (req, res, next) => usersController.createUser(req, res, next));
usersRouter.get('/:id', (req, res, next) => usersController.getUser(req, res, next));
usersRouter.put('/:id', verifyCsrf, (req, res, next) => usersController.updateUser(req, res, next));
usersRouter.put('/:id/warehouses', verifyCsrf, (req, res, next) => usersController.assignWarehouses(req, res, next));
usersRouter.post('/:id/reset-password', verifyCsrf, (req, res, next) => usersController.resetPassword(req, res, next));
