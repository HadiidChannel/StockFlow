'use client';

import React from 'react';
import Link from 'next/link';
import { motion } from 'motion/react';
import {
  Boxes,
  ShieldCheck,
  Zap,
  ArrowRight,
  TrendingUp,
  Warehouse,
  RotateCcw,
  Sparkles,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ThemeToggle } from '@/components/theme-toggle';

export default function MarketingPage() {
  return (
    <div className="min-h-screen bg-[#020204] text-white selection:bg-[#5962D8] selection:text-white overflow-hidden relative font-sans">
      {/* Background Cinematic Gradient & Glow */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-[300px] left-1/2 -translate-x-1/2 w-[1000px] h-[600px] bg-gradient-to-b from-[#197fff]/15 via-[#5962d8]/10 to-transparent blur-[140px] rounded-full" />
        <div className="absolute top-[400px] right-[-100px] w-[500px] h-[500px] bg-gradient-to-b from-[#0596b3]/10 to-transparent blur-[120px] rounded-full" />
      </div>

      {/* Navigation */}
      <header className="relative z-50 max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#5962D8] to-[#0596b3] flex items-center justify-center font-bold text-white shadow-lg shadow-[#5962D8]/20">
            SF
          </div>
          <span className="font-bold text-xl tracking-tight text-white">StockFlow</span>
        </div>

        <nav className="hidden md:flex items-center gap-8 text-sm text-[#A8B0BE]">
          <a href="#features" className="hover:text-white transition-colors">Fitur Utama</a>
          <a href="#architecture" className="hover:text-white transition-colors">Arsitektur</a>
          <a href="#workflow" className="hover:text-white transition-colors">Alur Operasional</a>
        </nav>

        <div className="flex items-center gap-4">
          <ThemeToggle />
          <Link href="/login">
            <Button variant="outline" className="border-white/10 hover:bg-white/5 text-white">
              Masuk
            </Button>
          </Link>
          <Link href="/login">
            <Button className="bg-[#5962D8] hover:bg-[#4C55C5] text-white shadow-lg shadow-[#5962D8]/25 font-semibold">
              Buka Workspace
            </Button>
          </Link>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative z-10 max-w-5xl mx-auto px-6 pt-20 pb-28 text-center flex flex-col items-center">
        {/* Luminous Pill Badge */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full border border-white/10 bg-white/[0.03] backdrop-blur-md shadow-inner mb-8"
        >
          <div className="w-5 h-5 rounded-md bg-gradient-to-tr from-[#0596b3] to-[#46afc8] flex items-center justify-center shadow-sm">
            <Sparkles className="w-3 h-3 text-white" />
          </div>
          <span className="text-xs text-white/90 font-medium tracking-wide">
            Next-Generation Enterprise Inventory Engine
          </span>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight leading-[1.08] text-white max-w-4xl"
        >
          Know your stock.<br />
          <span className="bg-gradient-to-r from-white via-[#EEF1F6] to-[#A9DCC4] bg-clip-text text-transparent">
            Move with confidence.
          </span>
        </motion.h1>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.2 }}
          className="mt-6 text-base sm:text-lg text-[#A8B0BE] max-w-2xl font-normal leading-relaxed"
        >
          Sistem manajemen pergudangan B2B presisi tinggi dengan pelacakan multi-gudang, transaksi atomik anti-race-condition, dan ledger mutasi immutable.
        </motion.p>

        {/* CTA Buttons */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.3 }}
          className="mt-10 flex flex-wrap items-center justify-center gap-4"
        >
          <Link href="/login">
            <Button size="lg" className="h-12 px-8 bg-gradient-to-r from-[#5962D8] to-[#4C55C5] text-white font-semibold rounded-xl shadow-xl shadow-[#5962D8]/20 flex items-center gap-2 hover:scale-[1.02] transition-transform">
              <span>Mulai Kelola Stok</span>
              <ArrowRight className="w-4 h-4" />
            </Button>
          </Link>
          <a href="#features">
            <Button size="lg" variant="outline" className="h-12 px-6 border-white/15 bg-white/[0.02] hover:bg-white/5 text-white/90 rounded-xl">
              Pelajari Spesifikasi
            </Button>
          </a>
        </motion.div>

        {/* Floating Metrics Showcase */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="mt-16 w-full max-w-4xl p-6 rounded-2xl border border-white/10 bg-[#171C25]/60 backdrop-blur-xl shadow-2xl grid grid-cols-2 md:grid-cols-4 gap-6 text-left"
        >
          <div className="space-y-1">
            <span className="text-xs text-[#7E899A] uppercase tracking-wider font-mono">Integritas Stok</span>
            <div className="text-2xl font-bold text-white font-mono">100.00%</div>
            <p className="text-[11px] text-[#A8B0BE]">Pencegahan saldo negatif otomatis</p>
          </div>
          <div className="space-y-1">
            <span className="text-xs text-[#7E899A] uppercase tracking-wider font-mono">Presisi Angka</span>
            <div className="text-2xl font-bold text-[#9DDBBD] font-mono">3 Desimal</div>
            <p className="text-[11px] text-[#A8B0BE]">Format exact DECIMAL(18,3)</p>
          </div>
          <div className="space-y-1">
            <span className="text-xs text-[#7E899A] uppercase tracking-wider font-mono">Isolasi Transaksi</span>
            <div className="text-2xl font-bold text-white font-mono">Row Lock</div>
            <p className="text-[11px] text-[#A8B0BE]">SELECT FOR UPDATE InnoDB</p>
          </div>
          <div className="space-y-1">
            <span className="text-xs text-[#7E899A] uppercase tracking-wider font-mono">Audit Trail</span>
            <div className="text-2xl font-bold text-[#969CFF] font-mono">Immutable</div>
            <p className="text-[11px] text-[#A8B0BE]">Ledger pergerakan permanen</p>
          </div>
        </motion.div>
      </section>

      {/* Feature Cards Grid */}
      <section id="features" className="max-w-7xl mx-auto px-6 py-20 border-t border-white/5 relative z-10">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <Badge variant="outline" className="border-[#969CFF]/30 text-[#969CFF] bg-[#969CFF]/10 mb-3">
            Kapabilitas Inti
          </Badge>
          <h2 className="text-3xl sm:text-4xl font-bold tracking-tight text-white">
            Dibangun untuk Keandalan Operasional Gudang
          </h2>
          <p className="mt-4 text-[#A8B0BE]">
            Setiap fitur dirancang berdasarkan standar spesifikasi FSD dan PRD, menjamin transaksi bisnis akurat dan terhindar dari inkonsistensi data.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {/* Card 1 */}
          <div className="p-8 rounded-2xl border border-white/10 bg-[#171C25]/50 backdrop-blur-md hover:border-[#5962D8]/40 transition-colors">
            <div className="w-12 h-12 rounded-xl bg-[#5962D8]/20 border border-[#5962D8]/30 flex items-center justify-center text-[#969CFF] mb-6">
              <Warehouse className="w-6 h-6" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Multi-Warehouse Scoping</h3>
            <p className="text-sm text-[#A8B0BE] leading-relaxed">
              Pemisahan ketat hak akses per staf gudang. Warehouse Staff hanya dapat melihat saldo dan mencatat transaksi pada gudang aktif yang ditugaskan secara eksplisit oleh Admin.
            </p>
          </div>

          {/* Card 2 */}
          <div className="p-8 rounded-2xl border border-white/10 bg-[#171C25]/50 backdrop-blur-md hover:border-[#0596b3]/40 transition-colors">
            <div className="w-12 h-12 rounded-xl bg-[#0596b3]/20 border border-[#0596b3]/30 flex items-center justify-center text-[#9DDBBD] mb-6">
              <Zap className="w-6 h-6" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Atomic Stock In & Out</h3>
            <p className="text-sm text-[#A8B0BE] leading-relaxed">
              Pembaruan saldo inventaris dan pencatatan snapshot item dilakukan dalam satu database transaction. Jika stok kurang pada Stock Out, sistem melakukan rollback seketika.
            </p>
          </div>

          {/* Card 3 */}
          <div className="p-8 rounded-2xl border border-white/10 bg-[#171C25]/50 backdrop-blur-md hover:border-[#2F8966]/40 transition-colors">
            <div className="w-12 h-12 rounded-xl bg-[#2F8966]/20 border border-[#2F8966]/30 flex items-center justify-center text-[#69C69B] mb-6">
              <RotateCcw className="w-6 h-6" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Safe Full Reversal</h3>
            <p className="text-sm text-[#A8B0BE] leading-relaxed">
              Koreksi transaksi stok yang keliru dilakukan melalui pembalikan penuh (full reversal). Saldo dipulihkan secara aman tanpa menghapus histori transaksi asal.
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/10 py-12 px-6 max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between text-xs text-[#7E899A] gap-4">
        <div>
          StockFlow IWMS &copy; 2026. Standard Full-Stack Production Implementation.
        </div>
        <div className="flex items-center gap-6">
          <Link href="/login" className="hover:text-white transition-colors">Login Admin</Link>
          <a href="#features" className="hover:text-white transition-colors">Spesifikasi</a>
        </div>
      </footer>
    </div>
  );
}
