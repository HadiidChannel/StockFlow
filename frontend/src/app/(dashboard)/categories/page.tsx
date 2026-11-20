'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage } from '@/lib/api';
import { Category } from '@/types';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Tags,
  Plus,
  Search,
  Loader2,
  AlertCircle,
} from 'lucide-react';

export default function CategoriesPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Add Category Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);

  const fetchCategories = () => {
    setIsLoading(true);
    api
      .get('/categories')
      .then((res) => setCategories(res.data.data))
      .catch((err) => console.error('Gagal memuat kategori:', err))
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.post('/categories', {
        name: name.trim(),
        description: description.trim() || null,
      });

      setIsModalOpen(false);
      setName('');
      setDescription('');
      fetchCategories();
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const filtered = categories.filter((c) => {
    if (!search) return true;
    return c.name.toLowerCase().includes(search.toLowerCase());
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <Tags className="w-8 h-8 text-[var(--sf-primary)]" />
            <span>Master Kategori Produk</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Pengelompokan barang untuk mempermudah klasifikasi dan pemfilteran katalog.
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
          <span>Tambah Kategori Baru</span>
        </Button>
      </div>

      <div className="flex items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari kategori..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] overflow-hidden">
        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-b border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-3 px-4 font-semibold">Nama Kategori</th>
                <th className="py-3 px-4 font-semibold">Deskripsi</th>
                <th className="py-3 px-4 font-semibold text-center">Status</th>
                <th className="py-3 px-4 font-semibold text-right">Dibuat Pada</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {isLoading ? (
                <tr>
                  <td colSpan={4} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    <div className="flex items-center justify-center gap-2">
                      <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
                      <span>Memuat kategori...</span>
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={4} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    Belum ada kategori yang terdaftar.
                  </td>
                </tr>
              ) : (
                filtered.map((c) => (
                  <tr key={c.id} className="hover:bg-[var(--sf-surface-hover)]">
                    <td className="py-3 px-4 font-semibold text-[var(--sf-text-primary)]">
                      {c.name}
                    </td>
                    <td className="py-3 px-4 text-xs text-[var(--sf-text-secondary)]">
                      {c.description || '-'}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <Badge variant={c.isActive ? 'success' : 'secondary'}>
                        {c.isActive ? 'AKTIF' : 'NONAKTIF'}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-right text-xs text-[var(--sf-text-muted)]">
                      {new Date(c.createdAt).toLocaleDateString('id-ID')}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>

      {/* Modal Add Category */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Tambah Kategori Baru
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            <form onSubmit={handleCreateCategory} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Nama Kategori *
                </label>
                <Input
                  placeholder="Contoh: Perangkat Jaringan"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Deskripsi
                </label>
                <Input
                  placeholder="Router, Switch, Kabel LAN, Connector"
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
                    'Simpan Kategori'
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
