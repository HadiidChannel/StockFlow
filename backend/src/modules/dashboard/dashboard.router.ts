import { Router } from 'express';
import { dashboardController } from './dashboard.controller';
import { requireAuth } from '../../middleware/auth';
import { warehouseScope } from '../../middleware/warehouse-scope';

export const dashboardRouter = Router();

dashboardRouter.use(requireAuth);
dashboardRouter.use(warehouseScope);

dashboardRouter.get('/summary', (req, res, next) => dashboardController.getSummary(req, res, next));
dashboardRouter.get('/movement-chart', (req, res, next) => dashboardController.getMovementChart(req, res, next));
dashboardRouter.get('/recent-movements', (req, res, next) => dashboardController.getRecentMovements(req, res, next));
dashboardRouter.get('/alerts', (req, res, next) => dashboardController.getAlerts(req, res, next));
