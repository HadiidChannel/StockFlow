'use client';

import React, { useEffect, useState } from 'react';
import { api, getErrorMessage } from '@/lib/api';
import { Organization } from '@/types';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Building2, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';

export default function OrganizationPage() {
  const [org, setOrg] = useState<Organization | null>(null);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [timezone, setTimezone] = useState('Asia/Makassar');

  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    api
      .get('/organization')
      .then((res) => {
        const data: Organization = res.data.data;
        setOrg(data);
        setName(data.name);
        setCode(data.code || '');
        setAddress(data.address || '');
        setPhone(data.phone || '');
        setEmail(data.email || '');
        setTimezone(data.timezone);
      })
      .catch((err) => {
        setErrorMessage(getErrorMessage(err));
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);
    setIsSaving(true);

    try {
      const res = await api.put('/organization', {
        name: name.trim(),
        code: code.trim() || null,
        address: address.trim() || null,
        phone: phone.trim() || null,
        email: email.trim() || null,
        timezone,
      });

      setOrg(res.data.data);
      setSuccessMessage('Profil organisasi berhasil diperbarui.');
      setTimeout(() => setSuccessMessage(null), 3000);
    } catch (err) {
      setErrorMessage(getErrorMessage(err));
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div className="h-64 flex items-center justify-center">
        <div className="flex items-center gap-2 text-sm text-[var(--sf-text-muted)]">
          <Loader2 className="w-4 h-4 animate-spin text-[var(--sf-primary)]" />
          <span>Memuat data organisasi...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--sf-text-primary)] flex items-center gap-3">
          <Building2 className="w-8 h-8 text-[var(--sf-primary)]" />
          <span>Profil Organisasi</span>
        </h1>
        <p className="text-sm text-[var(--sf-text-secondary)] mt-1">
          Identitas perusahaan induk, pengaturan zona waktu operasional, dan informasi kontak resmi.
        </p>
      </div>

      <form onSubmit={handleSubmit}>
        <Card className="bg-[var(--sf-surface)] border-[var(--sf-border)] shadow-md">
          <CardHeader>
            <CardTitle className="text-base font-semibold">Detail Konfigurasi Organisasi</CardTitle>
            <CardDescription className="text-xs">
              Mata uang sistem: <strong className="font-mono text-[var(--sf-text-primary)]">{org?.currency}</strong> &bull; Model instalasi: Single-Tenant Multi-Warehouse
            </CardDescription>
          </CardHeader>

          <CardContent className="space-y-4">
            {errorMessage && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 text-xs text-[var(--sf-danger)] flex items-start gap-2">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMessage}</span>
              </div>
            )}

            {successMessage && (
              <div className="p-3 rounded-lg bg-[#2F8966]/10 border border-[#2F8966]/20 text-xs text-[#2F8966] flex items-start gap-2">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{successMessage}</span>
              </div>
            )}

            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Nama Resmi Organisasi *
                </label>
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Kode Organisasi
                </label>
                <Input
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="ORG-MAIN"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Alamat Kantor Pusat
              </label>
              <Input
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Jl. Raya Logistik No. 88, Makassar"
              />
            </div>

            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Nomor Telepon
                </label>
                <Input
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+62 411 888999"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                  Email Resmi
                </label>
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="contact@stockflow.com"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Zona Waktu Acuan (Timezone) *
              </label>
              <select
                value={timezone}
                onChange={(e) => setTimezone(e.target.value)}
                className="w-full h-9 px-3 rounded-md border border-[var(--sf-border)] bg-[var(--sf-surface)] text-sm text-[var(--sf-text-primary)] focus:outline-none focus:ring-1 focus:ring-[var(--sf-primary)]"
                required
              >
                <option value="Asia/Jakarta">Asia/Jakarta (WIB - UTC+7)</option>
                <option value="Asia/Makassar">Asia/Makassar (WITA - UTC+8)</option>
                <option value="Asia/Jayapura">Asia/Jayapura (WIT - UTC+9)</option>
              </select>
            </div>
          </CardContent>

          <CardFooter className="flex justify-end pt-4 border-t border-[var(--sf-border)]">
            <Button
              type="submit"
              className="bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white font-semibold"
              disabled={isSaving}
            >
              {isSaving ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Menyimpan...
                </>
              ) : (
                'Simpan Perubahan'
              )}
            </Button>
          </CardFooter>
        </Card>
      </form>
    </div>
  );
}
