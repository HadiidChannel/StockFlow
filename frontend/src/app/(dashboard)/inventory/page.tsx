'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { InventoryBalance, Warehouse } from '@/types';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Boxes,
  ArrowDownToLine,
  ArrowUpFromLine,
  Search,
  Filter,
  Loader2,
} from 'lucide-react';

export default function InventoryBalancesPage() {
  const [balances, setBalances] = useState<InventoryBalance[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string>('');
  const [search, setSearch] = useState<string>('');
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const fetchBalances = () => {
    setIsLoading(true);
    let url = '/inventory/balances?';
    if (selectedWarehouseId) url += `warehouseId=${selectedWarehouseId}&`;

    api
      .get(url)
      .then((res) => {
        setBalances(res.data.data);
      })
      .catch((err) => {
        console.error('Gagal memuat saldo:', err);
      })
      .finally(() => {
        setIsLoading(false);
      });
  };

  useEffect(() => {
    api
      .get('/warehouses?isActive=true')
      .then((res) => {
        setWarehouses(res.data.data);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    fetchBalances();
  }, [selectedWarehouseId]);

  const filteredBalances = balances.filter((b) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      b.product.name.toLowerCase().includes(q) ||
      b.product.sku.toLowerCase().includes(q) ||
      b.warehouse.name.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)]">
            Saldo Inventaris
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Pantau kuantitas stok produk terkini pada masing-masing lokasi gudang.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <Link href="/inventory/stock-in">
            <Button className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white gap-2 font-medium">
              <ArrowDownToLine className="w-4 h-4" />
              <span>Stock In</span>
            </Button>
          </Link>
          <Link href="/inventory/stock-out">
            <Button variant="outline" className="border-[var(--sf-border)] gap-2 font-medium">
              <ArrowUpFromLine className="w-4 h-4" />
              <span>Stock Out</span>
            </Button>
          </Link>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari produk berdasarkan nama atau SKU..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-[var(--sf-text-muted)] shrink-0" />
          <select
            value={selectedWarehouseId}
            onChange={(e) => setSelectedWarehouseId(e.target.value)}
            className="h-9 px-3 py-1 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] w-full sm:w-56 focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
          >
            <option value="">Semua Gudang</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name} ({w.code})
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Balances Table */}
      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] overflow-hidden">
        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-b border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-3 px-4 font-semibold">Produk</th>
                <th className="py-3 px-4 font-semibold">SKU</th>
                <th className="py-3 px-4 font-semibold">Kategori</th>
                <th className="py-3 px-4 font-semibold">Gudang</th>
                <th className="py-3 px-4 font-semibold text-right">Saldo Tersedia</th>
                <th className="py-3 px-4 font-semibold text-right">Batas Minimum</th>
                <th className="py-3 px-4 font-semibold text-center">Status</th>
                <th className="py-3 px-4 font-semibold text-right">Terakhir Diperbarui</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    <div className="flex items-center justify-center gap-2">
                      <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
                      <span>Memuat saldo inventaris...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredBalances.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    Tidak ada saldo inventaris yang ditemukan.
                  </td>
                </tr>
              ) : (
                filteredBalances.map((b) => {
                  const qty = parseFloat(b.quantity);
                  const min = parseFloat(b.product.minimumStock);
                  const isOutOfStock = qty === 0;
                  const isLow = qty <= min && !isOutOfStock;

                  return (
                    <tr key={b.id} className="hover:bg-[var(--sf-surface-hover)]">
                      <td className="py-3 px-4 font-medium text-[var(--sf-text-primary)]">
                        {b.product.name}
                      </td>
                      <td className="py-3 px-4 font-mono text-xs text-[var(--sf-text-secondary)]">
                        {b.product.sku}
                      </td>
                      <td className="py-3 px-4 text-xs text-[var(--sf-text-secondary)]">
                        {b.product.categoryName || '-'}
                      </td>
                      <td className="py-3 px-4 text-xs font-medium text-[var(--sf-text-primary)]">
                        {b.warehouse.name}
                      </td>
                      <td className="py-3 px-4 text-right font-mono font-bold text-base text-[var(--sf-text-primary)]">
                        {b.quantity} {b.product.unit}
                      </td>
                      <td className="py-3 px-4 text-right font-mono text-xs text-[var(--sf-text-muted)]">
                        {b.product.minimumStock} {b.product.unit}
                      </td>
                      <td className="py-3 px-4 text-center">
                        {isOutOfStock ? (
                          <Badge variant="danger">HABIS</Badge>
                        ) : isLow ? (
                          <Badge variant="warning">MENIPIS</Badge>
                        ) : (
                          <Badge variant="success">AMAN</Badge>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right text-xs text-[var(--sf-text-muted)]">
                        {new Date(b.updatedAt).toLocaleString('id-ID', {
                          day: '2-digit',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>
    </div>
  );
}
