import bcrypt from 'bcryptjs';
import { prisma } from '../../database/client';
import {
  NotFoundError,
  ValidationError,
  ConflictError,
  ForbiddenError,
} from '../../utils/app-error';
import {
  CreateUserInput,
  UpdateUserInput,
  AssignWarehousesInput,
  ResetPasswordInput,
} from './users.dto';

export class UsersService {
  async listUsers(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    roleCode?: string;
    status?: string;
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 20));
    const skip = (page - 1) * pageSize;

    const where: any = {};

    if (params.search) {
      where.OR = [
        { name: { contains: params.search } },
        { email: { contains: params.search } },
      ];
    }

    if (params.roleCode) {
      where.role = { code: params.roleCode };
    }

    if (params.status) {
      where.status = params.status;
    }

    const [totalItems, users] = await Promise.all([
      prisma.user.count({ where }),
      prisma.user.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        include: {
          role: true,
          warehouseStaff: {
            include: {
              warehouse: true,
            },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: users.map((u) => ({
        id: u.id,
        name: u.name,
        email: u.email,
        role: {
          code: u.role.code,
          name: u.role.name,
        },
        status: u.status,
        mustChangePassword: u.mustChangePassword,
        lastLoginAt: u.lastLoginAt,
        createdAt: u.createdAt,
        assignedWarehouses: u.warehouseStaff.map((w) => ({
          id: w.warehouse.id,
          code: w.warehouse.code,
          name: w.warehouse.name,
          isActive: w.warehouse.isActive,
        })),
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async getUserById(id: string) {
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        role: true,
        warehouseStaff: {
          include: {
            warehouse: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundError('User tidak ditemukan.');
    }

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: {
        code: user.role.code,
        name: user.role.name,
      },
      status: user.status,
      mustChangePassword: user.mustChangePassword,
      lastLoginAt: user.lastLoginAt,
      createdAt: user.createdAt,
      assignedWarehouses: user.warehouseStaff.map((w) => ({
        id: w.warehouse.id,
        code: w.warehouse.code,
        name: w.warehouse.name,
        isActive: w.warehouse.isActive,
      })),
    };
  }

  async createUser(input: CreateUserInput, creatorId: string) {
    const normalizedEmail = input.email.trim().toLowerCase();

    // Check email uniqueness
    const existing = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (existing) {
      throw new ConflictError('Email sudah terdaftar.');
    }

    const role = await prisma.role.findUnique({
      where: { code: input.roleCode },
    });

    if (!role) {
      throw new NotFoundError(`Role ${input.roleCode} tidak ditemukan.`);
    }

    // Organization
    const org = await prisma.organization.findFirst();
    if (!org) {
      throw new ValidationError('Organisasi belum dikonfigurasi.');
    }

    // If Warehouse Staff, validate warehouse assignment
    if (input.roleCode === 'WAREHOUSE_STAFF') {
      if (!input.warehouseIds || input.warehouseIds.length === 0) {
        throw new ValidationError('Warehouse Staff wajib ditugaskan ke minimal satu gudang aktif.');
      }

      const activeWarehouses = await prisma.warehouse.findMany({
        where: {
          id: { in: input.warehouseIds },
          isActive: true,
        },
      });

      if (activeWarehouses.length !== input.warehouseIds.length) {
        throw new ValidationError('Semua gudang yang ditugaskan harus berstatus aktif.');
      }
    }

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(input.password, salt);

    return await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: {
          organizationId: org.id,
          roleId: role.id,
          name: input.name,
          email: normalizedEmail,
          passwordHash,
          status: 'ACTIVE',
          mustChangePassword: true,
          createdBy: creatorId,
        },
      });

      if (input.roleCode === 'WAREHOUSE_STAFF' && input.warehouseIds) {
        for (const whId of input.warehouseIds) {
          await tx.userWarehouseAssignment.create({
            data: {
              userId: newUser.id,
              warehouseId: whId,
              assignedBy: creatorId,
            },
          });
        }
      }

      return {
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        role: {
          code: role.code,
          name: role.name,
        },
        status: newUser.status,
      };
    });
  }

  async updateUser(id: string, input: UpdateUserInput, currentUserId: string) {
    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: true },
    });

    if (!user) {
      throw new NotFoundError('User tidak ditemukan.');
    }

    // Invariant: Satu-satunya Admin aktif tidak boleh dinonaktifkan atau diubah role-nya
    if (user.role.code === 'ADMIN' && (input.status === 'INACTIVE' || (input.roleCode && input.roleCode !== 'ADMIN'))) {
      const activeAdminCount = await prisma.user.count({
        where: {
          status: 'ACTIVE',
          role: { code: 'ADMIN' },
        },
      });

      if (activeAdminCount <= 1) {
        throw new ForbiddenError('Tidak dapat menonaktifkan atau mengubah role satu-satunya Administrator aktif.');
      }
    }

    let newRoleId: string | undefined;
    if (input.roleCode && input.roleCode !== user.role.code) {
      const role = await prisma.role.findUnique({
        where: { code: input.roleCode },
      });
      if (!role) throw new NotFoundError('Role tidak ditemukan.');
      newRoleId = role.id;
    }

    return await prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id },
        data: {
          name: input.name,
          status: input.status as any,
          roleId: newRoleId,
          updatedBy: currentUserId,
        },
        include: { role: true },
      });

      // If user is deactivated, revoke all active sessions immediately
      if (input.status === 'INACTIVE') {
        await tx.session.updateMany({
          where: {
            userId: id,
            revokedAt: null,
          },
          data: {
            revokedAt: new Date(),
          },
        });
      }

      return {
        id: updated.id,
        name: updated.name,
        email: updated.email,
        role: {
          code: updated.role.code,
          name: updated.role.name,
        },
        status: updated.status,
      };
    });
  }

  async assignWarehouses(userId: string, input: AssignWarehousesInput, currentUserId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { role: true },
    });

    if (!user) {
      throw new NotFoundError('User tidak ditemukan.');
    }

    if (user.role.code !== 'WAREHOUSE_STAFF') {
      throw new ValidationError('Penugasan gudang hanya dapat diterapkan untuk Warehouse Staff.');
    }

    // Verify all target warehouses exist and are active
    const activeWarehouses = await prisma.warehouse.findMany({
      where: {
        id: { in: input.warehouseIds },
        isActive: true,
      },
    });

    if (activeWarehouses.length !== input.warehouseIds.length) {
      throw new ValidationError('Seluruh gudang yang ditugaskan harus berstatus aktif.');
    }

    return await prisma.$transaction(async (tx) => {
      // Clear previous assignments
      await tx.userWarehouseAssignment.deleteMany({
        where: { userId },
      });

      // Insert new assignments
      for (const whId of input.warehouseIds) {
        await tx.userWarehouseAssignment.create({
          data: {
            userId,
            warehouseId: whId,
            assignedBy: currentUserId,
          },
        });
      }

      return { success: true, count: input.warehouseIds.length };
    });
  }

  async resetPassword(userId: string, input: ResetPasswordInput) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundError('User tidak ditemukan.');
    }

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(input.temporaryPassword, salt);

    await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          passwordHash,
          mustChangePassword: true,
        },
      });

      // Revoke all existing sessions so user must log in with new password
      await tx.session.updateMany({
        where: {
          userId,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });
    });

    return { success: true };
  }
}

export const usersService = new UsersService();
