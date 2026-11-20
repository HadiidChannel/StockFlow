'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Sidebar } from '@/components/layout/sidebar';
import { Topbar } from '@/components/layout/topbar';
import { api } from '@/lib/api';
import { User } from '@/types';
import { Loader2 } from 'lucide-react';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    api
      .get('/auth/me')
      .then((res) => {
        if (isMounted) {
          const userData = res.data.data.user;
          if (userData.mustChangePassword) {
            router.push('/change-password');
          } else {
            setUser(userData);
          }
        }
      })
      .catch(() => {
        if (isMounted) {
          router.push('/login');
        }
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, [router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[var(--sf-bg)] text-[var(--sf-text-secondary)]">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="w-8 h-8 animate-spin text-[var(--sf-primary)]" />
          <span className="text-sm font-medium">Memuat sesi StockFlow...</span>
        </div>
      </div>
    );
  }

  if (!user) return null;

  return (
    <div className="min-h-screen bg-[var(--sf-bg)] text-[var(--sf-text-primary)] flex">
      {/* Sidebar Nav */}
      <Sidebar userRole={user.role.code} />

      {/* Main Workspace */}
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar userName={user.name} userRole={user.role.name} />
        <main className="flex-1 p-6 md:p-8 max-w-7xl mx-auto w-full">
          {children}
        </main>
      </div>
    </div>
  );
}
