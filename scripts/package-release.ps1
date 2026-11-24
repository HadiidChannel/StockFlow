# ==============================================================================
# StockFlow - Official Release Packaging & Verification Script (v1.6.1)
# Script: scripts/package-release.ps1
# Description: Generates clean StockFlow_Final_v8_1.zip and
#              StockFlow_Final_Verification_v8_1.zip with strict artifact exclusions.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

$sourceZipName = "StockFlow_Final_v8_1.zip"
$verificationZipName = "StockFlow_Final_Verification_v8_1.zip"

$sourceZipPath = Join-Path $projectRoot $sourceZipName
$verificationZipPath = Join-Path $projectRoot $verificationZipName

Write-Host "======================================================================"
Write-Host " Packaging StockFlow v1.6.1 Official Release Artifacts"
Write-Host " Target Project Root: $projectRoot"
Write-Host "======================================================================"

# Clean existing zip packages if present
if (Test-Path -LiteralPath $sourceZipPath) { Remove-Item -LiteralPath $sourceZipPath -Force }
if (Test-Path -LiteralPath $verificationZipPath) { Remove-Item -LiteralPath $verificationZipPath -Force }

$tempStageDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_stage_" + [Guid]::NewGuid().ToString().Substring(0, 8))
$tempVerifyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_verify_stage_" + [Guid]::NewGuid().ToString().Substring(0, 8))

