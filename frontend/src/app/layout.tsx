import type { Metadata } from 'next';
import './globals.css';
import { ThemeProvider } from '@/components/theme-provider';

export const metadata: Metadata = {
  title: 'StockFlow - B2B Inventory & Warehouse Management System',
  description: 'Know your stock. Move with confidence. Sistem manajemen inventaris multi-gudang modern, aman, dan presisi.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id" suppressHydrationWarning>
      <body className="min-h-screen bg-[var(--sf-bg)] text-[var(--sf-text-primary)] antialiased">
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
