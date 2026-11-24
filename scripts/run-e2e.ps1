# ==============================================================================
# StockFlow - Isolated E2E Test Suite Runner
# Script: scripts/run-e2e.ps1
# Description: Orchestrates the dedicated isolated E2E stack on port 3100,
#              executes Playwright E2E lifecycle tests, and tears down cleanly.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$E2ePort = 3100,

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
$e2eComposePath = Join-Path $projectRoot "docker-compose.e2e.yml"
$secretsDir = Join-Path $projectRoot ".secrets"

# Generate unique cryptographic Run ID and project name for strict isolation
$runId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
$projectName = "stockflow-e2e-$runId"
$e2eSecretFile = Join-Path $secretsDir "e2e_${runId}_initial_admin_password.txt"

Write-Host "======================================================================"
Write-Host " StockFlow E2E Isolated Runner (Port: $E2ePort)"
Write-Host " Project Target: $projectName (Run ID: $runId)"
Write-Host " Safety Rule: Main application (stockflow-prod) remains 100% untouched"
Write-Host "======================================================================"

# 2. Check Port Availability on 127.0.0.1
Write-Host "[1/8] Memeriksa ketersediaan port $E2ePort pada 127.0.0.1..."
$activePort = Get-NetTCPConnection -LocalPort $E2ePort -State Listen -ErrorAction SilentlyContinue
if ($activePort) {
    Write-Error "Port $E2ePort pada 127.0.0.1 sedang digunakan oleh proses lain. Hentikan proses tersebut sebelum menjalankan pengujian E2E."
    exit 1
}
Write-Host "Port $E2ePort tersedia untuk pengujian terisolasi."

# 3. Check Docker Daemon
Write-Host "[2/8] Memeriksa status Docker daemon..."
& docker.exe info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker daemon tidak terdeteksi atau tidak berjalan. Pastikan Docker Desktop aktif."
    exit 1
}
Write-Host "Docker daemon aktif."

# 4. Record Main Stack Status Before E2E Execution
$mainStatusBefore = & docker.exe ps --filter "name=stockflow" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-String
Write-Host "[3/8] Status kontainer saat ini sebelum pengujian E2E:"
Write-Host $mainStatusBefore

if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
    if (-not (Test-Path $EvidenceDir)) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    }
    $mainBeforePath = Join-Path $EvidenceDir "main_stack_before.txt"
    [System.IO.File]::WriteAllText($mainBeforePath, $mainStatusBefore, [System.Text.UTF8Encoding]::new($false))
}

# 5. Generate Cryptographic Credentials for Disposable E2E Stack
Write-Host "[4/8] Membuat kredensial dinamis untuk stack E2E..."

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

function Get-CryptoRandomPassword([int]$length = 24) {
    $upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $lower = "abcdefghjkmnpqrstuvwxyz"
    $digits = "23456789"
    $symbols = "!@#$%^&*()-_=+"
    $allChars = $upper + $lower + $digits + $symbols

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $chars = [System.Collections.Generic.List[char]]::new()
        function Pick-Char([string]$pool) {
            $bytes = [byte[]]::new(4)
            $rng.GetBytes($bytes)
            $uintVal = [System.BitConverter]::ToUInt32($bytes, 0)
            return $pool[$uintVal % $pool.Length]
        }

        $chars.Add((Pick-Char $upper))
        $chars.Add((Pick-Char $upper))
        $chars.Add((Pick-Char $lower))
        $chars.Add((Pick-Char $lower))
        $chars.Add((Pick-Char $digits))
        $chars.Add((Pick-Char $digits))
        $chars.Add((Pick-Char $symbols))
        $chars.Add((Pick-Char $symbols))

        while ($chars.Count -lt $length) {
            $chars.Add((Pick-Char $allChars))
        }

        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $bytes = [byte[]]::new(4)
            $rng.GetBytes($bytes)
            $uintVal = [System.BitConverter]::ToUInt32($bytes, 0)
            $j = $uintVal % ($i + 1)
            $tmp = $chars[$i]
            $chars[$i] = $chars[$j]
            $chars[$j] = $tmp
        }

        return -join $chars
    } finally {
        $rng.Dispose()
    }
}

function Set-SecureAcl([string]$targetPath) {
    if (-not (Test-Path -LiteralPath $targetPath)) {
        throw "Target path '$targetPath' tidak ditemukan saat konfigurasi ACL."
    }
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userSid = $currentUser.User.Value
    $systemSid = "S-1-5-18"
    $adminSid = "S-1-5-32-544"

    & icacls.exe "$targetPath" /inheritance:r /grant:r "*${userSid}:(R,W)" /grant:r "*${systemSid}:(R,W)" /grant:r "*${adminSid}:(R,W)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal menerapkan Windows ACL pada '$targetPath'. Exit code: $LASTEXITCODE"
    }
}

