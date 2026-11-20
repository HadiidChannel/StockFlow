import { z } from 'zod';

export const TransactionItemInputSchema = z.object({
  productId: z.string().uuid({ message: 'Product ID harus berupa UUID valid.' }),
  quantity: z
    .string()
    .regex(/^\d+(\.\d{1,3})?$/, {
      message: 'Kuantitas harus berupa angka positif dengan maksimal 3 angka desimal.',
    })
    .refine((val) => parseFloat(val) > 0, {
      message: 'Kuantitas harus lebih besar dari 0.',
    }),
});

export const StockInSchema = z.object({
  warehouseId: z.string().uuid({ message: 'Warehouse ID harus berupa UUID valid.' }),
  note: z.string().trim().max(1000).optional().nullable(),
  externalReference: z.string().trim().max(120).optional().nullable(),
  items: z.array(TransactionItemInputSchema).min(1, {
    message: 'Transaksi harus memiliki setidaknya satu item barang.',
  }),
});

export type StockInInput = z.infer<typeof StockInSchema>;

export const StockOutSchema = z.object({
  warehouseId: z.string().uuid({ message: 'Warehouse ID harus berupa UUID valid.' }),
  note: z.string().trim().max(1000).optional().nullable(),
  externalReference: z.string().trim().max(120).optional().nullable(),
  items: z.array(TransactionItemInputSchema).min(1, {
    message: 'Transaksi harus memiliki setidaknya satu item barang.',
  }),
});

export type StockOutInput = z.infer<typeof StockOutSchema>;

export const ReversalSchema = z.object({
  note: z.string().trim().max(1000).optional().nullable(),
});

export type ReversalInput = z.infer<typeof ReversalSchema>;
