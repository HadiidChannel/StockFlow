# ==============================================================================
# StockFlow v1.6.4 - Negative & Positive Test Suite for scripts/verify-release.ps1
# File: tests/test-verify-release.ps1
# Description: Executes 13 isolated scenarios against scripts/verify-release.ps1
#              using temporary Git repositories and fixture archives in %TEMP%.
#              Never modifies or dirties the main StockFlow repository.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$verifyScript = Join-Path $projectRoot "scripts\verify-release.ps1"

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$logLines = [System.Collections.Generic.List[string]]::new()

function Write-TestLog([string]$msg) {
    Write-Host $msg
    $logLines.Add($msg)
}

Write-TestLog "======================================================================"
Write-TestLog " StockFlow Release Verifier Test Suite (Negative & Positive Tests)"
Write-TestLog " Target Script: $verifyScript"
Write-TestLog " Execution Time: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
Write-TestLog "======================================================================"

function New-ZipFromDirectory([string]$sourceDir, [string]$zipPath) {
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($sourceDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
}

function Invoke-GitSafe([string]$repoPath, [string[]]$gitArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $allArgs = @("-C", $repoPath) + $gitArgs
        $out = & git.exe $allArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "Git command failed (git $($allArgs -join ' ')): $out"
        }
        return $out.Trim()
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Invoke-Verifier([string]$repoPath, [string]$releaseDir, [string]$branch = "fix/stockflow-v16-4-release-integrity", [string]$customPathEnv = "") {
    $prevEap = $ErrorActionPreference
    $prevPath = $env:PATH
    $ErrorActionPreference = "Continue"
    try {
        if (-not [string]::IsNullOrWhiteSpace($customPathEnv)) {
            $env:PATH = $customPathEnv
        }
        $cmdArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $verifyScript,
            "-RepositoryRoot", $repoPath,
            "-TargetDirectory", $releaseDir,
            "-ExpectedBranch", $branch
        )
        $out = & powershell.exe $cmdArgs 2>&1 | Out-String
        return [PSCustomObject]@{
            Output = $out
            ExitCode = $LASTEXITCODE
        }
    } finally {
        $env:PATH = $prevPath
        $ErrorActionPreference = $prevEap
    }
}

function Get-GateFailureLine([string]$outText) {
    $failLine = ($outText -split "`r?`n" | Where-Object { $_ -match '\[GATE-\d+\]\s+FAIL' } | Select-Object -First 1)
    if ($failLine) { return $failLine.Trim() }
    return (($outText.Trim() -split "`r?`n" | Select-Object -Last 2) -join " | ")
}

