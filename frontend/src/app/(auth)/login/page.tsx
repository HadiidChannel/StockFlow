'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api, getErrorMessage } from '@/lib/api';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { ThemeToggle } from '@/components/theme-toggle';
import { Loader2, AlertCircle } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setIsLoading(true);

    try {
      const res = await api.post('/auth/login', {
        email: email.trim(),
        password,
      });

      const user = res.data.data.user;
      if (user.mustChangePassword) {
        router.push('/change-password');
      } else {
        router.push('/dashboard');
      }
    } catch (err) {
      setErrorMessage(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-[var(--sf-bg)] relative">
      <div className="absolute top-6 right-6">
        <ThemeToggle />
      </div>

      <Card className="w-full max-w-md shadow-xl border-[var(--sf-border)] bg-[var(--sf-surface)]">
        <CardHeader className="space-y-2 text-center">
          <div className="mx-auto w-12 h-12 rounded-xl bg-[var(--sf-primary)] flex items-center justify-center text-white font-bold text-xl shadow-md">
            SF
          </div>
          <CardTitle className="text-2xl font-bold tracking-tight text-[var(--sf-text-primary)]">
            Masuk ke StockFlow
          </CardTitle>
          <CardDescription className="text-sm text-[var(--sf-text-secondary)]">
            Masukkan kredensial akun Anda untuk mengakses sistem inventaris.
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
                Email Pengguna
              </label>
              <Input
                type="email"
                placeholder="admin@stockflow.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-[var(--sf-text-secondary)] uppercase">
                Kata Sandi
              </label>
              <Input
                type="password"
                placeholder="********"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={isLoading}
              />
            </div>
          </CardContent>

          <CardFooter className="flex flex-col gap-3">
            <Button
              type="submit"
              className="w-full bg-[var(--sf-primary)] hover:bg-[var(--sf-primary-hover)] text-white font-semibold"
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Memverifikasi...
                </>
              ) : (
                'Masuk ke Sistem'
              )}
            </Button>

            <Link href="/" className="text-xs text-[var(--sf-text-muted)] hover:text-[var(--sf-text-primary)] text-center transition-colors">
              Kembali ke Halaman Utama
            </Link>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}
