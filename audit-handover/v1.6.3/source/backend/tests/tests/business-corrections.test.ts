import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { getLocalCalendarDate } from '../src/utils/sequence';
import { dashboardService } from '../src/modules/dashboard/dashboard.service';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

describe('Milestone 7: Business Corrections and Optimization (P1-14, P1-15)', () => {
  describe('P1-15: Reference Number Sequence Timezone', () => {
    it('harus memformat tanggal kalender lokal berdasarkan timezone yang ditentukan (Asia/Makassar)', () => {
      // 2026-11-20T23:30:00Z is 2026-11-21 07:30:00 in Asia/Makassar (UTC+8)
      const lateUtcDate = new Date('2026-11-20T23:30:00.000Z');
      const makassarResult = getLocalCalendarDate(lateUtcDate, 'Asia/Makassar');
      expect(makassarResult.dateStr).toBe('20261121');
      expect(makassarResult.year).toBe(2026);
      expect(makassarResult.month).toBe(11);
      expect(makassarResult.day).toBe(21);
    });

    it('harus menghasilkan tanggal UTC jika timezone adalah UTC', () => {
      const lateUtcDate = new Date('2026-11-20T23:30:00.000Z');
      const utcResult = getLocalCalendarDate(lateUtcDate, 'UTC');
      expect(utcResult.dateStr).toBe('20261120');
      expect(utcResult.day).toBe(20);
    });

    it('harus graceful fallback jika timezone string tidak valid', () => {
      const date = new Date('2026-05-15T12:00:00.000Z');
      const fallbackResult = getLocalCalendarDate(date, 'Invalid/Timezone_Name');
      expect(fallbackResult.dateStr).toBe('20260515');
    });
  });

  describe('P1-14: Movement Chart Metrics Definition Discrepancy', () => {
    let orgId: string;

    beforeAll(async () => {
      const org = await prisma.organization.findFirst();
      if (!org) throw new Error('Organization not found');
      orgId = org.id;
    });

    it('harus mengembalikan array data grafik pergerakan transaksi harian', async () => {
      const chartData = await dashboardService.getMovementChart(orgId, undefined, 7);
      expect(Array.isArray(chartData)).toBe(true);
      expect(chartData.length).toBeGreaterThanOrEqual(7);

      for (const entry of chartData) {
        expect(entry.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
        expect(typeof entry.inCount).toBe('number');
        expect(typeof entry.outCount).toBe('number');
      }
    });

    it('harus mendukung filter berdasarkan warehouseId tertentu', async () => {
      const warehouse = await prisma.warehouse.findFirst({ where: { organizationId: orgId } });
      if (warehouse) {
        const chartData = await dashboardService.getMovementChart(orgId, undefined, 7, warehouse.id);
        expect(Array.isArray(chartData)).toBe(true);
      }
    });
  });
});