function New-IsolatedFixture {
    param(
        [string]$BaseDir,
        [string]$BranchName = "fix/stockflow-v16-4-release-integrity",
        [switch]$IncludeHistoricalManifestInSource,
        [switch]$IncludeMissingVerifiedClaimInHandover,
        [string]$OverrideHandoverCommit = ""
    )

    if (Test-Path -LiteralPath $BaseDir) { Remove-Item -LiteralPath $BaseDir -Recurse -Force }
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

    $repoDir = Join-Path $BaseDir "repo"
    New-Item -ItemType Directory -Path $repoDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repoDir "backend") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repoDir "frontend") -Force | Out-Null

    # Minimal clean repo contents
    [System.IO.File]::WriteAllText((Join-Path $repoDir ".gitignore"), "release-output/`n*.zip`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $repoDir ".env.example"), "DB_PASSWORD=`"your_strong_password_here`"`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $repoDir "backend\.env.example"), "PORT=4000`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $repoDir "frontend\.env.example"), "PORT=3000`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $repoDir "README.md"), "# Fixture Repo`nClean readme.`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $repoDir "docker-compose.yml"), "services:`n  frontend:`n    ports:`n      - `"127.0.0.1:3000:3000`"`n", $utf8NoBom)

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git.exe init -b $BranchName "$repoDir" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            & git.exe init "$repoDir" 2>&1 | Out-Null
            & git.exe -C "$repoDir" checkout -b $BranchName 2>&1 | Out-Null
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }

    Invoke-GitSafe $repoDir @("config", "user.name", "Fixture Tester") | Out-Null
    Invoke-GitSafe $repoDir @("config", "user.email", "tester@stockflow.local") | Out-Null
    Invoke-GitSafe $repoDir @("add", "-A") | Out-Null
    Invoke-GitSafe $repoDir @("commit", "-m", "Initial fixture baseline") | Out-Null
    $commitHash = Invoke-GitSafe $repoDir @("rev-parse", "HEAD")

    $releaseDir = Join-Path $repoDir "release-output\v1.6.4"
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

    # Stage Source ZIP
    $srcStage = Join-Path $BaseDir "stage_src"
    New-Item -ItemType Directory -Path (Join-Path $srcStage "backend") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $srcStage "frontend") -Force | Out-Null
    Copy-Item (Join-Path $repoDir ".gitignore") $srcStage -Force
    Copy-Item (Join-Path $repoDir ".env.example") $srcStage -Force
    Copy-Item (Join-Path $repoDir "backend\.env.example") (Join-Path $srcStage "backend") -Force
    Copy-Item (Join-Path $repoDir "frontend\.env.example") (Join-Path $srcStage "frontend") -Force
    Copy-Item (Join-Path $repoDir "README.md") $srcStage -Force
    Copy-Item (Join-Path $repoDir "docker-compose.yml") $srcStage -Force
    if ($IncludeHistoricalManifestInSource) {
        [System.IO.File]::WriteAllText((Join-Path $srcStage "StockFlow_Release_Checksums_v8_2.txt"), "stale", $utf8NoBom)
    }
    $srcZip = Join-Path $releaseDir "StockFlow_Final_v8_4.zip"
    New-ZipFromDirectory $srcStage $srcZip

    $evCommit = if ([string]::IsNullOrWhiteSpace($OverrideHandoverCommit)) { $commitHash } else { $OverrideHandoverCommit }

    # Stage Verification ZIP
    $verStage = Join-Path $BaseDir "stage_ver"
    New-Item -ItemType Directory -Path (Join-Path $verStage "evidence\git") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $verStage "documentation") -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $verStage "evidence\git\git_commit.txt"), "$evCommit`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $verStage "evidence\git\git_branch.txt"), "$BranchName`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $verStage "evidence\git\git_status.txt"), "CLEAN (0 uncommitted changes)`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $verStage "documentation\README.md"), "# Verification Docs`nClean ASCII only.`n", $utf8NoBom)
    $verZip = Join-Path $releaseDir "StockFlow_Final_Verification_v8_4.zip"
    New-ZipFromDirectory $verStage $verZip

    # Stage Audit Handover ZIP
    $hanStage = Join-Path $BaseDir "stage_han"
    New-Item -ItemType Directory -Path (Join-Path $hanStage "source\root") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $hanStage "source\backend") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $hanStage "source\frontend") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $hanStage "evidence\git") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $hanStage "documentation") -Force | Out-Null

    Copy-Item (Join-Path $repoDir ".env.example") (Join-Path $hanStage "source\root\.env.example") -Force
    Copy-Item (Join-Path $repoDir "backend\.env.example") (Join-Path $hanStage "source\backend\.env.example") -Force
    Copy-Item (Join-Path $repoDir "frontend\.env.example") (Join-Path $hanStage "source\frontend\.env.example") -Force
    [System.IO.File]::WriteAllText((Join-Path $hanStage "evidence\git\git_commit.txt"), "$evCommit`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $hanStage "evidence\git\git_branch.txt"), "$BranchName`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $hanStage "evidence\git\git_status.txt"), "CLEAN (0 uncommitted changes)`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $hanStage "documentation\README.md"), "# Handover Docs`nClean ASCII only.`n", $utf8NoBom)

    $extraClaim = ""
    if ($IncludeMissingVerifiedClaimInHandover) {
        $extraClaim = "`n| F-99 | Fake missing file | missing.txt | source/root/missing.txt | Yes | N/A | none | Verified |"
    }

    $manifestMd = @"
