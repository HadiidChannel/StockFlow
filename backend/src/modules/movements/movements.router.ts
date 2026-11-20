import { Router } from 'express';
import { movementsController } from './movements.controller';
import { requireAuth } from '../../middleware/auth';
import { warehouseScope } from '../../middleware/warehouse-scope';

export const movementsRouter = Router();

movementsRouter.use(requireAuth);
movementsRouter.use(warehouseScope);

movementsRouter.get('/', (req, res, next) => movementsController.listMovements(req, res, next));
