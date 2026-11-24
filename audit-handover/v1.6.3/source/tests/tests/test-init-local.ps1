# ==============================================================================
# Automated Verification Test Suite for scripts/init-local.ps1 (v1.6.3)
# File: tests/test-init-local.ps1
# Description: Rigorous 19-scenario verification for local initialization,
#              cryptographic complexity, Windows ACLs, principals, inheritance,
#              existing directory ACL, and 4 real fault-injected rollbacks.
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
Write-Host " Test Execution Time: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
Write-Host " Host OS: Windows ($([System.Environment]::OSVersion.VersionString))"
Write-Host " PowerShell Version: $($PSVersionTable.PSVersion.ToString())"
Write-Host "======================================================================"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $currentUser.User.Value
$userName = $env:USERNAME

function Invoke-InitLocal([string[]]$extraArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $allArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $initScript) + $extraArgs
        $out = & powershell.exe $allArgs 2>&1 | Out-String
        return [PSCustomObject]@{
            Output = $out
            ExitCode = $LASTEXITCODE
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Test-AclCompliance([string]$path, [bool]$isDirectory = $false) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $acl = Get-Acl -LiteralPath $path
    # 1. Inheritance must be disabled (AreAccessRulesProtected must be true)
    if (-not $acl.AreAccessRulesProtected) {
        Write-Warning "ACL Compliance Failure: Inheritance is not disabled on '$path'."
        return $false
    }
    # 2. Check explicit access rules by SecurityIdentifier
    $rules = $acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])
    $allowedSids = @(
        $userSid,
        "S-1-5-18",      # Local SYSTEM
        "S-1-5-32-544"   # Built-in Administrators
    )
    $hasUser = $false
    $hasSystem = $false
    $hasAdmin = $false

    foreach ($rule in $rules) {
        $sidVal = $rule.IdentityReference.Value
        if ($sidVal -eq $userSid) { $hasUser = $true }
        if ($sidVal -eq "S-1-5-18") { $hasSystem = $true }
        if ($sidVal -eq "S-1-5-32-544") { $hasAdmin = $true }
        if ($sidVal -notin $allowedSids) {
            Write-Warning "ACL Compliance Failure: Unauthorized SID '$sidVal' found on '$path'."
            return $false
        }
    }
    return ($hasUser -and $hasSystem -and $hasAdmin)
}

$testTempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_test_init_" + [Guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null

$passCount = 0
$totalTests = 19

