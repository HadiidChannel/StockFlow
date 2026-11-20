'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Boxes,
  ArrowDownToLine,
  ArrowUpFromLine,
  History,
  Package,
  Tags,
  Warehouse,
  Users,
  Building2,
  Settings,
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  adminOnly?: boolean;
}

const navItems: NavItem[] = [
  { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Saldo Inventaris', href: '/inventory', icon: Boxes },
  { label: 'Stock In', href: '/inventory/stock-in', icon: ArrowDownToLine },
  { label: 'Stock Out', href: '/inventory/stock-out', icon: ArrowUpFromLine },
  { label: 'Riwayat Mutasi', href: '/movements', icon: History },
  { label: 'Katalog Produk', href: '/products', icon: Package },
  { label: 'Kategori', href: '/categories', icon: Tags, adminOnly: true },
  { label: 'Gudang', href: '/warehouses', icon: Warehouse },
  { label: 'Kelola Pengguna', href: '/users', icon: Users, adminOnly: true },
  { label: 'Profil Organisasi', href: '/organization', icon: Building2, adminOnly: true },
  { label: 'Pengaturan', href: '/settings', icon: Settings },
];

interface SidebarProps {
  userRole?: 'ADMIN' | 'WAREHOUSE_STAFF';
}

export function Sidebar({ userRole = 'ADMIN' }: SidebarProps) {
  const pathname = usePathname();

  return (
    <aside className="w-64 border-r border-[var(--sf-border)] bg-[var(--sf-surface)] flex flex-col shrink-0 h-screen sticky top-0">
      {/* Brand Logo */}
      <div className="h-16 flex items-center px-6 border-b border-[var(--sf-border)] gap-3">
        <div className="w-8 h-8 rounded-lg bg-[var(--sf-primary)] flex items-center justify-center text-white font-bold shadow-md">
          SF
        </div>
        <div className="flex flex-col">
          <span className="font-bold tracking-tight text-[var(--sf-text-primary)] text-lg leading-tight">
            StockFlow
          </span>
          <span className="text-[10px] text-[var(--sf-text-muted)] font-mono tracking-wider uppercase">
            Enterprise WMS
          </span>
        </div>
      </div>

      {/* Nav Menu */}
      <nav className="flex-1 overflow-y-auto p-4 space-y-1">
        <div className="px-2 py-1.5 text-[11px] font-semibold text-[var(--sf-text-muted)] uppercase tracking-wider">
          Operasional
        </div>
        {navItems
          .filter((item) => !item.adminOnly || userRole === 'ADMIN')
          .map((item) => {
            const isActive = pathname === item.href || (item.href !== '/dashboard' && pathname?.startsWith(item.href));
            const Icon = item.icon;

            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-[var(--sf-primary-soft)] text-[var(--sf-primary)] font-semibold'
                    : 'text-[var(--sf-text-secondary)] hover:bg-[var(--sf-surface-subtle)] hover:text-[var(--sf-text-primary)]'
                )}
              >
                <Icon className={cn('w-4 h-4', isActive ? 'text-[var(--sf-primary)]' : 'text-[var(--sf-text-muted)]')} />
                <span>{item.label}</span>
              </Link>
            );
          })}
      </nav>

      {/* Role Pill Footer */}
      <div className="p-4 border-t border-[var(--sf-border)] bg-[var(--sf-surface-subtle)]">
        <div className="flex items-center justify-between text-xs">
          <span className="text-[var(--sf-text-secondary)]">Hak Akses:</span>
          <span className="font-mono px-2 py-0.5 rounded bg-[var(--sf-surface)] border border-[var(--sf-border)] font-semibold text-[var(--sf-primary)]">
            {userRole}
          </span>
        </div>
      </div>
    </aside>
  );
}
