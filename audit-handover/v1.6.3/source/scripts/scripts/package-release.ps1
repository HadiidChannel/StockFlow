# ==============================================================================
# StockFlow - Official Release Packaging Script (v1.6.3)
# Script: scripts/package-release.ps1
# Description: Implements strict staged release packaging:
#              1. StockFlow_Final_v8_3.zip (Source code with .env.example)
#              2. StockFlow_Final_Verification_v8_3.zip (Sanitized evidence & docs)
#              3. StockFlow_Audit_Handover_v8_3.zip (Complete supplementary audit files)
#              4. StockFlow_Release_Checksums_v8_3.txt (External manifest sitting outside ZIPs)
#              Places output in release-output/v1.6.3/ and audit/v8_3/ and workspace root.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReleaseVersion = "v1.6.3",

    [Parameter(Mandatory = $false)]
    [string]$GitCommitHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

$sourceZipName = "StockFlow_Final_v8_3.zip"
$verificationZipName = "StockFlow_Final_Verification_v8_3.zip"
$handoverZipName = "StockFlow_Audit_Handover_v8_3.zip"
$manifestName = "StockFlow_Release_Checksums_v8_3.txt"

# Destination directories
$releaseOutputDir = Join-Path $projectRoot "release-output\v1.6.3"
$auditOutputDir = Join-Path $projectRoot "audit\v8_3"

if (-not (Test-Path -LiteralPath $releaseOutputDir)) {
    New-Item -ItemType Directory -Path $releaseOutputDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $auditOutputDir)) {
    New-Item -ItemType Directory -Path $auditOutputDir -Force | Out-Null
}

$sourceZipPath = Join-Path $releaseOutputDir $sourceZipName
$verificationZipPath = Join-Path $releaseOutputDir $verificationZipName
$handoverZipPath = Join-Path $releaseOutputDir $handoverZipName
$manifestPath = Join-Path $releaseOutputDir $manifestName

Write-Host "======================================================================"
Write-Host " Packaging StockFlow $ReleaseVersion Official Release Artifacts"
Write-Host " Target Output Directory: $releaseOutputDir"
Write-Host " Target Audit Directory:  $auditOutputDir"
Write-Host "======================================================================"

# Clean existing packages in release-output
if (Test-Path -LiteralPath $sourceZipPath) { Remove-Item -LiteralPath $sourceZipPath -Force }
if (Test-Path -LiteralPath $verificationZipPath) { Remove-Item -LiteralPath $verificationZipPath -Force }
if (Test-Path -LiteralPath $handoverZipPath) { Remove-Item -LiteralPath $handoverZipPath -Force }
if (Test-Path -LiteralPath $manifestPath) { Remove-Item -LiteralPath $manifestPath -Force }

$tempStageDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_stage_" + [Guid]::NewGuid().ToString().Substring(0, 8))
$tempVerifyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_verify_stage_" + [Guid]::NewGuid().ToString().Substring(0, 8))