try {
    # --------------------------------------------------------------------------
    # Scenario 1: Fresh Initialization in Isolated Directory
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 1/19] Menjalankan inisialisasi pada direktori kosong..."
    $res1 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir)
    if ($res1.ExitCode -ne 0) {
        throw "Scenario 1 Gagal: init-local.ps1 keluar dengan kode $($res1.ExitCode). Output: $($res1.Output)"
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
    $res2 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir)
    if ($res2.ExitCode -eq 0 -or $res2.Output -notmatch "File '\.env' sudah ada") {
        throw "Scenario 2 Gagal: Seharusnya gagal ketika .env sudah ada. Exit code: $($res2.ExitCode). Output: $($res2.Output)"
    }
    $passCount++
    Write-Host "[Scenario 2 PASSED] Safety guard berhasil mencegah penimpaan file .env (Exit Code: $($res2.ExitCode))."

    # --------------------------------------------------------------------------
    # Scenario 3: Safety Guard: Rejection when secret file already exists
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 3/19] Menguji penolakan overwrite jika file secret sudah ada..."
    $testTempDir3 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_test_guard_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $testTempDir3 ".secrets") -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $testTempDir3 ".secrets\initial_admin_password.txt"), "PreExistingSecret123!", [System.Text.UTF8Encoding]::new($false))
    try {
        $res3 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir3)
        if ($res3.ExitCode -eq 0 -or $res3.Output -notmatch "sudah ada") {
            throw "Scenario 3 Gagal: Seharusnya gagal ketika file secret sudah ada. Exit code: $($res3.ExitCode). Output: $($res3.Output)"
        }
        $passCount++
        Write-Host "[Scenario 3 PASSED] Safety guard berhasil mencegah penimpaan file secret (Exit Code: $($res3.ExitCode))."
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
    if ($res1.Output -match [regex]::Escape($secretRaw)) {
        throw "Scenario 10 Gagal: Password administrator bocor pada console output!"
    }
    if ($res1.Output -match "DB_ROOT_PASSWORD" -or $res1.Output -match "SESSION_SECRET") {
        throw "Scenario 10 Gagal: Nama variabel rahasia atau nilainya tercetak pada console output!"
    }
    $passCount++
    Write-Host "[Scenario 10 PASSED] Zero credential exposure terverifikasi pada console output."

    # --------------------------------------------------------------------------
    # Scenario 11: Windows ACL on .env File (Verified via Get-Acl & Inheritance Disabled)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 11/19] Memeriksa Windows ACL & Inheritance pada file .env..."
    if (-not (Test-AclCompliance -path "$createdEnv" -isDirectory $false)) {
        throw "Scenario 11 Gagal: File .env tidak memenuhi standar proteksi ACL atau inheritance belum dinonaktifkan."
    }
    $passCount++
    Write-Host "[Scenario 11 PASSED] File .env terverifikasi memiliki inheritance dinonaktifkan dan ACL restriktif."

    # --------------------------------------------------------------------------
    # Scenario 12: Windows ACL on initial_admin_password.txt File (Verified via Get-Acl)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 12/19] Memeriksa Windows ACL & Inheritance pada initial_admin_password.txt..."
    if (-not (Test-AclCompliance -path "$createdSecret" -isDirectory $false)) {
        throw "Scenario 12 Gagal: File secret tidak memenuhi standar proteksi ACL atau inheritance belum dinonaktifkan."
    }
    $passCount++
    Write-Host "[Scenario 12 PASSED] File initial_admin_password.txt terverifikasi memiliki inheritance dinonaktifkan dan ACL restriktif."

    # --------------------------------------------------------------------------
    # Scenario 13: Windows ACL on Newly Created .secrets Directory (Verified via Get-Acl)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 13/19] Memeriksa Windows ACL pada direktori .secrets..."
    $secretsDir13 = Join-Path $testTempDir ".secrets"
    if (-not (Test-AclCompliance -path "$secretsDir13" -isDirectory $true)) {
        throw "Scenario 13 Gagal: Direktori .secrets tidak memenuhi standar proteksi ACL atau inheritance belum dinonaktifkan."
    }
    $passCount++
    Write-Host "[Scenario 13 PASSED] Direktori .secrets terverifikasi memiliki inheritance dinonaktifkan dan ACL restriktif."

    # --------------------------------------------------------------------------
    # Scenario 14: Existing .secrets Directory Receives ACL Unconditionally
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 14/19] Menguji penerapan ACL pada direktori .secrets yang sudah ada sebelumnya..."
    $testTempDir14 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_existdir_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    $existSecretsDir = Join-Path $testTempDir14 ".secrets"
    New-Item -ItemType Directory -Path $existSecretsDir -Force | Out-Null
    try {
        $res14 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir14)
        if ($res14.ExitCode -ne 0) {
            throw "Scenario 14 Gagal: Eksekusi gagal pada direktori dengan .secrets yang sudah ada (Exit Code: $($res14.ExitCode)). Output: $($res14.Output)"
        }
        if (-not (Test-AclCompliance -path "$existSecretsDir" -isDirectory $true)) {
            throw "Scenario 14 Gagal: Direktori .secrets yang sudah ada tidak menerima ACL baru dengan inheritance dinonaktifkan."
        }
        $passCount++
        Write-Host "[Scenario 14 PASSED] Direktori .secrets pre-existing berhasil menerima proteksi ACL secara mutlak."
    } finally {
        Remove-Item -LiteralPath $testTempDir14 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 15: Real Rollback: Fault Injection 1 (after-temp-secret)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 15/19] Menguji rollback nyata: fault injection 1 (after-temp-secret)..."
    $testTempDir15 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_sec_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir15 -Force | Out-Null
    try {
        $res15 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir15, "-TestFaultStage", "after-temp-secret")
        if ($res15.ExitCode -eq 0) {
            throw "Scenario 15 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        if ($res15.Output -notmatch "after-temp-secret") {
            throw "Scenario 15 Gagal: Output error tidak memuat tahapan fault injection after-temp-secret. Output: $($res15.Output)"
        }
        $tempSecretCheck = Join-Path $testTempDir15 ".secrets\initial_admin_password.txt.tmp"
        if (Test-Path -LiteralPath $tempSecretCheck) {
            throw "Scenario 15 Gagal: File .tmp secret masih tertinggal setelah rollback!"
        }
        $finalSecretCheck15 = Join-Path $testTempDir15 ".secrets\initial_admin_password.txt"
        if (Test-Path -LiteralPath $finalSecretCheck15) {
            throw "Scenario 15 Gagal: File secret final ditemukan padahal seharusnya di-rollback!"
        }
        $passCount++
        Write-Host "[Scenario 15 PASSED] Fault injection after-temp-secret terverifikasi: exit code non-zero ($($res15.ExitCode)), pesan cocok, dan 0 artefak tersisa."
    } finally {
        Remove-Item -LiteralPath $testTempDir15 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 16: Real Rollback: Fault Injection 2 (after-temp-env)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 16/19] Menguji rollback nyata: fault injection 2 (after-temp-env)..."
    $testTempDir16 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_env_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir16 -Force | Out-Null
    try {
        $res16 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir16, "-TestFaultStage", "after-temp-env")
        if ($res16.ExitCode -eq 0) {
            throw "Scenario 16 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        if ($res16.Output -notmatch "after-temp-env") {
            throw "Scenario 16 Gagal: Output error tidak memuat tahapan fault injection after-temp-env. Output: $($res16.Output)"
        }
        $tempEnvCheck = Join-Path $testTempDir16 ".env.tmp"
        $tempSecretCheck16 = Join-Path $testTempDir16 ".secrets\initial_admin_password.txt.tmp"
        if ((Test-Path -LiteralPath $tempEnvCheck) -or (Test-Path -LiteralPath $tempSecretCheck16)) {
            throw "Scenario 16 Gagal: File .tmp masih tertinggal setelah rollback!"
        }
        $passCount++
        Write-Host "[Scenario 16 PASSED] Fault injection after-temp-env terverifikasi: exit code non-zero ($($res16.ExitCode)), pesan cocok, dan seluruh file staging bersih."
    } finally {
        Remove-Item -LiteralPath $testTempDir16 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 17: Real Rollback: Fault Injection 3 (after-move-secret)
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 17/19] Menguji rollback nyata: fault injection 3 (after-move-secret)..."
    $testTempDir17 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_movsec_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir17 -Force | Out-Null
    try {
        $res17 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir17, "-TestFaultStage", "after-move-secret")
        if ($res17.ExitCode -eq 0) {
            throw "Scenario 17 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        if ($res17.Output -notmatch "after-move-secret") {
            throw "Scenario 17 Gagal: Output error tidak memuat tahapan fault injection after-move-secret. Output: $($res17.Output)"
        }
        $movedSecretCheck17 = Join-Path $testTempDir17 ".secrets\initial_admin_password.txt"
        $tempEnvCheck17 = Join-Path $testTempDir17 ".env.tmp"
        if (Test-Path -LiteralPath $movedSecretCheck17) {
            throw "Scenario 17 Gagal: File secret yang sudah dipindahkan tidak dibersihkan saat rollback!"
        }
        if (Test-Path -LiteralPath $tempEnvCheck17) {
            throw "Scenario 17 Gagal: File .env.tmp masih tertinggal setelah rollback!"
        }
        $passCount++
        Write-Host "[Scenario 17 PASSED] Fault injection after-move-secret terverifikasi: exit code non-zero ($($res17.ExitCode)), pesan cocok, dan file dipindahkan berhasil di-rollback."
    } finally {
        Remove-Item -LiteralPath $testTempDir17 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --------------------------------------------------------------------------
    # Scenario 18: Real Rollback: Fault Injection 4 (after-move-env) & User File Protection
    # --------------------------------------------------------------------------
    Write-Host "[Scenario 18/19] Menguji rollback nyata: fault injection 4 (after-move-env) dan proteksi file user..."
    $testTempDir18 = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_rb_movenv_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $testTempDir18 -Force | Out-Null
    $userPreexistingFile = Join-Path $testTempDir18 "user_preexisting_data.json"
    [System.IO.File]::WriteAllText($userPreexistingFile, '{"preserved": true}', [System.Text.UTF8Encoding]::new($false))

    try {
        $res18 = Invoke-InitLocal @("-TargetProjectRoot", $testTempDir18, "-TestFaultStage", "after-move-env")
        if ($res18.ExitCode -eq 0) {
            throw "Scenario 18 Gagal: Injeksi kegagalan seharusnya menghasilkan exit code non-zero."
        }
        if ($res18.Output -notmatch "after-move-env") {
            throw "Scenario 18 Gagal: Output error tidak memuat tahapan fault injection after-move-env. Output: $($res18.Output)"
        }
        # Final .env and secret must be deleted
        $finalEnv18 = Join-Path $testTempDir18 ".env"
        $finalSec18 = Join-Path $testTempDir18 ".secrets\initial_admin_password.txt"
        if (Test-Path -LiteralPath $finalEnv18) {
            throw "Scenario 18 Gagal: File .env tidak dibersihkan saat rollback after-move-env!"
        }
        if (Test-Path -LiteralPath $finalSec18) {
            throw "Scenario 18 Gagal: File secret tidak dibersihkan saat rollback after-move-env!"
        }
        # Pre-existing user file must remain intact
        if (-not (Test-Path -LiteralPath $userPreexistingFile)) {
            throw "Scenario 18 Gagal: File pengguna yang sudah ada terhapus selama proses rollback!"
        }
        $userFileContent = [System.IO.File]::ReadAllText($userPreexistingFile)
        if ($userFileContent -notmatch '"preserved": true') {
            throw "Scenario 18 Gagal: Konten file pengguna yang sudah ada termodifikasi!"
        }
        $passCount++
        Write-Host "[Scenario 18 PASSED] Fault injection after-move-env terverifikasi: exit code non-zero ($($res18.ExitCode)), artefak dibersihkan, dan file pengguna tetap utuh."
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
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $out19 = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { Set-StrictMode -Version Latest; `$ErrorActionPreference = 'Stop'; & '$initScript' -TargetProjectRoot '$testTempDir19' }" 2>&1 | Out-String
        $exit19 = $LASTEXITCODE
        $ErrorActionPreference = $prevEap

        if ($exit19 -ne 0) {
            throw "Scenario 19 Gagal: Eksekusi gagal di bawah StrictMode Latest (Exit Code: $exit19). Output: $out19"
        }
        $passCount++
        Write-Host "[Scenario 19 PASSED] Skrip 100% kompatibel dengan Set-StrictMode -Version Latest (Exit Code: 0)."
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