try {
    # --------------------------------------------------------------------------
    # 1. Package Clean Source Code (StockFlow_Final_v8_1.zip)
    # --------------------------------------------------------------------------
    Write-Host "[1/4] Menyiapkan berkas source code untuk $sourceZipName..."
    New-Item -ItemType Directory -Path $tempStageDir -Force | Out-Null

    $excludePatterns = @(
        "(?:^|[\\/])\.git(?:[\\/]|$)",
        "(?:^|[\\/])node_modules(?:[\\/]|$)",
        "(?:^|[\\/])\.next(?:[\\/]|$)",
        "(?:^|[\\/])dist(?:[\\/]|$)",
        "(?:^|[\\/])\.secrets(?:[\\/]|$)",
        "(?:^|[\\/])\.env$",
        "(?:^|[\\/])\.env\..*",
        "\.log$",
        "\.tsbuildinfo$",
        "(?:^|[\\/])test-results(?:[\\/]|$)",
        "(?:^|[\\/])playwright-report(?:[\\/]|$)",
        "results\.json$",
        "(?:^|[\\/])evidence(?:[\\/]|$)",
        "(?:^|[\\/])audit(?:[\\/]|$)",
        "\.zip$"
    )

    $allFiles = Get-ChildItem -Path $projectRoot -Recurse -File
    $copiedCount = 0

    foreach ($file in $allFiles) {
        $relPath = $file.FullName.Substring($projectRoot.Length).TrimStart('\', '/')
        $skip = $false

        foreach ($pat in $excludePatterns) {
            if ($relPath -match $pat) {
                $skip = $true
                break
            }
        }

        if (-not $skip) {
            $destPath = Join-Path $tempStageDir $relPath
            $destDir = Split-Path -Parent $destPath
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
            $copiedCount++
        }
    }

    Write-Host "Total berkas sumber bersih yang dikemas: $copiedCount"
    Compress-Archive -Path (Join-Path $tempStageDir "*") -DestinationPath $sourceZipPath -CompressionLevel Optimal
    Write-Host "Paket source code berhasil dibuat: $sourceZipName"

    # --------------------------------------------------------------------------
    # 2. Package Verification Evidence (StockFlow_Final_Verification_v8_1.zip)
    # --------------------------------------------------------------------------
    Write-Host "[2/4] Menyiapkan bukti verifikasi untuk $verificationZipName..."
    New-Item -ItemType Directory -Path $tempVerifyDir -Force | Out-Null

    # Copy evidence/v1.6.1
    $srcEvidence = Join-Path $projectRoot "evidence\v1.6.1"
    $dstEvidence = Join-Path $tempVerifyDir "evidence\v1.6.1"
    Copy-Item -Path $srcEvidence -Destination $dstEvidence -Recurse -Force

    # Copy engineering release reports
    $dstDocs = Join-Path $tempVerifyDir "docs\engineering"
    New-Item -ItemType Directory -Path $dstDocs -Force | Out-Null

    $reportsToCopy = @(
        "docs\engineering\FINAL_RELEASE_REPORT_V1_6_1.md",
        "docs\engineering\E2E_REPORT.md",
        "docs\engineering\SECURITY_REVIEW.md",
        "docs\engineering\TEST_RESULTS.md",
        "docs\engineering\BUG_LOG.md",
        "docs\engineering\ARCHITECTURE_DECISIONS.md"
    )

    foreach ($rep in $reportsToCopy) {
        $repSrc = Join-Path $projectRoot $rep
        if (Test-Path $repSrc) {
            Copy-Item -LiteralPath $repSrc -Destination $dstDocs -Force
        }
    }

    Compress-Archive -Path (Join-Path $tempVerifyDir "*") -DestinationPath $verificationZipPath -CompressionLevel Optimal
    Write-Host "Paket bukti verifikasi berhasil dibuat: $verificationZipName"

    # --------------------------------------------------------------------------
    # 3. Compute SHA-256 Checksums
    # --------------------------------------------------------------------------
    Write-Host "[3/4] Menghitung checksum SHA-256 untuk setiap paket rilis..."
    $hashSource = (Get-FileHash -Path $sourceZipPath -Algorithm SHA256).Hash
    $hashVerify = (Get-FileHash -Path $verificationZipPath -Algorithm SHA256).Hash
    $sizeSource = (Get-Item $sourceZipPath).Length
    $sizeVerify = (Get-Item $verificationZipPath).Length

    $checksumContent = @"
=== STOCKFLOW OFFICIAL RELEASE CHECKSUMS (v1.6.1) ===
Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')

File: $sourceZipName
Size: $sizeSource bytes
SHA-256: $hashSource

File: $verificationZipName
Size: $sizeVerify bytes
SHA-256: $hashVerify
"@

    $checksumFile = Join-Path $projectRoot "evidence\v1.6.1\RELEASE_CHECKSUMS.txt"
    [System.IO.File]::WriteAllText($checksumFile, $checksumContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host $checksumContent

    # --------------------------------------------------------------------------
    # 4. Scan Both ZIP Packages for Secrets
    # --------------------------------------------------------------------------
    Write-Host "[4/4] Memindai kedua paket rilis menggunakan scripts/scan-secrets.ps1..."
    $scannerScript = Join-Path $projectRoot "scripts\scan-secrets.ps1"

    $sourceScanReport = Join-Path $projectRoot "evidence\v1.6.1\source_package_scan.txt"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scannerScript" -TargetScanPath "$sourceZipPath" -OutputFile "$sourceScanReport"
    if ($LASTEXITCODE -ne 0) { throw "Gagal: Ditemukan temuan rahasia pada $sourceZipName!" }

    $verifyScanReport = Join-Path $projectRoot "evidence\v1.6.1\verification_package_scan.txt"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scannerScript" -TargetScanPath "$verificationZipPath" -OutputFile "$verifyScanReport"
    if ($LASTEXITCODE -ne 0) { throw "Gagal: Ditemukan temuan rahasia pada $verificationZipName!" }

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " Pemaketan dan Verifikasi Rilis v1.6.1 SELESAI (100% CLEAN & GREEN)"
    Write-Host "======================================================================"
    Write-Host ""

} finally {
    if (Test-Path $tempStageDir) { Remove-Item -LiteralPath $tempStageDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempVerifyDir) { Remove-Item -LiteralPath $tempVerifyDir -Recurse -Force -ErrorAction SilentlyContinue }
}
