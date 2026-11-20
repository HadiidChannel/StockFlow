'use client';

import React from 'react';
import { useTheme } from '@/components/theme-provider';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { Sun, Moon, Laptop, Settings as SettingsIcon } from 'lucide-react';

export default function SettingsPage() {
  const { theme, setTheme } = useTheme();

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
          <SettingsIcon className="w-8 h-8 text-[var(--sf-primary)]" />
          <span>Pengaturan & Preferensi</span>
        </h1>
        <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
          Sesuaikan tampilan visual antarmuka dan preferensi kerja Anda.
        </p>
      </div>

      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] shadow-sm">
        <CardHeader>
          <CardTitle className="text-base font-semibold">Tema Visual Antarmuka</CardTitle>
          <CardDescription className="text-xs">
            Pilih mode tampilan yang nyaman untuk operasional kerja harian Anda.
          </CardDescription>
        </CardHeader>

        <CardContent>
          <div className="grid grid-cols-3 gap-4">
            {/* Light Mode */}
            <button
              onClick={() => setTheme('light')}
              className={`p-4 rounded-xl border flex flex-col items-center gap-3 transition-all text-center ${
                theme === 'light'
                  ? 'border-[var(--sf-primary)] bg-[var(--sf-primary-soft)] text-[var(--sf-primary)] ring-2 ring-[var(--sf-primary)]/20 shadow-sm font-semibold'
                  : 'border-[var(--sf-border)] bg-[var(--sf-surface)] hover:bg-[var(--sf-surface-hover)] text-[var(--sf-text-secondary)]'
              }`}
            >
              <div className="w-10 h-10 rounded-full bg-white border border-gray-200 shadow flex items-center justify-center text-amber-500">
                <Sun className="w-5 h-5" />
              </div>
              <span className="text-sm">Mode Terang (Light)</span>
            </button>

            {/* Dark Mode */}
            <button
              onClick={() => setTheme('dark')}
              className={`p-4 rounded-xl border flex flex-col items-center gap-3 transition-all text-center ${
                theme === 'dark'
                  ? 'border-[var(--sf-primary)] bg-[var(--sf-primary-soft)] text-[var(--sf-primary)] ring-2 ring-[var(--sf-primary)]/20 shadow-sm font-semibold'
                  : 'border-[var(--sf-border)] bg-[var(--sf-surface)] hover:bg-[var(--sf-surface-hover)] text-[var(--sf-text-secondary)]'
              }`}
            >
              <div className="w-10 h-10 rounded-full bg-gray-900 border border-gray-700 shadow flex items-center justify-center text-blue-400">
                <Moon className="w-5 h-5" />
              </div>
              <span className="text-sm">Mode Gelap (Dark)</span>
            </button>

            {/* System */}
            <button
              onClick={() => setTheme('system')}
              className={`p-4 rounded-xl border flex flex-col items-center gap-3 transition-all text-center ${
                theme === 'system'
                  ? 'border-[var(--sf-primary)] bg-[var(--sf-primary-soft)] text-[var(--sf-primary)] ring-2 ring-[var(--sf-primary)]/20 shadow-sm font-semibold'
                  : 'border-[var(--sf-border)] bg-[var(--sf-surface)] hover:bg-[var(--sf-surface-hover)] text-[var(--sf-text-secondary)]'
              }`}
            >
              <div className="w-10 h-10 rounded-full bg-[var(--sf-surface-subtle)] border border-[var(--sf-border)] flex items-center justify-center text-[var(--sf-text-muted)]">
                <Laptop className="w-5 h-5" />
              </div>
              <span className="text-sm">Ikuti Sistem (Auto)</span>
            </button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
