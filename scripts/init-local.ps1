# ==============================================================================
# StockFlow - Secure Localhost Environment Generator
# Script: scripts/init-local.ps1
# Description: Generates cryptographically secure secrets for local deployment.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 1. Resolve Project Root Directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

$envFilePath = Join-Path $projectRoot ".env"
$secretsDirPath = Join-Path $projectRoot ".secrets"
$secretPasswordFilePath = Join-Path $secretsDirPath "initial_admin_password.txt"

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

# 4. Generate High-Entropy Cryptographic Secrets
# Database credentials use pure hex (URL-safe for DATABASE_URL parsing)
$dbRootPassword = Get-CryptoRandomHex 24
$dbPassword = Get-CryptoRandomHex 24

# Session & CSRF secrets (64 hex characters = 256 bits entropy)
$sessionSecret = Get-CryptoRandomHex 32
$csrfSecret = Get-CryptoRandomHex 32

# Initial Admin Password (24 characters, NIST compliant complexity)
$initialAdminPassword = Get-CryptoRandomPassword 24

# 5. Atomic File Generation
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    # Ensure .secrets directory exists
    if (-not (Test-Path -LiteralPath $secretsDirPath)) {
        New-Item -ItemType Directory -Path $secretsDirPath -Force | Out-Null
    }

    # Write initial admin password file
    $tempSecretPath = "$secretPasswordFilePath.tmp"
    [System.IO.File]::WriteAllText($tempSecretPath, $initialAdminPassword, $utf8NoBom)
    Move-Item -LiteralPath $tempSecretPath -Destination $secretPasswordFilePath -Force

    # Restrict file permissions using Windows icacls (current user and administrators only)
    try {
        & icacls.exe "$secretPasswordFilePath" /inheritance:r /grant:r "$($env:USERNAME):(R,W)" /grant:r "*S-1-5-32-544:(R,W)" | Out-Null
    } catch {
        # Graceful notice if running in non-elevated or restricted context
    }

    # Prepare .env template
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

    # Write .env file atomically
    $tempEnvPath = "$envFilePath.tmp"
    [System.IO.File]::WriteAllText($tempEnvPath, $envContent, $utf8NoBom)
    Move-Item -LiteralPath $tempEnvPath -Destination $envFilePath -Force

} catch {
    # Cleanup on error
    if (Test-Path -LiteralPath "$secretPasswordFilePath.tmp") { Remove-Item -LiteralPath "$secretPasswordFilePath.tmp" -Force }
    if (Test-Path -LiteralPath "$envFilePath.tmp") { Remove-Item -LiteralPath "$envFilePath.tmp" -Force }
    Write-Error "Terjadi kegagalan saat membuat konfigurasi rahasia: $_"
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
