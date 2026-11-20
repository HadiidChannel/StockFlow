'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage } from '@/lib/api';
import { User, Warehouse } from '@/types';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Users as UsersIcon,
  Plus,
  Search,
  Warehouse as WarehouseIcon,
  KeyRound,
  ShieldAlert,
  Loader2,
  AlertCircle,
  CheckCircle2,
} from 'lucide-react';

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Add User Modal State
  const [isAddUserOpen, setIsAddUserOpen] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [roleCode, setRoleCode] = useState<'ADMIN' | 'WAREHOUSE_STAFF'>('WAREHOUSE_STAFF');
  const [selectedWarehouseIds, setSelectedWarehouseIds] = useState<string[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);

  // Assign Warehouses Modal State
  const [isAssignOpen, setIsAssignOpen] = useState(false);
  const [assignTargetUser, setAssignTargetUser] = useState<User | null>(null);
  const [assignWarehouseIds, setAssignWarehouseIds] = useState<string[]>([]);

  // Reset Password Modal State
  const [isResetOpen, setIsResetOpen] = useState(false);
  const [resetTargetUser, setResetTargetUser] = useState<User | null>(null);
  const [temporaryPassword, setTemporaryPassword] = useState('StockFlowTemp2026!');
  const [resetSuccess, setResetSuccess] = useState<string | null>(null);

  const fetchUsers = () => {
    setIsLoading(true);
    api
      .get('/users?pageSize=100')
      .then((res) => setUsers(res.data.data))
      .catch((err) => console.error('Gagal memuat pengguna:', err))
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    Promise.all([
      api.get('/users?pageSize=100'),
      api.get('/warehouses?isActive=true'),
    ])
      .then(([usersRes, whRes]) => {
        setUsers(usersRes.data.data);
        setWarehouses(whRes.data.data);
      })
      .catch((err) => console.error(err))
      .finally(() => setIsLoading(false));
  }, []);

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.post('/users', {
        name: name.trim(),
        email: email.trim(),
        password,
        roleCode,
        warehouseIds: roleCode === 'WAREHOUSE_STAFF' ? selectedWarehouseIds : undefined,
      });

      setIsAddUserOpen(false);
      setName('');
      setEmail('');
      setPassword('');
      setSelectedWarehouseIds([]);
      fetchUsers();
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleOpenAssign = (user: User) => {
    setAssignTargetUser(user);
    const currentIds = user.assignedWarehouses ? user.assignedWarehouses.map((w) => w.id) : [];
    setAssignWarehouseIds(currentIds);
    setModalError(null);
    setIsAssignOpen(true);
  };

  const handleSaveAssignments = async () => {
    if (!assignTargetUser) return;
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.put(`/users/${assignTargetUser.id}/warehouses`, {
        warehouseIds: assignWarehouseIds,
      });
      setIsAssignOpen(false);
      fetchUsers();
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleResetPassword = async () => {
    if (!resetTargetUser) return;
    setModalError(null);
    setIsSubmitting(true);

    try {
      await api.post(`/users/${resetTargetUser.id}/reset-password`, {
        temporaryPassword,
      });
      setResetSuccess(`Password untuk ${resetTargetUser.name} berhasil direset.`);
      setTimeout(() => {
        setIsResetOpen(false);
        setResetSuccess(null);
      }, 2000);
    } catch (err) {
      setModalError(getErrorMessage(err));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleStatus = async (user: User) => {
    const nextStatus = user.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await api.put(`/users/${user.id}`, { status: nextStatus });
      fetchUsers();
    } catch (err) {
      alert(getErrorMessage(err));
    }
  };

  const filtered = users.filter((u) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
            <UsersIcon className="w-8 h-8 text-[var(--sf-primary)]" />
            <span>Manajemen Pengguna & Otorisasi</span>
          </h1>
          <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
            Kelola akun tim, tetapkan hak akses peran (Admin / Warehouse Staff), dan atur penugasan gudang.
          </p>
        </div>

        <Button
          onClick={() => {
            setModalError(null);
            setIsAddUserOpen(true);
          }}
          className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white gap-2 font-medium"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Pengguna</span>
        </Button>
      </div>

      {/* Filter and Search */}
      <div className="flex items-center gap-3 bg-[var(--sf-surface)] p-4 rounded-lg border border-[var(--sf-border)]">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--sf-text-muted)]" />
          <Input
            placeholder="Cari pengguna berdasarkan nama atau email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
      </div>

      {/* Users Table */}
      <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] overflow-hidden">
        <CardContent className="p-0 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--sf-surface-subtle)] border-b border-[var(--sf-border)] text-[var(--sf-text-secondary)] text-xs">
              <tr>
                <th className="py-3 px-4 font-semibold">Nama Pengguna</th>
                <th className="py-3 px-4 font-semibold">Email</th>
                <th className="py-3 px-4 font-semibold">Peran (Role)</th>
                <th className="py-3 px-4 font-semibold">Gudang yang Ditugaskan</th>
                <th className="py-3 px-4 font-semibold text-center">Status</th>
                <th className="py-3 px-4 font-semibold text-center">Aksi Otorisasi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--sf-border)]">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    <div className="flex items-center justify-center gap-2">
                      <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
                      <span>Memuat daftar pengguna...</span>
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-sm text-[var(--sf-text-muted)]">
                    Belum ada pengguna yang terdaftar.
                  </td>
                </tr>
              ) : (
                filtered.map((u) => (
                  <tr key={u.id} className="hover:bg-[var(--sf-surface-hover)]">
                    <td className="py-3 px-4 font-medium text-[var(--sf-text-primary)]">
                      {u.name}
                    </td>
                    <td className="py-3 px-4 text-xs font-mono text-[var(--sf-text-secondary)]">
                      {u.email}
                    </td>
                    <td className="py-3 px-4">
                      <Badge variant={u.role.code === 'ADMIN' ? 'default' : 'secondary'}>
                        {u.role.name}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-xs">
                      {u.role.code === 'ADMIN' ? (
                        <span className="text-[var(--sf-text-muted)] italic">Akses Seluruh Gudang</span>
                      ) : !u.assignedWarehouses || u.assignedWarehouses.length === 0 ? (
                        <span className="text-[var(--sf-danger)] font-medium">Belum Ditugaskan</span>
                      ) : (
                        <div className="flex flex-wrap gap-1">
                          {u.assignedWarehouses.map((w) => (
                            <span
                              key={w.id}
                              className="px-2 py-0.5 rounded bg-[var(--sf-surface-subtle)] border border-[var(--sf-border)] text-[11px] font-mono"
                            >
                              {w.name}
                            </span>
                          ))}
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <button
                        onClick={() => handleToggleStatus(u)}
                        title="Klik untuk mengubah status"
                      >
                        <Badge variant={u.status === 'ACTIVE' ? 'success' : 'danger'}>
                          {u.status === 'ACTIVE' ? 'AKTIF' : 'NONAKTIF'}
                        </Badge>
                      </button>
                    </td>
                    <td className="py-3 px-4 text-center">
                      <div className="flex items-center justify-center gap-2">
                        {u.role.code === 'WAREHOUSE_STAFF' && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleOpenAssign(u)}
                            className="text-xs text-[var(--sf-primary)] gap-1"
                            title="Atur Gudang yang Ditugaskan"
                          >
                            <WarehouseIcon className="w-3.5 h-3.5" />
                            <span>Gudang</span>
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            setResetTargetUser(u);
                            setResetSuccess(null);
                            setModalError(null);
                            setIsResetOpen(true);
                          }}
                          className="text-xs text-[var(--sf-text-secondary)] hover:text-[var(--sf-warning)] gap-1"
                          title="Reset Password Pengguna"
                        >
                          <KeyRound className="w-3.5 h-3.5" />
                          <span>Reset</span>
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </CardContent>
      </Card>

      {/* Modal Add User */}
      {isAddUserOpen && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-lg w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Tambah Pengguna Baru
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            <form onSubmit={handleCreateUser} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Nama Lengkap *
                </label>
                <Input
                  placeholder="Contoh: Budi Prasetyo"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Email Akun *
                </label>
                <Input
                  type="email"
                  placeholder="budi@stockflow.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Kata Sandi Awal *
                </label>
                <Input
                  type="password"
                  placeholder="Minimal 8 karakter (huruf besar, kecil, angka)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Peran Akses (Role) *
                </label>
                <select
                  value={roleCode}
                  onChange={(e) => setRoleCode(e.target.value as any)}
                  className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                >
                  <option value="WAREHOUSE_STAFF">Warehouse Staff (Operasional Gudang)</option>
                  <option value="ADMIN">Administrator (Akses Penuh)</option>
                </select>
              </div>

              {roleCode === 'WAREHOUSE_STAFF' && (
                <div className="space-y-1.5 p-3 rounded-lg border border-[var(--sf-border)] bg-[var(--sf-surface-subtle)]">
                  <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase block">
                    Penugasan Gudang (Minimal 1 Aktif) *
                  </label>
                  <div className="max-h-36 overflow-y-auto space-y-1">
                    {warehouses.map((w) => (
                      <label key={w.id} className="flex items-center gap-2 text-xs text-[var(--sf-text-primary)] cursor-pointer">
                        <input
                          type="checkbox"
                          checked={selectedWarehouseIds.includes(w.id)}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setSelectedWarehouseIds([...selectedWarehouseIds, w.id]);
                            } else {
                              setSelectedWarehouseIds(selectedWarehouseIds.filter((id) => id !== w.id));
                            }
                          }}
                          className="rounded text-[var(--sf-primary)]"
                        />
                        <span>{w.name} ({w.code})</span>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-[var(--sf-border)]">
                <Button
                  variant="outline"
                  type="button"
                  onClick={() => setIsAddUserOpen(false)}
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
                    'Simpan Akun'
                  )}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Assign Warehouses */}
      {isAssignOpen && assignTargetUser && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Penugasan Gudang untuk {assignTargetUser.name}
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            <div className="space-y-2">
              <span className="text-xs text-[var(--sf-text-secondary)]">
                Pilih gudang aktif yang dapat diakses oleh staf ini:
              </span>
              <div className="max-h-56 overflow-y-auto space-y-1 p-2 border border-[var(--sf-border)] rounded-lg">
                {warehouses.map((w) => (
                  <label key={w.id} className="flex items-center gap-2 text-xs text-[var(--sf-text-primary)] cursor-pointer p-1.5 hover:bg-[var(--sf-surface-hover)] rounded">
                    <input
                      type="checkbox"
                      checked={assignWarehouseIds.includes(w.id)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setAssignWarehouseIds([...assignWarehouseIds, w.id]);
                        } else {
                          setAssignWarehouseIds(assignWarehouseIds.filter((id) => id !== w.id));
                        }
                      }}
                      className="rounded text-[var(--sf-primary)]"
                    />
                    <span>{w.name} ({w.code})</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-[var(--sf-border)]">
              <Button
                variant="outline"
                type="button"
                onClick={() => setIsAssignOpen(false)}
                disabled={isSubmitting}
              >
                Batal
              </Button>
              <Button
                onClick={handleSaveAssignments}
                className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white font-semibold"
                disabled={isSubmitting || assignWarehouseIds.length === 0}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Menyimpan...
                  </>
                ) : (
                  'Simpan Penugasan'
                )}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Reset Password */}
      {isResetOpen && resetTargetUser && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[var(--sf-surface)] border border-[var(--sf-border)] rounded-xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h3 className="text-lg font-bold text-[var(--sf-text-primary)]">
              Reset Password: {resetTargetUser.name}
            </h3>

            {modalError && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{modalError}</span>
              </div>
            )}

            {resetSuccess && (
              <div className="p-3 rounded-lg bg-[#2F8966]/10 border border-[#2F8966]/20 text-xs text-[#2F8966] flex items-start gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{resetSuccess}</span>
              </div>
            )}

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Password Sementara Baru
              </label>
              <Input
                value={temporaryPassword}
                onChange={(e) => setTemporaryPassword(e.target.value)}
                disabled={isSubmitting || !!resetSuccess}
              />
              <p className="text-[11px] text-[var(--sf-text-muted)] mt-1">
                Pengguna akan diwajibkan mengganti password saat login berikutnya.
              </p>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-[var(--sf-border)]">
              <Button
                variant="outline"
                type="button"
                onClick={() => setIsResetOpen(false)}
                disabled={isSubmitting || !!resetSuccess}
              >
                Tutup
              </Button>
              <Button
                onClick={handleResetPassword}
                className="bg-[var(--sf-warning)] hover:bg-[var(--sf-warning)]/90 text-white font-semibold"
                disabled={isSubmitting || !!resetSuccess}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Mereset...
                  </>
                ) : (
                  'Reset Password Sekarang'
                )}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
