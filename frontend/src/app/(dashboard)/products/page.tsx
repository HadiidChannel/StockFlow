'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage } from '@/lib/api';
import { Product, Category } from '@/types';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Package,
  Plus,
  Search,
  Filter,
  Loader2,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';

export default function ProductsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategoryId, setSelectedCategoryId] = useState('');
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Create Product Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [name, setName] = useState('');
  const [sku, setSku] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [unit, setUnit] = useState('PCS');
  const [minimumStock, setMinimumStock] = useState('0.000');
  const [costPrice, setCostPrice] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);

  const fetchProducts = () => {
    setIsLoading(true);
    let url = '/products?pageSize=100&';
    if (selectedCategoryId) url += `categoryId=${selectedCategoryId}&`;

    api
      .get(url)
      .then((res) => setProducts(res.data.data))
      .catch((err) => console.error('Gagal memuat produk:', err))
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    api
      .get('/categories?isActive=true')
      .then((res) => {
        setCategories(res.data.data);
        if (res.data.data.length > 0) setCategoryId(res.data.data[0].id);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    fetchProducts();
  }, [selectedCategoryId]);

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.post('/products', {
        name: name.trim(),
        sku: sku.trim().toUpperCase(),
        categoryId,
        unit: unit.trim().toUpperCase(),
        minimumStock: minimumStock.trim() || '0.000',
        costPrice: costPrice.trim() || null,
        description: description.trim() || null,
      });

      setIsModalOpen(false);
      setName('');
      setSku('');
      setDescription('');
      fetchProducts();
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredProducts = products.filter((p) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <Package className="w-8 h-8 text-[var(--sf-primary)]" />
            <span>Katalog Master Produk</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Kelola data master barang, SKU unik, satuan pengukuran, dan parameter batas stok minimum.
          </p>
        </div>

        <Button
          onClick={() => {
            setModalError(null);
            setIsModalOpen(true);
          }}
          className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white gap-2 font-medium"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Produk Baru</span>
        </Button>
      </div>

      {/* Filter and Search */}
      <div className="flex flex-col sm:flex-row items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari berdasarkan nama produk atau SKU..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-[var(--sf-text-muted)] shrink-0" />
          <select
            value={selectedCategoryId}
            onChange={(e) => setSelectedCategoryId(e.target.value)}
            className="h-9 px-3 py-1 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] w-full sm:w-48 focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
          >
            <option value="">Semua Kategori</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Products Table */}
      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] overflow-hidden">
        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-b border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-3 px-4 font-semibold">SKU</th>
                <th className="py-3 px-4 font-semibold">Nama Produk</th>
                <th className="py-3 px-4 font-semibold">Kategori</th>
                <th className="py-3 px-4 font-semibold">Satuan</th>
                <th className="py-3 px-4 font-semibold text-right">Total Saldo</th>
                <th className="py-3 px-4 font-semibold text-right">Batas Min</th>
                <th className="py-3 px-4 font-semibold text-right">Harga Pokok</th>
                <th className="py-3 px-4 font-semibold text-center">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    <div className="flex items-center justify-center gap-2">
                      <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
                      <span>Memuat katalog produk...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredProducts.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    Belum ada produk yang terdaftar.
                  </td>
                </tr>
              ) : (
                filteredProducts.map((p) => (
                  <tr key={p.id} className="hover:bg-[var(--sf-surface-hover)]">
                    <td className="py-3 px-4 font-mono text-xs font-semibold text-[var(--sf-text-primary)]">
                      {p.sku}
                    </td>
                    <td className="py-3 px-4 font-medium text-[var(--sf-text-primary)]">
                      {p.name}
                    </td>
                    <td className="py-3 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {p.category.name}
                    </td>
                    <td className="py-3 px-4 text-xs font-mono text-[var(--sf-text-secondary)]">
                      {p.unit}
                    </td>
                    <td className="py-3 px-4 text-right font-mono font-bold text-sm text-[var(--sf-text-primary)]">
                      {p.totalQuantity || '0.000'} {p.unit}
                    </td>
                    <td className="py-3 px-4 text-right font-mono text-xs text-[var(--sf-text-muted)]">
                      {p.minimumStock} {p.unit}
                    </td>
                    <td className="py-3 px-4 text-right font-mono text-xs text-[var(--sf-text-secondary)]">
                      {p.costPrice ? `Rp ${parseFloat(p.costPrice).toLocaleString('id-ID')}` : '-'}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <Badge variant={p.isActive ? 'success' : 'secondary'}>
                        {p.isActive ? 'AKTIF' : 'NONAKTIF'}
                      </Badge>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>

      {/* Modal Add Product */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-lg w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Tambah Produk Baru
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            <form onSubmit={handleCreateProduct} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Nama Produk *
                  </label>
                  <Input
                    placeholder="Contoh: Kabel UTP Cat6 305m"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    SKU (Kode Barang) *
                  </label>
                  <Input
                    placeholder="Contoh: KBL-UTP-C6"
                    value={sku}
                    onChange={(e) => setSku(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Kategori *
                  </label>
                  <select
                    value={categoryId}
                    onChange={(e) => setCategoryId(e.target.value)}
                    className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                    required
                  >
                    <option value="">Pilih Kategori</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Satuan Pengukuran *
                  </label>
                  <Input
                    placeholder="PCS, BOX, ROLL, KG"
                    value={unit}
                    onChange={(e) => setUnit(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Batas Minimum Stok
                  </label>
                  <Input
                    placeholder="5.000"
                    value={minimumStock}
                    onChange={(e) => setMinimumStock(e.target.value)}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                    Harga Pokok (Opsional)
                  </label>
                  <Input
                    placeholder="Contoh: 1500000"
                    value={costPrice}
                    onChange={(e) => setCostPrice(e.target.value)}
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Deskripsi / Keterangan
                </label>
                <Input
                  placeholder="Spesifikasi teknis produk atau lokasi penyimpanan..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-[var(--sf-border)]">
                <Button
                  variant="outline"
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  disabled={isSubmitting}
                >
                  Batal
                </Button>
                <Button
                  type="submit"
                  className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white font-semibold"
                  disabled={isSubmitting}
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      Menyimpan...
                    </>
                  ) : (
                    'Simpan Produk'
                  )}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
