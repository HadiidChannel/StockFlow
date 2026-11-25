# ==============================================================================
# StockFlow - Complete Independent Audit Handover Assembler & Verifier (v1.6.5)
# Script: scripts/assemble-handover.ps1
# Description: Builds StockFlow_Audit_Handover_v8_5.zip using explicit POSIX '/'
#              ZIP entries (via zip-utils.ps1) from committed Git HEAD plus
#              verified v1.6.5 & inherited evidence. Generates AUDIT_FILE_MANIFEST.md
#              following strict non-self-referential inventory rules, performs
#              bidirectional Manifest <-> Archive validation (0 Missing, 0 Extra),
#              runs secret scan, and saves completeness proof.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReleaseOutputDir,

    [Parameter(Mandatory = $false)]
    [string]$GitCommitHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
. (Join-Path $scriptDir "zip-utils.ps1")

if ([string]::IsNullOrWhiteSpace($ReleaseOutputDir)) {
    $outDir = Join-Path $projectRoot "release-output\v1.6.5"
} else {
    $outDir = (Resolve-Path $ReleaseOutputDir).Path
}

$evRoot = Join-Path $outDir "evidence"
$scannerScript = Join-Path $scriptDir "scan-secrets.ps1"
$handoverZipPath = Join-Path $outDir "StockFlow_Audit_Handover_v8_5.zip"
$completenessReportPath = Join-Path $evRoot "handover\audit_handover_completeness.txt"
$handoverScanReportPath = Join-Path $evRoot "security\audit_handover_package_scan.txt"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Invoke-GitLocal([string[]]$gitArgs) {
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

$headCommit = if ([string]::IsNullOrWhiteSpace($GitCommitHash)) {
    (Invoke-GitLocal @("rev-parse", "HEAD")).Output.Trim().ToLowerInvariant()
} else {
    $GitCommitHash.Trim().ToLowerInvariant()
}
$headBranch = (Invoke-GitLocal @("branch", "--show-current")).Output.Trim()

if ($headCommit -notmatch '^[a-f0-9]{40}$') {
    throw "Cannot assemble audit handover: invalid Git HEAD commit '$headCommit'."
}

Write-Host "======================================================================"
Write-Host " StockFlow Audit Handover Assembler (v1.6.5)"
Write-Host " Source Commit: $headCommit ($headBranch)"
Write-Host " Target Archive: $handoverZipPath"
Write-Host "======================================================================"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_handover_v165_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$gitExportZip = Join-Path $tempRoot "head_export.zip"
$gitExportDir = Join-Path $tempRoot "head_src"
$stageDir = Join-Path $tempRoot "handover_stage"
$reExtractDir = Join-Path $tempRoot "handover_verify"

try {
    New-Item -ItemType Directory -Path $gitExportDir, $stageDir, $reExtractDir -Force | Out-Null

    Write-Host "[1/6] Exporting clean committed repository state at $headCommit..."
    $archRes = Invoke-GitLocal @("archive", "--format=zip", "--output=$gitExportZip", "HEAD")
    if ($archRes.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $gitExportZip)) {
        throw "git archive HEAD failed: $($archRes.Output)"
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($gitExportZip, $gitExportDir)

    Write-Host "[2/6] Staging complete root, backend, frontend, scripts, tests, evidence, docs..."
    $sourceOut = Join-Path $stageDir "source"
    New-Item -ItemType Directory -Path (Join-Path $sourceOut "root"), (Join-Path $stageDir "evidence"), (Join-Path $stageDir "documentation") -Force | Out-Null

    $rootFiles = @(
        "README.md",
        "SPEC.md",
        ".gitignore",
        ".env.example",
        "docker-compose.yml",
        "docker-compose.dev.yml",
        "docker-compose.e2e.yml",
        "docker-compose.bootstrap-test.yml",
        "docker-compose.test.yml"
    )
    foreach ($rf in $rootFiles) {
        $srcFile = Join-Path $gitExportDir $rf
        if (Test-Path -LiteralPath $srcFile -PathType Leaf) {
            Copy-Item -LiteralPath $srcFile -Destination (Join-Path $sourceOut "root\$rf") -Force
        }
    }

    Copy-Item -Path (Join-Path $gitExportDir "backend") -Destination $sourceOut -Recurse -Force
    Copy-Item -Path (Join-Path $gitExportDir "frontend") -Destination $sourceOut -Recurse -Force
    Copy-Item -Path (Join-Path $gitExportDir "scripts") -Destination $sourceOut -Recurse -Force
    Copy-Item -Path (Join-Path $gitExportDir "tests") -Destination $sourceOut -Recurse -Force

    if (-not (Test-Path -LiteralPath $evRoot)) {
        throw "Evidence root missing at '$evRoot'. Run scripts/capture-evidence.ps1 first."
    }
    # Copy pre-package evidence into Handover (excluding post-package or self-cyclical files that do not exist yet)
    Copy-Item -Path (Join-Path $evRoot "*") -Destination (Join-Path $stageDir "evidence") -Recurse -Force

    $engDocsExport = Join-Path $gitExportDir "docs\engineering"
    if (Test-Path -LiteralPath $engDocsExport) {
        Copy-Item -Path (Join-Path $engDocsExport "*") -Destination (Join-Path $stageDir "documentation") -Recurse -Force
    }

    $stagedFilesPre = @(Get-ChildItem -LiteralPath $stageDir -Recurse -File)
    foreach ($sf in $stagedFilesPre) {
        $rel = $sf.FullName.Substring($stageDir.Length).TrimStart('\', '/')
        if ($sf.Name -match '^StockFlow_Release_Checksums.*\.txt$' -or $sf.Name -eq '.env' -or $sf.Name -eq '.env.local' -or $rel -match '(?:^|[\\/])(?:\.secrets|node_modules|\.next|dist)(?:[\\/]|$)') {
            throw "Handover exclusion rule violated by staged file: $rel"
        }
    }

    Write-Host "[3/6] Validating mandatory files across all handover categories..."
    $mandatoryArchivePaths = @(
        "source/root/README.md",
        "source/root/.gitignore",
        "source/root/.env.example",
        "source/root/docker-compose.yml",
        "source/root/docker-compose.dev.yml",
        "source/root/docker-compose.e2e.yml",
        "source/root/docker-compose.bootstrap-test.yml",
        "source/backend/package.json",
        "source/backend/package-lock.json",
        "source/backend/Dockerfile",
        "source/backend/.env.example",
        "source/backend/tsconfig.json",
        "source/backend/vitest.config.ts",
        "source/backend/prisma/schema.prisma",
        "source/backend/src/app.ts",
        "source/backend/src/server.ts",
        "source/backend/src/config/env.ts",
        "source/backend/src/scripts/bootstrap.ts",
        "source/backend/src/utils/bootstrap-guard.ts",
        "source/backend/tests/bootstrap-guard.test.ts",
        "source/backend/tests/bootstrap.integration.test.ts",
        "source/frontend/package.json",
        "source/frontend/package-lock.json",
        "source/frontend/Dockerfile",
        "source/frontend/.env.example",
        "source/frontend/next.config.ts",
        "source/frontend/tsconfig.json",
        "source/frontend/vitest.config.ts",
        "source/frontend/playwright.config.ts",
        "source/frontend/src/app/layout.tsx",
        "source/frontend/src/lib/api.ts",
        "source/frontend/src/components/layout/sidebar.tsx",
        "source/frontend/tests/e2e/stockflow-lifecycle.spec.ts",
        "source/scripts/zip-utils.ps1",
        "source/scripts/init-local.ps1",
        "source/scripts/run-e2e.ps1",
        "source/scripts/run-bootstrap-test.ps1",
        "source/scripts/scan-secrets.ps1",
        "source/scripts/package-release.ps1",
        "source/scripts/verify-release.ps1",
        "source/scripts/capture-evidence.ps1",
        "source/scripts/assemble-handover.ps1",
        "source/tests/test-init-local.ps1",
        "source/tests/test-verify-release.ps1",
        "evidence/git/git_commit.txt",
        "evidence/git/git_branch.txt",
        "evidence/git/git_status.txt",
        "evidence/git/git_log.txt",
        "evidence/git/git_identity_verification.txt",
        "evidence/git/git_evidence_negative_test.txt",
        "evidence/release/release_verifier_negative_test.txt",
        "evidence/release/source_package_verification.txt",
        "evidence/release/test_reconciliation.txt",
        "evidence/handover/audit_manifest_negative_test.txt",
        "evidence/portability/zip_portability_negative_test.txt",
        "evidence/docker/docker_compose_verification.txt",
        "evidence/security/secret_scan_repository.txt",
        "evidence/security/source_package_scan.txt",
        "evidence/security/secret_scanner_self_test.txt",
        "evidence/backend/backend_test_results.txt",
        "evidence/frontend/frontend_test_results.txt",
        "evidence/windows-acl/init_local_test_results.txt",
        "evidence/bootstrap/bootstrap_integration_test_results.txt",
        "evidence/e2e/e2e_test_results.txt",
        "documentation/BUG_LOG.md",
        "documentation/TEST_RESULTS.md",
        "documentation/SECURITY_REVIEW.md",
        "documentation/ARCHITECTURE_DECISIONS.md",
        "documentation/DEPLOYMENT_GUIDE.md",
        "documentation/TROUBLESHOOTING.md"
    )

    foreach ($mp in $mandatoryArchivePaths) {
        $fullCandidate = Join-Path $stageDir ($mp.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $fullCandidate -PathType Leaf)) {
            throw "Mandatory handover file missing from staging: $mp"
        }
    }

    Write-Host "[4/6] Generating AUDIT_FILE_MANIFEST.md (non-self-referential inventory)..."
    $stagedFiles = @(Get-ChildItem -LiteralPath $stageDir -Recurse -File | Sort-Object FullName)
    $inventoryCount = $stagedFiles.Count
    $totalArchiveFileCount = $inventoryCount + 1
    $totalStagedBytes = ($stagedFiles | Measure-Object -Property Length -Sum).Sum

    function Get-ManifestFileRecord([string]$relArchivePath) {
        $norm = $relArchivePath.Replace('/', '\')
        $fp = Join-Path $stageDir $norm
        if (Test-Path -LiteralPath $fp -PathType Leaf) {
            $item = Get-Item -LiteralPath $fp
            $sha = (Get-FileHash -LiteralPath $fp -Algorithm SHA256).Hash.ToUpperInvariant()
            return @{ Exists = "Yes"; Size = $item.Length; Sha = $sha; Status = "Verified" }
        }
        return @{ Exists = "No"; Size = 0; Sha = "N/A"; Status = "Missing" }
    }

    $findingSpecs = @(
        @{ Id = "FINDING-01"; Desc = "Shared POSIX ZIP builder and entry hygiene helpers"; RepoPath = "scripts/zip-utils.ps1"; ArchPath = "source/scripts/zip-utils.ps1"; EvRef = "evidence/portability/zip_portability_negative_test.txt" },
        @{ Id = "FINDING-01"; Desc = "Deterministic Git HEAD packaging with forward-slash entries"; RepoPath = "scripts/package-release.ps1"; ArchPath = "source/scripts/package-release.ps1"; EvRef = "evidence/release/source_package_verification.txt" },
        @{ Id = "FINDING-02"; Desc = "44-scenario fail-closed verifier and ZIP portability tests"; RepoPath = "tests/test-verify-release.ps1"; ArchPath = "source/tests/test-verify-release.ps1"; EvRef = "evidence/release/release_verifier_negative_test.txt" },
        @{ Id = "FINDING-03"; Desc = "Handover builder with non-self-ref manifest & 1-to-1 checks"; RepoPath = "scripts/assemble-handover.ps1"; ArchPath = "source/scripts/assemble-handover.ps1"; EvRef = "AUDIT_FILE_MANIFEST.md" },
        @{ Id = "FINDING-04"; Desc = "Fail-closed Git status evidence with metadata and markers"; RepoPath = "scripts/capture-evidence.ps1"; ArchPath = "source/scripts/capture-evidence.ps1"; EvRef = "evidence/git/git_status.txt" },
        @{ Id = "FINDING-04"; Desc = "Post-commit Git status proof inside handover"; RepoPath = "(post-commit generated)"; ArchPath = "evidence/git/git_status.txt"; EvRef = "evidence/git/git_identity_verification.txt" },
        @{ Id = "FINDING-05"; Desc = "Secret scanner reporting target, excluded, allowlist & exit"; RepoPath = "scripts/scan-secrets.ps1"; ArchPath = "source/scripts/scan-secrets.ps1"; EvRef = "evidence/security/secret_scan_repository.txt" },
        @{ Id = "FINDING-06 / GATE-14"; Desc = "14-gate fail-closed verifier (Bidirectional, 4-scan, POSIX 3-way)"; RepoPath = "scripts/verify-release.ps1"; ArchPath = "source/scripts/verify-release.ps1"; EvRef = "evidence/portability/zip_portability_negative_test.txt" },
        @{ Id = "BASELINE"; Desc = "Backend Express API application entrypoint"; RepoPath = "backend/src/app.ts"; ArchPath = "source/backend/src/app.ts"; EvRef = "evidence/backend/backend_test_results.txt" },
        @{ Id = "BASELINE"; Desc = "Backend npm dependency lockfile"; RepoPath = "backend/package-lock.json"; ArchPath = "source/backend/package-lock.json"; EvRef = "source/backend/package.json" },
        @{ Id = "BASELINE"; Desc = "Backend multi-stage Dockerfile"; RepoPath = "backend/Dockerfile"; ArchPath = "source/backend/Dockerfile"; EvRef = "evidence/docker/docker_compose_verification.txt" },
        @{ Id = "BASELINE"; Desc = "Frontend Next.js configuration"; RepoPath = "frontend/next.config.ts"; ArchPath = "source/frontend/next.config.ts"; EvRef = "source/frontend/Dockerfile" },
        @{ Id = "BASELINE"; Desc = "Frontend npm dependency lockfile"; RepoPath = "frontend/package-lock.json"; ArchPath = "source/frontend/package-lock.json"; EvRef = "source/frontend/package.json" },
        @{ Id = "BASELINE"; Desc = "Frontend multi-stage Dockerfile"; RepoPath = "frontend/Dockerfile"; ArchPath = "source/frontend/Dockerfile"; EvRef = "evidence/docker/docker_compose_verification.txt" },
        @{ Id = "BASELINE"; Desc = "Frontend API client and CSRF interceptor"; RepoPath = "frontend/src/lib/api.ts"; ArchPath = "source/frontend/src/lib/api.ts"; EvRef = "evidence/frontend/frontend_test_results.txt" }
    )

    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# StockFlow v1.6.5: Complete Independent Audit Handover Manifest")
    $md.Add("")
    $md.Add("- Generated At: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $md.Add("- Release Version: v1.6.5")
    $md.Add("- Git Branch: $headBranch")
    $md.Add("- Git Commit: $headCommit")
    $md.Add("- Inventory Payload Files (Section 2): $inventoryCount")
    $md.Add("- Mandatory Special Manifest File: AUDIT_FILE_MANIFEST.md (1 file, verified for presence, size, and ZIP CRC)")
    $md.Add("- Total Files in Handover Archive: $totalArchiveFileCount ($inventoryCount inventory files + 1 AUDIT_FILE_MANIFEST.md)")
    $md.Add("- Total Inventory Payload Size: $totalStagedBytes bytes")
    $md.Add("- Self-Reference Rule: AUDIT_FILE_MANIFEST.md does not calculate a self-referential SHA-256 hash inside Section 2 inventory.")
    $md.Add("- Repository Structure Note: StockFlow uses per-workspace package manifests (backend/package.json and frontend/package.json); no root package.json exists in this repository.")
    $md.Add("")
    $md.Add("## 1. Finding Remediation Traceability Matrix")
    $md.Add("")
    $md.Add("| Finding ID | Description | Source Repository Path | Archive Path | File Exists | Size (bytes) | SHA-256 | Evidence Reference | Verification Status |")
    $md.Add("| :--- | :--- | :--- | :--- | :---: | ---: | :--- | :--- | :---: |")

    foreach ($fs in $findingSpecs) {
        $rec = Get-ManifestFileRecord $fs.ArchPath
        if ($rec.Status -ne "Verified") {
            throw "AUDIT_FILE_MANIFEST generation failed: required item '$($fs.ArchPath)' is Missing!"
        }
        $md.Add("| $($fs.Id) | $($fs.Desc) | $($fs.RepoPath) | $($fs.ArchPath) | $($rec.Exists) | $($rec.Size) | $($rec.Sha) | $($fs.EvRef) | $($rec.Status) |")
    }

    $md.Add("")
    $md.Add("## 2. Complete Handover Archive File Inventory ($inventoryCount Non-Manifest Files)")
    $md.Add("")
    $md.Add("| Archive Path | File Exists | Size (bytes) | SHA-256 | Verification Status |")
    $md.Add("| :--- | :---: | ---: | :--- | :---: |")

    $manifestShaMap = @{}
    foreach ($sf in ($stagedFiles | Sort-Object { $_.FullName.Substring($stageDir.Length).TrimStart('\', '/').Replace('\', '/') })) {
        $relUnix = $sf.FullName.Substring($stageDir.Length).TrimStart('\', '/').Replace('\', '/')
        $sha = (Get-FileHash -LiteralPath $sf.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        $manifestShaMap[$relUnix] = @{ Size = [int64]$sf.Length; Hash = $sha }
        $md.Add("| $relUnix | Yes | $($sf.Length) | $sha | Verified |")
    }

    $md.Add("")
    $md.Add("## 3. External Post-Packaging Deliverables (Outside Archive by Design)")
    $md.Add("")
    $md.Add("The outputs below depend on final sealed ZIP hashes or post-seal scanning and sit directly inside release-output/v1.6.5/ outside the ZIP archives:")
    $md.Add("")
    $md.Add("| Artifact Name | Output Location | Purpose | Archive Inclusion |")
    $md.Add("| :--- | :--- | :--- | :--- |")
    $md.Add("| StockFlow_Release_Checksums_v8_5.txt | release-output/v1.6.5/StockFlow_Release_Checksums_v8_5.txt | External SHA-256 manifest | Excluded from all ZIPs |")
    $md.Add("| verification_package_scan.txt | release-output/v1.6.5/evidence/security/verification_package_scan.txt | Secret scan of Verification ZIP | Post-ZIP output |")
    $md.Add("| audit_handover_package_scan.txt | release-output/v1.6.5/evidence/security/audit_handover_package_scan.txt | Secret scan of Handover ZIP | Post-ZIP output |")
    $md.Add("| audit_handover_completeness.txt | release-output/v1.6.5/evidence/handover/audit_handover_completeness.txt | Bidirectional handover check | Post-ZIP output |")
    $md.Add("| zip_portability_verification.txt | release-output/v1.6.5/evidence/portability/zip_portability_verification.txt | 3-engine ZIP parity report | Post-ZIP output |")
    $md.Add("| writing_constraint_verification.txt | release-output/v1.6.5/evidence/release/writing_constraint_verification.txt | Multi-ZIP Markdown dash scan | Post-ZIP output |")
    $md.Add("| release_verification_summary.md | release-output/v1.6.5/evidence/release/release_verification_summary.md | 14-gate summary report | Post-ZIP output |")
    $md.Add("| FINAL_RELEASE_REPORT_V1_6_5.md | release-output/v1.6.5/FINAL_RELEASE_REPORT_V1_6_5.md | Final release sign-off report | Written post-verification |")

    $manifestFilePath = Join-Path $stageDir "AUDIT_FILE_MANIFEST.md"
    [System.IO.File]::WriteAllLines($manifestFilePath, $md, $utf8NoBom)

    Write-Host "[5/6] Compressing StockFlow_Audit_Handover_v8_5.zip using POSIX '/' paths..."
    New-PortableZipArchive -SourceDirectory $stageDir -DestinationZipPath $handoverZipPath | Out-Null

    $entryCheck = Test-ZipArchiveEntries -ZipPath $handoverZipPath
    if (-not $entryCheck.Valid) {
        throw "POSIX ZIP validation failed on Handover ZIP: $($entryCheck.Violations -join '; ')"
    }

    Write-Host "[6/6] Re-extracting StockFlow_Audit_Handover_v8_5.zip for bidirectional 1-to-1 verification..."
    [System.IO.Compression.ZipFile]::ExtractToDirectory($handoverZipPath, $reExtractDir)

    $extractedFiles = @(Get-ChildItem -LiteralPath $reExtractDir -Recurse -File | Sort-Object FullName)
    if ($extractedFiles.Count -ne $totalArchiveFileCount) {
        throw "Handover extraction count mismatch! Expected $totalArchiveFileCount files ($inventoryCount inventory + 1 manifest), extracted $($extractedFiles.Count)."
    }

    $hashVerifiedCount = 0
    $extraUnlistedCount = 0
    $seenExtracted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $catCounts = @{ backend = 0; frontend = 0; root = 0; scripts = 0; tests = 0; evidence = 0; documentation = 0; manifest = 0 }

    foreach ($ef in $extractedFiles) {
        $relUnix = $ef.FullName.Substring($reExtractDir.Length).TrimStart('\', '/').Replace('\', '/')
        if (-not $seenExtracted.Add($relUnix)) {
            throw "Duplicate extracted file detected in Handover ZIP: '$relUnix'"
        }
        if ($relUnix -eq "AUDIT_FILE_MANIFEST.md") {
            $catCounts.manifest++
            continue
        }
        if (-not $manifestShaMap.ContainsKey($relUnix)) {
            $extraUnlistedCount++
            throw "Archive-to-Manifest check FAILED: extra unlisted file '$relUnix' exists in Handover ZIP!"
        }
        $actualSha = (Get-FileHash -LiteralPath $ef.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualSha -cne $manifestShaMap[$relUnix].Hash) {
            throw "Hash Mismatch on extracted file '$relUnix'!"
        }
        if ([int64]$ef.Length -ne $manifestShaMap[$relUnix].Size) {
            throw "Size Mismatch on extracted file '$relUnix'!"
        }
        $hashVerifiedCount++
        if ($relUnix.StartsWith("source/backend/")) { $catCounts.backend++ }
        elseif ($relUnix.StartsWith("source/frontend/")) { $catCounts.frontend++ }
        elseif ($relUnix.StartsWith("source/root/")) { $catCounts.root++ }
        elseif ($relUnix.StartsWith("source/scripts/")) { $catCounts.scripts++ }
        elseif ($relUnix.StartsWith("source/tests/")) { $catCounts.tests++ }
        elseif ($relUnix.StartsWith("evidence/")) { $catCounts.evidence++ }
        elseif ($relUnix.StartsWith("documentation/")) { $catCounts.documentation++ }
    }

    if ($hashVerifiedCount -ne $inventoryCount) {
        throw "Manifest-to-Archive check FAILED: expected $inventoryCount inventory entries, verified $hashVerifiedCount!"
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scannerScript -TargetScanPath $handoverZipPath -OutputFile $handoverScanReportPath | Out-Null
        $scanExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($scanExit -ne 0) {
        throw "Secret scan failed on $handoverZipPath (Exit: $scanExit)"
    }

    $zipSize = (Get-Item -LiteralPath $handoverZipPath).Length
    $zipHash = (Get-FileHash -LiteralPath $handoverZipPath -Algorithm SHA256).Hash.ToUpperInvariant()

    $compText = @"
================================================================================
STOCKFLOW v1.6.5 - BIDIRECTIONAL AUDIT HANDOVER COMPLETENESS VERIFICATION
================================================================================
Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Archive Path: $handoverZipPath
Git Commit: $headCommit
Git Branch: $headBranch
Archive Byte Size: $zipSize bytes
Archive SHA-256: $zipHash
ZIP POSIX Separator Check: $($entryCheck.BackslashCount) backslashes across $($entryCheck.EntryCount) entries (PASS)

--- Bidirectional Inventory Check (Manifest <-> Archive) ---
Total Files in Archive (Inventory + AUDIT_FILE_MANIFEST.md): $($extractedFiles.Count)
Section 2 Manifest Inventory Rows: $inventoryCount
Manifest -> Archive Verified (Exact Size + SHA-256 Match): $hashVerifiedCount
Archive -> Manifest Unlisted Extra Files: $extraUnlistedCount
Duplicate Inventory Paths: 0
Missing Files: 0
Hash Mismatches: 0
Size Mismatches: 0
Mandatory Special Manifest File (AUDIT_FILE_MANIFEST.md): PRESENT ($($catCounts.manifest) file; excluded from self-hash by design)

Category Breakdown:
- source/root/          : $($catCounts.root) files (README, SPEC, .gitignore, .env.example, 5 compose files)
- source/backend/       : $($catCounts.backend) files (src/, prisma/, tests/, package.json, package-lock.json, Dockerfile, .env.example, configs)
- source/frontend/      : $($catCounts.frontend) files (src/, public/, tests/, package.json, package-lock.json, Dockerfile, .env.example, next.config.ts, configs)
- source/scripts/       : $($catCounts.scripts) files (including zip-utils.ps1)
- source/tests/         : $($catCounts.tests) files
- evidence/             : $($catCounts.evidence) files
- documentation/        : $($catCounts.documentation) files
- AUDIT_FILE_MANIFEST.md: $($catCounts.manifest) file

--- Secret Scan Verification ---
Scan Script: scripts/scan-secrets.ps1
Exit Code: $scanExit
Report: evidence/security/audit_handover_package_scan.txt
Status: 100% CLEAN (0 findings)

COMPLETENESS STATUS: 100% VERIFIED COMPLETE
================================================================================
"@
    [System.IO.File]::WriteAllText($completenessReportPath, $compText, $utf8NoBom)
    Write-Host "[OK] Audit Handover ZIP verified ($($extractedFiles.Count) files, 0 extra, 0 missing, 0 backslashes)."
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
