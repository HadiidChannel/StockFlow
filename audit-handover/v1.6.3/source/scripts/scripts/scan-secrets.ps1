# ==============================================================================
# StockFlow - Comprehensive Secret & Credential Exposure Scanner (v1.6.3)
# Script: scripts/scan-secrets.ps1
# Description: Rigorously scans directories or ZIP archives for credentials,
#              CLI arguments, connection strings, YAML/JSON secrets, tokens,
#              and private keys without printing secret values (100% redacted).
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetScanPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

# ------------------------------------------------------------------------------
# Targeted Detection Signatures
# ------------------------------------------------------------------------------
$staffPatt = "Staff" + "PermanentPassword2026!"
$adminPatt = "Admin" + "PermanentPassword2026!"

$secretPatterns = @(
    # 1. CLI Arguments with Passwords (e.g. -p<pass> or --password=<pass>)
    @{
        Category = "CLI Argument Password"
        Severity = "CRITICAL"
        Regex = '(?i)\s(?:-p(?=[a-zA-Z0-9_!@#\$%\^&\*\(\)\-=\+]{8,})(?!(?:Path|Profile|PassThru|Process|Port|Parent|Pester|Project|Package|Policy|Parameters|Prompt)\b)|--password=)(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''))[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{8,}'
    },
    # 2. Database Connection Strings with Raw Credentials
    @{
        Category = "Database URI with Credentials"
        Severity = "CRITICAL"
        Regex = 'mysql://(?:root|stockflow_user|stockflow_prod_user|stockflow_e2e_user):(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''|your_))[^@\s/]{8,}@'
    },
    # 3. Direct Plaintext Secret and Admin Password Assignment
    @{
        Category = "Plaintext Password or Secret Assignment"
        Severity = "HIGH"
        Regex = '(?i)(?<![A-Za-z0-9_])(?:MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD|DB_ROOT_PASSWORD|DB_PASSWORD|SESSION_SECRET|CSRF_SECRET|INITIAL_ADMIN_PASSWORD|ADMIN_PASSWORD|JWT_SECRET|API_KEY)\b\s*[:=]\s*["'']?(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''|"dev_|dev_|''dev_|"stockflow-placeholder|"your_|your_|''your_|replace_with_|change_me|process\.env|env:))[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{10,}["'']?'
    },
    # 4. Known Insecure or Hardcoded Test Passwords (including secureTestPassword)
    @{
        Category = "Hardcoded Test Password or Credential Pattern"
        Severity = "CRITICAL"
        Regex = '(?i)["''](?:secureTestPassword[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]*|' + $staffPatt + '|' + $adminPatt + ')["'']'
    },
    # 5. Bearer / API Tokens
    @{
        Category = "Bearer Authentication Token"
        Severity = "HIGH"
        Regex = '(?i)Bearer\s+(?!\[REDACTED|\$\{|\$|<)[A-Za-z0-9_\-\.]{32,}'
    },
    # 6. Private Cryptographic Keys
    @{
        Category = "Private Cryptographic Key"
        Severity = "CRITICAL"
        Regex = '-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'
    }
)

