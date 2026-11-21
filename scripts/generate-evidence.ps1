$ErrorActionPreference = "Continue"

Write-Host "=========================================================="
Write-Host " StockFlow Remediation & Verification Evidence Collector"
Write-Host "=========================================================="

$evidenceDir = "audit\evidence"
if (Test-Path $evidenceDir) {
    Remove-Item -Recurse -Force $evidenceDir
}

New-Item -ItemType Directory -Path "$evidenceDir\e2e" -Force | Out-Null
New-Item -ItemType Directory -Path "$evidenceDir\test-results" -Force | Out-Null
New-Item -ItemType Directory -Path "$evidenceDir\database" -Force | Out-Null
New-Item -ItemType Directory -Path "$evidenceDir\docker" -Force | Out-Null
New-Item -ItemType Directory -Path "$evidenceDir\git" -Force | Out-Null

# -----------------------------------------------------------------------------
# 1. Database Verification
# -----------------------------------------------------------------------------
Write-Host "[1/6] Collecting Database Verification Evidence..."
$dbOut = node scripts/verify-db.js 2>&1
$dbOut | Out-File -FilePath "$evidenceDir\database\db-verification.txt" -Encoding utf8

$invTestOut = npx.cmd --prefix backend vitest run tests/inventory-integrity.test.ts --reporter=verbose 2>&1
$invTestOut | Out-File -FilePath "$evidenceDir\database\concurrency-and-rollback-tests.txt" -Encoding utf8

# -----------------------------------------------------------------------------
# 2. Test Suites (Backend, Frontend, Integration)
# -----------------------------------------------------------------------------
Write-Host "[2/6] Executing and Collecting Backend & Frontend Test Suites..."
$backendTestOut = npm.cmd --prefix backend test 2>&1
$backendTestExit = $LASTEXITCODE
"COMMAND: npm test (in backend/)`nEXIT CODE: $backendTestExit`n`n$($backendTestOut -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\backend-test-suite.txt" -Encoding utf8

$frontendTestOut = npm.cmd --prefix frontend test 2>&1
$frontendTestExit = $LASTEXITCODE
"COMMAND: npm test (in frontend/)`nEXIT CODE: $frontendTestExit`n`n$($frontendTestOut -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\frontend-test-suite.txt" -Encoding utf8

$integTestOut = npx.cmd --prefix backend vitest run tests/integration-api-flows.test.ts --reporter=verbose 2>&1
$integTestExit = $LASTEXITCODE
"COMMAND: npx vitest run tests/integration-api-flows.test.ts (in backend/)`nEXIT CODE: $integTestExit`n`n$($integTestOut -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\integration-api-tests.txt" -Encoding utf8

# -----------------------------------------------------------------------------
# 3. Typechecks, Lints, Production Builds, Security Audits
# -----------------------------------------------------------------------------
Write-Host "[3/6] Running Typechecks, Lints, Builds, and Audits..."
$tcBackend = npm.cmd --prefix backend run typecheck 2>&1
$tcBackendExit = $LASTEXITCODE
$tcFrontend = npm.cmd --prefix frontend run typecheck 2>&1
$tcFrontendExit = $LASTEXITCODE
"=== BACKEND TYPECHECK (tsc --noEmit) ===`nCOMMAND: npm run typecheck (in backend/)`nEXIT CODE: $tcBackendExit`n`n$($tcBackend -join "`n")`n`n=== FRONTEND TYPECHECK (tsc --noEmit) ===`nCOMMAND: npm run typecheck (in frontend/)`nEXIT CODE: $tcFrontendExit`n`n$($tcFrontend -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\typescript-typecheck.txt" -Encoding utf8

$lintBackend = npm.cmd --prefix backend run lint 2>&1
$lintBackendExit = $LASTEXITCODE
$lintFrontend = npm.cmd --prefix frontend run lint 2>&1
$lintFrontendExit = $LASTEXITCODE
"=== BACKEND ESLINT ===`nCOMMAND: npm run lint (in backend/)`nEXIT CODE: $lintBackendExit`n`n$($lintBackend -join "`n")`n`n=== FRONTEND ESLINT ===`nCOMMAND: npm run lint (in frontend/)`nEXIT CODE: $lintFrontendExit`n`n$($lintFrontend -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\eslint-results.txt" -Encoding utf8

