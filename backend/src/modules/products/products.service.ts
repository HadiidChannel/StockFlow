import { prisma } from '../../database/client';
import {
  NotFoundError,
  ConflictError,
  ValidationError,
} from '../../utils/app-error';
import { CreateProductInput, UpdateProductInput } from './products.dto';
import { Prisma } from '@prisma/client';

export class ProductsService {
  async listProducts(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    categoryId?: string;
    isActive?: boolean;
    lowStock?: boolean;
    organizationId: string;
    allowedWarehouseIds?: string[];
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 20));
    const skip = (page - 1) * pageSize;

    const where: any = {
      organizationId: params.organizationId,
    };

    if (params.search) {
      where.OR = [
        { name: { contains: params.search } },
        { sku: { contains: params.search } },
      ];
    }

    if (params.categoryId) {
      where.categoryId = params.categoryId;
    }

    if (params.isActive !== undefined) {
      where.isActive = params.isActive;
    }

    // Filter balances based on warehouse scoping
    const balanceWhere: any = {};
    if (params.allowedWarehouseIds !== undefined) {
      balanceWhere.warehouseId = { in: params.allowedWarehouseIds };
    }

    const [totalItems, products] = await Promise.all([
      prisma.product.count({ where }),
      prisma.product.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { name: 'asc' },
        include: {
          category: {
            select: {
              id: true,
              name: true,
            },
          },
          balances: {
            where: balanceWhere,
            include: {
              warehouse: {
                select: {
                  id: true,
                  name: true,
                  code: true,
                },
              },
            },
          },
        },
      }),
    ]);

    const formatted = products.map((p) => {
      let totalQty = new Prisma.Decimal(0);
      for (const b of p.balances) {
        totalQty = totalQty.plus(b.quantity);
      }

      const isLowStock = totalQty.lessThanOrEqualTo(p.minimumStock);
      const isOutOfStock = totalQty.equals(0);

      return {
        id: p.id,
        name: p.name,
        sku: p.sku,
        unit: p.unit,
        minimumStock: p.minimumStock.toString(),
        costPrice: p.costPrice ? p.costPrice.toString() : null,
        description: p.description,
        isActive: p.isActive,
        category: p.category,
        totalQuantity: totalQty.toString(),
        isLowStock,
        isOutOfStock,
        balances: p.balances.map((b) => ({
          warehouseId: b.warehouseId,
          warehouseName: b.warehouse.name,
          warehouseCode: b.warehouse.code,
          quantity: b.quantity.toString(),
        })),
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      };
    });

    const finalData = params.lowStock ? formatted.filter((f) => f.isLowStock) : formatted;
    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: finalData,
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async getProductById(id: string, organizationId: string, allowedWarehouseIds?: string[]) {
    const balanceWhere: any = {};
    if (allowedWarehouseIds !== undefined) {
      balanceWhere.warehouseId = { in: allowedWarehouseIds };
    }

    const product = await prisma.product.findFirst({
      where: { id, organizationId },
      include: {
        category: {
          select: {
            id: true,
            name: true,
          },
        },
        balances: {
          where: balanceWhere,
          include: {
            warehouse: {
              select: {
                id: true,
                name: true,
                code: true,
              },
            },
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundError('Produk tidak ditemukan.');
    }

    let totalQty = new Prisma.Decimal(0);
    for (const b of product.balances) {
      totalQty = totalQty.plus(b.quantity);
    }

    return {
      id: product.id,
      name: product.name,
      sku: product.sku,
      unit: product.unit,
      minimumStock: product.minimumStock.toString(),
      costPrice: product.costPrice ? product.costPrice.toString() : null,
      description: product.description,
      isActive: product.isActive,
      category: product.category,
      totalQuantity: totalQty.toString(),
      balances: product.balances.map((b) => ({
        warehouseId: b.warehouseId,
        warehouseName: b.warehouse.name,
        warehouseCode: b.warehouse.code,
        quantity: b.quantity.toString(),
      })),
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    };
  }

  async createProduct(input: CreateProductInput, userId: string, organizationId: string) {
    const normalizedSku = input.sku.trim().toUpperCase();

    // Check SKU uniqueness
    const existing = await prisma.product.findUnique({
      where: {
        organizationId_sku: {
          organizationId,
          sku: normalizedSku,
        },
      },
    });

    if (existing) {
      throw new ConflictError('SKU produk sudah digunakan pada organisasi ini.');
    }

    // Verify category exists and is active
    const category = await prisma.category.findFirst({
      where: {
        id: input.categoryId,
        organizationId,
      },
    });

    if (!category) {
      throw new NotFoundError('Kategori tidak ditemukan.');
    }

    if (!category.isActive) {
      throw new ValidationError('Produk baru hanya dapat menggunakan kategori yang aktif.');
    }

    const product = await prisma.product.create({
      data: {
        organizationId,
        categoryId: input.categoryId,
        name: input.name.trim(),
        sku: normalizedSku,
        unit: input.unit.trim(),
        minimumStock: new Prisma.Decimal(input.minimumStock),
        costPrice: input.costPrice ? new Prisma.Decimal(input.costPrice) : null,
        description: input.description,
        isActive: true,
        createdBy: userId,
        updatedBy: userId,
      },
      include: {
        category: true,
      },
    });

    return {
      id: product.id,
      name: product.name,
      sku: product.sku,
      unit: product.unit,
      minimumStock: product.minimumStock.toString(),
      costPrice: product.costPrice ? product.costPrice.toString() : null,
      description: product.description,
      isActive: product.isActive,
      category: product.category,
      createdAt: product.createdAt,
    };
  }

  async updateProduct(
    id: string,
    input: UpdateProductInput,
    userId: string,
    organizationId: string
  ) {
    const product = await prisma.product.findFirst({
      where: { id, organizationId },
    });

    if (!product) {
      throw new NotFoundError('Produk tidak ditemukan.');
    }

    const normalizedSku = input.sku ? input.sku.trim().toUpperCase() : undefined;
    if (normalizedSku && normalizedSku !== product.sku) {
      const existing = await prisma.product.findUnique({
        where: {
          organizationId_sku: {
            organizationId,
            sku: normalizedSku,
          },
        },
      });

      if (existing) {
        throw new ConflictError('SKU produk sudah digunakan pada organisasi ini.');
      }
    }

    if (input.categoryId && input.categoryId !== product.categoryId) {
      const category = await prisma.category.findFirst({
        where: { id: input.categoryId, organizationId },
      });
      if (!category) throw new NotFoundError('Kategori tidak ditemukan.');
    }

    // P1-04: Produk yang masih memiliki saldo stok tidak boleh dinonaktifkan
    if (input.isActive === false && product.isActive === true) {
      const balances = await prisma.inventoryBalance.findMany({
        where: { productId: id },
      });
      const hasStock = balances.some((b) => b.quantity.greaterThan(0));
      if (hasStock) {
        throw new ValidationError(
          'Produk tidak dapat dinonaktifkan karena masih memiliki sisa saldo stok di gudang. Habiskan stok terlebih dahulu melalui transaksi barang keluar.'
        );
      }
    }

    const updated = await prisma.product.update({
      where: { id },
      data: {
        categoryId: input.categoryId,
        name: input.name ? input.name.trim() : undefined,
        sku: normalizedSku,
        unit: input.unit ? input.unit.trim() : undefined,
        minimumStock: input.minimumStock ? new Prisma.Decimal(input.minimumStock) : undefined,
        costPrice: input.costPrice !== undefined ? (input.costPrice ? new Prisma.Decimal(input.costPrice) : null) : undefined,
        description: input.description,
        isActive: input.isActive,
        updatedBy: userId,
      },
      include: { category: true },
    });

    return {
      id: updated.id,
      name: updated.name,
      sku: updated.sku,
      unit: updated.unit,
      minimumStock: updated.minimumStock.toString(),
      costPrice: updated.costPrice ? updated.costPrice.toString() : null,
      description: updated.description,
      isActive: updated.isActive,
      category: updated.category,
      updatedAt: updated.updatedAt,
    };
  }

  async deleteProduct(id: string, organizationId: string) {
    const product = await prisma.product.findFirst({
      where: { id, organizationId },
      include: {
        _count: {
          select: {
            balances: true,
            stockTransactionItems: true,
            stockMovements: true,
          },
        },
      },
    });

    if (!product) {
      throw new NotFoundError('Produk tidak ditemukan.');
    }

    const totalRelations =
      product._count.balances +
      product._count.stockTransactionItems +
      product._count.stockMovements;

    if (totalRelations > 0) {
      throw new ValidationError(
        'Produk yang memiliki saldo, transaksi, atau riwayat pergerakan tidak dapat dihapus permanen. Silakan nonaktifkan produk ini.'
      );
    }

    await prisma.product.delete({
      where: { id },
    });

    return { success: true };
  }
}

export const productsService = new ProductsService();