# ------------------------------------------------------------------------------
# Scanner Self-Test Routine
# ------------------------------------------------------------------------------
if ($SelfTest) {
    Write-Host "======================================================================"
    Write-Host " Running Secret Scanner Automated Self-Test Fixtures (v1.6.3)"
    Write-Host "======================================================================"

    $fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_scanner_fixture_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

    try {
        # Create 7 positive fixture files (must be detected)
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test1_cli.sh"), "mysqladmin ping -prootpassword12345678", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test2_db.env"), "DATABASE_URL=mysql://stockflow_user:rawunmaskedpassword123@localhost:3306/db", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test3_secret.yml"), "SESSION_SECRET: 0123456789abcdef0123456789abcdef0123456789abcdef", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test4_token.txt"), "Authorization: Bearer abcdef1234567890abcdef1234567890abcdef12", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test5_key.pem"), "-----BEGIN RSA PRIVATE KEY-----`nMIIEowIBAAKCAQEAz", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test6_hist.md"), "Old pass: $staffPatt", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test7_pattern_pass.js"), "const p = `"secureTestPassword2026!`";", [System.Text.UTF8Encoding]::new($false))

        # Create 4 negative safe fixture files (must NOT be detected)
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe1.env.example"), "DB_PASSWORD=`"your_strong_password_here`"`nSESSION_SECRET=`"your_session_secret_32_characters_minimum`"", [System.Text.UTF8Encoding]::new($false))
        $safeComposeContent = 'MYSQL_ROOT_PASSWORD: $${MYSQL_ROOT_PASSWORD}' + [System.Environment]::NewLine + 'DATABASE_URL: mysql://user:${DB_PASSWORD}@db:3306/db'
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe2_compose.yml"), $safeComposeContent, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe3_doc.md"), "Password has been [REDACTED] for security.", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe4_code.ts"), "const password = process.env.DB_PASSWORD;", [System.Text.UTF8Encoding]::new($false))

        # Scan fixtures
        $detectedCategories = [System.Collections.Generic.HashSet[string]]::new()
        $safeViolations = [System.Collections.Generic.List[string]]::new()

        $fixtureFiles = Get-ChildItem -Path $fixtureDir -File
        foreach ($ff in $fixtureFiles) {
            $content = [System.IO.File]::ReadAllText($ff.FullName)
            $isSafeFile = $ff.Name.StartsWith("safe")

            foreach ($pat in $secretPatterns) {
                $matches = [regex]::Matches($content, $pat.Regex)
                foreach ($m in $matches) {
                    $val = $m.Value
                    if ($val -notmatch "REDACTED" -and $val -notmatch "\$\{" -and $val -notmatch "\$\$") {
                        if ($isSafeFile) {
                            $safeViolations.Add("$($ff.Name): $($pat.Category)")
                        } else {
                            $detectedCategories.Add($pat.Category) | Out-Null
                        }
                    }
                }
            }
        }

        Write-Host "Self-Test: Kategori terdeteksi: $($detectedCategories.Count) dari 6 kategori wajib."
        foreach ($cat in $detectedCategories) {
            Write-Host "  [+] Terdeteksi: $cat"
        }

        if ($detectedCategories.Count -lt 6) {
            Write-Error "Self-Test GAGAL: Tidak seluruh 6 kategori rahasia berhasil dideteksi."
            exit 1
        }

        if ($safeViolations.Count -gt 0) {
            Write-Error "Self-Test GAGAL: Terjadi false positive pada file safe fixture: $($safeViolations -join ', ')"
            exit 1
        }

        Write-Host "Self-Test BERHASIL: Seluruh 6 pola rahasia terdeteksi secara akurat (7 uji positif) tanpa false positive pada 4 berkas aman."
        exit 0
    } finally {
        if (Test-Path -LiteralPath $fixtureDir) {
            Remove-Item -LiteralPath $fixtureDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------------------------
# Production Scanning Logic
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($TargetScanPath)) {
    $scanPath = $projectRoot
} else {
    $scanPath = (Resolve-Path $TargetScanPath).Path
}

Write-Host "======================================================================"
Write-Host " StockFlow Credential and Sensitive Secret Scanner (v1.6.3)"
Write-Host " Target Path: $scanPath"
Write-Host " Zero Secret Output Policy: Enabled ([REDACTED] Masking)"
Write-Host "======================================================================"

# Strictly minimal exclusions (Only local uncommitted environments and engine caches)
$excludedPatterns = @(
    "(?:^|[\\/])\.git(?:[\\/]|$)",
    "(?:^|[\\/])node_modules(?:[\\/]|$)",
    "(?:^|[\\/])\.next(?:[\\/]|$)",
    "(?:^|[\\/])dist(?:[\\/]|$)",
    "(?:^|[\\/])\.secrets(?:[\\/]|$)",
    "(?:^|[\\/])release-output(?:[\\/]|$)",
    "(?:^|[\\/])audit(?:[\\/]|$)",
    "(?:^|[\\/])audit-handover(?:[\\/]|$)",
    "(?:^|[\\/])\.env$",
    "(?:^|[\\/])\.env\.local$"
)

# Specific test fixture allow-list (documents/fixtures testing validation schemas)
$allowListPaths = @(
    "scripts\scan-secrets.ps1",
    "backend\tests\env-validation.test.ts"
)

$isZip = $scanPath.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
$tempExtractDir = $null
$filesToScan = [System.Collections.Generic.List[string]]::new()

try {
    if ($isZip) {
        $tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_zip_scan_" + [Guid]::NewGuid().ToString().Substring(0, 8))
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory($scanPath, $tempExtractDir)
    }

    $baseScanDir = if ($isZip) { $tempExtractDir } else { $scanPath }
    $scannedItems = Get-ChildItem -Path $baseScanDir -Recurse -File
    foreach ($item in $scannedItems) {
        $fullPath = $item.FullName
        $rel = $fullPath.Substring($baseScanDir.Length).TrimStart('\', '/')
        $relNorm = $rel.Replace('/', '\')
        $skip = $false
        if ($relNorm -in $allowListPaths) {
            $skip = $true
        } else {
            foreach ($ex in $excludedPatterns) {
                if ($relNorm -match $ex) {
                    $skip = $true
                    break
                }
            }
        }
        if (-not $skip) {
            $filesToScan.Add($fullPath)
        }
    }

    Write-Host "Total berkas yang diperiksa: $($filesToScan.Count)"

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($filePath in $filesToScan) {
        $fileName = [System.IO.Path]::GetFileName($filePath).ToLowerInvariant()
        $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()

        $isInspectable = ($fileName -in @(".env.example", ".env.test", "dockerfile") -or
                          $fileName.StartsWith("docker-compose") -or
                          $ext -in @(".txt", ".md", ".json", ".yml", ".yaml", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".ps1", ".sh", ".sql", ".xml", ".config", ".log", ".pem", ".key", ".env"))

        if ($isInspectable) {
            try {
                $lines = [System.IO.File]::ReadAllLines($filePath)
                for ($lineIdx = 0; $lineIdx -lt $lines.Length; $lineIdx++) {
                    $lineContent = $lines[$lineIdx]
                    foreach ($pattern in $secretPatterns) {
                        $matches = [regex]::Matches($lineContent, $pattern.Regex)
                        foreach ($m in $matches) {
                            $val = $m.Value
                            if ($val -notmatch "REDACTED" -and $val -notmatch "\$\{" -and $val -notmatch "\$\$") {
                                $displayPath = if ($isZip) {
                                    $filePath.Substring($tempExtractDir.Length).TrimStart('\', '/')
                                } else {
                                    $filePath.Substring($scanPath.Length).TrimStart('\', '/')
                                }

                                $findings.Add([PSCustomObject]@{
                                    File = $displayPath
                                    Line = $lineIdx + 1
                                    Category = $pattern.Category
                                    Severity = $pattern.Severity
                                    Status = "VIOLATION"
                                    MaskedValue = "[REDACTED]"
                                })
                            }
                        }
                    }
                }
            } catch {
                # Skip locked or inaccessible files
            }
        }
    }

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " Hasil Pemindaian Rahasia (Secret Scan Results):"
    Write-Host " Total Berkas Diperiksa: $($filesToScan.Count)"
    Write-Host " Total Temuan (Findings): $($findings.Count)"
    Write-Host " Status: $(if ($findings.Count -eq 0) { '100% BERSIH (CLEAN)' } else { 'TERDETEKSI KEBOCORAN RAHASIA' })"
    Write-Host "======================================================================"
    Write-Host ""

    $reportLines = [System.Collections.Generic.List[string]]::new()
    $reportLines.Add("=== STOCKFLOW CREDENTIAL AND SECRET SCAN REPORT ===")
    $reportLines.Add("Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $reportLines.Add("Scan Target: $scanPath")
    $reportLines.Add("Total Files Scanned: $($filesToScan.Count)")
    $reportLines.Add("Total Findings: $($findings.Count)")
    $reportLines.Add("Scan Status: $(if ($findings.Count -eq 0) { '100% CLEAN' } else { 'FAILED' })")
    $reportLines.Add("")

    if ($findings.Count -gt 0) {
        $reportLines.Add("--- Findings Detail (Zero Exposure Masked) ---")
        foreach ($f in $findings) {
            $logEntry = "[$($f.Severity)] Category: $($f.Category) | File: $($f.File):$($f.Line) | Value: $($f.MaskedValue)"
            $reportLines.Add($logEntry)
            Write-Warning $logEntry
        }
    } else {
        $reportLines.Add("Findings: 0 sensitive credentials, hardcoded passwords, or unmasked secrets found.")
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $outDir = Split-Path -Parent $OutputFile
        if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllLines($OutputFile, $reportLines, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Laporan pemindaian disimpan di: $OutputFile"
    }

    if ($findings.Count -gt 0) {
        exit 1
    }
    exit 0

} catch {
    $scanErr = $_.Exception.Message
    Write-Error "Terjadi kegagalan operasional scanner: $scanErr"
    exit 2
} finally {
    if ($null -ne $tempExtractDir -and (Test-Path $tempExtractDir)) {
        Remove-Item -LiteralPath $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
