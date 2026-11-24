# ==============================================================================
# StockFlow - Secure Localhost Environment Generator
# Script: scripts/init-local.ps1
# Description: Generates cryptographically secure secrets for local deployment.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetProjectRoot,

    [Parameter(Mandatory = $false)]
    [ValidateSet("none", "after-temp-secret", "after-temp-env", "after-move-secret", "after-move-env")]
    [string]$TestFaultStage = "none"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 1. Resolve Project Root Directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($TargetProjectRoot)) {
    $projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $projectRoot = (Resolve-Path $TargetProjectRoot).Path
}

$envFilePath = Join-Path $projectRoot ".env"
$secretsDirPath = Join-Path $projectRoot ".secrets"
$secretPasswordFilePath = Join-Path $secretsDirPath "initial_admin_password.txt"
$tempSecretPath = Join-Path $secretsDirPath "initial_admin_password.txt.tmp"
$tempEnvPath = Join-Path $projectRoot ".env.tmp"

# 2. Safety Guards: Do not overwrite existing configuration
if (Test-Path -LiteralPath $envFilePath) {
    Write-Error "Inisialisasi dibatalkan: File '.env' sudah ada di '$envFilePath'. Skrip ini tidak menimpa konfigurasi yang sudah ada secara otomatis. Gunakan prosedur rotasi kredensial jika ingin memperbarui secret."
    exit 1
}

if (Test-Path -LiteralPath $secretPasswordFilePath) {
    Write-Error "Inisialisasi dibatalkan: File '$secretPasswordFilePath' sudah ada. Skrip ini tidak menimpa kredensial yang sudah ada secara otomatis."
    exit 1
}

# 3. Cryptographically Secure Helper Functions (.NET Cryptography)
function Get-CryptoRandomHex([int]$byteCount) {
    $bytes = [byte[]]::new($byteCount)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
        $hex = -join ($bytes | ForEach-Object { $_.ToString("x2") })
        return $hex
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
            $idx = $uintVal % $pool.Length
            return $pool[$idx]
        }

        # Ensure complexity: at least 2 uppercase, 2 lowercase, 2 digits, 2 symbols
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

        # Fisher-Yates Cryptographic Shuffle
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

function Set-SecureAcl([string]$targetPath, [bool]$isDirectory = $false) {
    if (-not (Test-Path -LiteralPath $targetPath)) {
        throw "Target path '$targetPath' tidak ditemukan saat konfigurasi ACL."
    }
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userSid = $currentUser.User.Value
    $systemSid = "S-1-5-18"
    $adminSid = "S-1-5-32-544"

    if ($isDirectory) {
        & icacls.exe "$targetPath" /inheritance:r /grant:r "*${userSid}:(OI)(CI)(M)" /grant:r "*${systemSid}:(OI)(CI)(M)" /grant:r "*${adminSid}:(OI)(CI)(M)" | Out-Null
    } else {
        & icacls.exe "$targetPath" /inheritance:r /grant:r "*${userSid}:(M)" /grant:r "*${systemSid}:(M)" /grant:r "*${adminSid}:(M)" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Gagal menerapkan Windows ACL pada '$targetPath'. Exit code: $LASTEXITCODE"
    }
}

# 4. Generate High-Entropy Cryptographic Secrets
$dbRootPassword = Get-CryptoRandomHex 24
$dbPassword = Get-CryptoRandomHex 24
$sessionSecret = Get-CryptoRandomHex 32
$csrfSecret = Get-CryptoRandomHex 32
$initialAdminPassword = Get-CryptoRandomPassword 24

# 5. Staged Generation and Atomic Replacement with Rollback
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$createdSecretsDir = $false
$createdTempSecret = $false
$createdSecretFile = $false
$createdTempEnv = $false
$createdEnvFile = $false

