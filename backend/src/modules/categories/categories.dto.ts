import { z } from 'zod';

export const CreateCategorySchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama kategori minimal 2 karakter.' }).max(100),
  description: z.string().trim().max(500).optional().nullable(),
});

export type CreateCategoryInput = z.infer<typeof CreateCategorySchema>;

export const UpdateCategorySchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama kategori minimal 2 karakter.' }).max(100).optional(),
  description: z.string().trim().max(500).optional().nullable(),
  isActive: z.boolean().optional(),
});

export type UpdateCategoryInput = z.infer<typeof UpdateCategorySchema>;
