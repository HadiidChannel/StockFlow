'use client';

import React from 'react';
import { ThemeToggle } from '@/components/theme-toggle';
import { Button } from '@/components/ui/button';
import { LogOut, User as UserIcon } from 'lucide-react';
import { api } from '@/lib/api';

interface TopbarProps {
  userName?: string;
  userRole?: string;
}

export function Topbar({ userName = 'Admin StockFlow', userRole = 'Administrator' }: TopbarProps) {
  const handleLogout = async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      // Ignored
    } finally {
      window.location.href = '/login';
    }
  };

  return (
    <header className="h-16 border-b border-[var(--sf-border)] bg-[var(--sf-surface)]/80 backdrop-blur-md px-6 flex items-center justify-between sticky top-0 z-30">
      {/* Page Title or Breadcrumb space */}
      <div className="flex items-center gap-2">
        <span className="text-xs font-mono text-[var(--sf-text-muted)]">StockFlow Workspace</span>
      </div>

      {/* Action Controls */}
      <div className="flex items-center gap-4">
        {/* Theme Toggle */}
        <ThemeToggle />

        {/* User Info */}
        <div className="flex items-center gap-3 pl-4 border-l border-[var(--sf-border)]">
          <div className="w-8 h-8 rounded-full bg-[var(--sf-primary-soft)] border border-[var(--sf-primary)]/20 flex items-center justify-center text-[var(--sf-primary)] font-semibold">
            <UserIcon className="w-4 h-4" />
          </div>
          <div className="hidden sm:flex flex-col text-left">
            <span className="text-sm font-medium leading-none text-[var(--sf-text-primary)]">
              {userName}
            </span>
            <span className="text-[11px] text-[var(--sf-text-muted)]">
              {userRole}
            </span>
          </div>
          <Button
            variant="ghost"
            size="icon"
            onClick={handleLogout}
            title="Keluar"
            aria-label="Logout"
            className="text-[var(--sf-text-secondary)] hover:text-[var(--sf-danger)]"
          >
            <LogOut className="w-4 h-4" />
          </Button>
        </div>
      </div>
    </header>
  );
}
