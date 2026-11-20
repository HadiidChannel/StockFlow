# Modul Pembelajaran 08: Next.js App Router, SSR, & Layout Hierarchies

## 1. Konsep yang Digunakan
- Next.js 15 App Router Architecture.
- Server Components (RSC) vs Client Components (`'use client'`).
- Nested Layouts dan Route Groups `(auth)`, `(dashboard)`, `(marketing)`.
- Streaming dengan React Suspense.
- Server Actions dan Route Handlers.

## 2. Mengapa Konsep Ini Diperlukan
Next.js App Router memberikan pemisahan rendering yang efisien. Landing page dan shell aplikasi dapat di-render di server untuk kecepatan First Contentful Paint (FCP) dan SEO optimal, sedangkan modul formulir interaktif menggunakan client components untuk interaktivitas instan.

## 3. Cara Kerja
File `layout.tsx` membungkus seluruh child routes di dalam direktori yang sama. Route groups (folder dengan tanda kurung seperti `(dashboard)`) memungkinkan kita mengelompokkan halaman dengan layout berbeda tanpa memengaruhi struktur URL browser.

## 4. Contoh Kode dalam Konteks StockFlow
```tsx
// frontend/src/app/(dashboard)/layout.tsx
import { Sidebar } from '@/components/layout/sidebar';
import { Topbar } from '@/components/layout/topbar';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[var(--sf-bg)] text-[var(--sf-text-primary)] flex">
      {/* Sidebar navigasi tetap */}
      <Sidebar />

      {/* Konten utama dengan Topbar */}
      <div className="flex-1 flex flex-col min-w-0">
        <Topbar />
        <main className="flex-1 p-6 md:p-8 max-w-7xl mx-auto w-full">
          {children}
        </main>
      </div>
    </div>
  );
}
```

## 5. Penjelasan Bagian Penting Kode
1. Shared Layout: Komponen `Sidebar` dan `Topbar` tidak me-mount ulang saat pengguna berpindah halaman dashboard, mempertahankan state navigasi dan scroll position.
2. Token CSS Variable: Menggunakan variabel desain `--sf-bg` untuk mendukung pergantian tema Light dan Dark secara instan.

## 6. Kesalahan Umum yang Perlu Dihindari
- Menambahkan `'use client'` di tingkat paling atas layout atau halaman ketika hanya satu tombol yang membutuhkan interaktivitas. Buat komponen interaktif kecil dengan `'use client'` dan impor ke dalam Server Component.
- Mengakses objek browser seperti `window` atau `document` di Server Component.
