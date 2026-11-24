import { describe, it, expect } from 'vitest';
import { StockInSchema, StockOutSchema } from '../src/modules/inventory/inventory.dto';
import { CreateProductSchema } from '../src/modules/products/products.dto';
import { CreateWarehouseSchema } from '../src/modules/warehouses/warehouses.dto';

describe('Validation Schemas Test', () => {
  it('harus memvalidasi input Stock In dengan kuantitas positif 3 desimal', () => {
    const validData = {
      warehouseId: '11111111-1111-4111-8111-111111111111',
      items: [
        {
          productId: '22222222-2222-4222-8222-222222222222',
          quantity: '10.500',
        },
      ],
    };
    const res = StockInSchema.safeParse(validData);
    expect(res.success).toBe(true);
  });

  it('harus menolak Stock In jika kuantitas bernilai 0 atau negatif', () => {
    const invalidDataZero = {
      warehouseId: '11111111-1111-4111-8111-111111111111',
      items: [
        {
          productId: '22222222-2222-4222-8222-222222222222',
          quantity: '0.000',
        },
      ],
    };
    const res = StockInSchema.safeParse(invalidDataZero);
    expect(res.success).toBe(false);
  });

  it('harus menolak Stock In jika item kosong', () => {
    const invalidEmptyItems = {
      warehouseId: '11111111-1111-4111-8111-111111111111',
      items: [],
    };
    const res = StockInSchema.safeParse(invalidEmptyItems);
    expect(res.success).toBe(false);
  });

  it('harus menolak SKU yang mengandung karakter non-alphanumeric selain hyphen dan underscore', () => {
    const invalidProduct = {
      categoryId: '11111111-1111-4111-8111-111111111111',
      name: 'Produk Uji',
      sku: 'SKU#123@!',
      unit: 'PCS',
      minimumStock: '5.000',
    };
    const res = CreateProductSchema.safeParse(invalidProduct);
    expect(res.success).toBe(false);
  });

  it('harus menerima format kode gudang uppercase valid', () => {
    const validWarehouse = {
      name: 'Gudang Pusat Surabaya',
      code: 'WH_SUB_01',
      location: 'Rungkut Industri',
    };
    const res = CreateWarehouseSchema.safeParse(validWarehouse);
    expect(res.success).toBe(true);
  });
});
