import { describe, it, expect } from 'vitest';
import { getRolePermissions } from '../src/modules/auth/auth.service';

describe('RBAC Permission Matrix', () => {
  it('Admin harus memiliki izin penuh mencakup manajemen user, organisasi, dan gudang', () => {
    const permissions = getRolePermissions('ADMIN');
    expect(permissions).toContain('user.manage');
    expect(permissions).toContain('organization.manage');
    expect(permissions).toContain('warehouse.manage');
    expect(permissions).toContain('category.manage');
    expect(permissions).toContain('product.create');
    expect(permissions).toContain('stock_in.create');
    expect(permissions).toContain('stock_out.create');
  });

  it('Warehouse Staff TIDAK boleh memiliki izin administrasi', () => {
    const permissions = getRolePermissions('WAREHOUSE_STAFF');
    expect(permissions).not.toContain('user.manage');
    expect(permissions).not.toContain('organization.manage');
    expect(permissions).not.toContain('warehouse.manage');
    expect(permissions).not.toContain('category.manage');
    expect(permissions).not.toContain('product.create');

    // Tapi memiliki izin operasional gudang
    expect(permissions).toContain('dashboard.read');
    expect(permissions).toContain('inventory.read');
    expect(permissions).toContain('stock_in.create');
    expect(permissions).toContain('stock_out.create');
    expect(permissions).toContain('movement.read');
  });
});
