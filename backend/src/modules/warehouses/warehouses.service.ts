import { prisma } from '../../database/client';
import {
  NotFoundError,
  ConflictError,
  ValidationError,
  ForbiddenError,
} from '../../utils/app-error';
import { CreateWarehouseInput, UpdateWarehouseInput } from './warehouses.dto';

export class WarehousesService {
  async listWarehouses(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    isActive?: boolean;
    organizationId: string;
    allowedWarehouseIds?: string[];
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 50));
    const skip = (page - 1) * pageSize;

    const where: any = {
      organizationId: params.organizationId,
    };

    // Scoping for Warehouse Staff
    if (params.allowedWarehouseIds !== undefined) {
      where.id = { in: params.allowedWarehouseIds };
    }

    if (params.search) {
      where.OR = [
        { name: { contains: params.search } },
        { code: { contains: params.search } },
      ];
    }

    if (params.isActive !== undefined) {
      where.isActive = params.isActive;
    }

    const [totalItems, warehouses] = await Promise.all([
      prisma.warehouse.count({ where }),
      prisma.warehouse.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { code: 'asc' },
        include: {
          _count: {
            select: {
              balances: true,
              stockTransactions: true,
              staffAssignments: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: warehouses.map((w) => ({
        id: w.id,
        name: w.name,
        code: w.code,
        location: w.location,
        description: w.description,
        isActive: w.isActive,
        createdAt: w.createdAt,
        updatedAt: w.updatedAt,
        balanceCount: w._count.balances,
        transactionCount: w._count.stockTransactions,
        staffCount: w._count.staffAssignments,
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async getWarehouseById(id: string, organizationId: string, allowedWarehouseIds?: string[]) {
    if (allowedWarehouseIds !== undefined && !allowedWarehouseIds.includes(id)) {
      throw new ForbiddenError('Akses ditolak: Anda tidak memiliki akses ke gudang ini.');
    }

    const warehouse = await prisma.warehouse.findFirst({
      where: { id, organizationId },
      include: {
        _count: {
          select: {
            balances: true,
            stockTransactions: true,
            staffAssignments: true,
          },
        },
      },
    });

    if (!warehouse) {
      throw new NotFoundError('Gudang tidak ditemukan.');
    }

    return {
      id: warehouse.id,
      name: warehouse.name,
      code: warehouse.code,
      location: warehouse.location,
      description: warehouse.description,
      isActive: warehouse.isActive,
      createdAt: warehouse.createdAt,
      updatedAt: warehouse.updatedAt,
      balanceCount: warehouse._count.balances,
      transactionCount: warehouse._count.stockTransactions,
      staffCount: warehouse._count.staffAssignments,
    };
  }

  async createWarehouse(input: CreateWarehouseInput, userId: string, organizationId: string) {
    const normalizedCode = input.code.trim().toUpperCase();

    const existing = await prisma.warehouse.findUnique({
      where: {
        organizationId_code: {
          organizationId,
          code: normalizedCode,
        },
      },
    });

    if (existing) {
      throw new ConflictError('Kode gudang sudah digunakan pada organisasi ini.');
    }

    const warehouse = await prisma.warehouse.create({
      data: {
        organizationId,
        name: input.name.trim(),
        code: normalizedCode,
        location: input.location,
        description: input.description,
        isActive: true,
        createdBy: userId,
        updatedBy: userId,
      },
    });

    return warehouse;
  }

  async updateWarehouse(
    id: string,
    input: UpdateWarehouseInput,
    userId: string,
    organizationId: string
  ) {
    const warehouse = await prisma.warehouse.findFirst({
      where: { id, organizationId },
    });

    if (!warehouse) {
      throw new NotFoundError('Gudang tidak ditemukan.');
    }

    const normalizedCode = input.code ? input.code.trim().toUpperCase() : undefined;
    if (normalizedCode && normalizedCode !== warehouse.code) {
      const existing = await prisma.warehouse.findUnique({
        where: {
          organizationId_code: {
            organizationId,
            code: normalizedCode,
          },
        },
      });

      if (existing) {
        throw new ConflictError('Kode gudang sudah digunakan pada organisasi ini.');
      }
    }

    // Invariant: Admin tidak dapat menonaktifkan gudang jika membuat Warehouse Staff aktif kehilangan seluruh gudang aktifnya
    if (input.isActive === false && warehouse.isActive === true) {
      // Temukan seluruh staff yang ditugaskan ke gudang ini
      const staffAssignments = await prisma.userWarehouseAssignment.findMany({
        where: { warehouseId: id },
        include: {
          user: {
            include: {
              warehouseStaff: {
                include: {
                  warehouse: true,
                },
              },
            },
          },
        },
      });

      for (const assignment of staffAssignments) {
        if (assignment.user.status === 'ACTIVE') {
          // Hitung berapa banyak gudang aktif lain yang ditugaskan ke staff ini selain gudang yang akan dinonaktifkan
          const otherActiveWarehouses = assignment.user.warehouseStaff.filter(
            (w) => w.warehouseId !== id && w.warehouse.isActive === true
          );

          if (otherActiveWarehouses.length === 0) {
            throw new ValidationError(
              `Gudang tidak dapat dinonaktifkan karena staf '${assignment.user.name}' tidak memiliki gudang aktif lain yang ditugaskan.`
            );
          }
        }
      }

      // P1-04: Gudang yang masih memiliki saldo stok tidak boleh dinonaktifkan
      const balances = await prisma.inventoryBalance.findMany({
        where: { warehouseId: id },
      });
      const hasStock = balances.some((b) => b.quantity.greaterThan(0));
      if (hasStock) {
        throw new ValidationError(
          'Gudang tidak dapat dinonaktifkan karena masih memiliki saldo stok barang. Kosongkan saldo stok terlebih dahulu melalui transaksi barang keluar.'
        );
      }
    }

    const updated = await prisma.warehouse.update({
      where: { id },
      data: {
        name: input.name ? input.name.trim() : undefined,
        code: normalizedCode,
        location: input.location,
        description: input.description,
        isActive: input.isActive,
        updatedBy: userId,
      },
    });

    return updated;
  }

  async deleteWarehouse(id: string, organizationId: string) {
    const warehouse = await prisma.warehouse.findFirst({
      where: { id, organizationId },
      include: {
        _count: {
          select: {
            balances: true,
            stockTransactions: true,
            stockMovements: true,
            staffAssignments: true,
          },
        },
      },
    });

    if (!warehouse) {
      throw new NotFoundError('Gudang tidak ditemukan.');
    }

    const totalRelations =
      warehouse._count.balances +
      warehouse._count.stockTransactions +
      warehouse._count.stockMovements +
      warehouse._count.staffAssignments;

    if (totalRelations > 0) {
      throw new ValidationError(
        'Gudang yang memiliki saldo, transaksi, mutasi, atau penugasan staf tidak dapat dihapus permanen. Silakan nonaktifkan gudang ini.'
      );
    }

    await prisma.warehouse.delete({
      where: { id },
    });

    return { success: true };
  }
}

export const warehousesService = new WarehousesService();
