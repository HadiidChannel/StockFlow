# ==============================================================================
# StockFlow - Complete Independent Audit Handover Assembler & Verifier (v1.6.4)
# Script: scripts/assemble-handover.ps1
# Description: Builds StockFlow_Audit_Handover_v8_4.zip exclusively from
#              committed Git HEAD plus verified v1.6.4 & inherited evidence.
#              Generates AUDIT_FILE_MANIFEST.md dynamically, validates 100%
#              file & SHA-256 accuracy, extracts the sealed ZIP for independent
#              verification, scans for secrets, and outputs completeness proof.
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
if ([string]::IsNullOrWhiteSpace($ReleaseOutputDir)) {
    $outDir = Join-Path $projectRoot "release-output\v1.6.4"
} else {
    $outDir = (Resolve-Path $ReleaseOutputDir).Path
}

$evRoot = Join-Path $outDir "evidence"
$scannerScript = Join-Path $scriptDir "scan-secrets.ps1"
$handoverZipPath = Join-Path $outDir "StockFlow_Audit_Handover_v8_4.zip"
$completenessReportPath = Join-Path $evRoot "release\audit_handover_completeness.txt"
$handoverScanReportPath = Join-Path $evRoot "security\audit_handover_package_scan.txt"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

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
Write-Host " StockFlow Audit Handover Assembler (v1.6.4)"
Write-Host " Source Commit: $headCommit ($headBranch)"
Write-Host " Target Archive: $handoverZipPath"
Write-Host "======================================================================"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_handover_build_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$gitExportZip = Join-Path $tempRoot "head_export.zip"
$gitExportDir = Join-Path $tempRoot "head_src"
$stageDir = Join-Path $tempRoot "handover_stage"
$reExtractDir = Join-Path $tempRoot "handover_verify"