try {
    # --------------------------------------------------------------------------
    # 1. Package Clean Source Code (StockFlow_Final_v8_3.zip)
    # --------------------------------------------------------------------------
    Write-Host "[1/6] Menyiapkan berkas source code untuk $sourceZipName..."
    New-Item -ItemType Directory -Path $tempStageDir -Force | Out-Null

    # Strictly preserve .env.example while excluding live secrets, git, node_modules, build outputs
    $excludePatterns = @(
        "(?:^|[\\/])\.git(?:[\\/]|$)",
        "(?:^|[\\/])node_modules(?:[\\/]|$)",
        "(?:^|[\\/])\.next(?:[\\/]|$)",
        "(?:^|[\\/])dist(?:[\\/]|$)",
        "(?:^|[\\/])\.secrets(?:[\\/]|$)",
        "(?i)(?:^|[\\/])\.env(?:\.(?!example$)[^\\/]+)?$",
        "\.log$",
        "\.tsbuildinfo$",
        "(?:^|[\\/])test-results(?:[\\/]|$)",
        "(?:^|[\\/])playwright-report(?:[\\/]|$)",
        "results\.json$",
        "(?:^|[\\/])evidence(?:[\\/]|$)",
        "(?:^|[\\/])audit(?:[\\/]|$)",
        "(?:^|[\\/])audit-handover(?:[\\/]|$)",
        "(?:^|[\\/])release-output(?:[\\/]|$)",
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
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
            $copiedCount++
        }
    }

    # Verify that .env.example was copied
    if (-not (Test-Path -LiteralPath (Join-Path $tempStageDir ".env.example"))) {
        throw "Gagal: .env.example tidak ikut tersalin ke dalam staging source!"
    }

    Write-Host "Total berkas sumber bersih yang dikemas: $copiedCount"
    Compress-Archive -Path (Join-Path $tempStageDir "*") -DestinationPath $sourceZipPath -CompressionLevel Optimal
    Write-Host "Paket source code berhasil dibuat: $sourceZipName"

    # --------------------------------------------------------------------------
    # 2. Package Verification Evidence (StockFlow_Final_Verification_v8_3.zip)
    # --------------------------------------------------------------------------
    Write-Host "[2/6] Menyiapkan bukti verifikasi untuk $verificationZipName..."
    New-Item -ItemType Directory -Path $tempVerifyDir -Force | Out-Null

    # Copy evidence/v1.6.3
    $srcEvidence = Join-Path $projectRoot "evidence\v1.6.3"
    $dstEvidence = Join-Path $tempVerifyDir "evidence\v1.6.3"
    if (Test-Path -LiteralPath $srcEvidence) {
        Copy-Item -Path $srcEvidence -Destination $dstEvidence -Recurse -Force
    }

    # Copy engineering release reports and docs
    $dstDocs = Join-Path $tempVerifyDir "docs\engineering"
    New-Item -ItemType Directory -Path $dstDocs -Force | Out-Null

    $reportsToCopy = @(
        "docs\engineering\FINAL_RELEASE_REPORT_V1_6_3.md",
        "docs\engineering\E2E_REPORT.md",
        "docs\engineering\SECURITY_REVIEW.md",
        "docs\engineering\TEST_RESULTS.md",
        "docs\engineering\BUG_LOG.md",
        "docs\engineering\ARCHITECTURE_DECISIONS.md",
        "docs\engineering\DEPLOYMENT_GUIDE.md",
        "docs\engineering\TROUBLESHOOTING.md"
    )

    foreach ($rep in $reportsToCopy) {
        $repSrc = Join-Path $projectRoot $rep
        if (Test-Path -LiteralPath $repSrc) {
            Copy-Item -LiteralPath $repSrc -Destination $dstDocs -Force
        }
    }

    Compress-Archive -Path (Join-Path $tempVerifyDir "*") -DestinationPath $verificationZipPath -CompressionLevel Optimal
    Write-Host "Paket bukti verifikasi berhasil dibuat: $verificationZipName"

    # --------------------------------------------------------------------------
    # 3. Package Audit Handover (StockFlow_Audit_Handover_v8_3.zip)
    # --------------------------------------------------------------------------
    Write-Host "[3/6] Menyiapkan paket Audit Handover ($handoverZipName)..."
    $handoverSourceDir = Join-Path $projectRoot "audit-handover\v1.6.3"
    if (-not (Test-Path -LiteralPath $handoverSourceDir)) {
        throw "Gagal: Direktori $handoverSourceDir belum tersedia!"
    }
    Compress-Archive -Path (Join-Path $handoverSourceDir "*") -DestinationPath $handoverZipPath -CompressionLevel Optimal
    Write-Host "Paket Audit Handover berhasil dibuat: $handoverZipName"

    # --------------------------------------------------------------------------
    # 4. Compute SHA-256 Checksums and Write External Manifest
    # --------------------------------------------------------------------------
    Write-Host "[4/6] Menghitung checksum SHA-256 untuk seluruh paket rilis..."
    $hashSource = (Get-FileHash -LiteralPath $sourceZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
    $hashVerify = (Get-FileHash -LiteralPath $verificationZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
    $hashHandover = (Get-FileHash -LiteralPath $handoverZipPath -Algorithm SHA256).Hash.ToUpperInvariant()

    $sizeSource = (Get-Item -LiteralPath $sourceZipPath).Length
    $sizeVerify = (Get-Item -LiteralPath $verificationZipPath).Length
    $sizeHandover = (Get-Item -LiteralPath $handoverZipPath).Length

    $finalCommit = if ([string]::IsNullOrWhiteSpace($GitCommitHash)) {
        (& git.exe rev-parse HEAD 2>$null)
    } else {
        $GitCommitHash
    }
    if ($finalCommit) { $finalCommit = $finalCommit.Trim() }

    $manifestContent = @"
=== STOCKFLOW OFFICIAL RELEASE MANIFEST AND CHECKSUMS ($ReleaseVersion) ===
Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
Release Version: $ReleaseVersion
Final Git Branch: fix/stockflow-v16-3-release-integrity
Final Git Commit: $finalCommit

Package 1: $sourceZipName
Description: Source Code Package (Clean codebase with .env.example)
Size: $sizeSource bytes
SHA-256: $hashSource

Package 2: $verificationZipName
Description: Verification Evidence Package (Sanitized raw evidence and engineering docs)
Size: $sizeVerify bytes
SHA-256: $hashVerify

Package 3: $handoverZipName
Description: Audit Handover Package (Self-contained standalone audit package with source and evidence)
Size: $sizeHandover bytes
SHA-256: $hashHandover
"@

    [System.IO.File]::WriteAllText($manifestPath, $manifestContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host $manifestContent

    # --------------------------------------------------------------------------
    # 5. Mirror Artifacts to audit/v8_3 and Root Directory
    # --------------------------------------------------------------------------
    Write-Host "[5/6] Menyalin artefak ke direktori $auditOutputDir dan project root..."
    Copy-Item -LiteralPath $sourceZipPath -Destination (Join-Path $auditOutputDir $sourceZipName) -Force
    Copy-Item -LiteralPath $verificationZipPath -Destination (Join-Path $auditOutputDir $verificationZipName) -Force
    Copy-Item -LiteralPath $handoverZipPath -Destination (Join-Path $auditOutputDir $handoverZipName) -Force
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $auditOutputDir $manifestName) -Force

    Copy-Item -LiteralPath $sourceZipPath -Destination (Join-Path $projectRoot $sourceZipName) -Force
    Copy-Item -LiteralPath $verificationZipPath -Destination (Join-Path $projectRoot $verificationZipName) -Force
    Copy-Item -LiteralPath $handoverZipPath -Destination (Join-Path $projectRoot $handoverZipName) -Force
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $projectRoot $manifestName) -Force

    # --------------------------------------------------------------------------
    # 6. Execute Verify Release Gate
    # --------------------------------------------------------------------------
    Write-Host "[6/6] Menjalankan scripts/verify-release.ps1 terhadap $releaseOutputDir..."
    $verifyScript = Join-Path $projectRoot "scripts\verify-release.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$verifyScript" -TargetDirectory "$releaseOutputDir"
    if ($LASTEXITCODE -ne 0) {
        throw "Verifikasi release gate gagal pada $releaseOutputDir!"
    }

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " Pemaketan dan Verifikasi Rilis $ReleaseVersion SELESAI (100% CLEAN & GREEN)"
    Write-Host " Artefak Rilis Tersedia di:"
    Write-Host "   1. $releaseOutputDir"
    Write-Host "   2. $auditOutputDir"
    Write-Host "   3. $projectRoot"
    Write-Host "======================================================================"
    Write-Host ""

} finally {
    if (Test-Path -LiteralPath $tempStageDir) { Remove-Item -LiteralPath $tempStageDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $tempVerifyDir) { Remove-Item -LiteralPath $tempVerifyDir -Recurse -Force -ErrorAction SilentlyContinue }
}