$dbRootPassword = Get-CryptoRandomHex 24
$dbPassword = Get-CryptoRandomHex 24
$sessionSecret = Get-CryptoRandomHex 32
$csrfSecret = Get-CryptoRandomHex 32
$initialAdminPassword = Get-CryptoRandomPassword 24

if (-not (Test-Path $secretsDir)) {
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($e2eSecretFile, $initialAdminPassword, $utf8NoBom)
try {
    Set-SecureAcl -targetPath $e2eSecretFile
} catch {
    # Non-blocking if environment is constrained
}

# Set Environment Variables for Docker Compose Process
$env:COMPOSE_PROJECT_NAME = $projectName
$env:DB_ROOT_PASSWORD = $dbRootPassword
$env:DB_PASSWORD = $dbPassword
$env:DB_USER = "stockflow_e2e_user"
$env:SESSION_SECRET = $sessionSecret
$env:CSRF_SECRET = $csrfSecret
$env:INITIAL_ADMIN_PASSWORD_FILE = $e2eSecretFile
$env:E2E_FRONTEND_URL = "http://127.0.0.1:$E2ePort"
$env:E2E_PORT = "$E2ePort"
$env:E2E_HOST_IP = "127.0.0.1"

$playwrightExitCode = 1

try {
    # 6. Bring Up Database and Wait for Health
    Write-Host "[5/8] Menjalankan kontainer database E2E ($projectName-db)..."
    & docker.exe compose -p $projectName -f "$e2eComposePath" up -d db
    if ($LASTEXITCODE -ne 0) { throw "Gagal menjalankan container db E2E." }

    Write-Host "Menunggu database E2E berstatus healthy..."
    $dbHealthy = $false
    for ($i = 0; $i -lt 40; $i++) {
        $dbContainerId = (& docker.exe compose -p $projectName -f "$e2eComposePath" ps -q db 2>$null)
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
        throw "Database E2E tidak mencapai status healthy dalam batas waktu 80 detik."
    }
    Write-Host "Database E2E siap dan berstatus healthy."

    # 7. Run Database Migration
    Write-Host "[6/8] Menjalankan migrator database E2E..."
    & docker.exe compose -p $projectName -f "$e2eComposePath" run --rm migrator
    if ($LASTEXITCODE -ne 0) { throw "Migrator database E2E gagal." }
    Write-Host "Migrasi skema database E2E selesai."

    # 8. Run Bootstrap
    Write-Host "Menjalankan administrator bootstrap untuk akun awal E2E..."
    & docker.exe compose -p $projectName -f "$e2eComposePath" --profile bootstrap run --rm bootstrap
    if ($LASTEXITCODE -ne 0) { throw "Bootstrap akun awal E2E gagal." }
    Write-Host "Bootstrap administrator selesai."

    # 9. Start Backend and Frontend
    Write-Host "Menjalankan backend dan frontend E2E..."
    & docker.exe compose -p $projectName -f "$e2eComposePath" up -d backend frontend
    if ($LASTEXITCODE -ne 0) { throw "Gagal menjalankan service backend dan frontend E2E." }

    # 10. Probe Ingress Endpoint
    Write-Host "Melakukan probe kesehatan pada http://127.0.0.1:$E2ePort/api/v1/health..."
    $probeReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $res = Invoke-WebRequest -Uri "http://127.0.0.1:$E2ePort/api/v1/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($res.StatusCode -eq 200) {
                $probeReady = $true
                break
            }
        } catch {
            # Continue polling
        }
        Start-Sleep -Seconds 2
    }
    if (-not $probeReady) {
        throw "Endpoint http://127.0.0.1:$E2ePort/api/v1/health tidak merespons 200 OK setelah 60 detik."
    }
    Write-Host "Aplikasi E2E aktif dan merespons 200 OK pada http://127.0.0.1:$E2ePort."

    # Capture Isolation Proof and Compose Config if requested
    if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $activeContainers = (& docker.exe ps --filter "name=stockflow" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}") | Out-String
        $activeNetworks = (& docker.exe network ls --filter "name=stockflow") | Out-String
        $activeVolumes = (& docker.exe volume ls --filter "name=mysql") | Out-String

        $isolationLog = "=== E2E AND MAIN STACK RESOURCE ISOLATION PROOF ===`n`n" +
            "--- Docker Containers (Active) ---`n$activeContainers`n" +
            "--- Docker Networks ---`n$activeNetworks`n" +
            "--- Docker Volumes ---`n$activeVolumes`n"

        $isoPath = Join-Path $EvidenceDir "e2e_resource_isolation.txt"
        [System.IO.File]::WriteAllText($isoPath, $isolationLog, [System.Text.UTF8Encoding]::new($false))

        $e2eRawConfig = (& docker.exe compose -p $projectName -f "$e2eComposePath" config) | Out-String
        $e2eSanitizedConfig = $e2eRawConfig -replace '(?m)(CSRF_SECRET:\s*).*', '$1[REDACTED_SECRET]' `
                                            -replace '(?m)(SESSION_SECRET:\s*).*', '$1[REDACTED_SECRET]' `
                                            -replace '(?m)(MYSQL_PASSWORD:\s*).*', '$1[REDACTED_SECRET]' `
                                            -replace '(?m)(MYSQL_ROOT_PASSWORD:\s*).*', '$1[REDACTED_SECRET]' `
                                            -replace '(?m)(DATABASE_URL:\s*mysql://[^:]+:)[^@]+(@.*)', '$1[REDACTED_SECRET]$2' `
                                            -replace '(-p)[^\s\\]+', '$1[REDACTED_PASSWORD]' `
                                            -replace '(--password=)[^\s\\]+', '$1[REDACTED_PASSWORD]'

        $sanitizedPath = Join-Path $EvidenceDir "e2e_compose_config_sanitized.txt"
        [System.IO.File]::WriteAllText($sanitizedPath, $e2eSanitizedConfig, [System.Text.UTF8Encoding]::new($false))
    }

    # 11. Execute Playwright E2E Tests
    Write-Host "[7/8] Menjalankan Playwright End-to-End Test Suite..."
    $env:PLAYWRIGHT_BASE_URL = "http://127.0.0.1:$E2ePort"
    $env:E2E_ADMIN_PASSWORD_FILE = (Resolve-Path $e2eSecretFile).Path
    $playwrightConfigPath = Join-Path $projectRoot "frontend\playwright.config.ts"

    $playwrightOutput = & npx.cmd --prefix frontend playwright test -c "$playwrightConfigPath" 2>&1 | Out-String
    $playwrightExitCode = $LASTEXITCODE

    Write-Host $playwrightOutput

    if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $e2eResultPath = Join-Path $EvidenceDir "e2e_test_results.txt"
        [System.IO.File]::WriteAllText($e2eResultPath, $playwrightOutput, [System.Text.UTF8Encoding]::new($false))
    }

    if ($playwrightExitCode -eq 0) {
        Write-Host "Playwright E2E Test Suite BERHASIL (Exit Code: 0)."
    } else {
        Write-Warning "Playwright E2E Test Suite GAGAL dengan exit code $playwrightExitCode."
    }

} catch {
    $err = $_.Exception.Message
    Write-Error "Terjadi kegagalan selama siklus pengujian E2E: $err"
    $playwrightExitCode = 1
} finally {
    # 12. Strict Ownership Cleanup Guard and Teardown
    Write-Host "[8/8] Membersihkan disposable E2E stack ($projectName)..."
    if ($projectName -notmatch '^stockflow-e2e-[a-f0-9]{8}$') {
        Write-Error "Ownership Guard: Nama project '$projectName' tidak valid. Teardown otomatis dibatalkan demi keamanan."
    } elseif (-not $KeepStack) {
        & docker.exe compose -p $projectName -f "$e2eComposePath" down -v --remove-orphans
        if (Test-Path -LiteralPath $e2eSecretFile) {
            Remove-Item -LiteralPath $e2eSecretFile -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Stack E2E $projectName berhasil dibersihkan beserta volume terisolasinya."
    } else {
        Write-Host "Flag KeepStack aktif: stack E2E dibiarkan berjalan untuk inspeksi manual."
    }

    # Record Main Stack Status After E2E Teardown
    $mainStatusAfter = & docker.exe ps --filter "name=stockflow" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-String
    Write-Host "Status kontainer aplikasi utama setelah pengujian E2E selesai:"
    Write-Host $mainStatusAfter

    if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $mainAfterPath = Join-Path $EvidenceDir "main_stack_after.txt"
        [System.IO.File]::WriteAllText($mainAfterPath, $mainStatusAfter, [System.Text.UTF8Encoding]::new($false))
    }
}

exit $playwrightExitCode
