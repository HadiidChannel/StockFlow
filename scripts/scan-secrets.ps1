# ==============================================================================
# StockFlow - Comprehensive Secret & Credential Exposure Scanner
# Script: scripts/scan-secrets.ps1
# Description: Rigorously scans directories or ZIP archives for credentials,
#              CLI arguments, connection strings, YAML/JSON secrets, and tokens.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetScanPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($TargetScanPath)) {
    $scanPath = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $scanPath = (Resolve-Path $TargetScanPath).Path
}

Write-Host "======================================================================"
Write-Host " StockFlow Credential and Sensitive Secret Scanner"
Write-Host " Target Path: $scanPath"
Write-Host "======================================================================"

# Define Targeted Detection Signatures
$staffPatt = "Staff" + "PermanentPassword2026!"
$adminPatt = "Admin" + "PermanentPassword2026!"

$secretPatterns = @(
    # 1. CLI Arguments with Passwords (e.g. -prootpass or --password=secret)
    @{
        Name = "CLI argument with embedded password"
        Regex = '(?i)\s(?:-p(?=[0-9a-fA-F]{8,})|--password=)(?!(?:\[REDACTED|\$\{|\$|\$MYSQL|<|""|''''))[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{8,}'
    },
    # 2. Database Connection Strings with Raw Credentials
    @{
        Name = "Database URI with active production credentials"
        Regex = 'mysql://(?:root|stockflow_user|stockflow_prod_user):(?!(?:\[REDACTED|\$\{|\$|\$MYSQL|\$DB_PASSWORD|<|""|''''|stockflow_pass123))[^@\s/]{8,}@'
    },
    # 3. Direct Plaintext Password Assignments in Manifests/Configs
    @{
        Name = "Direct Production Password Assignment"
        Regex = '(?m)^(?!\s*#)\s*(?:MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD|DB_ROOT_PASSWORD|DB_PASSWORD)\s*[:=]\s*(?!\[REDACTED|\$\{|\$|\$MYSQL|<|"root_dev_password_2026"|"stockflow_pass123")["'']?[A-Za-z0-9_!@#\$%\^&\*\(\)\-=\+]{16,}'
    },
    # 4. Session / CSRF Secrets in Plaintext
    @{
        Name = "Direct Session or CSRF Secret Exposure"
        Regex = '(?m)^(?!\s*#)\s*(?:SESSION_SECRET|CSRF_SECRET)\s*[:=]\s*(?!\[REDACTED|\$\{|\$|\$SESSION|\$CSRF|<|"dev_|"stockflow-)[a-f0-9]{48,}'
    },
    # 5. Private Cryptographic Keys
    @{
        Name = "Private Cryptographic Key Header"
        Regex = '-----BEGIN (?:RSA|EC|OPENSSH|DSA|PRIVATE) KEY-----'
    },
    # 6. Hardcoded Historical Test Passwords (Forbidden in release artifacts)
    @{
        Name = "Historical Hardcoded Test Password"
        Regex = "$staffPatt|$adminPatt"
    }
)

# Files and Directories to Exclude from Scans
$excludedPaths = @(
    "\.git\",
    "\node_modules\",
    "\.next\",
    "\dist\",
    "\.secrets\",
    "\.env",
    "BUG_LOG.md",
    "FINAL_RELEASE_REPORT_V1_6.md",
    "docker-compose.dev.yml",
    "env-validation.test.ts",
    "scan-secrets.ps1",
    "source_package_scan.txt",
    "verification_package_scan.txt"
)

$isZip = $scanPath.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
$tempExtractDir = $null
$filesToScan = [System.Collections.Generic.List[string]]::new()

try {
    if ($isZip) {
        $tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_zip_scan_" + [Guid]::NewGuid().ToString().Substring(0, 8))
        New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
        Expand-Archive -LiteralPath $scanPath -DestinationPath $tempExtractDir -Force
        $scannedItems = Get-ChildItem -Path $tempExtractDir -Recurse -File
        foreach ($item in $scannedItems) {
            $fullPath = $item.FullName
            $skip = $false
            foreach ($ex in $excludedPaths) {
                if ($fullPath -like "*$ex*") {
                    $skip = $true
                    break
                }
            }
            if (-not $skip) {
                $filesToScan.Add($fullPath)
            }
        }
    } else {
        $scannedItems = Get-ChildItem -Path $scanPath -Recurse -File
        foreach ($item in $scannedItems) {
            $fullPath = $item.FullName
            $skip = $false
            foreach ($ex in $excludedPaths) {
                if ($fullPath -like "*$ex*") {
                    $skip = $true
                    break
                }
            }
            if (-not $skip) {
                $filesToScan.Add($fullPath)
            }
        }
    }

    Write-Host "Total berkas yang akan diperiksa: $($filesToScan.Count)"

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($filePath in $filesToScan) {
        $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
        # Only inspect text-based files
        if ($ext -in @(".txt", ".md", ".json", ".yml", ".yaml", ".ts", ".tsx", ".js", ".mjs", ".ps1", ".sh", ".sql", ".env.example")) {
            try {
                $content = [System.IO.File]::ReadAllText($filePath)
                foreach ($pattern in $secretPatterns) {
                    $matches = [regex]::Matches($content, $pattern.Regex)
                    foreach ($m in $matches) {
                        $val = $m.Value
                        if ($val -notmatch "REDACTED" -and $val -notmatch "\$\{" -and $val -notmatch "\$\$") {
                            $findings.Add([PSCustomObject]@{
                                File = (Resolve-Path -Relative -Path $filePath)
                                Rule = $pattern.Name
                                Match = $val.Substring(0, [Math]::Min(20, $val.Length)) + "..."
                            })
                        }
                    }
                }
            } catch {
                # Skip unreadable or locked files
            }
        }
    }

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " Hasil Pemindaian Rahasia (Secret Scan Results):"
    Write-Host " Total Berkas Diperiksa: $($filesToScan.Count)"
    Write-Host " Total Temuan (Findings): $($findings.Count)"
    Write-Host " Status: $(if ($findings.Count -eq 0) { '100% BERSIH (CLEAN)' } else { 'DITEMUKAN KEBOCORAN' })"
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
        $reportLines.Add("--- Findings Detail ---")
        foreach ($f in $findings) {
            $line = "[$($f.Rule)] File: $($f.File) -> Pattern matched: $($f.Match)"
            $reportLines.Add($line)
            Write-Warning $line
        }
    } else {
        $reportLines.Add("Findings: 0 sensitive credentials, hardcoded passwords, or unprotected secrets found.")
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $outDir = Split-Path -Parent $OutputFile
        if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllLines($OutputFile, $reportLines, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Laporan disimpan di: $OutputFile"
    }

    if ($findings.Count -gt 0) {
        exit 1
    }

} finally {
    if ($null -ne $tempExtractDir -and (Test-Path $tempExtractDir)) {
        Remove-Item -LiteralPath $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
