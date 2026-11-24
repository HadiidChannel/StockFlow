// ==============================================================================
// StockFlow - Fail-Closed Bootstrap Database Guard
// File: backend/src/utils/bootstrap-guard.ts
// Description: Strictly protects operational databases (production, dev, E2E)
//              from accidental execution of bootstrap integration tests.
// ==============================================================================

export interface BootstrapGuardConfig {
  databaseUrl?: string;
  runIntegrationTest?: string;
  composeProjectName?: string;
  runId?: string;
}

export interface ValidationResult {
  allowed: boolean;
  reason?: string;
  databaseName?: string;
  hostname?: string;
  port?: number;
  runId?: string;
}

const OPERATIONAL_DATABASE_PATTERNS = [
  /^stockflow_db$/i,
  /^stockflow_dev_db$/i,
  /^stockflow_prod$/i,
  /^stockflow_e2e_db$/i,
  /^mysql$/i,
  /^sys$/i,
  /^information_schema$/i,
  /^performance_schema$/i,
];

const ALLOWED_TEST_DB_PATTERN = /^stockflow_bootstrap_test_([a-f0-9]{8})$/i;
const ALLOWED_PROJECT_PATTERN = /^stockflow-bootstrap-test-([a-f0-9]{8})$/i;
const ALLOWED_HOSTNAMES = ['127.0.0.1', 'localhost', 'db', 'db-bootstrap-test'];

/**
 * Validates whether the given configuration points to a strictly verified,
 * disposable, isolated test database for bootstrap integration testing.
 */
export function validateBootstrapTestDatabase(config?: BootstrapGuardConfig): ValidationResult {
  const runFlag = config?.runIntegrationTest ?? process.env.RUN_BOOTSTRAP_INTEGRATION_TEST;
  if (runFlag !== 'true') {
    return {
      allowed: false,
      reason: 'Explicit integration-test mode (RUN_BOOTSTRAP_INTEGRATION_TEST=true) wajib diaktifkan.',
    };
  }

  const rawUrl = config?.databaseUrl ?? process.env.DATABASE_URL;
  if (!rawUrl || rawUrl.trim() === '') {
    return {
      allowed: false,
      reason: 'DATABASE_URL tidak disediakan atau kosong.',
    };
  }

  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch (err: any) {
    return {
      allowed: false,
      reason: `DATABASE_URL tidak valid: ${err.message}`,
    };
  }

  if (parsed.protocol !== 'mysql:') {
    return {
      allowed: false,
      reason: `Protokol database harus mysql:, ditemukan: ${parsed.protocol}`,
    };
  }

  const dbName = parsed.pathname.replace(/^\//, '');
  if (!dbName) {
    return {
      allowed: false,
      reason: 'Nama database pada DATABASE_URL tidak ditemukan.',
    };
  }

  // 1. Operational database exclusion check
  for (const pattern of OPERATIONAL_DATABASE_PATTERNS) {
    if (pattern.test(dbName)) {
      return {
        allowed: false,
        reason: `DATABASE DITOLAK: Database '${dbName}' terdaftar dalam daftar proteksi database operasional.`,
        databaseName: dbName,
      };
    }
  }

  // 2. Strict naming pattern validation
  const dbMatch = dbName.match(ALLOWED_TEST_DB_PATTERN);
  if (!dbMatch) {
    return {
      allowed: false,
      reason: `DATABASE DITOLAK: Nama database '${dbName}' tidak sesuai pola izin disposable test: ^stockflow_bootstrap_test_[a-f0-9]{8}$`,
      databaseName: dbName,
    };
  }

  const dbRunId = dbMatch[1].toLowerCase();

  // 3. Hostname validation
  const hostname = parsed.hostname.toLowerCase();
  if (!ALLOWED_HOSTNAMES.includes(hostname)) {
    return {
      allowed: false,
      reason: `HOST DITOLAK: Host '${hostname}' tidak termasuk host loopback/internal yang diizinkan untuk test.`,
      hostname,
      databaseName: dbName,
    };
  }

  // 4. Run ID consistency check
  const expectedRunId = config?.runId ?? process.env.BOOTSTRAP_TEST_RUN_ID;
  if (expectedRunId && expectedRunId.toLowerCase() !== dbRunId) {
    return {
      allowed: false,
      reason: `RUN ID MISMATCH: Run ID pada nama database (${dbRunId}) tidak cocok dengan BOOTSTRAP_TEST_RUN_ID (${expectedRunId}).`,
      runId: dbRunId,
      databaseName: dbName,
    };
  }

  // 5. Compose Project Name validation (if provided)
  const projectName = config?.composeProjectName ?? process.env.COMPOSE_PROJECT_NAME;
  if (projectName) {
    const projMatch = projectName.match(ALLOWED_PROJECT_PATTERN);
    if (!projMatch) {
      return {
        allowed: false,
        reason: `PROJECT NAME DITOLAK: Nama Docker Compose project '${projectName}' tidak sesuai pola izin: ^stockflow-bootstrap-test-[a-f0-9]{8}$`,
        databaseName: dbName,
      };
    }
    const projRunId = projMatch[1].toLowerCase();
    if (projRunId !== dbRunId) {
      return {
        allowed: false,
        reason: `PROJECT RUN ID MISMATCH: Run ID pada Docker project (${projRunId}) tidak cocok dengan database (${dbRunId}).`,
        databaseName: dbName,
      };
    }
  }

  const port = parsed.port ? parseInt(parsed.port, 10) : 3306;

  return {
    allowed: true,
    databaseName: dbName,
    hostname,
    port,
    runId: dbRunId,
  };
}

/**
 * Asserts that the current database connection is 100% verified as a disposable,
 * isolated test database. Throws an Error immediately if not safe (fail-closed).
 */
export function assertBootstrapTestDatabaseSafe(config?: BootstrapGuardConfig): ValidationResult {
  const result = validateBootstrapTestDatabase(config);
  if (!result.allowed) {
    throw new Error(`[FAIL-CLOSED DATABASE GUARD] Eksekusi dihentikan: ${result.reason}`);
  }
  return result;
}
