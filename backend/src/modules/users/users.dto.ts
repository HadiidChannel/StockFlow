import { z } from 'zod';

export const CreateUserSchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama minimal 2 karakter.' }).max(120),
  email: z.string().trim().email({ message: 'Format email tidak valid.' }),
  password: z
    .string()
    .min(8, { message: 'Password minimal 8 karakter.' })
    .regex(/[A-Z]/, { message: 'Password harus mengandung setidaknya 1 huruf besar.' })
    .regex(/[a-z]/, { message: 'Password harus mengandung setidaknya 1 huruf kecil.' })
    .regex(/[0-9]/, { message: 'Password harus mengandung setidaknya 1 angka.' }),
  roleCode: z.enum(['ADMIN', 'WAREHOUSE_STAFF']),
  warehouseIds: z.array(z.string().uuid()).optional(),
});

export type CreateUserInput = z.infer<typeof CreateUserSchema>;

export const UpdateUserSchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama minimal 2 karakter.' }).max(120).optional(),
  roleCode: z.enum(['ADMIN', 'WAREHOUSE_STAFF']).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
});

export type UpdateUserInput = z.infer<typeof UpdateUserSchema>;

export const AssignWarehousesSchema = z.object({
  warehouseIds: z.array(z.string().uuid()).min(1, {
    message: 'Warehouse Staff harus ditugaskan ke minimal satu gudang aktif.',
  }),
});

export type AssignWarehousesInput = z.infer<typeof AssignWarehousesSchema>;

export const ResetPasswordSchema = z.object({
  temporaryPassword: z
    .string()
    .min(8, { message: 'Password sementara minimal 8 karakter.' }),
});

export type ResetPasswordInput = z.infer<typeof ResetPasswordSchema>;
