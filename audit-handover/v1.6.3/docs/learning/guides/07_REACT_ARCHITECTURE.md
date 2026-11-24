# Modul Pembelajaran 07: React Component Architecture & State Management

## 1. Konsep yang Digunakan
- React 19 Component Driven Development.
- Custom Hooks untuk enkapsulasi logika data fetch dan form handling.
- Uncontrolled vs Controlled Components.
- Composition Pattern (Slots, Compound Components dengan Radix UI / shadcn).
- UI States: Loading skeleton, Empty state, Error state, Success feedback.

## 2. Mengapa Konsep Ini Diperlukan
Aplikasi operasional gudang membutuhkan kecepatan respons tinggi dan validasi input instan. Dengan arsitektur komponen yang baik, form Stock In dan Stock Out dapat memvalidasi saldo secara lokal sebelum request dikirim ke server, sekaligus memberikan feedback visual yang jelas tanpa memuat ulang seluruh halaman.

## 3. Cara Kerja
React menggunakan Virtual DOM untuk membandingkan perubahan state (reconciliation). Ketika user mengetik kuantitas atau memilih gudang, state lokal diperbarui, memicu rendering ulang yang efisien hanya pada elemen yang terpengaruh.

## 4. Contoh Kode dalam Konteks StockFlow
```tsx
// frontend/src/hooks/use-inventory-balance.ts
import { useState, useEffect } from 'react';
import { api } from '@/lib/api';

export function useInventoryBalance(productId?: string, warehouseId?: string) {
  const [balance, setBalance] = useState<string>('0.000');
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!productId || !warehouseId) {
      setBalance('0.000');
      return;
    }

    let isMounted = true;
    setIsLoading(true);
    setError(null);

    api.get(`/inventory/balances?productId=${productId}&warehouseId=${warehouseId}`)
      .then((res) => {
        if (isMounted) {
          const item = res.data.data[0];
          setBalance(item ? item.quantity : '0.000');
        }
      })
      .catch((err) => {
        if (isMounted) setError(err.message || 'Gagal memuat saldo');
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, [productId, warehouseId]);

  return { balance, isLoading, error };
}
```

## 5. Penjelasan Bagian Penting Kode
1. Flag `isMounted`: Mencegah pembaruan state pada komponen yang sudah di-unmount jika respons jaringan tiba terlambat (mencegah memory leak).
2. Reset Dependensi: `useEffect` otomatis dieksekusi ulang saat `productId` atau `warehouseId` berubah.

## 6. Kesalahan Umum yang Perlu Dihindari
- Menyimpan state yang dapat dihitung (derived state) dalam `useState`. Hitung secara langsung saat render atau gunakan `useMemo`.
- Menempatkan logic bisnis backend di dalam komponen UI presentation.
