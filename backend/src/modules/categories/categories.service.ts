import { prisma } from '../../database/client';
import {
  NotFoundError,
  ConflictError,
  ValidationError,
} from '../../utils/app-error';
import { CreateCategoryInput, UpdateCategoryInput } from './categories.dto';

export class CategoriesService {
  async listCategories(params: {
    page?: number;
    pageSize?: number;
    search?: string;
    isActive?: boolean;
    organizationId: string;
  }) {
    const page = Math.max(1, Number(params.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(params.pageSize) || 50));
    const skip = (page - 1) * pageSize;

    const where: any = {
      organizationId: params.organizationId,
    };

    if (params.search) {
      where.name = { contains: params.search };
    }

    if (params.isActive !== undefined) {
      where.isActive = params.isActive;
    }

    const [totalItems, categories] = await Promise.all([
      prisma.category.count({ where }),
      prisma.category.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { name: 'asc' },
        include: {
          _count: {
            select: { products: true },
          },
        },
      }),
    ]);

    const totalPages = Math.ceil(totalItems / pageSize);

    return {
      data: categories.map((c) => ({
        id: c.id,
        name: c.name,
        description: c.description,
        isActive: c.isActive,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        productCount: c._count.products,
      })),
      meta: {
        page,
        pageSize,
        totalItems,
        totalPages,
      },
    };
  }

  async getCategoryById(id: string, organizationId: string) {
    const category = await prisma.category.findFirst({
      where: { id, organizationId },
      include: {
        _count: {
          select: { products: true },
        },
      },
    });

    if (!category) {
      throw new NotFoundError('Kategori tidak ditemukan.');
    }

    return {
      id: category.id,
      name: category.name,
      description: category.description,
      isActive: category.isActive,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      productCount: category._count.products,
    };
  }

  async createCategory(input: CreateCategoryInput, userId: string, organizationId: string) {
    const normalizedName = input.name.trim();

    const existing = await prisma.category.findUnique({
      where: {
        organizationId_name: {
          organizationId,
          name: normalizedName,
        },
      },
    });

    if (existing) {
      throw new ConflictError('Kategori dengan nama tersebut sudah ada.');
    }

    const category = await prisma.category.create({
      data: {
        organizationId,
        name: normalizedName,
        description: input.description,
        isActive: true,
        createdBy: userId,
        updatedBy: userId,
      },
    });

    return category;
  }

  async updateCategory(
    id: string,
    input: UpdateCategoryInput,
    userId: string,
    organizationId: string
  ) {
    const category = await prisma.category.findFirst({
      where: { id, organizationId },
    });

    if (!category) {
      throw new NotFoundError('Kategori tidak ditemukan.');
    }

    if (input.name && input.name.trim() !== category.name) {
      const existing = await prisma.category.findUnique({
        where: {
          organizationId_name: {
            organizationId,
            name: input.name.trim(),
          },
        },
      });

      if (existing) {
        throw new ConflictError('Kategori dengan nama tersebut sudah ada.');
      }
    }

    const updated = await prisma.category.update({
      where: { id },
      data: {
        name: input.name ? input.name.trim() : undefined,
        description: input.description,
        isActive: input.isActive,
        updatedBy: userId,
      },
    });

    return updated;
  }

  async deleteCategory(id: string, organizationId: string) {
    const category = await prisma.category.findFirst({
      where: { id, organizationId },
      include: {
        _count: {
          select: { products: true },
        },
      },
    });

    if (!category) {
      throw new NotFoundError('Kategori tidak ditemukan.');
    }

    if (category._count.products > 0) {
      throw new ValidationError(
        'Kategori yang sudah digunakan oleh produk tidak dapat dihapus. Silakan nonaktifkan kategori ini.'
      );
    }

    await prisma.category.delete({
      where: { id },
    });

    return { success: true };
  }
}

export const categoriesService = new CategoriesService();
