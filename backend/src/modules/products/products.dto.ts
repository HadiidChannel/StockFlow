import { z } from 'zod';

export const CreateProductSchema = z.object({
  categoryId: z.string().uuid({ message: 'Category ID harus berupa UUID valid.' }),
  name: z.string().trim().min(2, { message: 'Nama produk minimal 2 karakter.' }).max(160),
  sku: z
    .string()
    .trim()
    .min(2, { message: 'SKU minimal 2 karakter.' })
    .max(64)
    .regex(/^[A-Z0-9_-]+$/, { message: 'SKU hanya boleh berisi huruf besar, angka, underscore, atau hyphen.' }),
  unit: z.string().trim().min(1, { message: 'Satuan wajib diisi.' }).max(24),
  minimumStock: z
    .string()
    .regex(/^\d+(\.\d{1,3})?$/, { message: 'Minimum stock harus berupa angka >= 0 dengan maks 3 desimal.' })
    .default('0.000'),
  costPrice: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, { message: 'Harga pokok harus berupa angka >= 0 dengan maks 2 desimal.' })
    .optional()
    .nullable(),
  description: z.string().trim().max(1000).optional().nullable(),
});

export type CreateProductInput = z.infer<typeof CreateProductSchema>;

export const UpdateProductSchema = z.object({
  categoryId: z.string().uuid().optional(),
  name: z.string().trim().min(2).max(160).optional(),
  sku: z
    .string()
    .trim()
    .min(2)
    .max(64)
    .regex(/^[A-Z0-9_-]+$/, { message: 'SKU hanya boleh berisi huruf besar, angka, underscore, atau hyphen.' })
    .optional(),
  unit: z.string().trim().min(1).max(24).optional(),
  minimumStock: z
    .string()
    .regex(/^\d+(\.\d{1,3})?$/, { message: 'Minimum stock harus berupa angka >= 0 dengan maks 3 desimal.' })
    .optional(),
  costPrice: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, { message: 'Harga pokok harus berupa angka >= 0 dengan maks 2 desimal.' })
    .optional()
    .nullable(),
  description: z.string().trim().max(1000).optional().nullable(),
  isActive: z.boolean().optional(),
});

export type UpdateProductInput = z.infer<typeof UpdateProductSchema>;
