# ==============================================================================
# Automated Verification Test Suite for scripts/init-local.ps1
# File: tests/test-init-local.ps1
# Description: Rigorous 19-scenario verification for local initialization,
#              cryptographic complexity, Windows ACLs, principals, inheritance,
#              existing directory ACL, and real fault-injected rollbacks.
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
$totalTests = 19

try {
    # --------------------------------------------------------------------------
    # Scenario 1: Fresh Initialization in Isolated Directory
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 1/19] Menjalankan inisialisasi pada direktori kosong..."
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
    Write-Host "[Scenario 2/19] Menguji penolakan overwrite jika .env sudah ada..."
    $proc2 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir`"" -NoNewWindow -Wait -PassThru
    if ($proc2.ExitCode -eq 0) {
        throw "Scenario 2 Gagal: init-local.ps1 seharusnya gagal (non-zero) ketika .env sudah ada."
    }
    $passCount++
    Write-Host "[Scenario 2 PASSED] Safety guard berhasil mencegah penimpaan file .env (Exit Code: $($proc2.ExitCode))."

    # --------------------------------------------------------------------------
    # Scenario 3: Safety Guard: Rejection when secret file already exists
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 3/19] Menguji penolakan overwrite jika file secret sudah ada..."
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
    Write-Host "[Scenario 4/19] Memeriksa panjang password administrator..."
    if ($secretRaw.Length -lt 24) {
        throw "Scenario 4 Gagal: Panjang password ($($secretRaw.Length)) kurang dari 24 karakter."
    }
    $passCount++
    Write-Host "[Scenario 4 PASSED] Panjang password memenuhi syarat ($($secretRaw.Length) karakter >= 24)."

    # --------------------------------------------------------------------------
    # Scenario 5: Admin Password Complexity Policy
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 5/19] Memeriksa kompleksitas karakter password administrator..."
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
    Write-Host "[Scenario 6/19] Memeriksa entropi DB_ROOT_PASSWORD..."
    if ($envRaw -match "DB_ROOT_PASSWORD=([a-f0-9]{48,})") {
        $passCount++
        Write-Host "[Scenario 6 PASSED] DB_ROOT_PASSWORD memiliki format hex 24+ byte yang valid."
    } else {
        throw "Scenario 6 Gagal: DB_ROOT_PASSWORD tidak memenuhi format hex entropi tinggi."
    }

    # --------------------------------------------------------------------------
    # Scenario 7: Database User Password Entropy (>= 48 hex chars / 24 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 7/19] Memeriksa entropi DB_PASSWORD..."
    if ($envRaw -match "DB_PASSWORD=([a-f0-9]{48,})") {
        $passCount++
        Write-Host "[Scenario 7 PASSED] DB_PASSWORD memiliki format hex 24+ byte yang valid."
    } else {
        throw "Scenario 7 Gagal: DB_PASSWORD tidak memenuhi format hex entropi tinggi."
    }

    # --------------------------------------------------------------------------
    # Scenario 8: Session Secret Entropy (>= 64 hex chars / 32 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 8/19] Memeriksa entropi SESSION_SECRET..."
    if ($envRaw -match "SESSION_SECRET=`"([a-f0-9]{64,})`"") {
        $passCount++
        Write-Host "[Scenario 8 PASSED] SESSION_SECRET memiliki format hex 32+ byte yang valid."
    } else {
        throw "Scenario 8 Gagal: SESSION_SECRET tidak memenuhi format hex 32 byte."
    }

    # --------------------------------------------------------------------------
    # Scenario 9: CSRF Secret Entropy (>= 64 hex chars / 32 bytes)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 9/19] Memeriksa entropi CSRF_SECRET..."
    if ($envRaw -match "CSRF_SECRET=`"([a-f0-9]{64,})`"") {
        $passCount++
        Write-Host "[Scenario 9 PASSED] CSRF_SECRET memiliki format hex 32+ byte yang valid."
    } else {
        throw "Scenario 9 Gagal: CSRF_SECRET tidak memenuhi format hex 32 byte."
    }

    # --------------------------------------------------------------------------
    # Scenario 10: Zero Credential Exposure in Console Output
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 10/19] Memeriksa higienitas console output terhadap kebocoran rahasia..."
    if ($initOutput -match [regex]::Escape($secretRaw)) {
        throw "Scenario 10 Gagal: Password administrator bocor pada console output!"
    }
    if ($initOutput -match "DB_ROOT_PASSWORD" -or $initOutput -match "SESSION_SECRET") {
        throw "Scenario 10 Gagal: Nama variabel rahasia atau nilainya tercetak pada console output!"
    }
    $passCount++
    Write-Host "[Scenario 10 PASSED] Zero credential exposure terverifikasi pada console output."

    # --------------------------------------------------------------------------
    # Scenario 11: Windows ACL on .env File (Principals & Inheritance)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 11/19] Memeriksa Windows ACL & Principals pada file .env..."
    $envAcl = (& icacls.exe "$createdEnv") -join "`n"
    $hasUser = ($envAcl -match [regex]::Escape($userName)) -or ($envAcl -match [regex]::Escape($userSid))
    $hasSystem = ($envAcl -match "SYSTEM") -or ($envAcl -match "S-1-5-18")
    $hasAdmin = ($envAcl -match "Administrators") -or ($envAcl -match "S-1-5-32-544")

    if (-not ($hasUser -and $hasSystem -and $hasAdmin)) {
        throw "Scenario 11 Gagal: File .env tidak memiliki ACL lengkap untuk User ($hasUser), SYSTEM ($hasSystem), atau Admins ($hasAdmin)."
    }
    $passCount++
    Write-Host "[Scenario 11 PASSED] File .env terproteksi ACL lengkap (CurrentUser, SYSTEM, Administrators)."

    # --------------------------------------------------------------------------
    # Scenario 12: Windows ACL on initial_admin_password.txt File (Principals & Inheritance)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 12/19] Memeriksa Windows ACL & Principals pada initial_admin_password.txt..."
    $secretAcl = (& icacls.exe "$createdSecret") -join "`n"
    $hasUserSec = ($secretAcl -match [regex]::Escape($userName)) -or ($secretAcl -match [regex]::Escape($userSid))
    $hasSystemSec = ($secretAcl -match "SYSTEM") -or ($secretAcl -match "S-1-5-18")
    $hasAdminSec = ($secretAcl -match "Administrators") -or ($secretAcl -match "S-1-5-32-544")

    if (-not ($hasUserSec -and $hasSystemSec -and $hasAdminSec)) {
        throw "Scenario 12 Gagal: File secret tidak memiliki ACL lengkap untuk User ($hasUserSec), SYSTEM ($hasSystemSec), atau Admins ($hasAdminSec)."
    }
    $passCount++
    Write-Host "[Scenario 12 PASSED] File initial_admin_password.txt terproteksi ACL lengkap."

    # --------------------------------------------------------------------------
    # Scenario 13: Windows ACL on .secrets Directory (Inheritance & Principals)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 13/19] Memeriksa Windows ACL pada direktori .secrets..."
    $dirAcl = (& icacls.exe (Join-Path $testTempDir ".secrets")) -join "`n"
    $hasUserDir = ($dirAcl -match [regex]::Escape($userName)) -or ($dirAcl -match [regex]::Escape($userSid))
    $hasSystemDir = ($dirAcl -match "SYSTEM") -or ($dirAcl -match "S-1-5-18")
    $hasAdminDir = ($dirAcl -match "Administrators") -or ($dirAcl -match "S-1-5-32-544")

    if (-not ($hasUserDir -and $hasSystemDir -and $hasAdminDir)) {
        throw "Scenario 13 Gagal: Direktori .secrets tidak memiliki ACL lengkap."
    }
    $passCount++
    Write-Host "[Scenario 13 PASSED] Direktori .secrets terproteksi ACL secara ketat (User, SYSTEM, Admins)."

    # --------------------------------------------------------------------------
    # Scenario 14: Existing .secrets Directory Receives ACL Unconditionally
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 14/19] Menguji penerapan ACL pada direktori .secrets yang sudah ada sebelumnya..."
    $testTempDir14 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_existdir_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    $existSecretsDir = Join-Path $testTempDir14 ".secrets"
    New-Item -ItemType Directory -Path $existSecretsDir -Force | Out-Null
    try {
        $proc14 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir14`"" -NoNewWindow -Wait -PassThru
        if ($proc14.ExitCode -ne 0) {
            throw "Scenario 14 Gagal: Eksekusi gagal pada direktori dengan .secrets yang sudah ada (Exit Code: $($proc14.ExitCode))."
        }
        $postAcl = (& icacls.exe "$existSecretsDir") -join "`n"
        $hasUserPost = ($postAcl -match [regex]::Escape($userName)) -or ($postAcl -match [regex]::Escape($userSid))
        $hasSystemPost = ($postAcl -match "SYSTEM") -or ($postAcl -match "S-1-5-18")
        $hasAdminPost = ($postAcl -match "Administrators") -or ($postAcl -match "S-1-5-32-544")
        if (-not ($hasUserPost -and $hasSystemPost -and $hasAdminPost)) {
            throw "Scenario 14 Gagal: Direktori .secrets yang sudah ada tidak menerima ACL baru secara benar."
        }
        $passCount++
        Write-Host "[Scenario 14 PASSED] Direktori .secrets yang sudah ada berhasil menerima proteksi ACL secara mutlak."
    } finally {
        Remove-Item -LiteralPath $testTempDir14 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 15: Real Rollback: Fault Injection after temp secret creation
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 15/19] Menguji rollback nyata: fault injection setelah temporary secret dibuat..."
    $testTempDir15 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_sec_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir15 -Force | Out-Null
    try {
        $proc15 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir15`" -TestFaultStage after-temp-secret" -NoNewWindow -Wait -PassThru
        if ($proc15.ExitCode -eq 0) {
            throw "Scenario 15 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        # Verify temporary secret was deleted
        $tempSecretCheck = Join-Path $testTempDir15 ".secrets\initial_admin_password.txt.tmp"
        if (Test-Path -LiteralPath $tempSecretCheck) {
            throw "Scenario 15 Gagal: File .tmp secret masih tertinggal setelah rollback!"
        }
        $passCount++
        Write-Host "[Scenario 15 PASSED] Rollback setelah temp secret berhasil menghapus artefak sementara."
    } finally {
        Remove-Item -LiteralPath $testTempDir15 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 16: Real Rollback: Fault Injection after temp env creation
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 16/19] Menguji rollback nyata: fault injection setelah temporary .env dibuat..."
    $testTempDir16 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_env_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir16 -Force | Out-Null
    try {
        $proc16 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir16`" -TestFaultStage after-temp-env" -NoNewWindow -Wait -PassThru
        if ($proc16.ExitCode -eq 0) {
            throw "Scenario 16 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        $tempEnvCheck = Join-Path $testTempDir16 ".env.tmp"
        $tempSecretCheck16 = Join-Path $testTempDir16 ".secrets\initial_admin_password.txt.tmp"
        if ((Test-Path -LiteralPath $tempEnvCheck) -or (Test-Path -LiteralPath $tempSecretCheck16)) {
            throw "Scenario 16 Gagal: File .tmp masih tertinggal setelah rollback!"
        }
        $passCount++
        Write-Host "[Scenario 16 PASSED] Rollback setelah temp .env berhasil membersihkan seluruh file staging."
    } finally {
        Remove-Item -LiteralPath $testTempDir16 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 17: Real Rollback: Fault Injection after move secret file
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 17/19] Menguji rollback nyata: fault injection setelah secret file dipindahkan..."
    $testTempDir17 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_mov_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir17 -Force | Out-Null
    try {
        $proc17 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir17`" -TestFaultStage after-move-secret" -NoNewWindow -Wait -PassThru
        if ($proc17.ExitCode -eq 0) {
            throw "Scenario 17 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        $finalSecretCheck = Join-Path $testTempDir17 ".secrets\initial_admin_password.txt"
        if (Test-Path -LiteralPath $finalSecretCheck) {
            throw "Scenario 17 Gagal: File secret parsial tidak dibersihkan saat rollback!"
        }
        $passCount++
        Write-Host "[Scenario 17 PASSED] Rollback setelah pemindahan secret berhasil membersihkan file parsial."
    } finally {
        Remove-Item -LiteralPath $testTempDir17 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 18: Rollback Safety: Pre-existing user files preserved intact
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 18/19] Memverifikasi file pengguna yang sudah ada tetap utuh selama rollback..."
    $testTempDir18 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_preserve_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir18 -Force | Out-Null
    $userFile = Join-Path $testTempDir18 "user_preexisting_data.json"
    [System.IO.File]::WriteAllText($userFile, '{"preserved": true}', [System.Text.UTF8Encoding]::new($false))
    try {
        $proc18 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`" -TargetProjectRoot `"$testTempDir18`" -TestFaultStage after-temp-env" -NoNewWindow -Wait -PassThru
        if (-not (Test-Path -LiteralPath $userFile)) {
            throw "Scenario 18 Gagal: File pengguna yang sudah ada terhapus selama proses rollback!"
        }
        $userFileContent = [System.IO.File]::ReadAllText($userFile)
        if ($userFileContent -notmatch '"preserved": true') {
            throw "Scenario 18 Gagal: Konten file pengguna yang sudah ada termodifikasi!"
        }
        $passCount++
        Write-Host "[Scenario 18 PASSED] File pengguna yang sudah ada terbukti terlindungi penuh dan tidak terhapus."
    } finally {
        Remove-Item -LiteralPath $testTempDir18 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 19: StrictMode Compatibility Check
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 19/19] Memeriksa kompatibilitas Set-StrictMode -Version Latest..."
    $testTempDir19 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_strict_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir19 -Force | Out-Null
    try {
        $proc19 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { Set-StrictMode -Version Latest; `$ErrorActionPreference = 'Stop'; & '$initScript' -TargetProjectRoot '$testTempDir19' }`"" -NoNewWindow -Wait -PassThru
        if ($proc19.ExitCode -ne 0) {
            throw "Scenario 19 Gagal: Eksekusi gagal di bawah StrictMode Latest (Exit Code: $($proc19.ExitCode))."
        }
        $passCount++
        Write-Host "[Scenario 19 PASSED] Skrip 100% kompatibel dengan Set-StrictMode -Version Latest."
    } finally {
        Remove-Item -LiteralPath $testTempDir19 -Recurse -Force -ErrorAction SilentlyContinue
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
