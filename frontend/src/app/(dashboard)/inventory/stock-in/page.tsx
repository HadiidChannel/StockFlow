'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api, getErrorMessage, generateIdempotencyKey } from '@/lib/api';
import { Warehouse, Product } from '@/types';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  ArrowDownToLine,
  Plus,
  Trash2,
  AlertCircle,
  CheckCircle2,
  Loader2,
  ArrowLeft,
} from 'lucide-react';

interface StockInLineItem {
  productId: string;
  quantity: string;
}

export default function StockInPage() {
  const router = useRouter();
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedWarehouseId, setSelectedWarehouseId] = useState('');
  const [note, setNote] = useState('');
  const [externalReference, setExternalReference] = useState('');
  const [items, setItems] = useState<StockInLineItem[]>([
    { productId: '', quantity: '1.000' },
  ]);
  const [idempotencyKey, setIdempotencyKey] = useState<string>(() => generateIdempotencyKey());

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

  const handleAddItem = () => {
    setItems([...items, { productId: '', quantity: '1.000' }]);
  };

  const handleRemoveItem = (index: number) => {
    if (items.length <= 1) return;
    setItems(items.filter((_, i) => i !== index));
  };

  const handleItemChange = (index: number, field: keyof StockInLineItem, value: string) => {
    const updated = [...items];
    updated[index][field] = value;
    setItems(updated);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    // Validate warehouse
    if (!selectedWarehouseId) {
      setErrorMessage('Pilih gudang tujuan terlebih dahulu.');
      return;
    }

    // Validate items
    for (let i = 0; i < items.length; i++) {
      if (!items[i].productId) {
        setErrorMessage(`Baris ${i + 1}: Produk wajib dipilih.`);
        return;
      }
      const q = parseFloat(items[i].quantity);
      if (isNaN(q) || q <= 0) {
        setErrorMessage(`Baris ${i + 1}: Kuantitas harus lebih besar dari 0.`);
        return;
      }
    }

    setIsLoading(true);

    try {
      const res = await api.post(
        '/inventory/stock-in',
        {
          warehouseId: selectedWarehouseId,
          note: note.trim() || undefined,
          externalReference: externalReference.trim() || undefined,
          items: items.map((it) => ({
            productId: it.productId,
            quantity: it.quantity,
          })),
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
          <div className="w-16 h-16 rounded-full bg-[#2F8966]/15 text-[#2F8966] mx-auto flex items-center justify-center mb-4">
            <CheckCircle2 className="w-8 h-8" />
          </div>
          <CardTitle className="text-2xl font-bold text-[var(--sf-text-primary)]">
            Stock In Berhasil Diposting!
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
                setItems([{ productId: '', quantity: '1.000' }]);
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
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/inventory">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="w-5 h-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <ArrowDownToLine className="w-7 h-7 text-[#2F8966]" />
            <span>Formulir Penerimaan Barang (Stock In)</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Catat barang masuk untuk menambah saldo inventaris pada gudang tujuan.
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit}>
        <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] shadow-md">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Informasi Transaksi</CardTitle>
          </CardHeader>

          <CardContent className="space-y-6">
            {errorMessage && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 flex items-start gap-3 text-sm text-[var(--sf-danger)]">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMessage}</span>
              </div>
            )}

            {/* Warehouse & Reference */}
            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Gudang Tujuan *
                </label>
                <select
                  value={selectedWarehouseId}
                  onChange={(e) => setSelectedWarehouseId(e.target.value)}
                  className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                  required
                >
                  <option value="">Pilih Gudang Tujuan</option>
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name} ({w.code})
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  No. Referensi Eksternal (Surat Jalan / PO)
                </label>
                <Input
                  placeholder="Contoh: SJ-2026-0042"
                  value={externalReference}
                  onChange={(e) => setExternalReference(e.target.value)}
                />
              </div>
            </div>

            {/* Note */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Catatan Penerimaan
              </label>
              <Input
                placeholder="Catatan tambahan mengenai kondisi barang atau vendor pengirim..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
            </div>

            {/* Items Table */}
            <div className="space-y-3 pt-4 border-t border-[var(--sf-border)]">
              <div className="flex items-center justify-between">
                <label className="text-sm font-semibold text-[var(--sf-text-primary)]">
                  Daftar Barang Masuk
                </label>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={handleAddItem}
                  className="gap-1.5 text-xs border-[var(--sf-border)]"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Tambah Baris Produk</span>
                </Button>
              </div>

              <div className="space-y-2">
                {items.map((item, index) => (
                  <div
                    key={index}
                    className="flex flex-col sm:flex-row items-center gap-3 p-3 rounded-lg border border-[var(--sf-border)] bg-[var(--sf-surface-subtle)]"
                  >
                    <div className="flex-1 w-full">
                      <select
                        value={item.productId}
                        onChange={(e) => handleItemChange(index, 'productId', e.target.value)}
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

                    <div className="w-full sm:w-44 flex items-center gap-2">
                      <Input
                        type="text"
                        placeholder="1.000"
                        value={item.quantity}
                        onChange={(e) => handleItemChange(index, 'quantity', e.target.value)}
                        className="font-mono text-right"
                        required
                      />
                    </div>

                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleRemoveItem(index)}
                      disabled={items.length <= 1}
                      className="text-[var(--sf-text-muted)] hover:text-[var(--sf-danger)] shrink-0"
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                ))}
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
              className="bg-[#2F8966] hover:bg-[#257254] text-white font-semibold"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Memproses Stock In...
                </>
              ) : (
                'Posting Stock In'
              )}
            </Button>
          </CardFooter>
        </Card>
      </form>
    </div>
  );
}
