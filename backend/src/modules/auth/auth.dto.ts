import { z } from 'zod';

export const LoginSchema = z.object({
  email: z.string().trim().email({ message: 'Format email tidak valid.' }),
  password: z.string().min(1, { message: 'Password wajib diisi.' }),
});

export type LoginInput = z.infer<typeof LoginSchema>;

export const ChangePasswordSchema = z.object({
  currentPassword: z.string().min(1, { message: 'Password saat ini wajib diisi.' }),
  newPassword: z
    .string()
    .min(8, { message: 'Password baru minimal 8 karakter.' })
    .regex(/[A-Z]/, { message: 'Password baru harus mengandung setidaknya 1 huruf besar.' })
    .regex(/[a-z]/, { message: 'Password baru harus mengandung setidaknya 1 huruf kecil.' })
    .regex(/[0-9]/, { message: 'Password baru harus mengandung setidaknya 1 angka.' }),
});

export type ChangePasswordInput = z.infer<typeof ChangePasswordSchema>;