# AUDIT FILE MANIFEST
| Finding ID | Description | Source Repository Path | Archive Path | File Exists | SHA-256 | Evidence Reference | Verification Status |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- | :--- |
| F-01 | Root env template | .env.example | source/root/.env.example | Yes | N/A | none | Verified |
| F-02 | Backend env template | backend/.env.example | source/backend/.env.example | Yes | N/A | none | Verified |
| F-03 | Frontend env template | frontend/.env.example | source/frontend/.env.example | Yes | N/A | none | Verified |
| F-04 | Git commit evidence | evidence/git/git_commit.txt | evidence/git/git_commit.txt | Yes | N/A | none | Verified |$extraClaim
"@
    [System.IO.File]::WriteAllText((Join-Path $hanStage "AUDIT_FILE_MANIFEST.md"), $manifestMd, $utf8NoBom)
    $hanZip = Join-Path $releaseDir "StockFlow_Audit_Handover_v8_4.zip"
    New-ZipFromDirectory $hanStage $hanZip

    $s1 = (Get-Item -LiteralPath $srcZip).Length; $h1 = (Get-FileHash -LiteralPath $srcZip -Algorithm SHA256).Hash.ToUpperInvariant()
    $s2 = (Get-Item -LiteralPath $verZip).Length; $h2 = (Get-FileHash -LiteralPath $verZip -Algorithm SHA256).Hash.ToUpperInvariant()
    $s3 = (Get-Item -LiteralPath $hanZip).Length; $h3 = (Get-FileHash -LiteralPath $hanZip -Algorithm SHA256).Hash.ToUpperInvariant()

    $manifestTxt = @"
=== STOCKFLOW OFFICIAL RELEASE MANIFEST (v1.6.4) ===

Release Version: v1.6.4
Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
Git Branch: $BranchName
Git Commit: $commitHash
Working Tree: Clean

Package 1:
Name: StockFlow_Final_v8_4.zip
Description: Source Code Package
Size: $s1 bytes
SHA-256: $h1

Package 2:
Name: StockFlow_Final_Verification_v8_4.zip
Description: Verification Evidence Package
Size: $s2 bytes
SHA-256: $h2

Package 3:
Name: StockFlow_Audit_Handover_v8_4.zip
Description: Audit Handover Package
Size: $s3 bytes
SHA-256: $h3
"@
    $manifestPath = Join-Path $releaseDir "StockFlow_Release_Checksums_v8_4.txt"
    [System.IO.File]::WriteAllText($manifestPath, $manifestTxt, $utf8NoBom)

    return [PSCustomObject]@{
        BaseDir = $BaseDir
        RepoDir = $repoDir
        ReleaseDir = $releaseDir
        CommitHash = $commitHash
        BranchName = $BranchName
        ManifestPath = $manifestPath
        SourceZip = $srcZip
        VerifyZip = $verZip
        HandoverZip = $hanZip
    }
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_verifier_tests_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$totalScenarios = 13
$passedScenarios = 0

