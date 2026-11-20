import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { prisma } from '../../database/client';
import { UnauthorizedError, ValidationError, NotFoundError } from '../../utils/app-error';
import { LoginInput, ChangePasswordInput } from './auth.dto';

// 7 days session expiration
const SESSION_EXPIRATION_DAYS = 7;

export function getRolePermissions(roleCode: string): string[] {
  if (roleCode === 'ADMIN') {
    return [
      'dashboard.read',
      'product.read',
      'product.create',
      'product.update',
      'product.deactivate',
      'category.read',
      'category.manage',
      'warehouse.read',
      'warehouse.manage',
      'inventory.read',
      'stock_in.create',
      'stock_out.create',
      'movement.read',
      'user.manage',
      'user.warehouse_assignment.manage',
      'organization.manage',
      'preference.manage_self',
    ];
  }

  // WAREHOUSE_STAFF permissions
  return [
    'dashboard.read',
    'product.read',
    'category.read',
    'warehouse.read',
    'inventory.read',
    'stock_in.create',
    'stock_out.create',
    'movement.read',
    'preference.manage_self',
  ];
}

export class AuthService {
  async login(input: LoginInput) {
    const normalizedEmail = input.email.trim().toLowerCase();

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      include: {
        role: true,
      },
    });

    if (!user) {
      throw new UnauthorizedError('Email atau password tidak valid.');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedError('Akun dinonaktifkan. Silakan hubungi Administrator.');
    }

    const isMatch = await bcrypt.compare(input.password, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedError('Email atau password tidak valid.');
    }

    // Generate cryptographically secure random opaque tokens
    const rawSessionToken = crypto.randomBytes(32).toString('hex');
    const rawCsrfToken = crypto.randomBytes(32).toString('hex');

    const tokenHash = crypto.createHash('sha256').update(rawSessionToken).digest('hex');
    const csrfTokenHash = crypto.createHash('sha256').update(rawCsrfToken).digest('hex');

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + SESSION_EXPIRATION_DAYS);

    // Save session in database
    await prisma.session.create({
      data: {
        userId: user.id,
        tokenHash,
        csrfTokenHash,
        expiresAt,
      },
    });

    // Update lastLoginAt asynchronously
    prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    }).catch(() => {});

    const permissions = getRolePermissions(user.role.code);

    return {
      rawSessionToken,
      rawCsrfToken,
      expiresAt,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: {
          code: user.role.code,
          name: user.role.name,
        },
        mustChangePassword: user.mustChangePassword,
        permissions,
      },
    };
  }

  async logout(sessionId?: string) {
    if (!sessionId) return;
    await prisma.session.update({
      where: { id: sessionId },
      data: { revokedAt: new Date() },
    }).catch(() => {});
  }

  async getMe(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
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

    const permissions = getRolePermissions(user.role.code);

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: {
        code: user.role.code,
        name: user.role.name,
      },
      mustChangePassword: user.mustChangePassword,
      permissions,
      assignedWarehouses: user.warehouseStaff.map((w) => ({
        id: w.warehouse.id,
        code: w.warehouse.code,
        name: w.warehouse.name,
        isActive: w.warehouse.isActive,
      })),
    };
  }

  async changePassword(userId: string, input: ChangePasswordInput) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundError('User tidak ditemukan.');
    }

    const isMatch = await bcrypt.compare(input.currentPassword, user.passwordHash);
    if (!isMatch) {
      throw new ValidationError('Password saat ini salah.');
    }

    const salt = await bcrypt.genSalt(12);
    const newPasswordHash = await bcrypt.hash(input.newPassword, salt);

    await prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newPasswordHash,
        mustChangePassword: false,
      },
    });

    return { success: true };
  }
}

export const authService = new AuthService();
