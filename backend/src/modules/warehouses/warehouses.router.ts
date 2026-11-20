import { Router } from 'express';
import { warehousesController } from './warehouses.controller';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { warehouseScope } from '../../middleware/warehouse-scope';
import { verifyCsrf } from '../../middleware/csrf';

export const warehousesRouter = Router();

warehousesRouter.use(requireAuth);
warehousesRouter.use(warehouseScope);

warehousesRouter.get('/', (req, res, next) => warehousesController.listWarehouses(req, res, next));
warehousesRouter.get('/:id', (req, res, next) => warehousesController.getWarehouse(req, res, next));
warehousesRouter.post('/', requireRole('ADMIN'), verifyCsrf, (req, res, next) => warehousesController.createWarehouse(req, res, next));
warehousesRouter.put('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => warehousesController.updateWarehouse(req, res, next));
warehousesRouter.delete('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => warehousesController.deleteWarehouse(req, res, next));