try {
    # Scenario 1: Commit match, clean working tree -> PASS
    Write-TestLog "`n[Scenario 01/13] Matching commit, matching branch, clean tree -> EXPECT PASS"
    $f1 = New-IsolatedFixture (Join-Path $workRoot "s01")
    $r1 = Invoke-Verifier $f1.RepoDir $f1.ReleaseDir
    Write-TestLog "ExitCode: $($r1.ExitCode)"
    if ($r1.ExitCode -ne 0) {
        Write-TestLog "Output:`n$($r1.Output)"
        throw "Scenario 01 FAILED: Expected exit code 0, got $($r1.ExitCode)."
    }
    $passedScenarios++
    Write-TestLog "[Scenario 01 PASSED] All gates returned 0."

    # Scenario 2: Commit mismatch -> EXPECT FAIL
    Write-TestLog "`n[Scenario 02/13] Full commit hash mismatch -> EXPECT FAIL"
    $f2 = New-IsolatedFixture (Join-Path $workRoot "s02")
    $fakeCommit = "0000000000000000000000000000000000000000"
    if ($f2.CommitHash -eq $fakeCommit) { $fakeCommit = "ffffffffffffffffffffffffffffffffffffffff" }
    $m2 = (Get-Content -LiteralPath $f2.ManifestPath -Raw).Replace($f2.CommitHash, $fakeCommit)
    [System.IO.File]::WriteAllText($f2.ManifestPath, $m2, $utf8NoBom)
    $r2 = Invoke-Verifier $f2.RepoDir $f2.ReleaseDir
    Write-TestLog "ExitCode: $($r2.ExitCode) | Detail: $(Get-GateFailureLine $r2.Output)"
    if ($r2.ExitCode -eq 0) { throw "Scenario 02 FAILED: Verifier allowed commit mismatch!" }
    $passedScenarios++
    Write-TestLog "[Scenario 02 PASSED] Rejected commit mismatch (Exit: $($r2.ExitCode))."

    # Scenario 3: Branch mismatch -> EXPECT FAIL
    Write-TestLog "`n[Scenario 03/13] Active branch mismatch -> EXPECT FAIL"
    $f3 = New-IsolatedFixture (Join-Path $workRoot "s03") -BranchName "wrong-branch"
    $r3 = Invoke-Verifier $f3.RepoDir $f3.ReleaseDir -branch "fix/stockflow-v16-4-release-integrity"
    Write-TestLog "ExitCode: $($r3.ExitCode) | Detail: $(Get-GateFailureLine $r3.Output)"
    if ($r3.ExitCode -eq 0) { throw "Scenario 03 FAILED: Verifier allowed branch mismatch!" }
    $passedScenarios++
    Write-TestLog "[Scenario 03 PASSED] Rejected branch mismatch (Exit: $($r3.ExitCode))."

    # Scenario 4: Working tree modified -> EXPECT FAIL
    Write-TestLog "`n[Scenario 04/13] Modified tracked file (dirty working tree) -> EXPECT FAIL"
    $f4 = New-IsolatedFixture (Join-Path $workRoot "s04")
    [System.IO.File]::AppendAllText((Join-Path $f4.RepoDir "README.md"), "uncommitted modification`n", $utf8NoBom)
    $r4 = Invoke-Verifier $f4.RepoDir $f4.ReleaseDir
    Write-TestLog "ExitCode: $($r4.ExitCode) | Detail: $(Get-GateFailureLine $r4.Output)"
    if ($r4.ExitCode -eq 0) { throw "Scenario 04 FAILED: Verifier allowed modified tracked file!" }
    $passedScenarios++
    Write-TestLog "[Scenario 04 PASSED] Rejected dirty modified working tree (Exit: $($r4.ExitCode))."

    # Scenario 5: Untracked file -> EXPECT FAIL
    Write-TestLog "`n[Scenario 05/13] Untracked file present in working tree -> EXPECT FAIL"
    $f5 = New-IsolatedFixture (Join-Path $workRoot "s05")
    [System.IO.File]::WriteAllText((Join-Path $f5.RepoDir "untracked_stray.txt"), "stray", $utf8NoBom)
    $r5 = Invoke-Verifier $f5.RepoDir $f5.ReleaseDir
    Write-TestLog "ExitCode: $($r5.ExitCode) | Detail: $(Get-GateFailureLine $r5.Output)"
    if ($r5.ExitCode -eq 0) { throw "Scenario 05 FAILED: Verifier allowed untracked file!" }
    $passedScenarios++
    Write-TestLog "[Scenario 05 PASSED] Rejected untracked file (Exit: $($r5.ExitCode))."

    # Scenario 6: Git command unavailable -> EXPECT FAIL
    Write-TestLog "`n[Scenario 06/13] Git executable unavailable on PATH -> EXPECT FAIL"
    $f6 = New-IsolatedFixture (Join-Path $workRoot "s06")
    $sysOnlyPath = "$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\WindowsPowerShell\v1.0"
    $r6 = Invoke-Verifier $f6.RepoDir $f6.ReleaseDir -customPathEnv $sysOnlyPath
    Write-TestLog "ExitCode: $($r6.ExitCode) | Detail: $(Get-GateFailureLine $r6.Output)"
    if ($r6.ExitCode -eq 0) { throw "Scenario 06 FAILED: Verifier succeeded when git binary was unavailable!" }
    $passedScenarios++
    Write-TestLog "[Scenario 06 PASSED] Failed closed when git unavailable (Exit: $($r6.ExitCode))."

    # Scenario 7: Manifest missing -> EXPECT FAIL
    Write-TestLog "`n[Scenario 07/13] External checksum manifest missing -> EXPECT FAIL"
    $f7 = New-IsolatedFixture (Join-Path $workRoot "s07")
    Remove-Item -LiteralPath $f7.ManifestPath -Force
    $r7 = Invoke-Verifier $f7.RepoDir $f7.ReleaseDir
    Write-TestLog "ExitCode: $($r7.ExitCode) | Detail: $(Get-GateFailureLine $r7.Output)"
    if ($r7.ExitCode -eq 0) { throw "Scenario 07 FAILED: Verifier succeeded with missing manifest!" }
    $passedScenarios++
    Write-TestLog "[Scenario 07 PASSED] Rejected missing manifest (Exit: $($r7.ExitCode))."

    # Scenario 8: Manifest corrupt -> EXPECT FAIL
    Write-TestLog "`n[Scenario 08/13] Corrupt / truncated manifest -> EXPECT FAIL"
    $f8 = New-IsolatedFixture (Join-Path $workRoot "s08")
    [System.IO.File]::WriteAllText($f8.ManifestPath, "CORRUPT DATA ONLY", $utf8NoBom)
    $r8 = Invoke-Verifier $f8.RepoDir $f8.ReleaseDir
    Write-TestLog "ExitCode: $($r8.ExitCode) | Detail: $(Get-GateFailureLine $r8.Output)"
    if ($r8.ExitCode -eq 0) { throw "Scenario 08 FAILED: Verifier accepted corrupt manifest!" }
    $passedScenarios++
    Write-TestLog "[Scenario 08 PASSED] Rejected corrupt manifest (Exit: $($r8.ExitCode))."

    # Scenario 9: ZIP missing -> EXPECT FAIL
    Write-TestLog "`n[Scenario 09/13] Release ZIP archive missing -> EXPECT FAIL"
    $f9 = New-IsolatedFixture (Join-Path $workRoot "s09")
    Remove-Item -LiteralPath $f9.HandoverZip -Force
    $r9 = Invoke-Verifier $f9.RepoDir $f9.ReleaseDir
    Write-TestLog "ExitCode: $($r9.ExitCode) | Detail: $(Get-GateFailureLine $r9.Output)"
    if ($r9.ExitCode -eq 0) { throw "Scenario 09 FAILED: Verifier succeeded with missing ZIP!" }
    $passedScenarios++
    Write-TestLog "[Scenario 09 PASSED] Rejected missing ZIP archive (Exit: $($r9.ExitCode))."

    # Scenario 10: Checksum mismatch -> EXPECT FAIL
    Write-TestLog "`n[Scenario 10/13] SHA-256 checksum mismatch in manifest -> EXPECT FAIL"
    $f10 = New-IsolatedFixture (Join-Path $workRoot "s10")
    $m10 = Get-Content -LiteralPath $f10.ManifestPath -Raw
    $m10 = [regex]::Replace($m10, 'SHA-256:\s*[A-F0-9]{64}', 'SHA-256: 0000000000000000000000000000000000000000000000000000000000000000', 1)
    [System.IO.File]::WriteAllText($f10.ManifestPath, $m10, $utf8NoBom)
    $r10 = Invoke-Verifier $f10.RepoDir $f10.ReleaseDir
    Write-TestLog "ExitCode: $($r10.ExitCode) | Detail: $(Get-GateFailureLine $r10.Output)"
    if ($r10.ExitCode -eq 0) { throw "Scenario 10 FAILED: Verifier allowed checksum mismatch!" }
    $passedScenarios++
    Write-TestLog "[Scenario 10 PASSED] Rejected checksum mismatch (Exit: $($r10.ExitCode))."

    # Scenario 11: Historical manifest inside Source ZIP -> EXPECT FAIL (FINDING-03 guard)
    Write-TestLog "`n[Scenario 11/13] Historical checksum manifest embedded in Source ZIP -> EXPECT FAIL"
    $f11 = New-IsolatedFixture (Join-Path $workRoot "s11") -IncludeHistoricalManifestInSource
    $r11 = Invoke-Verifier $f11.RepoDir $f11.ReleaseDir
    Write-TestLog "ExitCode: $($r11.ExitCode) | Detail: $(Get-GateFailureLine $r11.Output)"
    if ($r11.ExitCode -eq 0) { throw "Scenario 11 FAILED: Verifier allowed historical checksum manifest in Source ZIP!" }
    $passedScenarios++
    Write-TestLog "[Scenario 11 PASSED] Rejected historical manifest in Source ZIP (Exit: $($r11.ExitCode))."

    # Scenario 12: False Verified claim for missing file in Handover manifest -> EXPECT FAIL (FINDING-04 guard)
    Write-TestLog "`n[Scenario 12/13] Missing file marked Verified in AUDIT_FILE_MANIFEST.md -> EXPECT FAIL"
    $f12 = New-IsolatedFixture (Join-Path $workRoot "s12") -IncludeMissingVerifiedClaimInHandover
    $r12 = Invoke-Verifier $f12.RepoDir $f12.ReleaseDir
    Write-TestLog "ExitCode: $($r12.ExitCode) | Detail: $(Get-GateFailureLine $r12.Output)"
    if ($r12.ExitCode -eq 0) { throw "Scenario 12 FAILED: Verifier allowed false Verified claim for missing file!" }
    $passedScenarios++
    Write-TestLog "[Scenario 12 PASSED] Rejected false Verified claim in Handover manifest (Exit: $($r12.ExitCode))."

    # Scenario 13: Stale git_commit.txt inside Handover ZIP -> EXPECT FAIL (FINDING-02 guard)
    Write-TestLog "`n[Scenario 13/13] Stale Git commit recorded inside Handover ZIP evidence -> EXPECT FAIL"
    $f13 = New-IsolatedFixture (Join-Path $workRoot "s13") -OverrideHandoverCommit "1111111111111111111111111111111111111111"
    $r13 = Invoke-Verifier $f13.RepoDir $f13.ReleaseDir
    Write-TestLog "ExitCode: $($r13.ExitCode) | Detail: $(Get-GateFailureLine $r13.Output)"
    if ($r13.ExitCode -eq 0) { throw "Scenario 13 FAILED: Verifier allowed stale git_commit.txt inside Handover ZIP!" }
    $passedScenarios++
    Write-TestLog "[Scenario 13 PASSED] Rejected stale git_commit.txt inside Handover ZIP (Exit: $($r13.ExitCode))."

    Write-TestLog "`n======================================================================"
    Write-TestLog " Release Verifier Negative & Positive Tests Summary:"
    Write-TestLog " Passed: $passedScenarios / $totalScenarios (100% PASS)"
    Write-TestLog "======================================================================"

    if (-not [string]::IsNullOrWhiteSpace($OutputReportPath)) {
        $dir = Split-Path -Parent $OutputReportPath
        if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        [System.IO.File]::WriteAllLines($OutputReportPath, $logLines, $utf8NoBom)
    }
    exit 0
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
