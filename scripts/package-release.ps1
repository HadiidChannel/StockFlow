# ==============================================================================
# StockFlow - Anti-Circular Cross-Platform Release Packager (v1.6.5)
# Script: scripts/package-release.ps1
# Description: Implements the 18-step anti-circular release pipeline on clean HEAD:
#              1. Capture pre-package Git, Docker, Secret, Negative Test evidence
#              2. Build StockFlow_Final_v8_5.zip from git archive HEAD using
#                 POSIX '/' entries (via zip-utils.ps1) + source secret scan
#              3. Build & verify StockFlow_Audit_Handover_v8_5.zip
#              4. Build StockFlow_Final_Verification_v8_5.zip with POSIX '/'
#              5. Compute SHA-256 checksums -> StockFlow_Release_Checksums_v8_5.txt
#              6. Execute post-package Verification ZIP secret scan
#              7. Execute scripts/verify-release.ps1 across all 14 gates (incl.
#                 Python zipfile, Info-ZIP unzip, .NET 3-way extraction parity)
#              8. Capture operational stack + DB read-only row counts (after)
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReleaseVersion = "v1.6.5",

    [Parameter(Mandatory = $false)]
    [string]$ExpectedBranch = "fix/stockflow-v16-5-zip-portability"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
. (Join-Path $scriptDir "zip-utils.ps1")

