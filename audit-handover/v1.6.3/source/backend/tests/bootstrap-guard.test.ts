import { describe, it, expect } from 'vitest';
import {
  validateBootstrapTestDatabase,
  assertBootstrapTestDatabaseSafe,
} from '../src/utils/bootstrap-guard';

describe('Fail-Closed Bootstrap Database Guard Unit Tests', () => {
  const validRunId = 'a1b2c3d4';
  const validDbName = `stockflow_bootstrap_test_${validRunId}`;
  const validUrl = `mysql://stockflow_test_user:pass123@127.0.0.1:3307/${validDbName}`;
  const validProject = `stockflow-bootstrap-test-${validRunId}`;

  it('harus menolak jika RUN_BOOTSTRAP_INTEGRATION_TEST bukan true', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'false',
      databaseUrl: validUrl,
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('Explicit integration-test mode');
  });

  it('harus menolak jika DATABASE_URL kosong', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: '',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('DATABASE_URL tidak disediakan');
  });

  it('harus menolak jika protokol bukan mysql:', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: `postgres://user:pass@127.0.0.1:5432/${validDbName}`,
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('Protokol database harus mysql:');
  });

  it('harus menolak database produksi operasional (stockflow_db)', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: 'mysql://root:secret@127.0.0.1:3306/stockflow_db',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('terdaftar dalam daftar proteksi database operasional');
  });

  it('harus menolak database development (stockflow_dev_db)', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: 'mysql://stockflow_user:pass@127.0.0.1:3306/stockflow_dev_db',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('terdaftar dalam daftar proteksi database operasional');
  });

  it('harus menolak database E2E (stockflow_e2e_db)', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: 'mysql://stockflow_e2e_user:pass@127.0.0.1:3306/stockflow_e2e_db',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('terdaftar dalam daftar proteksi database operasional');
  });

  it('harus menolak nama database tanpa run ID atau format acak', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: 'mysql://user:pass@127.0.0.1:3307/stockflow_bootstrap_test',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('tidak sesuai pola izin disposable test');
  });

  it('harus menolak hostname eksternal atau tidak dikenal', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: `mysql://user:pass@192.168.1.100:3306/${validDbName}`,
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('tidak termasuk host loopback/internal');
  });

  it('harus menolak jika runId tidak cocok dengan database name', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: validUrl,
      runId: 'deadbeef',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('RUN ID MISMATCH');
  });

  it('harus menolak jika composeProjectName tidak cocok polanya', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: validUrl,
      composeProjectName: 'stockflow-prod',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('tidak sesuai pola izin');
  });

  it('harus menolak jika composeProjectName memiliki run ID berbeda', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: validUrl,
      composeProjectName: 'stockflow-bootstrap-test-99999999',
    });
    expect(res.allowed).toBe(false);
    expect(res.reason).toContain('PROJECT RUN ID MISMATCH');
  });

  it('harus menyetujui konfigurasi yang 100% valid dan terisolasi', () => {
    const res = validateBootstrapTestDatabase({
      runIntegrationTest: 'true',
      databaseUrl: validUrl,
      runId: validRunId,
      composeProjectName: validProject,
    });
    expect(res.allowed).toBe(true);
    expect(res.databaseName).toBe(validDbName);
    expect(res.runId).toBe(validRunId);
    expect(res.hostname).toBe('127.0.0.1');
    expect(res.port).toBe(3307);
  });

  it('assertBootstrapTestDatabaseSafe harus melempar Error jika tidak aman (fail-closed)', () => {
    expect(() =>
      assertBootstrapTestDatabaseSafe({
        runIntegrationTest: 'true',
        databaseUrl: 'mysql://root:secret@127.0.0.1:3306/stockflow_db',
      })
    ).toThrowError(/FAIL-CLOSED DATABASE GUARD/);
  });

  it('assertBootstrapTestDatabaseSafe harus mengembalikan result jika aman', () => {
    const result = assertBootstrapTestDatabaseSafe({
      runIntegrationTest: 'true',
      databaseUrl: validUrl,
      runId: validRunId,
      composeProjectName: validProject,
    });
    expect(result.allowed).toBe(true);
    expect(result.databaseName).toBe(validDbName);
  });
});
