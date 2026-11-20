'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, getErrorMessage } from '@/lib/api';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Loader2, AlertCircle, CheckCircle2 } from 'lucide-react';

export default function ChangePasswordPage() {
  const router = useRouter();
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    if (newPassword !== confirmPassword) {
      setErrorMessage('Konfirmasi password tidak cocok dengan password baru.');
      return;
    }

    if (newPassword.length < 8) {
      setErrorMessage('Password baru minimal 8 karakter.');
      return;
    }

    setIsLoading(true);

    try {
      await api.post('/auth/change-password', {
        currentPassword,
        newPassword,
      });

      router.push('/dashboard');
    } catch (err) {
      setErrorMessage(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-[var(--sf-bg)]">
      <Card className="w-full max-w-md shadow-xl border-[var(--sf-border)] bg-[var(--sf-surface)]">
        <CardHeader className="space-y-2 text-center">
          <CardTitle className="text-2xl font-bold tracking-tight text-[var(--sf-text-primary)]">
            Perbarui Kata Sandi
          </CardTitle>
          <CardDescription className="text-sm text-[var(--sf-text-secondary)]">
            Akun Anda memerlukan pembaruan kata sandi awal sebelum dapat menggunakan fitur operasional.
          </CardDescription>
        </CardHeader>

        <form onSubmit={handleSubmit}>
          <CardContent className="space-y-4">
            {errorMessage && (
              <div className="p-3 rounded-lg bg-[var(--sf-danger)]/10 border border-[var(--sf-danger)]/20 flex items-start gap-3 text-sm text-[var(--sf-danger)]">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{errorMessage}</span>
              </div>
            )}

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Kata Sandi Saat Ini / Sementara
              </label>
              <Input
                type="password"
                placeholder="********"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Kata Sandi Baru
              </label>
              <Input
                type="password"
                placeholder="Minimal 8 karakter (huruf besar, kecil, angka)"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Konfirmasi Kata Sandi Baru
              </label>
              <Input
                type="password"
                placeholder="Ulangi kata sandi baru"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>

            <div className="text-xs text-[var(--sf-text-muted)] space-y-1 bg-[var(--sf-surface-subtle)] p-3 rounded-md">
              <div className="font-semibold text-[var(--sf-text-secondary)]">Ketentuan Kata Sandi:</div>
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[var(--sf-primary)]" />
                <span>Minimal 8 karakter</span>
              </div>
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[var(--sf-primary)]" />
                <span>Mengandung huruf besar dan huruf kecil</span>
              </div>
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[var(--sf-primary)]" />
                <span>Mengandung setidaknya satu angka</span>
              </div>
            </div>
          </CardContent>

          <CardFooter>
            <Button
              type="submit"
              className="w-full bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white font-semibold"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Menyimpan...
                </>
              ) : (
                'Simpan dan Lanjutkan ke Dashboard'
              )}
            </Button>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}
