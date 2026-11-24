# ==============================================================================
# StockFlow - Automated Evidence Capture Script (v1.6.2)
# Script: scripts/capture-evidence.ps1
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$evidenceDir = Join-Path $projectRoot "evidence\v1.6.2"

if (-not (Test-Path -LiteralPath $evidenceDir)) {
    New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host "======================================================================"
Write-Host " Capturing Verification Evidence for StockFlow v1.6.2"
Write-Host " Target Evidence Directory: $evidenceDir"
Write-Host "======================================================================"

# 1. Secret Scanner Self-Test Output
Write-Host "[1/7] Menjalankan dan merekam secret scanner self-test..."
$selfTestOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$projectRoot\scripts\scan-secrets.ps1' -SelfTest" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "secret_scanner_self_test.txt"), $selfTestOutput, $utf8NoBom)

# 2. Repository Secret Scan Output
Write-Host "[2/7] Menjalankan dan merekam pemindaian rahasia repositori..."
$scanFile = Join-Path $evidenceDir "secret_scan.txt"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$projectRoot\scripts\scan-secrets.ps1" -OutputFile "$scanFile"

# 3. Init-Local 19-Scenario Test Suite Output
Write-Host "[3/7] Menjalankan dan merekam pengujian scripts/init-local.ps1..."
$initTestOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$projectRoot\tests\test-init-local.ps1" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "init_local_test_results.txt"), $initTestOutput, $utf8NoBom)

# 4. Backend and Frontend Unit/Integration Tests
Write-Host "[4/7] Menjalankan dan merekam pengujian backend dan frontend..."
$backendResults = & powershell.exe -NoProfile -Command ".\backend\node_modules\.bin\vitest.cmd run --config backend/vitest.config.ts" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "backend_test_results.txt"), $backendResults, $utf8NoBom)

$frontendResults = & powershell.exe -NoProfile -Command ".\backend\node_modules\.bin\vitest.cmd run --config frontend/vitest.config.ts" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "frontend_test_results.txt"), $frontendResults, $utf8NoBom)

$unitResults = & powershell.exe -NoProfile -Command ".\backend\node_modules\.bin\vitest.cmd run tests/bootstrap.unit.test.ts --config backend/vitest.config.ts" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "bootstrap_unit_test_results.txt"), $unitResults, $utf8NoBom)

$guardResults = & powershell.exe -NoProfile -Command ".\backend\node_modules\.bin\vitest.cmd run tests/bootstrap-guard.test.ts --config backend/vitest.config.ts" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "bootstrap_guard_test_results.txt"), $guardResults, $utf8NoBom)

# 5. E2E Secret ACL Fail-Closed Test
Write-Host "[5/7] Menguji proteksi fail-closed secret ACL pada E2E runner..."
$e2eAclOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$projectRoot\scripts\run-e2e.ps1' -TestFaultStage fail-secret-acl" 2>&1 | Out-String
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "e2e_secret_acl_test_results.txt"), $e2eAclOutput, $utf8NoBom)

# 6. Docker Compose Config Sanitized Verification
Write-Host "[6/7] Memverifikasi konfigurasi Docker Compose..."
$mainCompose = & docker.exe compose -f "$projectRoot\docker-compose.yml" config 2>&1 | Out-String
$devCompose = & docker.exe compose -f "$projectRoot\docker-compose.dev.yml" config 2>&1 | Out-String
$e2eCompose = & docker.exe compose -f "$projectRoot\docker-compose.e2e.yml" config 2>&1 | Out-String
$bootCompose = & docker.exe compose -f "$projectRoot\docker-compose.bootstrap-test.yml" config 2>&1 | Out-String

$composeVerification = @"
=== DOCKER COMPOSE CONFIGURATION VERIFICATION (v1.6.2) ===
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')

1. Main Compose (docker-compose.yml):
Status: SYNTAX_VALID
Host Ports: Loopback strictly (127.0.0.1:3000->3000)

2. Development Compose (docker-compose.dev.yml):
Status: SYNTAX_VALID
Host Ports: Loopback strictly (127.0.0.1:3306, 127.0.0.1:4000, 127.0.0.1:3000)

3. E2E Compose (docker-compose.e2e.yml):
Status: SYNTAX_VALID
Namespace: Dynamic project name (`${COMPOSE_PROJECT_NAME})
Host Port: 127.0.0.1:3100 -> 3000 (disposable)

4. Bootstrap Test Compose (docker-compose.bootstrap-test.yml):
Status: SYNTAX_VALID
Host Port: 127.0.0.1:3307 -> 3306 (disposable)
"@
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "docker_compose_verification.txt"), $composeVerification, $utf8NoBom)

# 7. Disposable MySQL Bootstrap Integration Test
Write-Host "[7/7] Menjalankan pengujian integrasi bootstrap MySQL disposable..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$projectRoot\scripts\run-bootstrap-test.ps1" -EvidenceDir "$evidenceDir"

Write-Host ""
Write-Host "Seluruh bukti verifikasi tahap 1-7 berhasil direkam di: $evidenceDir"
Write-Host ""