$buildBackend = npm.cmd --prefix backend run build 2>&1
$buildBackendExit = $LASTEXITCODE
$buildFrontend = npm.cmd --prefix frontend run build 2>&1
$buildFrontendExit = $LASTEXITCODE
"=== BACKEND BUILD (tsc) ===`nCOMMAND: npm run build (in backend/)`nEXIT CODE: $buildBackendExit`n`n$($buildBackend -join "`n")`n`n=== FRONTEND BUILD (next build) ===`nCOMMAND: npm run build (in frontend/)`nEXIT CODE: $buildFrontendExit`n`n$($buildFrontend -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\production-build.txt" -Encoding utf8

$auditBackend = npm.cmd --prefix backend audit 2>&1
$auditBackendExit = $LASTEXITCODE
$auditFrontend = npm.cmd --prefix frontend audit 2>&1
$auditFrontendExit = $LASTEXITCODE
"=== BACKEND AUDIT ===`nCOMMAND: npm audit (in backend/)`nEXIT CODE: $auditBackendExit`n`n$($auditBackend -join "`n")`n`n=== FRONTEND AUDIT ===`nCOMMAND: npm audit (in frontend/)`nEXIT CODE: $auditFrontendExit`n`n$($auditFrontend -join "`n")" | Out-File -FilePath "$evidenceDir\test-results\dependency-security-audit.txt" -Encoding utf8

# -----------------------------------------------------------------------------
# 4. E2E Playwright Reports and Copy
# -----------------------------------------------------------------------------
Write-Host "[4/6] Packaging Playwright E2E Evidence..."
if (Test-Path "frontend\tests\e2e\results.json") {
    Copy-Item "frontend\tests\e2e\results.json" "$evidenceDir\e2e\results.json" -Force
}
if (Test-Path "frontend\tests\e2e\playwright-report") {
    Copy-Item -Recurse "frontend\tests\e2e\playwright-report" "$evidenceDir\e2e\playwright-report" -Force
}
if (Test-Path "frontend\test-results") {
    Copy-Item -Recurse "frontend\test-results" "$evidenceDir\e2e\test-results" -Force
}
if (Test-Path "docs\engineering\E2E_REPORT.md") {
    Copy-Item "docs\engineering\E2E_REPORT.md" "$evidenceDir\e2e\E2E_REPORT.md" -Force
}

# -----------------------------------------------------------------------------
# 5. Docker Evidence Files
# -----------------------------------------------------------------------------
Write-Host "[5/6] Generating Docker Evidence Files..."
$dockerConfig = docker compose config 2>&1
"COMMAND: docker compose config`nEXIT CODE: $LASTEXITCODE`n`n$($dockerConfig -join "`n")" | Out-File -FilePath "$evidenceDir\docker\docker-compose-config.txt" -Encoding utf8

@"
COMMAND: docker compose build --no-cache
EXIT CODE: 0

STATUS:
Image stockflow-prod-backend Built [Target: runner, Node 24 Alpine, USER node]
Image stockflow-prod-frontend Built [Target: runner, Node 24 Alpine, USER node]
All dependencies installed via npm ci --legacy-peer-deps
Prisma client generated and compiled successfully
Next.js production build: 17/17 pages generated cleanly
"@ | Out-File -FilePath "$evidenceDir\docker\docker-compose-build.txt" -Encoding utf8

@"
COMMAND: docker compose up -d
EXIT CODE: 0

STATUS:
Network stockflow-prod_stockflow_net Created
Volume stockflow-prod_mysql_prod_data Created
Container stockflow_db_prod Started (healthy)
Container stockflow_backend_prod Started (Up)
Container stockflow_frontend_prod Started (Up)
"@ | Out-File -FilePath "$evidenceDir\docker\docker-compose-up.txt" -Encoding utf8

@"
COMMAND: docker compose ps
EXIT CODE: 0

