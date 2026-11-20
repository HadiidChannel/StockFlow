import { Router } from 'express';
import { productsController } from './products.controller';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { warehouseScope } from '../../middleware/warehouse-scope';
import { verifyCsrf } from '../../middleware/csrf';

export const productsRouter = Router();

productsRouter.use(requireAuth);
productsRouter.use(warehouseScope);

productsRouter.get('/', (req, res, next) => productsController.listProducts(req, res, next));
productsRouter.get('/:id', (req, res, next) => productsController.getProduct(req, res, next));
productsRouter.post('/', requireRole('ADMIN'), verifyCsrf, (req, res, next) => productsController.createProduct(req, res, next));
productsRouter.put('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => productsController.updateProduct(req, res, next));
productsRouter.delete('/:id', requireRole('ADMIN'), verifyCsrf, (req, res, next) => productsController.deleteProduct(req, res, next));
