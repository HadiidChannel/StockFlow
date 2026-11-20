import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../../database/client';
import { requireAuth } from '../../middleware/auth';
import { verifyCsrf } from '../../middleware/csrf';
import { ValidationError, UnauthorizedError } from '../../utils/app-error';

export const preferencesRouter = Router();

preferencesRouter.use(requireAuth);

const UpdatePreferencesSchema = z.object({
  themePreference: z.enum(['LIGHT', 'DARK', 'SYSTEM']),
});

preferencesRouter.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { themePreference: true },
    });
    return res.status(200).json({ data: user });
  } catch (err) {
    next(err);
  }
});

preferencesRouter.put('/', verifyCsrf, async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.user) throw new UnauthorizedError();
    const parsed = UpdatePreferencesSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new ValidationError('Validasi preferensi gagal.');
    }
    const updated = await prisma.user.update({
      where: { id: req.user.id },
      data: { themePreference: parsed.data.themePreference },
      select: { themePreference: true },
    });
    return res.status(200).json({ data: updated });
  } catch (err) {
    next(err);
  }
});
