'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import { DashboardSummary } from '@/types';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Boxes,
  Warehouse,
  AlertTriangle,
  XCircle,
  ArrowDownToLine,
  ArrowUpFromLine,
  ArrowRight,
  Loader2,
} from 'lucide-react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
} from 'recharts';

export default function DashboardPage() {
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [chartData, setChartData] = useState<Array<{ date: string; inCount: number; outCount: number }>>([]);
  const [alerts, setAlerts] = useState<any[]>([]);
  const [recentMovements, setRecentMovements] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    Promise.all([
      api.get('/dashboard/summary'),
      api.get('/dashboard/movement-chart?days=7'),
      api.get('/dashboard/alerts'),
      api.get('/dashboard/recent-movements?limit=6'),
    ])
      .then(([summaryRes, chartRes, alertsRes, recentRes]) => {
        if (isMounted) {
          setSummary(summaryRes.data.data);
          setChartData(chartRes.data.data);
          setAlerts(alertsRes.data.data);
          setRecentMovements(recentRes.data.data);
        }
      })
      .catch((err) => {
        console.error('Gagal memuat data dashboard:', err);
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  if (isLoading) {
    return (
      <div className="h-96 flex items-center justify-center">
        <div className="flex flex-col items-center gap-2 text-[var(--sf-text-secondary)]">
          <Loader2 className="w-6 h-6 animate-spin text-[var(--sf-primary)]" />
          <span className="text-sm">Memuat metrik dashboard...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)]">
            Dashboard Operasional
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Ringkasan status stok, mutasi terkini, dan peringatan batas minimum inventaris.
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

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        {/* Total Products */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase">Total Produk</span>
            <Boxes className="w-4 h-4 text-[var(--sf-primary)]" />
          </div>
          <div className="text-2xl font-bold text-[var(--sf-text-primary)] font-mono">
            {summary?.totalProducts || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">Katalog aktif</span>
        </Card>

        {/* Total Warehouses */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase">Gudang Aktif</span>
            <Warehouse className="w-4 h-4 text-[#0596b3]" />
          </div>
          <div className="text-2xl font-bold text-[var(--sf-text-primary)] font-mono">
            {summary?.totalWarehouses || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">Dalam scope akses</span>
        </Card>

        {/* Low Stock Alert */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase text-[var(--sf-warning)]">Stok Menipis</span>
            <AlertTriangle className="w-4 h-4 text-[var(--sf-warning)]" />
          </div>
          <div className="text-2xl font-bold text-[var(--sf-warning)] font-mono">
            {summary?.lowStockCount || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">&le; Batas minimum</span>
        </Card>

        {/* Out of Stock */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase text-[var(--sf-danger)]">Stok Habis</span>
            <XCircle className="w-4 h-4 text-[var(--sf-danger)]" />
          </div>
          <div className="text-2xl font-bold text-[var(--sf-danger)] font-mono">
            {summary?.outOfStockCount || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">Saldo 0 unit</span>
        </Card>

        {/* Stock In (30d) */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase text-[#2F8966]">Masuk (30h)</span>
            <ArrowDownToLine className="w-4 h-4 text-[#2F8966]" />
          </div>
          <div className="text-2xl font-bold text-[#2F8966] font-mono">
            {summary?.recentStockInCount || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">Transaksi posted</span>
        </Card>

        {/* Stock Out (30d) */}
        <Card className="p-4 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <div className="flex items-center justify-between text-[var(--sf-text-muted)] mb-2">
            <span className="text-xs font-semibold uppercase text-[#4C55C5]">Keluar (30h)</span>
            <ArrowUpFromLine className="w-4 h-4 text-[#4C55C5]" />
          </div>
          <div className="text-2xl font-bold text-[#4C55C5] font-mono">
            {summary?.recentStockOutCount || 0}
          </div>
          <span className="text-[11px] text-[var(--sf-text-muted)]">Transaksi posted</span>
        </Card>
      </div>

      {/* Middle Section: Chart and Low Stock Alerts */}
      <div className="grid lg:grid-cols-3 gap-6">
        {/* Recharts Chart */}
        <Card className="lg:col-span-2 p-6 bg-[var(--sf-surface)] border-[var(--sf-border)]">
          <CardHeader className="p-0 pb-6 flex flex-row items-center justify-between">
            <div>
              <CardTitle className="text-base font-bold text-[var(--sf-text-primary)]">
                Aktivitas Mutasi 7 Hari Terakhir
              </CardTitle>
              <p className="text-xs text-[var(--sf-text-secondary)] mt-0.5">
                Perbandingan frekuensi transaksi barang masuk dan keluar per hari.
              </p>
            </div>
            <Badge variant="outline" className="text-xs font-mono">
              7 Hari
            </Badge>
          </CardHeader>
          <CardContent className="p-0 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'var(--sf-surface)',
                    borderColor: 'var(--sf-border)',
                    borderRadius: '8px',
                    fontSize: '12px',
                  }}
                />
                <Legend wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                <Bar dataKey="inCount" name="Barang Masuk" fill="#2F8966" radius={[4, 4, 0, 0]} />
                <Bar dataKey="outCount" name="Barang Keluar" fill="#5962D8" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Low Stock Alerts Card */}
        <Card className="p-6 bg-[var(--sf-surface)] border-[var(--sf-border)] flex flex-col">
          <CardHeader className="p-0 pb-4 flex flex-row items-center justify-between">
            <CardTitle className="text-base font-bold text-[var(--sf-text-primary)] flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-[var(--sf-warning)]" />
              <span>Perlu Perhatian</span>
            </CardTitle>
            <Link href="/inventory?lowStock=true" className="text-xs text-[var(--sf-primary)] hover:underline flex items-center gap-1">
              <span>Semua</span>
              <ArrowRight className="w-3 h-3" />
            </Link>
          </CardHeader>

          <CardContent className="p-0 flex-1 overflow-y-auto space-y-3">
            {alerts.length === 0 ? (
              <div className="h-40 flex items-center justify-center text-xs text-[var(--sf-text-muted)]">
                Seluruh produk berada di atas batas stok minimum.
              </div>
            ) : (
              alerts.slice(0, 5).map((a) => (
                <div
                  key={a.productId}
                  className="p-3 rounded-lg border border-[var(--sf-border)] bg-[var(--sf-surface-subtle)] flex items-center justify-between"
                >
                  <div className="space-y-0.5">
                    <div className="text-sm font-semibold text-[var(--sf-text-primary)]">
                      {a.name}
                    </div>
                    <div className="text-xs text-[var(--sf-text-muted)] font-mono">
                      {a.sku} &bull; Min: {a.minimumStock} {a.unit}
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge variant={a.severity === 'OUT_OF_STOCK' ? 'danger' : 'warning'}>
                      {a.currentQuantity} {a.unit}
                    </Badge>
                  </div>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>

      {/* Recent Movements Section */}
      <Card className="p-6 bg-[var(--sf-surface)] border-[var(--sf-border)]">
        <CardHeader className="p-0 pb-4 flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base font-bold text-[var(--sf-text-primary)]">
              Riwayat Pergerakan Stok Terbaru
            </CardTitle>
            <p className="text-xs text-[var(--sf-text-secondary)] mt-0.5">
              Ledger mutasi stok realtime dari seluruh gudang yang Anda kelola.
            </p>
          </div>
          <Link href="/movements">
            <Button variant="ghost" size="sm" className="gap-1 text-xs text-[var(--sf-primary)]">
              <span>Buka Ledger Lengkap</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </Button>
          </Link>
        </CardHeader>

        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-y border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-2.5 px-4 font-semibold">Referensi</th>
                <th className="py-2.5 px-4 font-semibold">Tipe</th>
                <th className="py-2.5 px-4 font-semibold">Produk</th>
                <th className="py-2.5 px-4 font-semibold">Gudang</th>
                <th className="py-2.5 px-4 font-semibold text-right">Kuantitas</th>
                <th className="py-2.5 px-4 font-semibold">Petugas</th>
                <th className="py-2.5 px-4 font-semibold">Waktu</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {recentMovements.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-xs text-[var(--sf-text-muted)]">
                    Belum ada pergerakan stok yang tercatat.
                  </td>
                </tr>
              ) : (
                recentMovements.map((m) => (
                  <tr key={m.id} className="hover:bg-[var(--sf-surface-hover)]">
                    <td className="py-2.5 px-4 font-mono text-xs font-semibold text-[var(--sf-text-primary)]">
                      {m.referenceNumber}
                    </td>
                    <td className="py-2.5 px-4">
                      <Badge variant={m.type === 'IN' ? 'success' : 'default'}>
                        {m.type === 'IN' ? 'MASUK' : 'KELUAR'}
                      </Badge>
                    </td>
                    <td className="py-2.5 px-4">
                      <div className="font-medium text-[var(--sf-text-primary)]">{m.productName}</div>
                      <div className="text-[11px] text-[var(--sf-text-muted)] font-mono">{m.sku}</div>
                    </td>
                    <td className="py-2.5 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {m.warehouseName}
                    </td>
                    <td className="py-2.5 px-4 text-right font-mono font-semibold text-[var(--sf-text-primary)]">
                      {m.type === 'IN' ? `+${m.quantity}` : `-${m.quantity}`} {m.unit}
                    </td>
                    <td className="py-2.5 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {m.createdByName}
                    </td>
                    <td className="py-2.5 px-4 text-xs text-[var(--sf-text-muted)]">
                      {new Date(m.createdAt).toLocaleString('id-ID', {
                        day: '2-digit',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>
    </div>
  );
}
