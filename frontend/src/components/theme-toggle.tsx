'use client';

import React from 'react';
import { useTheme } from './theme-provider';
import { Sun, Moon, Laptop } from 'lucide-react';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <div className="flex items-center gap-1 p-1 rounded-lg bg-[var(--sf-surface-subtle)] border border-[var(--sf-border)]">
      <button
        onClick={() => setTheme('light')}
        className={`p-1.5 rounded-md transition-colors ${
          theme === 'light'
            ? 'bg-[var(--sf-surface)] text-[var(--sf-primary)] shadow-sm'
            : 'text-[var(--sf-text-secondary)] hover:text-[var(--sf-text-primary)]'
        }`}
        title="Light Mode"
        aria-label="Light Mode"
      >
        <Sun className="w-4 h-4" />
      </button>
      <button
        onClick={() => setTheme('dark')}
        className={`p-1.5 rounded-md transition-colors ${
          theme === 'dark'
            ? 'bg-[var(--sf-surface)] text-[var(--sf-primary)] shadow-sm'
            : 'text-[var(--sf-text-secondary)] hover:text-[var(--sf-text-primary)]'
        }`}
        title="Dark Mode"
        aria-label="Dark Mode"
      >
        <Moon className="w-4 h-4" />
      </button>
      <button
        onClick={() => setTheme('system')}
        className={`p-1.5 rounded-md transition-colors ${
          theme === 'system'
            ? 'bg-[var(--sf-surface)] text-[var(--sf-primary)] shadow-sm'
            : 'text-[var(--sf-text-secondary)] hover:text-[var(--sf-text-primary)]'
        }`}
        title="System Preference"
        aria-label="System Preference"
      >
        <Laptop className="w-4 h-4" />
      </button>
    </div>
  );
}
