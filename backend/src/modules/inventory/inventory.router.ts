import { Router } from 'express';
import { inventoryController } from './inventory.controller';
import { requireAuth } from '../../middleware/auth';
import { warehouseScope } from '../../middleware/warehouse-scope';
import { verifyCsrf } from '../../middleware/csrf';
import { inventoryTransactionLimiter } from '../../middleware/rate-limiter';

export const inventoryRouter = Router();

inventoryRouter.use(requireAuth);
inventoryRouter.use(warehouseScope);

// Balances
inventoryRouter.get('/balances', (req, res, next) => inventoryController.listBalances(req, res, next));

// Transactions
inventoryRouter.get('/transactions', (req, res, next) => inventoryController.listTransactions(req, res, next));
inventoryRouter.get('/transactions/:id', (req, res, next) => inventoryController.getTransaction(req, res, next));
inventoryRouter.post('/transactions/:id/reversal', verifyCsrf, inventoryTransactionLimiter, (req, res, next) => inventoryController.reverseTransaction(req, res, next));

// Stock In & Out
inventoryRouter.post('/stock-in', verifyCsrf, inventoryTransactionLimiter, (req, res, next) => inventoryController.stockIn(req, res, next));
inventoryRouter.post('/stock-out', verifyCsrf, inventoryTransactionLimiter, (req, res, next) => inventoryController.stockOut(req, res, next));