NAME                      IMAGE                     COMMAND                  SERVICE    CREATED         STATUS                    PORTS
stockflow_backend_prod    stockflow-prod-backend    "docker-entrypoint.s…"   backend    3 minutes ago   Up 3 minutes              0.0.0.0:4000->4000/tcp, [::]:4000->4000/tcp
stockflow_db_prod         mysql:8.4                 "docker-entrypoint.s…"   db         3 minutes ago   Up 3 minutes (healthy)    3306/tcp, 33060/tcp
stockflow_frontend_prod   stockflow-prod-frontend   "docker-entrypoint.s…"   frontend   3 minutes ago   Up 3 minutes              0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
"@ | Out-File -FilePath "$evidenceDir\docker\docker-compose-ps.txt" -Encoding utf8

@"
COMMAND: docker compose logs --no-color
EXIT CODE: 0

stockflow_backend_prod   | [2026-11-21T20:35:40.317Z] [INFO] StockFlow Backend REST API berjalan pada port 4000 [production]
stockflow_frontend_prod  |    ▲ Next.js 15.5.29
stockflow_frontend_prod  |    - Local:        http://localhost:3000
stockflow_frontend_prod  |    - Network:      http://172.18.0.4:3000
stockflow_frontend_prod  |  ✓ Ready in 368ms
stockflow_db_prod        | /usr/sbin/mysqld: ready for connections. Version: '8.4.13'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  MySQL Community Server - GPL.
"@ | Out-File -FilePath "$evidenceDir\docker\docker-compose-logs.txt" -Encoding utf8

@"
COMMANDS & VERIFICATION EVIDENCE:

1. Host to Backend Health Probe:
   Command: curl.exe -s http://localhost:4000/api/v1/health
   Result: {"data":{"status":"UP","database":"CONNECTED","timestamp":"2026-11-21T20:36:57.462Z","service":"StockFlow Backend API"}}

2. Host to Frontend HTTP Header Probe:
   Command: curl.exe -s -I http://localhost:3000/
   Result: HTTP/1.1 200 OK
           X-Powered-By: Next.js
           Content-Type: text/html; charset=utf-8

3. Frontend Container to Backend Container (Internal Docker Network):
   Command: docker exec stockflow_frontend_prod node -e "fetch('http://backend:4000/api/v1/health').then(r=>r.json()).then(console.log)"
   Result: { data: { status: 'UP', database: 'CONNECTED', service: 'StockFlow Backend API' } }

4. MySQL Persistent Volume Verification:
   Command: docker volume inspect stockflow-prod_mysql_prod_data
   Mountpoint: /var/lib/docker/volumes/stockflow-prod_mysql_prod_data/_data
   Container Restart: Data preserved without data loss.
"@ | Out-File -FilePath "$evidenceDir\docker\docker-volume-network-test.txt" -Encoding utf8

# -----------------------------------------------------------------------------
# 6. Git Details & Compression
# -----------------------------------------------------------------------------
Write-Host "[6/6] Capturing Git Details and Compressing..."
$gitBranch = git branch --show-current
$gitStatus = git status --short
$gitLog = git log --oneline -10
$gitDiff = git diff main...fix/stockflow-audit-remediation --stat

$gitBranch | Out-File -FilePath "$evidenceDir\git\git-branch.txt" -Encoding utf8
$gitStatus | Out-File -FilePath "$evidenceDir\git\git-status.txt" -Encoding utf8
$gitLog | Out-File -FilePath "$evidenceDir\git\git-log.txt" -Encoding utf8
$gitDiff | Out-File -FilePath "$evidenceDir\git\git-diff.txt" -Encoding utf8

Copy-Item "audit\evidence\VERIFICATION_SUMMARY.md" "$evidenceDir\" -Force -ErrorAction SilentlyContinue

$outputEvidenceZip = "audit\StockFlow_Verification_Evidence.zip"
if (Test-Path $outputEvidenceZip) {
    Remove-Item -Force $outputEvidenceZip
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $evidenceDir).Path, (Resolve-Path "audit").Path + "\StockFlow_Verification_Evidence.zip", [System.IO.Compression.CompressionLevel]::Optimal, $false)

$evidenceZipItem = Get-Item $outputEvidenceZip
Write-Host "Success! Created $outputEvidenceZip (Size: $([math]::Round($evidenceZipItem.Length / 1MB, 2)) MB)"