try {
    # 5a. Ensure .secrets directory exists and has restricted ACL unconditionally
    if (-not (Test-Path -LiteralPath $secretsDirPath)) {
        New-Item -ItemType Directory -Path $secretsDirPath -Force | Out-Null
        $createdSecretsDir = $true
    }
    Set-SecureAcl -targetPath $secretsDirPath -isDirectory $true

    # 5b. Staged secret file generation
    [System.IO.File]::WriteAllText($tempSecretPath, $initialAdminPassword, $utf8NoBom)
    $createdTempSecret = $true
    Set-SecureAcl -targetPath $tempSecretPath -isDirectory $false

    if ($TestFaultStage -eq "after-temp-secret") {
        throw "Simulated fault injection: after-temp-secret"
    }

    # 5c. Staged .env generation
    $envContent = @"
# Database Configuration
DB_ROOT_PASSWORD=$dbRootPassword
DB_USER=stockflow_user
DB_PASSWORD=$dbPassword
DATABASE_URL="mysql://stockflow_user:$dbPassword@localhost:3306/stockflow_db"

# Server Configuration
PORT=4000
NODE_ENV=production
APP_DEPLOYMENT_MODE=local
FRONTEND_URL="http://localhost:3000"
COOKIE_DOMAIN=""
COOKIE_SECURE="false"
COOKIE_SAME_SITE="lax"
SESSION_SECRET="$sessionSecret"
CSRF_SECRET="$csrfSecret"
LOG_LEVEL="info"

# Frontend Ingress & Reverse Proxy
NEXT_PUBLIC_API_URL="/api/v1"

# Administrator Bootstrap
INITIAL_ADMIN_EMAIL=admin@stockflow.com
INITIAL_ADMIN_NAME="System Administrator"
INITIAL_ORG_NAME="PT StockFlow Logistik Nusantara"
"@

    [System.IO.File]::WriteAllText($tempEnvPath, $envContent, $utf8NoBom)
    $createdTempEnv = $true
    Set-SecureAcl -targetPath $tempEnvPath -isDirectory $false

    if ($TestFaultStage -eq "after-temp-env") {
        throw "Simulated fault injection: after-temp-env"
    }

    # 5d. Atomic replacement to final destinations (guarding against race conditions)
    if (Test-Path -LiteralPath $secretPasswordFilePath) {
        throw "Target secret file '$secretPasswordFilePath' sudah dibuat oleh proses lain."
    }
    Move-Item -LiteralPath $tempSecretPath -Destination $secretPasswordFilePath
    $createdSecretFile = $true
    $createdTempSecret = $false
    Set-SecureAcl -targetPath $secretPasswordFilePath -isDirectory $false

    if ($TestFaultStage -eq "after-move-secret") {
        throw "Simulated fault injection: after-move-secret"
    }

    if (Test-Path -LiteralPath $envFilePath) {
        throw "Target env file '$envFilePath' sudah dibuat oleh proses lain."
    }
    Move-Item -LiteralPath $tempEnvPath -Destination $envFilePath
    $createdEnvFile = $true
    $createdTempEnv = $false
    Set-SecureAcl -targetPath $envFilePath -isDirectory $false

    if ($TestFaultStage -eq "after-move-env") {
        throw "Simulated fault injection: after-move-env"
    }

} catch {
    # 5e. Strict Rollback on Any Failure
    $errorMessage = $_.Exception.Message
    Write-Warning "Terjadi kegagalan saat inisialisasi lingkungan lokal: $errorMessage. Memulai rollback..."

    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userSid = $currentUser.User.Value

    function Remove-SafeRollbackFile([string]$targetFile) {
        if (Test-Path -LiteralPath $targetFile) {
            & icacls.exe "$targetFile" /grant:r "*${userSid}:(M)" 2>$null | Out-Null
            Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
        }
    }

    if ($createdTempSecret -or (Test-Path -LiteralPath $tempSecretPath)) {
        Remove-SafeRollbackFile $tempSecretPath
    }
    if ($createdSecretFile -and (Test-Path -LiteralPath $secretPasswordFilePath)) {
        Remove-SafeRollbackFile $secretPasswordFilePath
    }
    if ($createdTempEnv -or (Test-Path -LiteralPath $tempEnvPath)) {
        Remove-SafeRollbackFile $tempEnvPath
    }
    if ($createdEnvFile -and (Test-Path -LiteralPath $envFilePath)) {
        Remove-SafeRollbackFile $envFilePath
    }
    if ($createdSecretsDir -and (Test-Path -LiteralPath $secretsDirPath)) {
        $remaining = @(Get-ChildItem -LiteralPath $secretsDirPath -Force -ErrorAction SilentlyContinue)
        if ($null -eq $remaining -or $remaining.Length -eq 0) {
            Remove-Item -LiteralPath $secretsDirPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Error "Inisialisasi lingkungan lokal dibatalkan dan seluruh artefak parsial berhasil di-rollback: $errorMessage"
    exit 1
}

# 6. Success Output (Zero Credential Exposure)
Write-Host ""
Write-Host "StockFlow local environment initialization completed."
Write-Host ""
Write-Host "Generated files:"
Write-Host "- .env"
Write-Host "- .secrets/initial_admin_password.txt"
Write-Host ""
Write-Host "Secret values: REDACTED."
Write-Host ""
Write-Host "Next step:"
Write-Host "Run the documented Docker initialization procedure."
Write-Host ""
