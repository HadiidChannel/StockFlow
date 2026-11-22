'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage, generateIdempotencyKey } from '@/lib/api';
import { StockMovement, Warehouse } from '@/types';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  History,
  RotateCcw,
  Search,
  Filter,
  Loader2,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';

export default function StockMovementsPage() {
  const [movements, setMovements] = useState<StockMovement[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [selectedWarehouseId, setSelectedWarehouseId] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Reversal modal state
  const [reversalTargetId, setReversalTargetId] = useState<string | null>(null);
  const [reversalTargetRef, setReversalTargetRef] = useState<string>('');
  const [reversalNote, setReversalNote] = useState('');
  const [reversalIdempotencyKey, setReversalIdempotencyKey] = useState<string>('');
  const [isReversing, setIsReversing] = useState(false);
  const [reversalError, setReversalError] = useState<string | null>(null);
  const [reversalSuccess, setReversalSuccess] = useState<string | null>(null);

  const fetchMovements = () => {
    setIsLoading(true);
    let url = '/movements?';
    if (selectedWarehouseId) url += `warehouseId=${selectedWarehouseId}&`;
    if (selectedType) url += `type=${selectedType}&`;

    api
      .get(url)
      .then((res) => {
        setMovements(res.data.data);
      })
      .catch((err) => {
        console.error('Gagal memuat mutasi:', err);
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
    fetchMovements();
  }, [selectedWarehouseId, selectedType]);

  const handleOpenReversal = (transactionId: string, referenceNumber: string) => {
    setReversalTargetId(transactionId);
    setReversalTargetRef(referenceNumber);
    setReversalNote('');
    setReversalIdempotencyKey(generateIdempotencyKey());
    setReversalError(null);
    setReversalSuccess(null);
  };

  const handleExecuteReversal = async () => {
    if (!reversalTargetId) return;
    setIsReversing(true);
    setReversalError(null);

    try {
      const res = await api.post(
        `/inventory/transactions/${reversalTargetId}/reversal`,
        {
          note: reversalNote.trim() || undefined,
        },
        {
          headers: {
            'Idempotency-Key': reversalIdempotencyKey,
          },
        }
      );

      setReversalSuccess(
        `Transaksi berhasil dibatalkan. Referensi pembalik: ${res.data.data.referenceNumber}`
      );
      setTimeout(() => {
        setReversalTargetId(null);
        fetchMovements();
      }, 2000);
    } catch (err) {
      setReversalError(getErrorMessage(err));
    } finally {
      setIsReversing(false);
    }
  };

  const filteredMovements = movements.filter((m) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      m.productName?.toLowerCase().includes(q) ||
      m.sku?.toLowerCase().includes(q) ||
      m.referenceNumber?.toLowerCase().includes(q) ||
      m.warehouseName?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
          <History className="w-8 h-8 text-[var(--sf-primary)]" />
          <span>Ledger Riwayat Mutasi Stok</span>
        </h1>
        <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
          Audit trail permanen mencatat setiap transaksi barang masuk, barang keluar, dan pembatalan (reversal).
        </p>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari referensi transaksi, nama produk, atau SKU..."
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
            className="h-9 px-3 py-1 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] w-full sm:w-48 focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
          >
            <option value="">Semua Gudang</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.name}
              </option>
            ))}
          </select>

          <select
            value={selectedType}
            onChange={(e) => setSelectedType(e.target.value)}
            className="h-9 px-3 py-1 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] w-full sm:w-36 focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
          >
            <option value="">Semua Tipe</option>
            <option value="IN">MASUK (IN)</option>
            <option value="OUT">KELUAR (OUT)</option>
          </select>
        </div>
      </div>

      {/* Movements Ledger Table */}
      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] overflow-hidden">
        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-b border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-3 px-4 font-semibold">Referensi</th>
                <th className="py-3 px-4 font-semibold">Tipe</th>
                <th className="py-3 px-4 font-semibold">Produk</th>
                <th className="py-3 px-4 font-semibold">Gudang</th>
                <th className="py-3 px-4 font-semibold text-right">Kuantitas</th>
                <th className="py-3 px-4 font-semibold text-right">Saldo Sebelum</th>
                <th className="py-3 px-4 font-semibold text-right">Saldo Sesudah</th>
                <th className="py-3 px-4 font-semibold">Petugas</th>
                <th className="py-3 px-4 font-semibold">Waktu (UTC)</th>
                <th className="py-3 px-4 font-semibold text-center">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {isLoading ? (
                <tr>
                  <td colSpan={10} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    <div className="flex items-center justify-center gap-2">
                      <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
                      <span>Memuat ledger mutasi...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredMovements.length === 0 ? (
                <tr>
                  <td colSpan={10} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    Tidak ada mutasi stok yang tercatat.
                  </td>
                </tr>
              ) : (
                filteredMovements.map((m) => (
                  <tr key={m.id} className="hover:bg-[var(--sf-surface-hover)]">
                    <td className="py-3 px-4 font-mono text-xs font-semibold text-[var(--sf-text-primary)]">
                      {m.referenceNumber}
                    </td>
                    <td className="py-3 px-4">
                      <Badge variant={m.type === 'IN' ? 'success' : 'default'}>
                        {m.type === 'IN' ? 'MASUK' : 'KELUAR'}
                      </Badge>
                    </td>
                    <td className="py-3 px-4">
                      <div className="font-medium text-[var(--sf-text-primary)]">{m.productName}</div>
                      <div className="text-[11px] text-[var(--sf-text-muted)] font-mono">{m.sku}</div>
                    </td>
                    <td className="py-3 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {m.warehouseName}
                    </td>
                    <td className="py-3 px-4 text-right font-mono font-bold text-sm text-[var(--sf-text-primary)]">
                      {m.type === 'IN' ? `+${m.quantity}` : `-${m.quantity}`} {m.unit}
                    </td>
                    <td className="py-3 px-4 text-right font-mono text-xs text-[var(--sf-text-muted)]">
                      {m.balanceBefore}
                    </td>
                    <td className="py-3 px-4 text-right font-mono text-xs font-semibold text-[var(--sf-text-primary)]">
                      {m.balanceAfter}
                    </td>
                    <td className="py-3 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {m.createdByName}
                    </td>
                    <td className="py-3 px-4 text-xs text-[var(--sf-text-muted)]">
                      {new Date(m.createdAt).toLocaleString('id-ID', {
                        day: '2-digit',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleOpenReversal(m.transactionId, m.referenceNumber || '')}
                        className="text-xs text-[var(--sf-text-muted)] hover:text-[var(--sf-danger)] gap-1"
                        title="Pembalikan Penuh (Full Reversal)"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>Reversal</span>
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>

      {/* Reversal Confirmation Modal */}
      {reversalTargetId && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center gap-3 text-[var(--sf-danger)]">
              <RotateCcw className="w-6 h-6" />
              <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
                Konfirmasi Reversal Transaksi
              </h3>
            </div>

            <p className="text-sm text-[var(--sf-text-secondary)] leading-relaxed">
              Anda akan membatalkan seluruh transaksi{' '}
              <strong className="text-[var(--sf-text-primary)] font-mono">{reversalTargetRef}</strong>.
              Sistem akan membuat transaksi pembalik dan menyesuaikan saldo secara atomik. Tindakan ini tidak dapat dibatalkan kembali.
            </p>

            {reversalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{reversalError}</span>
              </div>
            )}

            {reversalSuccess && (
              <div className="p-3 rounded-lg bg-[#2F8966]/10 border border-[#2F8966]/20 text-xs text-[#2F8966] flex items-start gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{reversalSuccess}</span>
              </div>
            )}

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Alasan Pembalikan (Opsional)
              </label>
              <Input
                placeholder="Contoh: Kesalahan input kuantitas barang oleh staff"
                value={reversalNote}
                onChange={(e) => setReversalNote(e.target.value)}
                disabled={isReversing || !!reversalSuccess}
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-[var(--sf-border)]">
              <Button
                variant="outline"
                onClick={() => setReversalTargetId(null)}
                disabled={isReversing || !!reversalSuccess}
              >
                Batal
              </Button>
              <Button
                onClick={handleExecuteReversal}
                className="bg-[var(--sf-danger)] hover:bg-[var(--sf-danger)]/90 text-white font-semibold"
                disabled={isReversing || !!reversalSuccess}
              >
                {isReversing ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Memproses Reversal...
                  </>
                ) : (
                  'Lakukan Pembalikan Penuh'
                )}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
