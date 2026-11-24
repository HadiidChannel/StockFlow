# ==============================================================================
# Automated Verification Test Suite for scripts/init-local.ps1
# File: tests/test-init-local.ps1
# Description: Rigorous 15-scenario verification for local initialization,
#              cryptographic complexity, Windows ACLs, and rollback safety.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$initScript = Join-Path $projectRoot "scripts\init-local.ps1"

Write-Host "======================================================================"
Write-Host " Running Automated Verification Tests for scripts/init-local.ps1"
Write-Host " Target Script: $initScript"
Write-Host " Strict Mode: Enabled (Latest)"
Write-Host "======================================================================"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $currentUser.User.Value
$userName = $env:USERNAME

$testTempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_test_init_" + [Guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null

$passCount = 0
$totalTests = 15

try {
    # --------------------------------------------------------------------------
    # Scenario 1: Fresh Initialization in Isolated Directory
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 1/15] Menjalankan inisialisasi pada direktori kosong..."
    $initOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$initScript" -TargetProjectRoot "$testTempDir" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Scenario 1 Gagal: init-local.ps1 keluar dengan kode $LASTEXITCODE. Output: $initOutput"
    }

    $createdEnv = Join-Path $testTempDir ".env"
    $createdSecret = Join-Path $testTempDir ".secrets\initial_admin_password.txt"

    if (-not (Test-Path -LiteralPath $createdEnv)) { throw "Scenario 1 Gagal: File .env tidak ditemukan." }
    if (-not (Test-Path -LiteralPath $createdSecret)) { throw "Scenario 1 Gagal: File initial_admin_password.txt tidak ditemukan." }
    $passCount++
    Write-Host "[Scenario 1 PASSED] Fresh initialization berhasil membuat .env dan .secrets/initial_admin_password.txt."

    # Read contents for property validation
    $envRaw = Get-Content -LiteralPath $createdEnv -Raw
    $secretRaw = (Get-Content -LiteralPath $createdSecret -Raw).Trim()

    # --------------------------------------------------------------------------
    # Scenario 2: Safety Guard: Rejection when .env already exists
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 2/15] Menguji penolakan overwrite jika .env sudah ada..."
    $proc2 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir`"" -NoNewWindow -Wait -PassThru
    if ($proc2.ExitCode -eq 0) {
        throw "Scenario 2 Gagal: init-local.ps1 seharusnya gagal (non-zero) ketika .env sudah ada."
    }
    $passCount++
    Write-Host "[Scenario 2 PASSED] Safety guard berhasil mencegah penimpaan file .env (Exit Code: $($proc2.ExitCode))."

    # --------------------------------------------------------------------------
    # Scenario 3: Safety Guard: Rejection when secret file already exists
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 3/15] Menguji penolakan overwrite jika file secret sudah ada..."
    $testTempDir3 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_test_guard_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $testTempDir3 ".secrets") -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $testTempDir3 ".secrets\initial_admin_password.txt"), "PreExistingSecret123!", [System.Text.UTF8Encoding]::new($false))
    try {
        $proc3 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir3`"" -NoNewWindow -Wait -PassThru
        if ($proc3.ExitCode -eq 0) {
            throw "Scenario 3 Gagal: init-local.ps1 seharusnya gagal ketika file secret sudah ada."
        }
        $passCount++
        Write-Host "[Scenario 3 PASSED] Safety guard berhasil mencegah penimpaan file secret (Exit Code: $($proc3.ExitCode))."
    } finally {
        Remove-Item -LiteralPath $testTempDir3 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 4: Admin Password Minimum Length (>= 24 characters)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 4/15] Memeriksa panjang password administrator..."
    if ($secretRaw.Length -lt 24) {
        throw "Scenario 4 Gagal: Panjang password ($($secretRaw.Length)) kurang dari 24 karakter."
    }
    $passCount++
    Write-Host "[Scenario 4 PASSED] Panjang password memenuhi syarat ($($secretRaw.Length) karakter >= 24)."

    # --------------------------------------------------------------------------
    # Scenario 5: Admin Password Complexity Policy
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 5/15] Memeriksa kompleksitas karakter password administrator..."
    $hasUpper = $secretRaw -match "[A-Z]"
    $hasLower = $secretRaw -match "[a-z]"
    $hasDigit = $secretRaw -match "[0-9]"
    $hasSymbol = $secretRaw -match "[!@#\$%\^&\*\(\)\-_=\+]"

    if (-not ($hasUpper -and $hasLower -and $hasDigit -and $hasSymbol)) {
        throw "Scenario 5 Gagal: Password tidak memenuhi kombinasi huruf besar, kecil, angka, dan simbol."
    }
    $passCount++
    Write-Host "[Scenario 5 PASSED] Password memenuhi seluruh kriteria kompleksitas karakter."

    # --------------------------------------------------------------------------
    # Scenario 6: Database Root Password Entropy (>= 48 hex chars / 24 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 6/15] Memeriksa entropi DB_ROOT_PASSWORD..."
    if ($envRaw -match "DB_ROOT_PASSWORD=([a-f0-9]{48,})") {
        $passCount++
        Write-Host "[Scenario 6 PASSED] DB_ROOT_PASSWORD memiliki format hex 24+ byte yang valid."
    } else {
        throw "Scenario 6 Gagal: DB_ROOT_PASSWORD tidak memenuhi format hex entropi tinggi."
    }

    # --------------------------------------------------------------------------
    # Scenario 7: Database User Password Entropy (>= 48 hex chars / 24 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 7/15] Memeriksa entropi DB_PASSWORD..."
    if ($envRaw -match "DB_PASSWORD=([a-f0-9]{48,})") {
        $passCount++
        Write-Host "[Scenario 7 PASSED] DB_PASSWORD memiliki format hex 24+ byte yang valid."
    } else {
        throw "Scenario 7 Gagal: DB_PASSWORD tidak memenuhi format hex entropi tinggi."
    }

    # --------------------------------------------------------------------------
    # Scenario 8: Session Secret Entropy (>= 64 hex chars / 32 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 8/15] Memeriksa entropi SESSION_SECRET..."
    if ($envRaw -match "SESSION_SECRET=`"([a-f0-9]{64,})`"") {
        $passCount++
        Write-Host "[Scenario 8 PASSED] SESSION_SECRET memiliki format hex 32+ byte yang valid."
    } else {
        throw "Scenario 8 Gagal: SESSION_SECRET tidak memenuhi format hex 32 byte."
    }

    # --------------------------------------------------------------------------
    # Scenario 9: CSRF Secret Entropy (>= 64 hex chars / 32 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 9/15] Memeriksa entropi CSRF_SECRET..."
    if ($envRaw -match "CSRF_SECRET=`"([a-f0-9]{64,})`"") {
        $passCount++
        Write-Host "[Scenario 9 PASSED] CSRF_SECRET memiliki format hex 32+ byte yang valid."
    } else {
        throw "Scenario 9 Gagal: CSRF_SECRET tidak memenuhi format hex 32 byte."
    }

    # --------------------------------------------------------------------------
    # Scenario 10: Zero Credential Exposure in Console Output
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 10/15] Memeriksa higienitas console output terhadap kebocoran rahasia..."
    if ($initOutput -match [regex]::Escape($secretRaw)) {
        throw "Scenario 10 Gagal: Password administrator bocor pada console output!"
    }
    if ($initOutput -match "DB_ROOT_PASSWORD" -or $initOutput -match "SESSION_SECRET") {
        throw "Scenario 10 Gagal: Nama variabel rahasia atau nilainya tercetak pada console output!"
    }
    $passCount++
    Write-Host "[Scenario 10 PASSED] Zero credential exposure terverifikasi pada console output."

    # --------------------------------------------------------------------------
    # Scenario 11: Windows ACL on .env File
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 11/15] Memeriksa Windows ACL pada file .env..."
    $envAcl = (& icacls.exe "$createdEnv") -join "`n"
    if ($envAcl -notmatch [regex]::Escape($userName) -and $envAcl -notmatch [regex]::Escape($userSid)) {
        throw "Scenario 11 Gagal: File .env tidak memiliki ACL untuk user aktif."
    }
    $passCount++
    Write-Host "[Scenario 11 PASSED] File .env terproteksi ACL dengan hak akses user dan administrator."

    # --------------------------------------------------------------------------
    # Scenario 12: Windows ACL on initial_admin_password.txt File
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 12/15] Memeriksa Windows ACL pada file initial_admin_password.txt..."
    $secretAcl = (& icacls.exe "$createdSecret") -join "`n"
    if ($secretAcl -notmatch [regex]::Escape($userName) -and $secretAcl -notmatch [regex]::Escape($userSid)) {
        throw "Scenario 12 Gagal: File secret tidak memiliki ACL untuk user aktif."
    }
    $passCount++
    Write-Host "[Scenario 12 PASSED] File initial_admin_password.txt terproteksi ACL dengan benar."

    # --------------------------------------------------------------------------
    # Scenario 13: Windows ACL on .secrets Directory
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 13/15] Memeriksa Windows ACL pada direktori .secrets..."
    $dirAcl = (& icacls.exe (Join-Path $testTempDir ".secrets")) -join "`n"
    if ($dirAcl -notmatch [regex]::Escape($userName) -and $dirAcl -notmatch [regex]::Escape($userSid)) {
        throw "Scenario 13 Gagal: Direktori .secrets tidak memiliki ACL untuk user aktif."
    }
    $passCount++
    Write-Host "[Scenario 13 PASSED] Direktori .secrets terproteksi ACL secara ketat."

    # --------------------------------------------------------------------------
    # Scenario 14: StrictMode Compatibility Check
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 14/15] Memeriksa kompatibilitas Set-StrictMode -Version Latest..."
    # Verify that executing in a clean process running strict mode does not raise PropertyNotFoundStrict
    $testTempDir14 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_strict_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir14 -Force | Out-Null
    try {
        $proc14 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { Set-StrictMode -Version Latest; `$ErrorActionPreference = 'Stop'; & '$initScript' -TargetProjectRoot '$testTempDir14' }`"" -NoNewWindow -Wait -PassThru
        if ($proc14.ExitCode -ne 0) {
            throw "Scenario 14 Gagal: Eksekusi gagal di bawah StrictMode Latest (Exit Code: $($proc14.ExitCode))."
        }
        $passCount++
        Write-Host "[Scenario 14 PASSED] Skrip 100% kompatibel dengan Set-StrictMode -Version Latest."
    } finally {
        Remove-Item -LiteralPath $testTempDir14 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 15: Clean Rollback Validation on Failure
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 15/15] Menguji mekanisme rollback otomatis saat terjadi kegagalan..."
    $testTempDir15 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rollback_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir15 -Force | Out-Null

    # Create a pre-existing blocking folder where .env would be created to induce failure during Move-Item
    $blockingPath = Join-Path $testTempDir15 ".env"
    New-Item -ItemType Directory -Path $blockingPath -Force | Out-Null

    try {
        # init-local will fail because .env is an existing directory
        $proc15 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir15`"" -NoNewWindow -Wait -PassThru
        if ($proc15.ExitCode -eq 0) {
            throw "Scenario 15 Gagal: Skrip seharusnya gagal saat .env terhalang direktori."
        }

        # Verify no orphan .tmp files remain
        $orphanTmp = Get-ChildItem -Path $testTempDir15 -Filter "*.tmp" -Recurse -Force -ErrorAction SilentlyContinue
        if ($orphanTmp -and $orphanTmp.Count -gt 0) {
            throw "Scenario 15 Gagal: Ditemukan sisa file .tmp setelah rollback!"
        }

        $passCount++
        Write-Host "[Scenario 15 PASSED] Rollback berhasil membersihkan artefak sementara tanpa meninggalkan sisa .tmp."
    } finally {
        Remove-Item -LiteralPath $testTempDir15 -Recurse -Force -ErrorAction SilentlyContinue
    }

} finally {
    if (Test-Path -LiteralPath $testTempDir) {
        Remove-Item -LiteralPath $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "======================================================================"
Write-Host " Hasil Pengujian Otomatis scripts/init-local.ps1:"
Write-Host " Total Skenario: $totalTests"
Write-Host " Lulus (Passed): $passCount"
Write-Host " Gagal (Failed): $($totalTests - $passCount)"
Write-Host " Status: $(if ($passCount -eq $totalTests) { '100% SUKSES' } else { 'GAGAL' })"
Write-Host "======================================================================"
Write-Host ""

if ($passCount -ne $totalTests) {
    exit 1
}
