# ==============================================================================
# StockFlow - Disposable MySQL 8.4 Bootstrap Integration Test Runner
# Script: scripts/run-bootstrap-test.ps1
# Description: Orchestrates a dedicated disposable MySQL 8.4 stack on port 3307,
#              applies migrations, executes bootstrap integration tests,
#              verifies resource ownership, and performs safe teardown.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$BootstrapPort = 3307,

    [Parameter(Mandatory = $false)]
    [switch]$KeepStack,

    [Parameter(Mandatory = $false)]
    [string]$EvidenceDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 1. Resolve Project Root Directory and Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$composePath = Join-Path $projectRoot "docker-compose.bootstrap-test.yml"

# Generate unique cryptographic Run ID and project name for strict isolation
$runId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
$projectName = "stockflow-bootstrap-test-$runId"
$dbName = "stockflow_bootstrap_test_$runId"

Write-Host "======================================================================"
Write-Host " StockFlow Bootstrap Integration Test Runner (Disposable MySQL 8.4)"
Write-Host " Project Target: $projectName (Run ID: $runId)"
Write-Host " Database Name:  $dbName (Port: $BootstrapPort)"
Write-Host " Safety Guard:   Operational databases remain 100% untouched"
Write-Host "======================================================================"

# 2. Check Port Availability on 127.0.0.1
Write-Host "[1/6] Memeriksa ketersediaan port $BootstrapPort pada 127.0.0.1..."
$activePort = Get-NetTCPConnection -LocalPort $BootstrapPort -State Listen -ErrorAction SilentlyContinue
if ($activePort) {
    Write-Error "Port $BootstrapPort pada 127.0.0.1 sedang digunakan oleh proses lain. Hentikan proses tersebut sebelum menjalankan pengujian bootstrap."
    exit 1
}
Write-Host "Port $BootstrapPort tersedia untuk pengujian terisolasi."

# 3. Check Docker Daemon
Write-Host "[2/6] Memeriksa status Docker daemon..."
& docker.exe info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker daemon tidak terdeteksi atau tidak berjalan. Pastikan Docker Desktop aktif."
    exit 1
}
Write-Host "Docker daemon aktif."

# 4. Generate Cryptographic Credentials for Disposable MySQL
Write-Host "[3/6] Membuat kredensial dinamis untuk database disposable..."

function Get-CryptoRandomHex([int]$byteCount) {
    $bytes = [byte[]]::new($byteCount)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
        return -join ($bytes | ForEach-Object { $_.ToString("x2") })
    } finally {
        $rng.Dispose()
    }
}

$dbRootPassword = Get-CryptoRandomHex 24
$dbPassword = Get-CryptoRandomHex 24
$dbUser = "stockflow_test_user"

# Set Environment Variables for Docker Compose Process
$env:COMPOSE_PROJECT_NAME = $projectName
$env:RUN_ID = $runId
$env:BOOTSTRAP_DB_NAME = $dbName
$env:BOOTSTRAP_TEST_PORT = "$BootstrapPort"
$env:DB_ROOT_PASSWORD = $dbRootPassword
$env:DB_PASSWORD = $dbPassword
$env:DB_USER = $dbUser

$testExitCode = 1

try {
    # 5. Bring Up Disposable Database
    Write-Host "[4/6] Menjalankan kontainer disposable MySQL 8.4 ($projectName-db)..."
    & docker.exe compose -p $projectName -f "$composePath" up -d db
    if ($LASTEXITCODE -ne 0) { throw "Gagal menjalankan container db bootstrap test." }

    Write-Host "Menunggu database disposable berstatus healthy..."
    $dbHealthy = $false
    for ($i = 0; $i -lt 40; $i++) {
        $dbContainerId = (& docker.exe compose -p $projectName -f "$composePath" ps -q db 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($dbContainerId)) {
            $dbContainerId = $dbContainerId.Trim()
            $status = (& docker.exe inspect --format '{{.State.Health.Status}}' $dbContainerId 2>$null)
            if ($status -eq "healthy") {
                $dbHealthy = $true
                break
            }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $dbHealthy) {
        throw "Database disposable tidak mencapai status healthy dalam batas waktu 80 detik."
    }
    Write-Host "Database disposable siap dan berstatus healthy pada 127.0.0.1:$BootstrapPort."

    # 6. Apply Prisma Migrations to Fresh Database using isolated migrator container
    Write-Host "[5/6] Menerapkan migrasi skema database Prisma pada $dbName..."
    & docker.exe compose -p $projectName -f "$composePath" run --rm migrator
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal menerapkan migrasi Prisma pada database test (Exit code $LASTEXITCODE)."
    }
    Write-Host "Migrasi skema database berhasil diterapkan."

    # 7. Execute Bootstrap Integration Test Suite
    Write-Host "[6/6] Menjalankan Vitest Bootstrap Integration Test Suite..."
    $targetDbUrl = "mysql://${dbUser}:${dbPassword}@127.0.0.1:${BootstrapPort}/${dbName}"
    $env:DATABASE_URL = $targetDbUrl
    $env:RUN_BOOTSTRAP_INTEGRATION_TEST = "true"
    $env:BOOTSTRAP_TEST_RUN_ID = $runId
    $env:COMPOSE_PROJECT_NAME = $projectName

    $backendDir = Join-Path $projectRoot "backend"

    # Avoid PowerShell treating stderr info messages as terminating exceptions
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $testOutput = & npx.cmd --prefix "$backendDir" vitest run tests/bootstrap.integration.test.ts 2>&1 | Out-String
    $testExitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap

    Write-Host $testOutput

    if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
        if (-not (Test-Path -LiteralPath $EvidenceDir)) {
            New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
        }
        $resultPath = Join-Path $EvidenceDir "bootstrap_integration_test_results.txt"
        [System.IO.File]::WriteAllText($resultPath, $testOutput, [System.Text.UTF8Encoding]::new($false))
    }

    if ($testExitCode -eq 0) {
        Write-Host "Bootstrap Integration Test Suite BERHASIL (Exit Code: 0)."
    } else {
        Write-Warning "Bootstrap Integration Test Suite GAGAL dengan exit code $testExitCode."
    }

} catch {
    $err = $_.Exception.Message
    Write-Error "Terjadi kegagalan selama siklus pengujian bootstrap integration: $err"
    $testExitCode = 1
} finally {
    # 8. Strict Ownership Cleanup Guard and Teardown
    Write-Host "Membersihkan disposable bootstrap test stack ($projectName)..."
    if ($projectName -notmatch '^stockflow-bootstrap-test-[a-f0-9]{8}$') {
        Write-Error "Ownership Guard: Nama project '$projectName' tidak valid. Teardown otomatis dibatalkan demi keamanan."
    } elseif (-not $KeepStack) {
        & docker.exe compose -p $projectName -f "$composePath" down -v --remove-orphans
        $downExit = $LASTEXITCODE
        if ($downExit -ne 0) {
            Write-Warning "Peringatan: docker compose down keluar dengan kode $downExit."
        }

        # Verify removal
        $remainingContainers = & docker.exe ps -a --filter "label=stockflow.test.run_id=$runId" -q
        if ($remainingContainers) {
            Write-Warning "Peringatan: Masih ada kontainer tertinggal untuk run ID $runId."
        } else {
            Write-Host "Seluruh kontainer dan volume disposable berhasil dibersihkan."
        }
    } else {
        Write-Host "Flag KeepStack aktif: stack dibiarkan berjalan untuk inspeksi manual."
    }
}

exit $testExitCode
