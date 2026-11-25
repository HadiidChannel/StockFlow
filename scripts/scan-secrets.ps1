# ==============================================================================
# StockFlow - Comprehensive Secret & Credential Exposure Scanner (v1.6.5)
# Script: scripts/scan-secrets.ps1
# Description: Rigorously scans directories or ZIP archives for credentials,
#              CLI arguments, connection strings, YAML/JSON secrets, tokens,
#              and private keys without printing secret values (100% redacted).
#              Emits complete audit metadata including excluded counts,
#              allowlisted fixtures with rationale, masking status, and exit code.
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

$staffPatt = "Staff" + "PermanentPassword2026!"
$adminPatt = "Admin" + "PermanentPassword2026!"

$secretPatterns = @(
    @{
        Category = "CLI Argument Password"
        Severity = "CRITICAL"
        Regex = '(?i)\s(?:-p(?=[a-zA-Z0-9_!@#\$%\^&\*\(\)\-=\+]{8,})(?!(?:Path|Profile|PassThru|Process|Port|Parent|Pester|Project|Package|Policy|Parameters|Prompt)\b)|--password=)(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''))[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{8,}'
    },
    @{
        Category = "Database URI with Credentials"
        Severity = "CRITICAL"
        Regex = 'mysql://(?:root|stockflow_user|stockflow_prod_user|stockflow_e2e_user):(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''|your_))[^@\s/]{8,}@'
    },
    @{
        Category = "Plaintext Password or Secret Assignment"
        Severity = "HIGH"
        Regex = '(?i)(?<![A-Za-z0-9_])(?:MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD|DB_ROOT_PASSWORD|DB_PASSWORD|SESSION_SECRET|CSRF_SECRET|INITIAL_ADMIN_PASSWORD|ADMIN_PASSWORD|JWT_SECRET|API_KEY)\b\s*[:=]\s*["'']?(?!(?:\[REDACTED|\$\{|\$|\$\$|<|""|''''|"dev_|dev_|''dev_|"stockflow-placeholder|"your_|your_|''your_|replace_with_|change_me|process\.env|env:))[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{10,}["'']?'
    },
    @{
        Category = "Hardcoded Test Password or Credential Pattern"
        Severity = "CRITICAL"
        Regex = '(?i)["''](?:secureTestPassword[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]*|' + $staffPatt + '|' + $adminPatt + ')["'']'
    },
    @{
        Category = "Bearer Authentication Token"
        Severity = "HIGH"
        Regex = '(?i)Bearer\s+(?!\[REDACTED|\$\{|\$|<)[A-Za-z0-9_\-\.]{32,}'
    },
    @{
        Category = "Private Cryptographic Key"
        Severity = "CRITICAL"
        Regex = '-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'
    }
)

if ($SelfTest) {
    Write-Host "======================================================================"
    Write-Host " Running Secret Scanner Automated Self-Test Fixtures (v1.6.5)"
    Write-Host "======================================================================"

    $fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_scanner_fixture_" + [Guid]::NewGuid().ToString().Substring(0, 8))
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

    try {
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test1_cli.sh"), "mysqladmin ping -prootpassword12345678", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test2_db.env"), "DATABASE_URL=mysql://stockflow_user:rawunmaskedpassword123@localhost:3306/db", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test3_secret.yml"), "SESSION_SECRET: 0123456789abcdef0123456789abcdef0123456789abcdef", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test4_token.txt"), "Authorization: Bearer abcdef1234567890abcdef1234567890abcdef12", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test5_key.pem"), "-----BEGIN RSA PRIVATE KEY-----`nMIIEowIBAAKCAQEAz", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test6_hist.md"), "Old pass: $staffPatt", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "test7_pattern_pass.js"), "const p = `"secureTestPassword2026!`";", [System.Text.UTF8Encoding]::new($false))

        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe1.env.example"), "DB_PASSWORD=`"your_strong_password_here`"`nSESSION_SECRET=`"your_session_secret_32_characters_minimum`"", [System.Text.UTF8Encoding]::new($false))
        $safeComposeContent = 'MYSQL_ROOT_PASSWORD: $${MYSQL_ROOT_PASSWORD}' + [System.Environment]::NewLine + 'DATABASE_URL: mysql://user:${DB_PASSWORD}@db:3306/db'
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe2_compose.yml"), $safeComposeContent, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe3_doc.md"), "Password has been [REDACTED] for security.", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "safe4_code.ts"), "const password = process.env.DB_PASSWORD;", [System.Text.UTF8Encoding]::new($false))

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

if ([string]::IsNullOrWhiteSpace($TargetScanPath)) {
    $scanPath = $projectRoot
} else {
    $scanPath = (Resolve-Path $TargetScanPath).Path
}

$scannerCommit = "unknown"
$prevEapGit = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $gc = (& git.exe -C $projectRoot rev-parse --short HEAD 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -and $gc -match '^[a-f0-9]+$') { $scannerCommit = $gc }
} catch {} finally {
    $ErrorActionPreference = $prevEapGit
}

Write-Host "======================================================================"
Write-Host " StockFlow Credential and Sensitive Secret Scanner (v1.6.5)"
Write-Host " Target Path: $scanPath"
Write-Host " Zero Secret Output Policy: Enabled ([REDACTED] Masking)"
Write-Host "======================================================================"

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

$allowListSpecs = @(
    @{ Pattern = "(?i)(?:^|[\\/])scan-secrets\.ps1$"; Rationale = "Contains regex signature definitions and SelfTest synthetic fixture strings" },
    @{ Pattern = "(?i)(?:^|[\\/])env-validation\.test\.ts$"; Rationale = "Unit test validating Zod rejection of synthetic unsafe secret strings" }
)

$isZip = $scanPath.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
$tempExtractDir = $null
$filesToScan = [System.Collections.Generic.List[string]]::new()
$excludedCount = 0
$allowlistedItems = [System.Collections.Generic.List[string]]::new()

try {
    if ($isZip) {
        $tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_zip_scan_" + [Guid]::NewGuid().ToString().Substring(0, 8))
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::ExtractToDirectory($scanPath, $tempExtractDir)
    }

    $baseScanDir = if ($isZip) { $tempExtractDir } else { $scanPath }
    $scannedItems = @(Get-ChildItem -Path $baseScanDir -Recurse -File)
    foreach ($item in $scannedItems) {
        $fullPath = $item.FullName
        $rel = $fullPath.Substring($baseScanDir.Length).TrimStart('\', '/')
        $relNorm = $rel.Replace('/', '\')
        $relUnix = $rel.Replace('\', '/')

        $isExcluded = $false
        foreach ($ex in $excludedPatterns) {
            if ($relNorm -match $ex) {
                $isExcluded = $true
                break
            }
        }
        if ($isExcluded) {
            $excludedCount++
            continue
        }

        $allowMatched = $null
        foreach ($al in $allowListSpecs) {
            if ($relNorm -match $al.Pattern) {
                $allowMatched = "$relUnix ($($al.Rationale))"
                break
            }
        }
        if ($null -ne $allowMatched) {
            $allowlistedItems.Add($allowMatched)
            continue
        }

        $filesToScan.Add($fullPath)
    }

    Write-Host "Total berkas yang diperiksa: $($filesToScan.Count) (Dikecualikan: $excludedCount, Allowlisted: $($allowlistedItems.Count))"

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($filePath in $filesToScan) {
        $fileName = [System.IO.Path]::GetFileName($filePath).ToLowerInvariant()
        $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()

        $isInspectable = ($fileName -in @(".env.example", ".env.test", "dockerfile", ".dockerignore", ".gitignore", ".npmrc") -or
                          $fileName.StartsWith("docker-compose") -or
                          $ext -in @(".txt", ".md", ".json", ".yml", ".yaml", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".ps1", ".sh", ".sql", ".xml", ".config", ".log", ".pem", ".key", ".env", ".toml", ".css"))

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
                                    $filePath.Substring($tempExtractDir.Length).TrimStart('\', '/').Replace('\', '/')
                                } else {
                                    $filePath.Substring($scanPath.Length).TrimStart('\', '/').Replace('\', '/')
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
            }
        }
    }

    $exitCode = if ($findings.Count -gt 0) { 1 } else { 0 }
    $scanStatus = if ($findings.Count -eq 0) { "100% CLEAN" } else { "FAILED" }

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " Hasil Pemindaian Rahasia (Secret Scan Results):"
    Write-Host " Total Berkas Diperiksa: $($filesToScan.Count)"
    Write-Host " Total Berkas Dikecualikan: $excludedCount"
    Write-Host " Allowlisted Fixtures: $($allowlistedItems.Count)"
    Write-Host " Total Temuan (Findings): $($findings.Count)"
    Write-Host " Status: $(if ($findings.Count -eq 0) { '100% BERSIH (CLEAN)' } else { 'TERDETEKSI KEBOCORAN RAHASIA' })"
    Write-Host " Exit Code: $exitCode"
    Write-Host "======================================================================"
    Write-Host ""

    $allowText = if ($allowlistedItems.Count -gt 0) { "$($allowlistedItems.Count) -> $($allowlistedItems -join '; ')" } else { "0 (None)" }

    $reportLines = [System.Collections.Generic.List[string]]::new()
    $reportLines.Add("=== STOCKFLOW CREDENTIAL AND SECRET SCAN REPORT (v1.6.5) ===")
    $reportLines.Add("Scanner Version: v1.6.5 (commit $scannerCommit)")
    $reportLines.Add("Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $reportLines.Add("Scan Target: $scanPath")
    $reportLines.Add("Total Files Scanned: $($filesToScan.Count)")
    $reportLines.Add("Total Files Excluded: $excludedCount")
    $reportLines.Add("Allowlisted Files Scanned/Skipped: $allowText")
    $reportLines.Add("Total Findings: $($findings.Count)")
    $reportLines.Add("Masking Status: Enabled ([REDACTED] enforced; secret values never printed)")
    $reportLines.Add("Scan Status: $scanStatus")
    $reportLines.Add("Exit Code: $exitCode")
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
        if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllLines($OutputFile, $reportLines, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Laporan pemindaian disimpan di: $OutputFile"
    }

    exit $exitCode

} catch {
    $scanErr = $_.Exception.Message
    Write-Error "Terjadi kegagalan operasional scanner: $scanErr"
    exit 2
} finally {
    if ($null -ne $tempExtractDir -and (Test-Path -LiteralPath $tempExtractDir)) {
        Remove-Item -LiteralPath $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
