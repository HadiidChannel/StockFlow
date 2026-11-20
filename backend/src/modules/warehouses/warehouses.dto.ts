import { z } from 'zod';

export const CreateWarehouseSchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama gudang minimal 2 karakter.' }).max(160),
  code: z
    .string()
    .trim()
    .min(2, { message: 'Kode gudang minimal 2 karakter.' })
    .max(32)
    .regex(/^[A-Z0-9_-]+$/, { message: 'Kode gudang hanya boleh berisi huruf besar, angka, underscore, atau hyphen.' }),
  location: z.string().trim().max(255).optional().nullable(),
  description: z.string().trim().max(500).optional().nullable(),
});

export type CreateWarehouseInput = z.infer<typeof CreateWarehouseSchema>;

export const UpdateWarehouseSchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama gudang minimal 2 karakter.' }).max(160).optional(),
  code: z
    .string()
    .trim()
    .min(2)
    .max(32)
    .regex(/^[A-Z0-9_-]+$/, { message: 'Kode gudang hanya boleh berisi huruf besar, angka, underscore, atau hyphen.' })
    .optional(),
  location: z.string().trim().max(255).optional().nullable(),
  description: z.string().trim().max(500).optional().nullable(),
  isActive: z.boolean().optional(),
});

export type UpdateWarehouseInput = z.infer<typeof UpdateWarehouseSchema>;