try {
    New-Item -ItemType Directory -Path $gitExportDir, $stageDir, $reExtractDir -Force | Out-Null

    # 1. Export clean committed repository snapshot via git archive HEAD
    Write-Host "[1/6] Exporting clean repository state at commit $headCommit..."
    $archRes = Invoke-GitLocal @("archive", "--format=zip", "--output=$gitExportZip", "HEAD")
    if ($archRes.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $gitExportZip)) {
        throw "git archive HEAD failed: $($archRes.Output)"
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($gitExportZip, $gitExportDir)

    # 2. Populate Stage Structure from Clean Committed Export + Current Evidence
    Write-Host "[2/6] Staging complete root, backend, frontend, scripts, tests, evidence, docs..."
    $sourceOut = Join-Path $stageDir "source"
    New-Item -ItemType Directory -Path (Join-Path $sourceOut "root"), (Join-Path $stageDir "evidence"), (Join-Path $stageDir "documentation") -Force | Out-Null

    # 2a. Root configuration & compose files (no synthetic files; only real repository files)
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

    # 2b. Complete Backend Workspace (manifests, lockfile, Dockerfile, configs, prisma, src, tests)
    $backendExport = Join-Path $gitExportDir "backend"
    $backendDest = Join-Path $sourceOut "backend"
    Copy-Item -Path $backendExport -Destination $sourceOut -Recurse -Force

    # 2c. Complete Frontend Workspace (manifests, lockfile, Dockerfile, configs, src, public, tests)
    $frontendExport = Join-Path $gitExportDir "frontend"
    $frontendDest = Join-Path $sourceOut "frontend"
    Copy-Item -Path $frontendExport -Destination $sourceOut -Recurse -Force

    # 2d. Complete Scripts & Test Harnesses
    Copy-Item -Path (Join-Path $gitExportDir "scripts") -Destination $sourceOut -Recurse -Force
    Copy-Item -Path (Join-Path $gitExportDir "tests") -Destination $sourceOut -Recurse -Force

    # 2e. Evidence Tree (v1.6.4 + inherited v1.6.3 under exact organizational categories)
    if (-not (Test-Path -LiteralPath $evRoot)) {
        throw "Evidence root missing at '$evRoot'. Run scripts/capture-evidence.ps1 first."
    }
    Copy-Item -Path (Join-Path $evRoot "*") -Destination (Join-Path $stageDir "evidence") -Recurse -Force

    # 2f. Documentation (Engineering documentation tracked in Git HEAD)
    $engDocsExport = Join-Path $gitExportDir "docs\engineering"
    if (Test-Path -LiteralPath $engDocsExport) {
        Copy-Item -Path (Join-Path $engDocsExport "*") -Destination (Join-Path $stageDir "documentation") -Recurse -Force
    }

    # Verify exclusion rules strictly (ensure zero secrets, node_modules, .next, dist, checksum manifests)
    $stagedFilesPre = @(Get-ChildItem -Path $stageDir -Recurse -File)
    foreach ($sf in $stagedFilesPre) {
        $rel = $sf.FullName.Substring($stageDir.Length).TrimStart('\', '/')
        if ($sf.Name -match '^StockFlow_Release_Checksums.*\.txt$' -or $sf.Name -eq '.env' -or $sf.Name -eq '.env.local' -or $rel -match '(?:^|[\\/])(?:\.secrets|node_modules|\.next|dist)(?:[\\/]|$)') {
            throw "Handover exclusion rule violated by staged file: $rel"
        }
    }

    # 3. Strict Mandatory File Presence Validation
    Write-Host "[3/6] Validating mandatory files across backend, frontend, root, scripts, tests, evidence, docs..."
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
        "evidence/release/release_verifier_negative_test.txt",
        "evidence/release/source_package_verification.txt",
        "evidence/release/test_reconciliation.txt",
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

    # 4. Generate Dynamic & Exact AUDIT_FILE_MANIFEST.md
    Write-Host "[4/6] Generating AUDIT_FILE_MANIFEST.md from actual staged files..."
    $stagedFiles = @(Get-ChildItem -Path $stageDir -Recurse -File | Sort-Object FullName)
    $totalStagedCount = $stagedFiles.Count
    $totalStagedBytes = ($stagedFiles | Measure-Object -Property Length -Sum).Sum

    function Get-ManifestFileRecord([string]$relArchivePath) {
        $norm = $relArchivePath.Replace('/', '\')
        $fp = Join-Path $stageDir $norm
        if (Test-Path -LiteralPath $fp -PathType Leaf) {
            $sha = (Get-FileHash -LiteralPath $fp -Algorithm SHA256).Hash.ToUpperInvariant()
            return @{ Exists = "Yes"; Sha = $sha; Status = "Verified" }
        }
        return @{ Exists = "No"; Sha = "N/A"; Status = "Missing" }
    }

    $findingSpecs = @(
        @{ Id = "FINDING-01"; Desc = "Fail-closed release verifier (commit, branch, dirty tree)"; RepoPath = "scripts/verify-release.ps1"; ArchPath = "source/scripts/verify-release.ps1"; EvRef = "evidence/release/release_verifier_negative_test.txt" },
        @{ Id = "FINDING-01"; Desc = "Isolated 13-scenario verifier negative & positive test suite"; RepoPath = "tests/test-verify-release.ps1"; ArchPath = "source/tests/test-verify-release.ps1"; EvRef = "evidence/release/release_verifier_negative_test.txt" },
        @{ Id = "FINDING-02"; Desc = "Post-commit clean Git identity evidence"; RepoPath = "(post-commit generated)"; ArchPath = "evidence/git/git_commit.txt"; EvRef = "evidence/git/git_identity_verification.txt" },
        @{ Id = "FINDING-02"; Desc = "Post-commit clean working tree status evidence"; RepoPath = "(post-commit generated)"; ArchPath = "evidence/git/git_status.txt"; EvRef = "evidence/git/git_identity_verification.txt" },
        @{ Id = "FINDING-03"; Desc = "Deterministic Git HEAD source packaging excluding manifests"; RepoPath = "scripts/package-release.ps1"; ArchPath = "source/scripts/package-release.ps1"; EvRef = "evidence/release/source_package_verification.txt" },
        @{ Id = "FINDING-03"; Desc = "Root environment template preserved"; RepoPath = ".env.example"; ArchPath = "source/root/.env.example"; EvRef = "evidence/release/source_package_verification.txt" },
        @{ Id = "FINDING-03"; Desc = "Backend environment template preserved"; RepoPath = "backend/.env.example"; ArchPath = "source/backend/.env.example"; EvRef = "evidence/release/source_package_verification.txt" },
        @{ Id = "FINDING-03"; Desc = "Frontend environment template preserved"; RepoPath = "frontend/.env.example"; ArchPath = "source/frontend/.env.example"; EvRef = "evidence/release/source_package_verification.txt" },
        @{ Id = "FINDING-04"; Desc = "Complete handover builder and verifier script"; RepoPath = "scripts/assemble-handover.ps1"; ArchPath = "source/scripts/assemble-handover.ps1"; EvRef = "AUDIT_FILE_MANIFEST.md" },
        @{ Id = "FINDING-04"; Desc = "Backend Express API application entrypoint"; RepoPath = "backend/src/app.ts"; ArchPath = "source/backend/src/app.ts"; EvRef = "evidence/backend/backend_test_results.txt" },
        @{ Id = "FINDING-04"; Desc = "Backend npm dependency lockfile"; RepoPath = "backend/package-lock.json"; ArchPath = "source/backend/package-lock.json"; EvRef = "source/backend/package.json" },
        @{ Id = "FINDING-04"; Desc = "Backend multi-stage Dockerfile"; RepoPath = "backend/Dockerfile"; ArchPath = "source/backend/Dockerfile"; EvRef = "evidence/docker/docker_compose_verification.txt" },
        @{ Id = "FINDING-04"; Desc = "Frontend Next.js configuration (reverse proxy rewrites)"; RepoPath = "frontend/next.config.ts"; ArchPath = "source/frontend/next.config.ts"; EvRef = "source/frontend/Dockerfile" },
        @{ Id = "FINDING-04"; Desc = "Frontend npm dependency lockfile"; RepoPath = "frontend/package-lock.json"; ArchPath = "source/frontend/package-lock.json"; EvRef = "source/frontend/package.json" },
        @{ Id = "FINDING-04"; Desc = "Frontend multi-stage Dockerfile"; RepoPath = "frontend/Dockerfile"; ArchPath = "source/frontend/Dockerfile"; EvRef = "evidence/docker/docker_compose_verification.txt" },
        @{ Id = "FINDING-04"; Desc = "Frontend API client and CSRF interceptor"; RepoPath = "frontend/src/lib/api.ts"; ArchPath = "source/frontend/src/lib/api.ts"; EvRef = "evidence/frontend/frontend_test_results.txt" }
    )

    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# StockFlow v1.6.4: Complete Independent Audit Handover Manifest")
    $md.Add("")
    $md.Add("- Generated At: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $md.Add("- Release Version: v1.6.4")
    $md.Add("- Git Branch: $headBranch")
    $md.Add("- Git Commit: $headCommit")
    $md.Add("- Total Files in Handover Archive: $($totalStagedCount + 1) (including this manifest)")
    $md.Add("- Total Staged Payload Size: $totalStagedBytes bytes")
    $md.Add("- Repository Structure Note: StockFlow uses per-workspace package manifests (backend/package.json and frontend/package.json). There is no root package.json in this repository.")
    $md.Add("")
    $md.Add("## 1. Finding Remediation Traceability Matrix")
    $md.Add("")
    $md.Add("| Finding ID | Description | Source Repository Path | Archive Path | File Exists | SHA-256 | Evidence Reference | Verification Status |")
    $md.Add("| :--- | :--- | :--- | :--- | :---: | :--- | :--- | :---: |")

    foreach ($fs in $findingSpecs) {
        $rec = Get-ManifestFileRecord $fs.ArchPath
        if ($rec.Status -ne "Verified") {
            throw "AUDIT_FILE_MANIFEST generation failed: required finding item '$($fs.ArchPath)' is Missing!"
        }
        $md.Add("| $($fs.Id) | $($fs.Desc) | $($fs.RepoPath) | $($fs.ArchPath) | $($rec.Exists) | $($rec.Sha) | $($fs.EvRef) | $($rec.Status) |")
    }

    $md.Add("")
    $md.Add("## 2. Complete Handover Archive File Inventory")
    $md.Add("")
    $md.Add("| Archive Path | File Exists | Size (bytes) | SHA-256 | Verification Status |")
    $md.Add("| :--- | :---: | ---: | :--- | :---: |")

    $manifestShaMap = @{}
    foreach ($sf in $stagedFiles) {
        $relUnix = $sf.FullName.Substring($stageDir.Length).TrimStart('\', '/').Replace('\', '/')
        $sha = (Get-FileHash -LiteralPath $sf.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        $manifestShaMap[$relUnix] = @{ Size = $sf.Length; Hash = $sha }
        $md.Add("| $relUnix | Yes | $($sf.Length) | $sha | Verified |")
    }

    $md.Add("")
    $md.Add("## 3. External Post-Packaging Deliverables (Outside Archive by Design)")
    $md.Add("")
    $md.Add("The following outputs depend on the final SHA-256 hashes of the sealed ZIP packages and verification gates. Per Section 10.4, Section 11, and Section 14, they sit directly inside release-output/v1.6.4/ outside the ZIP archives to prevent circular hashes:")
    $md.Add("")
    $md.Add("| Artifact Name | Output Location | Purpose | Archive Inclusion |")
    $md.Add("| :--- | :--- | :--- | :--- |")
    $md.Add("| StockFlow_Release_Checksums_v8_4.txt | release-output/v1.6.4/StockFlow_Release_Checksums_v8_4.txt | External SHA-256 checksum manifest | Excluded from all ZIPs |")
    $md.Add("| release_verification_summary.md | release-output/v1.6.4/evidence/release/release_verification_summary.md | Post-packaging 13-gate report | Post-ZIP output |")
    $md.Add("| verification_package_scan.txt | release-output/v1.6.4/evidence/security/verification_package_scan.txt | Secret scan of Verification ZIP | Post-ZIP output |")
    $md.Add("| FINAL_RELEASE_REPORT_V1_6_4.md | release-output/v1.6.4/FINAL_RELEASE_REPORT_V1_6_4.md | Final release sign-off report | Written post-verification |")

    $manifestFilePath = Join-Path $stageDir "AUDIT_FILE_MANIFEST.md"
    [System.IO.File]::WriteAllLines($manifestFilePath, $md, $utf8NoBom)

    # 5. Compress into StockFlow_Audit_Handover_v8_4.zip
    Write-Host "[5/6] Compressing StockFlow_Audit_Handover_v8_4.zip..."
    if (Test-Path -LiteralPath $handoverZipPath) {
        Remove-Item -LiteralPath $handoverZipPath -Force
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $handoverZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

    # 6. Extract Re-Verification & Secret Scan
    Write-Host "[6/6] Re-extracting StockFlow_Audit_Handover_v8_4.zip to verify 100% completeness & hashes..."
    [System.IO.Compression.ZipFile]::ExtractToDirectory($handoverZipPath, $reExtractDir)

    $extractedFiles = @(Get-ChildItem -Path $reExtractDir -Recurse -File | Sort-Object FullName)
    $expectedTotal = $stagedFiles.Count + 1 # +1 for AUDIT_FILE_MANIFEST.md
    if ($extractedFiles.Count -ne $expectedTotal) {
        throw "Handover extraction count mismatch! Expected $expectedTotal files, extracted $($extractedFiles.Count)."
    }

    $hashVerifiedCount = 0
    $catCounts = @{ backend = 0; frontend = 0; root = 0; scripts = 0; tests = 0; evidence = 0; documentation = 0; manifest = 0 }
    foreach ($ef in $extractedFiles) {
        $relUnix = $ef.FullName.Substring($reExtractDir.Length).TrimStart('\', '/').Replace('\', '/')
        if ($relUnix -eq "AUDIT_FILE_MANIFEST.md") {
            $catCounts.manifest++
            continue
        }
        if (-not $manifestShaMap.ContainsKey($relUnix)) {
            throw "Extracted file '$relUnix' missing from AUDIT_FILE_MANIFEST.md!"
        }
        $actualSha = (Get-FileHash -LiteralPath $ef.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualSha -cne $manifestShaMap[$relUnix].Hash -or $ef.Length -ne $manifestShaMap[$relUnix].Size) {
            throw "Extracted file hash/size mismatch on '$relUnix'!"
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

    # Scan Handover ZIP for secrets
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
STOCKFLOW v1.6.4 - AUDIT HANDOVER COMPLETENESS VERIFICATION
================================================================================
Timestamp: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Archive Path: $handoverZipPath
Git Commit: $headCommit
Git Branch: $headBranch
Archive Byte Size: $zipSize bytes
Archive SHA-256: $zipHash

--- File Count & Category Coverage ---
Total Extracted Files: $($extractedFiles.Count) (Expected: $expectedTotal)
Manifest Inventory Rows Verified (1-to-1 Hash + Size Match): $hashVerifiedCount
Missing Files: 0
False Verified Claims: 0

Category Breakdown:
- source/root/          : $($catCounts.root) files (README, SPEC, .gitignore, .env.example, 5 compose files; root package.json N/A in this repo)
- source/backend/       : $($catCounts.backend) files (src/, prisma/, tests/, package.json, package-lock.json, Dockerfile, .env.example, configs)
- source/frontend/      : $($catCounts.frontend) files (src/, public/, tests/, package.json, package-lock.json, Dockerfile, .env.example, next.config.ts, configs)
- source/scripts/       : $($catCounts.scripts) files
- source/tests/         : $($catCounts.tests) files
- evidence/             : $($catCounts.evidence) files (v1.6.4 + labeled inherited v1.6.3 evidence)
- documentation/        : $($catCounts.documentation) files (engineering docs)
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
    Write-Host "[OK] Audit Handover ZIP & Completeness Proof verified ($($extractedFiles.Count) files, 0 missing)."
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
