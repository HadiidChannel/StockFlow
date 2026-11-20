import { z } from 'zod';

export const UpdateOrganizationSchema = z.object({
  name: z.string().trim().min(2, { message: 'Nama organisasi minimal 2 karakter.' }).max(160),
  code: z.string().trim().max(40).optional().nullable(),
  address: z.string().trim().max(500).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  email: z.string().trim().email({ message: 'Format email tidak valid.' }).max(160).optional().nullable(),
  timezone: z.string().trim().min(1, { message: 'Timezone wajib diisi.' }).max(64),
});

export type UpdateOrganizationInput = z.infer<typeof UpdateOrganizationSchema>;
