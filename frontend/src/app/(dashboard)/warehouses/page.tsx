'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage } from '@/lib/api';
import { Warehouse } from '@/types';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Warehouse as WarehouseIcon,
  Plus,
  Search,
  Loader2,
  AlertCircle,
  MapPin,
} from 'lucide-react';

export default function WarehousesPage() {
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Add Warehouse Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);

  const fetchWarehouses = () => {
    setIsLoading(true);
    api
      .get('/warehouses')
      .then((res) => setWarehouses(res.data.data))
      .catch((err) => console.error('Gagal memuat gudang:', err))
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchWarehouses();
  }, []);

  const handleCreateWarehouse = async (e: React.FormEvent) => {
    e.preventDefault();
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.post('/warehouses', {
        name: name.trim(),
        code: code.trim().toUpperCase(),
        location: location.trim() || null,
        description: description.trim() || null,
      });

      setIsModalOpen(false);
      setName('');
      setCode('');
      setLocation('');
      setDescription('');
      fetchWarehouses();
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const filtered = warehouses.filter((w) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return w.name.toLowerCase().includes(q) || w.code.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <WarehouseIcon className="w-8 h-8 text-[var(--sf-primary)]" />
            <span>Master Lokasi Gudang</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Kelola fasilitas penyimpanan fisik, kode lokasi, dan status operasional gudang.
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
          <span>Tambah Gudang Baru</span>
        </Button>
      </div>

      <div className="flex items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari gudang berdasarkan nama atau kode..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="col-span-full py-12 text-center text-sm text-[var(--sf-text-muted)] flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
            <span>Memuat data gudang...</span>
          </div>
        ) : filtered.length === 0 ? (
          <div className="col-span-full py-12 text-center text-sm text-[var(--sf-text-muted)]">
            Belum ada gudang yang terdaftar.
          </div>
        ) : (
          filtered.map((w) => (
            <Card key={w.id} className="p-6 bg-[var(--sf-surface)] border-[var(--sf-border)] shadow-sm space-y-4">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-bold text-lg text-[var(--sf-text-primary)]">{w.name}</h3>
                  <span className="font-mono text-xs text-[var(--sf-primary)] font-semibold">{w.code}</span>
                </div>
                <Badge variant={w.isActive ? 'success' : 'secondary'}>
                  {w.isActive ? 'AKTIF' : 'NONAKTIF'}
                </Badge>
              </div>

              {w.location && (
                <div className="flex items-center gap-2 text-xs text-[var(--sf-text-secondary)]">
                  <MapPin className="w-3.5 h-3.5 text-[var(--sf-text-muted)] shrink-0" />
                  <span>{w.location}</span>
                </div>
              )}

              {w.description && (
                <p className="text-xs text-[var(--sf-text-muted)] leading-relaxed">
                  {w.description}
                </p>
              )}
            </Card>
          ))
        )}
      </div>

      {/* Modal Add Warehouse */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Tambah Gudang Baru
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            <form onSubmit={handleCreateWarehouse} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Nama Gudang *
                </label>
                <Input
                  placeholder="Contoh: Gudang Sentral Jakarta"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Kode Gudang *
                </label>
                <Input
                  placeholder="Contoh: WH_JKT_01"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Lokasi / Alamat
                </label>
                <Input
                  placeholder="Kawasan Industri Pulogadung, Jakarta Timur"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Deskripsi
                </label>
                <Input
                  placeholder="Gudang utama distribusi barang elektronik"
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
                    'Simpan Gudang'
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