$releaseDir = Join-Path $projectRoot "release-output\v1.6.5"
$evRoot = Join-Path $releaseDir "evidence"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Invoke-GitPack([string[]]$gitArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $allArgs = @("-C", $projectRoot) + $gitArgs
        $out = & git.exe $allArgs 2>&1 | Out-String
        return [PSCustomObject]@{ Output = $out; ExitCode = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

Write-Host "======================================================================"
Write-Host " StockFlow Anti-Circular Official Release Packager ($ReleaseVersion)"
Write-Host " Output Directory (Single Official Location): $releaseDir"
Write-Host "======================================================================"

# ------------------------------------------------------------------------------
# Step 0: Strict Pre-Packaging Git Preconditions (Anti-Circular Order)
# ------------------------------------------------------------------------------
Write-Host "[Pre-Check] Verifying branch '$ExpectedBranch' and clean Git working tree..."
$brRes = Invoke-GitPack @("branch", "--show-current")
$actualBranch = $brRes.Output.Trim()
if ($brRes.ExitCode -ne 0 -or $actualBranch -cne $ExpectedBranch) {
    throw "Release packaging aborted: active branch is '$actualBranch', expected '$ExpectedBranch'."
}

$stRes = Invoke-GitPack @("status", "--porcelain", "--untracked-files=all")
if ($stRes.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stRes.Output)) {
    throw "Release packaging aborted: Git working tree is NOT clean! Commit all changes first.`n$($stRes.Output)"
}

$hdRes = Invoke-GitPack @("rev-parse", "HEAD")
$finalCommit = $hdRes.Output.Trim().ToLowerInvariant()
if ($hdRes.ExitCode -ne 0 -or $finalCommit -notmatch '^[a-f0-9]{40}$') {
    throw "Release packaging aborted: invalid HEAD commit '$finalCommit'."
}
Write-Host "[OK] Clean Git HEAD verified: $finalCommit on $actualBranch"

if (-not (Test-Path -LiteralPath $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}
foreach ($oldFile in @("StockFlow_Final_v8_5.zip", "StockFlow_Final_Verification_v8_5.zip", "StockFlow_Audit_Handover_v8_5.zip", "StockFlow_Release_Checksums_v8_5.txt", "FINAL_RELEASE_REPORT_V1_6_5.md")) {
    $p = Join-Path $releaseDir $oldFile
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
foreach ($staleSub in @("pre-package", "post-package", "git", "docker", "security", "release", "portability", "handover", "backend", "frontend", "bootstrap", "windows-acl", "e2e")) {
    $sp = Join-Path $evRoot $staleSub
    if (Test-Path -LiteralPath $sp) { Remove-Item -LiteralPath $sp -Recurse -Force }
}
foreach ($afterFile in @("main_stack_after.txt", "main_database_after.txt", "main_volume_after.txt")) {
    $ap = Join-Path (Join-Path $evRoot "operational") $afterFile
    if (Test-Path -LiteralPath $ap) { Remove-Item -LiteralPath $ap -Force }
}

# ------------------------------------------------------------------------------
# Step 1: Capture Pre-Package Git, Docker, Security & 44-Scenario Evidence
# ------------------------------------------------------------------------------
Write-Host "`n[Step 1/8] Executing capture-evidence.ps1 (post-commit pre-package)..."
$captureScript = Join-Path $scriptDir "capture-evidence.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $captureScript -EvidenceDir $evRoot -RequireCleanGit
if ($LASTEXITCODE -ne 0) {
    throw "capture-evidence.ps1 failed (Exit: $LASTEXITCODE)."
}

# ------------------------------------------------------------------------------
# Step 2: Build Source Package (StockFlow_Final_v8_5.zip) using POSIX '/'
# ------------------------------------------------------------------------------
Write-Host "`n[Step 2/8] Building StockFlow_Final_v8_5.zip from Git HEAD using POSIX '/' entries..."
$sourceZipPath = Join-Path $releaseDir "StockFlow_Final_v8_5.zip"
$scannerScript = Join-Path $scriptDir "scan-secrets.ps1"

$tempWork = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_pkg_src_v165_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$headZipTmp = Join-Path $tempWork "head.zip"
$headRawDir = Join-Path $tempWork "head_raw"
$srcStageDir = Join-Path $tempWork "src_stage"
$srcVerifyExtract = Join-Path $tempWork "src_verify_ext"

try {
    New-Item -ItemType Directory -Path $headRawDir, $srcStageDir, $srcVerifyExtract -Force | Out-Null

    $archRes = Invoke-GitPack @("archive", "--format=zip", "--output=$headZipTmp", "HEAD")
    if ($archRes.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $headZipTmp)) {
        throw "git archive HEAD failed: $($archRes.Output)"
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($headZipTmp, $headRawDir)

    $excludeRegexes = @(
        "(?:^|[\\/])StockFlow_Release_Checksums_.*\.txt$",
        "(?:^|[\\/])RELEASE_CHECKSUMS.*\.txt$",
        "\.zip$",
        "^(?:evidence|audit|audit-handover|release-output)[\\/]",
        "(?:^|[\\/])(?:\.git|\.secrets|node_modules|\.next|dist|test-results|playwright-report)[\\/]",
        "(?:^|[\\/])(?:\.env|\.env\.local|\.env\.(?!example$)[^\\/]+)$",
        "(?:^|[\\/])(?:results\.json|[^\\/]*\.tsbuildinfo|[^\\/]*\.secret|[^\\/]*\.log)$"
    )

    $exportedFiles = @(Get-ChildItem -LiteralPath $headRawDir -Recurse -File | Sort-Object FullName)
    $excludedList = [System.Collections.Generic.List[string]]::new()

    foreach ($ef in $exportedFiles) {
        $rel = $ef.FullName.Substring($headRawDir.Length).TrimStart('\', '/')
        $relUnix = $rel.Replace('\', '/')
        $skip = $false
        foreach ($rx in $excludeRegexes) {
            if ($rel -match $rx -or $relUnix -match $rx) {
                $skip = $true
                break
            }
        }
        if ($skip) {
            $excludedList.Add($relUnix)
        } else {
            $dst = Join-Path $srcStageDir $rel
            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $ef.FullName -Destination $dst -Force
        }
    }

    New-PortableZipArchive -SourceDirectory $srcStageDir -DestinationZipPath $sourceZipPath | Out-Null
    $srcStruct = Test-ZipArchiveEntries -ZipPath $sourceZipPath
    if (-not $srcStruct.Valid) {
        throw "POSIX entry check failed for Source ZIP: $($srcStruct.Violations -join '; ')"
    }

    [System.IO.Compression.ZipFile]::ExtractToDirectory($sourceZipPath, $srcVerifyExtract)
    $extFiles = @(Get-ChildItem -LiteralPath $srcVerifyExtract -Recurse -File | Sort-Object FullName)

    $envTemplatesOk = $true
    $templateReportLines = [System.Collections.Generic.List[string]]::new()
    foreach ($tpl in @(".env.example", "backend\.env.example", "frontend\.env.example")) {
        $exists = Test-Path -LiteralPath (Join-Path $srcVerifyExtract $tpl) -PathType Leaf
        if (-not $exists) { $envTemplatesOk = $false }
        $templateReportLines.Add("- $($tpl.Replace('\', '/')): $(if ($exists) { 'PRESENT' } else { 'MISSING' })")
    }
    if (-not $envTemplatesOk) {
        throw "Required .env.example template missing inside Source ZIP!"
    }

    $leakedManifests = @($extFiles | Where-Object { $_.Name -match '^StockFlow_Release_Checksums.*\.txt$' })
    if ($leakedManifests.Count -gt 0) {
        throw "Historical or release checksum manifest illegally found inside Source ZIP!"
    }

    $srcScanOut = Join-Path $evRoot "security\source_package_scan.txt"
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scannerScript -TargetScanPath $sourceZipPath -OutputFile $srcScanOut | Out-Null
    $srcScanExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($srcScanExit -ne 0) {
        throw "Secret scan failed on $sourceZipPath (Exit: $srcScanExit)"
    }

    $srcSize = (Get-Item -LiteralPath $sourceZipPath).Length
    $srcHash = (Get-FileHash -LiteralPath $sourceZipPath -Algorithm SHA256).Hash.ToUpperInvariant()

    $srcVerReport = [System.Collections.Generic.List[string]]::new()
    $srcVerReport.Add("================================================================================")
    $srcVerReport.Add("STOCKFLOW v1.6.5 - SOURCE PACKAGE HYGIENE AND POSIX STRUCTURE VERIFICATION")
    $srcVerReport.Add("================================================================================")
    $srcVerReport.Add("Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $srcVerReport.Add("Archive Path: $sourceZipPath")
    $srcVerReport.Add("Git Commit Origin: $finalCommit")
    $srcVerReport.Add("Archive Byte Size: $srcSize bytes")
    $srcVerReport.Add("Archive SHA-256: $srcHash")
    $srcVerReport.Add("ZIP Entries Checked: $($srcStruct.EntryCount) | Backslash Entries: $($srcStruct.BackslashCount) (PASS)")
    $srcVerReport.Add("Total Extracted Files: $($extFiles.Count)")
    $srcVerReport.Add("Historical Checksum Manifests Found: 0 (PASS)")
    $srcVerReport.Add("Secret Scan Exit Code: $srcScanExit (0 Findings - CLEAN)")
    $srcVerReport.Add("")
    $srcVerReport.Add("--- Environment Templates Verified ---")
    foreach ($tl in $templateReportLines) { $srcVerReport.Add($tl) }
    $srcVerReport.Add("")
    $srcVerReport.Add("--- Excluded Committed Categories (Non-Source / Historical Manifests) ---")
    $srcVerReport.Add("Total excluded paths from git archive HEAD: $($excludedList.Count)")
    $srcVerReport.Add("")
    $srcVerReport.Add("--- Complete Extracted File List ($($extFiles.Count) files) ---")
    foreach ($ef in $extFiles) {
        $srcVerReport.Add($ef.FullName.Substring($srcVerifyExtract.Length).TrimStart('\', '/').Replace('\', '/'))
    }
    [System.IO.File]::WriteAllLines((Join-Path $evRoot "release\source_package_verification.txt"), $srcVerReport, $utf8NoBom)
    Write-Host "[OK] Source ZIP verified ($($extFiles.Count) files, $srcSize bytes, 0 backslashes, SHA-256: $srcHash)."
} finally {
    if (Test-Path -LiteralPath $tempWork) {
        Remove-Item -LiteralPath $tempWork -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------------------
# Step 3: Build & Verify Audit Handover ZIP (StockFlow_Audit_Handover_v8_5.zip)
# ------------------------------------------------------------------------------
Write-Host "`n[Step 3/8] Assembling and verifying StockFlow_Audit_Handover_v8_5.zip..."
$handoverScript = Join-Path $scriptDir "assemble-handover.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $handoverScript -ReleaseOutputDir $releaseDir -GitCommitHash $finalCommit
if ($LASTEXITCODE -ne 0) {
    throw "assemble-handover.ps1 failed (Exit: $LASTEXITCODE)."
}
$handoverZipPath = Join-Path $releaseDir "StockFlow_Audit_Handover_v8_5.zip"

$recPath = Join-Path $evRoot "release\test_reconciliation.txt"
$recText = [System.IO.File]::ReadAllText($recPath)
$recText = [regex]::Replace($recText, 'Source Package Hygiene & POSIX Structure Verification\s+Post-ZIP\s+Pending\s+-\s+Executed during packaging', 'Source Package Hygiene & POSIX Structure Verification            1/1        1       0  Re-executed in v1.6.5 (PASS)')
$recText = [regex]::Replace($recText, 'Bidirectional Audit Handover & Manifest Verification\s+Post-ZIP\s+Pending\s+-\s+Executed during handover', 'Bidirectional Audit Handover & Manifest Verification             1/1        1       0  Re-executed in v1.6.5 (PASS)')
[System.IO.File]::WriteAllText($recPath, $recText, $utf8NoBom)

# ------------------------------------------------------------------------------
# Step 4: Build Verification Archive (StockFlow_Final_Verification_v8_5.zip)
# ------------------------------------------------------------------------------
Write-Host "`n[Step 4/8] Building StockFlow_Final_Verification_v8_5.zip using POSIX '/'..."
$verifyZipPath = Join-Path $releaseDir "StockFlow_Final_Verification_v8_5.zip"
$tempVerWork = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_pkg_ver_v165_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))

try {
    New-Item -ItemType Directory -Path (Join-Path $tempVerWork "evidence"), (Join-Path $tempVerWork "documentation") -Force | Out-Null
    Copy-Item -Path (Join-Path $evRoot "*") -Destination (Join-Path $tempVerWork "evidence") -Recurse -Force
    Copy-Item -Path (Join-Path $projectRoot "docs\engineering\*") -Destination (Join-Path $tempVerWork "documentation") -Recurse -Force

    $verNote = @"
=== STOCKFLOW v1.6.5 VERIFICATION ARCHIVE INDEX ===
Git Commit: $finalCommit
Git Branch: $actualBranch

Included pre-package evidence & documentation in this archive:
- evidence/git/*                  : Git identity & clean marker-delimited git_status.txt + negative test logs
- evidence/docker/*               : Docker Compose raw & summarized config validation
- evidence/security/*             : Repository, Source ZIP, Handover ZIP secret scans & SelfTest
- evidence/release/*              : 44-scenario verifier tests, source verification, provenance, reconciliation
- evidence/handover/*             : Handover completeness verification & Gate 09 negative test log
- evidence/portability/*          : Gate 14 negative test log
- evidence/pre-package/*          : Pre-package pipeline log
- evidence/operational/*          : Main stack, health, DB read-only row counts & volume baseline (before)
- evidence/{backend,frontend,windows-acl,bootstrap,e2e}/* : Inherited app test logs (origin e7bccf7)
- documentation/*                 : Committed engineering documentation

External post-package evidence generated AFTER sealing all 3 ZIPs (in release-output/v1.6.5/):
- StockFlow_Release_Checksums_v8_5.txt
- evidence/security/verification_package_scan.txt
- evidence/portability/zip_portability_verification.txt
- evidence/release/writing_constraint_verification.txt
- evidence/release/release_verification_summary.md
- evidence/post-package/post_package_pipeline_log.txt
- FINAL_RELEASE_REPORT_V1_6_5.md
"@
    [System.IO.File]::WriteAllText((Join-Path $tempVerWork "VERIFICATION_ARCHIVE_INDEX.txt"), $verNote, $utf8NoBom)

    New-PortableZipArchive -SourceDirectory $tempVerWork -DestinationZipPath $verifyZipPath | Out-Null
    $verStruct = Test-ZipArchiveEntries -ZipPath $verifyZipPath
    if (-not $verStruct.Valid) {
        throw "POSIX entry check failed for Verification ZIP: $($verStruct.Violations -join '; ')"
    }
    Write-Host "[OK] Verification ZIP built ($($verStruct.EntryCount) entries, 0 backslashes): $verifyZipPath"
} finally {
    if (Test-Path -LiteralPath $tempVerWork) {
        Remove-Item -LiteralPath $tempVerWork -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------------------
# Step 5: Compute Checksums & Write External Manifest Outside ZIPs
# ------------------------------------------------------------------------------
Write-Host "`n[Step 5/8] Computing SHA-256 checksums and writing StockFlow_Release_Checksums_v8_5.txt..."
$size1 = (Get-Item -LiteralPath $sourceZipPath).Length;    $hash1 = (Get-FileHash -LiteralPath $sourceZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
$size2 = (Get-Item -LiteralPath $verifyZipPath).Length;    $hash2 = (Get-FileHash -LiteralPath $verifyZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
$size3 = (Get-Item -LiteralPath $handoverZipPath).Length;  $hash3 = (Get-FileHash -LiteralPath $handoverZipPath -Algorithm SHA256).Hash.ToUpperInvariant()

$manifestPath = Join-Path $releaseDir "StockFlow_Release_Checksums_v8_5.txt"
$manifestContent = @"
=== STOCKFLOW OFFICIAL RELEASE MANIFEST (v1.6.5) ===

Release Version: $ReleaseVersion
Generated At: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Git Branch: $actualBranch
Git Commit: $finalCommit
Working Tree: Clean

Package 1:
Name: StockFlow_Final_v8_5.zip
Description: Source Code Package (Clean committed source from Git HEAD with POSIX '/' paths and env templates)
Size: $size1 bytes
SHA-256: $hash1

Package 2:
Name: StockFlow_Final_Verification_v8_5.zip
Description: Verification Evidence Package (v1.6.5 pre-package evidence with POSIX '/' paths, inherited logs, engineering docs)
Size: $size2 bytes
SHA-256: $hash2

Package 3:
Name: StockFlow_Audit_Handover_v8_5.zip
Description: Audit Handover Package (Complete backend/frontend source, lockfiles, Dockerfiles, tests, evidence, docs, bidirectional AUDIT_FILE_MANIFEST.md, POSIX '/' paths)
Size: $size3 bytes
SHA-256: $hash3
"@
[System.IO.File]::WriteAllText($manifestPath, $manifestContent, $utf8NoBom)
Write-Host $manifestContent

# ------------------------------------------------------------------------------
# Step 6: Execute Post-Package Secret Scan on Verification ZIP Before Gate Check
# ------------------------------------------------------------------------------
Write-Host "`n[Step 6/8] Running post-package secret scan on Verification ZIP..."
$verifyScanOut = Join-Path $evRoot "security\verification_package_scan.txt"
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scannerScript -TargetScanPath $verifyZipPath -OutputFile $verifyScanOut | Out-Null
$verScanExit = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($verScanExit -ne 0) {
    throw "Secret scan failed on $verifyZipPath (Exit: $verScanExit)"
}
Write-Host "[OK] Verification ZIP secret scan clean (Exit: $verScanExit)."

$postPipeLog = @(
    "=== STOCKFLOW v1.6.5 POST-PACKAGE PIPELINE LOG ===",
    "Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
    "External Checksum Manifest: $manifestPath",
    "Source ZIP SHA-256: $hash1 ($size1 bytes)",
    "Verification ZIP SHA-256: $hash2 ($size2 bytes)",
    "Handover ZIP SHA-256: $hash3 ($size3 bytes)",
    "Post-Package Verification ZIP Scan: Exit Code $verScanExit -> $verifyScanOut",
    "Proceeding to 14 fail-closed release quality gates..."
)
[System.IO.File]::WriteAllLines((Join-Path $evRoot "post-package\post_package_pipeline_log.txt"), $postPipeLog, $utf8NoBom)

# ------------------------------------------------------------------------------
# Step 7: Execute Fail-Closed Release Verification Gates (14/14)
# ------------------------------------------------------------------------------
Write-Host "`n[Step 7/8] Running fail-closed verify-release.ps1 across all 14 gates..."
$verifyScript = Join-Path $scriptDir "verify-release.ps1"
$summaryPath = Join-Path $evRoot "release\release_verification_summary.md"
$portabilityReportOut = Join-Path $evRoot "portability\zip_portability_verification.txt"
$dashReportOut = Join-Path $evRoot "release\writing_constraint_verification.txt"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifyScript `
    -TargetDirectory $releaseDir `
    -RepositoryRoot $projectRoot `
    -ExpectedBranch $ExpectedBranch `
    -ExpectedVersion $ReleaseVersion `
    -OutputSummaryPath $summaryPath `
    -OutputPortabilityPath $portabilityReportOut `
    -OutputDashCheckPath $dashReportOut

if ($LASTEXITCODE -ne 0) {
    throw "Release verification gate failed (Exit: $LASTEXITCODE)!"
}

# ------------------------------------------------------------------------------
# Step 8: Capture Operational Stack + DB Row Counts After & Final Clean Git Check
# ------------------------------------------------------------------------------
Write-Host "`n[Step 8/8] Capturing post-packaging operational stack health, DB counts & Git status..."
$tsAfter = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$psAfter = (& docker.exe ps -a --filter "name=stockflow" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>&1 | Out-String)
$portsAfter = (netstat -ano -p TCP | Select-String -Pattern ":3000\s|:3100\s|:3306\s|:3307\s|:4000\s" | Out-String)
[System.IO.File]::WriteAllText((Join-Path $evRoot "operational\main_stack_after.txt"), "Timestamp: $tsAfter`n=== DOCKER CONTAINERS ===`n$psAfter`n=== TCP LISTENING PORTS ===`n$portsAfter", $utf8NoBom)

$healthAfter = Invoke-WebRequest -Uri "http://127.0.0.1:3000/api/v1/health" -UseBasicParsing -TimeoutSec 5
$nodeDbScript = "const { PrismaClient } = require('@prisma/client'); const p = new PrismaClient(); async function go() { const r = { users: await p.user.count(), warehouses: await p.warehouse.count(), categories: await p.category.count(), products: await p.product.count(), balances: await p.inventoryBalance.count(), transactions: await p.stockTransaction.count(), movements: await p.stockMovement.count() }; console.log(JSON.stringify(r)); await p['\x24disconnect'](); } go();"
$dbCountsAfter = (& docker.exe exec stockflow_backend_prod node -e $nodeDbScript 2>&1 | Out-String).Trim()
[System.IO.File]::WriteAllText((Join-Path $evRoot "operational\main_database_after.txt"), "Timestamp: $tsAfter`nEndpoint: http://127.0.0.1:3000/api/v1/health`nHTTP Status: $($healthAfter.StatusCode) $($healthAfter.StatusDescription)`nResponse Body:`n$($healthAfter.Content)`nRead-Only Table Row Counts (stockflow_db_prod):`n$dbCountsAfter`n", $utf8NoBom)

$volAfter = (& docker.exe volume inspect stockflow-prod_mysql_prod_data 2>&1 | Out-String)
[System.IO.File]::WriteAllText((Join-Path $evRoot "operational\main_volume_after.txt"), "Timestamp: $tsAfter`nVolume: stockflow-prod_mysql_prod_data`n$volAfter", $utf8NoBom)

$stFinal = Invoke-GitPack @("status", "--porcelain", "--untracked-files=all")
if ($stFinal.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stFinal.Output)) {
    throw "CRITICAL: Git working tree became dirty after packaging!`n$($stFinal.Output)"
}

Write-Host ""
Write-Host "======================================================================"
Write-Host " STOCKFLOW $ReleaseVersion RELEASE PACKAGING & VERIFICATION COMPLETE"
Write-Host " Single Official Output Location: $releaseDir"
Write-Host " Git Working Tree Status: 100% CLEAN (Commit: $finalCommit)"
Write-Host "======================================================================"
exit 0
