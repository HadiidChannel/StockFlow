import { describe, it, expect } from 'vitest';
import { cn, formatQuantity, formatCurrency, formatDate } from '../src/lib/utils';

describe('Frontend Utils Suite', () => {
  it('cn harus menggabungkan class tailwind dan menyelesaikan konflik', () => {
    const result = cn('px-2 py-1', 'px-4', { 'text-red-500': true, 'bg-blue-500': false });
    expect(result).toBe('py-1 px-4 text-red-500');
  });

  it('formatQuantity harus memformat angka dengan 3 desimal format lokal Indonesia', () => {
    expect(formatQuantity('1250.5')).toBe('1.250,500');
    expect(formatQuantity(0)).toBe('0,000');
    expect(formatQuantity('invalid')).toBe('0.000');
  });

  it('formatCurrency harus memformat mata uang Rupiah secara tepat', () => {
    expect(formatCurrency(1500000)).toMatch(/Rp\s?1\.500\.000/);
    expect(formatCurrency(null)).toBe('-');
    expect(formatCurrency(undefined)).toBe('-');
  });

  it('formatDate harus memformat string tanggal ISO menjadi representasi lokal yang terbaca', () => {
    const dateStr = '2026-11-12T02:00:00.000Z';
    const formatted = formatDate(dateStr);
    expect(formatted).toContain('2026');
    expect(formatted).toContain('Nov');
  });
});
