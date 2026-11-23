# ==============================================================================
# Automated Verification Test for scripts/init-local.ps1
# File: tests/test-init-local.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$initScript = Join-Path $projectRoot "scripts\init-local.ps1"

Write-Host "=== Running Automated Tests for scripts/init-local.ps1 ==="

# Test 1: Fresh initialization in temporary isolated directory
$testTempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_test_init_" + [Guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null

try {
    Write-Host "[Test 1] Executing init-local.ps1 on fresh directory..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$initScript" -TargetProjectRoot "$testTempDir"
    if ($LASTEXITCODE -ne 0) {
        throw "Test 1 Failed: init-local.ps1 exited with code $LASTEXITCODE on fresh directory"
    }

    $createdEnv = Join-Path $testTempDir ".env"
    $createdSecret = Join-Path $testTempDir ".secrets\initial_admin_password.txt"

    if (-not (Test-Path $createdEnv)) { throw "Test 1 Failed: .env was not created" }
    if (-not (Test-Path $createdSecret)) { throw "Test 1 Failed: initial_admin_password.txt was not created" }

    $envContent = Get-Content $createdEnv -Raw
    $secretContent = (Get-Content $createdSecret -Raw).Trim()

    if ($secretContent.Length -lt 20) { throw "Test 1 Failed: Admin password too short" }
    if ($envContent -notmatch "DB_ROOT_PASSWORD=") { throw "Test 1 Failed: Missing DB_ROOT_PASSWORD" }
    if ($envContent -notmatch "SESSION_SECRET=") { throw "Test 1 Failed: Missing SESSION_SECRET" }
    Write-Host "[Test 1 PASSED] Fresh initialization succeeded with valid secrets."

    # Test 2: Safety Guard: Re-execution must fail and not overwrite
    Write-Host "[Test 2] Testing safety guard against overwriting existing .env..."
    $secProc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir`"" -NoNewWindow -Wait -PassThru
    if ($secProc.ExitCode -eq 0) {
        throw "Test 2 Failed: init-local.ps1 should have failed when .env already exists"
    }
    Write-Host "[Test 2 PASSED] Safety guard prevented overwrite with non-zero exit code ($($secProc.ExitCode))."

    # Test 3: ACL verification
    Write-Host "[Test 3] Verifying icacls permissions on created files..."
    $aclOutput = (& icacls.exe "$createdSecret") -join "`n"
    if ($aclOutput -notmatch [regex]::Escape($env:USERNAME)) {
        throw "Test 3 Failed: User permission not set on secret file"
    }
    Write-Host "[Test 3 PASSED] ACL correctly configured for current user."

} finally {
    if (Test-Path $testTempDir) {
        Remove-Item -LiteralPath $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "=== All init-local.ps1 Automated Tests PASSED (3/3) ==="
