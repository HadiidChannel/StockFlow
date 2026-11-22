'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { api, getErrorMessage, generateIdempotencyKey } from '@/lib/api';
import { Warehouse, Product } from '@/types';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  ArrowUpFromLine,
  AlertCircle,
  CheckCircle2,
  Loader2,
  ArrowLeft,
} from 'lucide-react';

export default function StockOutPage() {
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedWarehouseId, setSelectedWarehouseId] = useState('');
  const [selectedProductId, setSelectedProductId] = useState('');
  const [requestedQuantity, setRequestedQuantity] = useState('1.000');
  const [note, setNote] = useState('');
  const [externalReference, setExternalReference] = useState('');
  const [idempotencyKey, setIdempotencyKey] = useState<string>(() => generateIdempotencyKey());

  // Live balance check
  const [availableBalance, setAvailableBalance] = useState<string | null>(null);
  const [isCheckingBalance, setIsCheckingBalance] = useState(false);

  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successResult, setSuccessResult] = useState<any | null>(null);

  useEffect(() => {
    Promise.all([
      api.get('/warehouses?isActive=true'),
      api.get('/products?isActive=true&pageSize=100'),
    ])
      .then(([whRes, prodRes]) => {
        setWarehouses(whRes.data.data);
        setProducts(prodRes.data.data);
        if (whRes.data.data.length > 0) {
          setSelectedWarehouseId(whRes.data.data[0].id);
        }
      })
      .catch((err) => {
        setErrorMessage(getErrorMessage(err));
      });
  }, []);

  // Fetch available balance in realtime when warehouse or product changes
  useEffect(() => {
    if (!selectedWarehouseId || !selectedProductId) {
      setAvailableBalance(null);
      return;
    }

    setIsCheckingBalance(true);
    api
      .get(`/inventory/balances?warehouseId=${selectedWarehouseId}&productId=${selectedProductId}`)
      .then((res) => {
        const item = res.data.data[0];
        setAvailableBalance(item ? item.quantity : '0.000');
      })
      .catch(() => {
        setAvailableBalance('0.000');
      })
      .finally(() => {
        setIsCheckingBalance(false);
      });
  }, [selectedWarehouseId, selectedProductId]);

  const availableNum = availableBalance !== null ? parseFloat(availableBalance) : null;
  const requestedNum = parseFloat(requestedQuantity) || 0;
  const isInsufficient = availableNum !== null && requestedNum > availableNum;
  const estimatedRemaining = availableNum !== null ? Math.max(0, availableNum - requestedNum) : null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    if (!selectedWarehouseId || !selectedProductId) {
      setErrorMessage('Pilih gudang asal dan produk terlebih dahulu.');
      return;
    }

    if (isNaN(requestedNum) || requestedNum <= 0) {
      setErrorMessage('Kuantitas pengeluaran harus lebih besar dari 0.');
      return;
    }

    if (isInsufficient) {
      setErrorMessage(
        `Kuantitas yang diminta (${requestedQuantity}) melebihi saldo tersedia (${availableBalance}). Transaksi tidak dapat diproses.`
      );
      return;
    }

    setIsLoading(true);

    try {
      const res = await api.post(
        '/inventory/stock-out',
        {
          warehouseId: selectedWarehouseId,
          note: note.trim() || undefined,
          externalReference: externalReference.trim() || undefined,
          items: [
            {
              productId: selectedProductId,
              quantity: requestedQuantity,
            },
          ],
        },
        {
          headers: {
            'Idempotency-Key': idempotencyKey,
          },
        }
      );

      setSuccessResult(res.data.data);
    } catch (err) {
      setErrorMessage(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  if (successResult) {
    return (
      <div className="max-w-2xl mx-auto py-12">
        <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] text-center p-8 shadow-xl">
          <div className="w-16 h-16 rounded-full bg-[#5962D8]/15 text-[#5962D8] mx-auto flex items-center justify-center mb-4">
            <CheckCircle2 className="w-8 h-8" />
          </div>
          <CardTitle className="text-2xl font-bold text-[var(--sf-text-primary)]">
            Stock Out Berhasil Diposting!
          </CardTitle>
          <CardDescription className="text-sm text-[var(--sf-text-secondary)] mt-2">
            Nomor Referensi Transaksi:{' '}
            <span className="font-mono font-bold text-[var(--sf-primary)] text-base">
              {successResult.referenceNumber}
            </span>
          </CardDescription>

          <div className="mt-8 flex justify-center gap-4">
            <Button
              variant="outline"
              onClick={() => {
                setSuccessResult(null);
                setRequestedQuantity('1.000');
                setNote('');
                setExternalReference('');
                setIdempotencyKey(generateIdempotencyKey());
              }}
            >
              Catat Transaksi Lain
            </Button>
            <Link href="/movements">
              <Button className="bg-[var(--sf-primary)] text-white">
                Lihat di Riwayat Mutasi
              </Button>
            </Link>
          </div>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/inventory">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="w-5 h-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <ArrowUpFromLine className="w-7 h-7 text-[#5962D8]" />
            <span>Formulir Pengeluaran Barang (Stock Out)</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Catat barang keluar dengan verifikasi saldo tersedia secara instan untuk mencegah saldo negatif.
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit}>
        <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] shadow-md">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Detail Pengeluaran</CardTitle>
          </CardHeader>

          <CardContent className="space-y-6">
            {errorMessage && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 flex items-start gap-3 text-sm text-[var(--sf-danger)]">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMessage}</span>
              </div>
            )}

            {/* Warehouse selection */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Gudang Asal *
              </label>
              <select
                value={selectedWarehouseId}
                onChange={(e) => setSelectedWarehouseId(e.target.value)}
                className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                required
              >
                <option value="">Pilih Gudang Asal</option>
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </div>

            {/* Product selection */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Produk yang Dikeluarkan *
              </label>
              <select
                value={selectedProductId}
                onChange={(e) => setSelectedProductId(e.target.value)}
                className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                required
              >
                <option value="">Pilih Produk</option>
                {products.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name} ({p.sku}) &bull; Satuan: {p.unit}
                  </option>
                ))}
              </select>
            </div>

            {/* Live Stock Balance Indicator */}
            {selectedProductId && selectedWarehouseId && (
              <div className="p-4 rounded-lg border border-[var(--sf-border)] bg-[var(--sf-surface-subtle)] space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Saldo Tersedia di Gudang Ini
                  </span>
                  {isCheckingBalance ? (
                    <Loader2 className="w-3.5 h-3.5 animate-spin text-[var(--sf-primary)]" />
                  ) : (
                    <Badge variant={availableNum === 0 ? 'danger' : 'success'}>
                      {availableBalance} Unit
                    </Badge>
                  )}
                </div>

                <div className="flex items-center justify-between text-xs text-[var(--sf-text-muted)] pt-2 border-t border-[var(--sf-border)]">
                  <span>Estimasi Saldo Setelah Pengeluaran:</span>
                  <span className="font-mono font-semibold text-[var(--sf-text-primary)]">
                    {estimatedRemaining?.toFixed(3)} Unit
                  </span>
                </div>

                {isInsufficient && (
                  <div className="p-2.5 rounded bg-[var(--sf-danger)]/15 text-[var(--sf-danger)] text-xs flex items-center gap-2">
                    <AlertCircle className="w-4 h-4 shrink-0" />
                    <span>
                      Stok tidak mencukupi! Kuantitas diminta ({requestedQuantity}) lebih besar dari saldo tersedia ({availableBalance}).
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* Quantity */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Kuantitas yang Dikeluarkan *
              </label>
              <Input
                type="text"
                placeholder="1.000"
                value={requestedQuantity}
                onChange={(e) => setRequestedQuantity(e.target.value)}
                className="font-mono"
                required
              />
            </div>

            {/* References */}
            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  No. Referensi Eksternal (Delivery Order / Invoice)
                </label>
                <Input
                  placeholder="Contoh: DO-2026-0811"
                  value={externalReference}
                  onChange={(e) => setExternalReference(e.target.value)}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Catatan Pengeluaran
                </label>
                <Input
                  placeholder="Keterangan pengiriman atau tujuan pengeluaran..."
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
              </div>
            </div>
          </CardContent>

          <CardFooter className="flex items-center justify-end gap-3 pt-6 border-t border-[var(--sf-border)]">
            <Link href="/inventory">
              <Button variant="outline" type="button" disabled={isLoading}>
                Batal
              </Button>
            </Link>
            <Button
              type="submit"
              className="bg-[#5962D8] hover:bg-[#4C55C5] text-white font-semibold"
              disabled={isLoading || isInsufficient || availableNum === 0}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Memproses Stock Out...
                </>
              ) : (
                'Posting Stock Out'
              )}
            </Button>
          </CardFooter>
        </Card>
      </form>
    </div>
  );
}
