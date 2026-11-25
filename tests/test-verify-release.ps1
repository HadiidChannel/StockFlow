# ==============================================================================
# StockFlow v1.6.5 - Expanded Fail-Closed Release Verifier Test Suite
# File: tests/test-verify-release.ps1
# Description: Executes 44 isolated positive & negative scenarios covering all
#              14 release gates (Core Git/Manifest/Checksums + Gate 09
#              bidirectional Audit Handover + Gate 11 4-report Secret Scans +
#              Gate 12 Git Evidence & metadata + Gate 13 Markdown dash rules +
#              Gate 14 Cross-Platform ZIP Portability across Python/Info-ZIP/.NET).
#              Also emits separated category reports for Gates 09, 12, and 14.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputReportPath,

    [Parameter(Mandatory = $false)]
    [string]$AuditManifestReportPath,

    [Parameter(Mandatory = $false)]
    [string]$GitEvidenceReportPath,

    [Parameter(Mandatory = $false)]
    [string]$ZipPortabilityReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$verifyScript = Join-Path $projectRoot "scripts\verify-release.ps1"
$zipUtilsScript = Join-Path $projectRoot "scripts\zip-utils.ps1"

. $zipUtilsScript

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$logLines = [System.Collections.Generic.List[string]]::new()
$catLogs = @{
    AuditManifest = [System.Collections.Generic.List[string]]::new()
    GitEvidence = [System.Collections.Generic.List[string]]::new()
    ZipPortability = [System.Collections.Generic.List[string]]::new()
}

function Write-TestLog([string]$msg, [string]$category = "") {
    Write-Host $msg
    $logLines.Add($msg)
    if ($category -and $catLogs.ContainsKey($category)) {
        $catLogs[$category].Add($msg)
    }
}

$execStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
foreach ($hdr in @(
    "======================================================================",
    " StockFlow v1.6.5 Release Verifier Test Suite (44 Positive & Negative)",
    " Target Script: $verifyScript",
    " Execution Time: $execStamp",
    "======================================================================"
)) {
    Write-TestLog $hdr
    $catLogs.AuditManifest.Add($hdr)
    $catLogs.GitEvidence.Add($hdr)
    $catLogs.ZipPortability.Add($hdr)
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

function Invoke-Verifier {
    param(
        [string]$RepoPath,
        [string]$ReleaseDir,
        [string]$Branch = "fix/stockflow-v16-5-zip-portability",
        [string]$Version = "v1.6.5",
        [string]$CustomPathEnv = ""
    )
    $prevEap = $ErrorActionPreference
    $prevPath = $env:PATH
    $ErrorActionPreference = "Continue"
    try {
        if (-not [string]::IsNullOrWhiteSpace($CustomPathEnv)) {
            $env:PATH = $CustomPathEnv
        }
        $cmdArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $verifyScript,
            "-RepositoryRoot", $RepoPath,
            "-TargetDirectory", $ReleaseDir,
            "-ExpectedBranch", $Branch,
            "-ExpectedVersion", $Version
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

function New-FormattedGitEvidenceFiles {
    param(
        [string]$GitOutDir,
        [string]$BranchName,
        [string]$CommitHash,
        [string]$WorkDir,
        [int]$StatusExitCode = 0,
        [string]$StatusPorcelainText = "",
        [string]$WorkingTreeLabel = "Clean",
        [switch]$UseRawStatusOverride,
        [string]$RawStatusOverride = "",
        [switch]$OmitStatusFile
    )
    if (-not (Test-Path -LiteralPath $GitOutDir)) {
        New-Item -ItemType Directory -Path $GitOutDir -Force | Out-Null
    }
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')

    [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_branch.txt"), "Evidence Version: v1.6.5`nCommand: git branch --show-current`nTimestamp: $ts`nWorking Directory: $WorkDir`nExit Code: 0`nBranch: $BranchName`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_commit.txt"), "Evidence Version: v1.6.5`nCommand: git rev-parse HEAD`nTimestamp: $ts`nWorking Directory: $WorkDir`nExit Code: 0`nCommit: $CommitHash`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_log.txt"), "Evidence Version: v1.6.5`nCommand: git log -5 --oneline`nTimestamp: $ts`nWorking Directory: $WorkDir`nExit Code: 0`nLOG_OUTPUT_BEGIN`n$($CommitHash.Substring(0,7)) Initial fixture baseline`nLOG_OUTPUT_END`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_identity_verification.txt"), "=== STOCKFLOW v1.6.5 GIT IDENTITY ===`nTimestamp: $ts`nWorking Directory: $WorkDir`nBranch: $BranchName`nCommit: $CommitHash`nExit Code: 0`n", $utf8NoBom)

    if (-not $OmitStatusFile) {
        if ($UseRawStatusOverride) {
            [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_status.txt"), $RawStatusOverride, $utf8NoBom)
        } else {
            $bodyBlock = if ([string]::IsNullOrEmpty($StatusPorcelainText)) { "" } else { "$StatusPorcelainText`n" }
            $statusTxt = "Evidence Version: v1.6.5`nCommand: git status --porcelain --untracked-files=all`nTimestamp: $ts`nWorking Directory: $WorkDir`nExit Code: $StatusExitCode`n`nPORCELAIN_OUTPUT_BEGIN`n${bodyBlock}PORCELAIN_OUTPUT_END`n`nWorking Tree: $WorkingTreeLabel`n"
            [System.IO.File]::WriteAllText((Join-Path $GitOutDir "git_status.txt"), $statusTxt, $utf8NoBom)
        }
    }
}

function New-FormattedScanReport {
    param(
        [string]$OutPath,
        [string]$ScanTarget,
        [int]$FilesScanned = 6,
        [int]$FilesExcluded = 0,
        [int]$Findings = 0,
        [int]$ExitCode = 0,
        [string]$Status = "100% CLEAN"
    )
    $dir = Split-Path -Parent $OutPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    $body = @"
=== STOCKFLOW CREDENTIAL AND SECRET SCAN REPORT (v1.6.5) ===
Scanner Version: v1.6.5
Scan Date: $ts
Scan Target: $ScanTarget
Total Files Scanned: $FilesScanned
Total Files Excluded: $FilesExcluded
Allowlisted Files Scanned/Skipped: 0 (None in fixture)
Total Findings: $Findings
Masking Status: Enabled ([REDACTED] enforced)
Scan Status: $Status
Exit Code: $ExitCode

Findings: $Findings sensitive credentials detected.
"@
    [System.IO.File]::WriteAllText($OutPath, $body, $utf8NoBom)
}

function New-HandoverManifestFromStage {
    param(
        [string]$StageDir,
        [string]$BranchName,
        [string]$CommitHash,
        [string]$ExtraFakeRow = "",
        [switch]$OmitLastFile,
        [switch]$CorruptFirstSha,
        [switch]$CorruptFirstSize,
        [switch]$DuplicateFirstRow,
        [switch]$MarkFirstMissing
    )
    $files = @(Get-ChildItem -LiteralPath $StageDir -Recurse -File | Where-Object { $_.Name -ne "AUDIT_FILE_MANIFEST.md" } | Sort-Object FullName)
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# StockFlow v1.6.5 Audit Handover Manifest")
    $md.Add("")
    $md.Add("- Generated At: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $md.Add("- Release Version: v1.6.5")
    $md.Add("- Git Branch: $BranchName")
    $md.Add("- Git Commit: $CommitHash")
    $md.Add("- Total Files in Handover Archive: $($files.Count + 1) (including AUDIT_FILE_MANIFEST.md; Section 2 lists $($files.Count) non-manifest payload files)")
    $md.Add("")
    $md.Add("## 1. Complete Handover Archive File Inventory")
    $md.Add("")
    $md.Add("| Archive Path | File Exists | Size (bytes) | SHA-256 | Verification Status |")
    $md.Add("| :--- | :---: | ---: | :--- | :---: |")

    $idx = 0
    $limit = if ($OmitLastFile -and $files.Count -gt 1) { $files.Count - 1 } else { $files.Count }
    for ($i = 0; $i -lt $limit; $i++) {
        $f = $files[$i]
        $idx++
        $relUnix = $f.FullName.Substring($StageDir.Length).TrimStart('\', '/').Replace('\', '/')
        $sz = $f.Length
        $sha = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        $st = "Verified"

        if ($i -eq 0) {
            if ($CorruptFirstSha) { $sha = "0000000000000000000000000000000000000000000000000000000000000000" }
            if ($CorruptFirstSize) { $sz = $sz + 999 }
            if ($MarkFirstMissing) { $st = "Missing" }
        }

        $row = "| $relUnix | Yes | $sz | $sha | $st |"
        $md.Add($row)
        if ($i -eq 0 -and $DuplicateFirstRow) {
            $md.Add($row)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ExtraFakeRow)) {
        $md.Add($ExtraFakeRow)
    }
    return ($md -join "`n") + "`n"
}

function Update-FixtureChecksumsManifest {
    param(
        [string]$ManifestPath,
        [string]$BranchName,
        [string]$CommitHash,
        [string]$SrcZip,
        [string]$VerZip,
        [string]$HanZip
    )
    $s1 = (Get-Item -LiteralPath $SrcZip).Length; $h1 = (Get-FileHash -LiteralPath $SrcZip -Algorithm SHA256).Hash.ToUpperInvariant()
    $s2 = (Get-Item -LiteralPath $VerZip).Length; $h2 = (Get-FileHash -LiteralPath $VerZip -Algorithm SHA256).Hash.ToUpperInvariant()
    $s3 = (Get-Item -LiteralPath $HanZip).Length; $h3 = (Get-FileHash -LiteralPath $HanZip -Algorithm SHA256).Hash.ToUpperInvariant()

    $manifestTxt = @"
=== STOCKFLOW OFFICIAL RELEASE MANIFEST (v1.6.5) ===

Release Version: v1.6.5
Generated At: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Git Branch: $BranchName
Git Commit: $CommitHash
Working Tree: Clean

Package 1:
Name: StockFlow_Final_v8_5.zip
Description: Source Code Package
Size: $s1 bytes
SHA-256: $h1

Package 2:
Name: StockFlow_Final_Verification_v8_5.zip
Description: Verification Evidence Package
Size: $s2 bytes
SHA-256: $h2

Package 3:
Name: StockFlow_Audit_Handover_v8_5.zip
Description: Audit Handover Package
Size: $s3 bytes
SHA-256: $h3
"@
    [System.IO.File]::WriteAllText($ManifestPath, $manifestTxt, $utf8NoBom)
}

function New-IsolatedFixture {
    param(
        [string]$BaseDir,
        [string]$BranchName = "fix/stockflow-v16-5-zip-portability",
        [switch]$IncludeHistoricalManifestInSource,
        [switch]$IncludeMissingVerifiedClaimInHandover,
        [switch]$CorruptHandoverSha,
        [switch]$CorruptHandoverSize,
        [switch]$ExtraUnlistedHandoverFile,
        [switch]$DuplicateManifestRow,
        [switch]$OmitHandoverManifest,
        [switch]$MarkInventoryMissing,
        [string]$OverrideVerCommit = "",
        [string]$OverrideHanCommit = "",
        [switch]$OmitVerStatus,
        [switch]$OmitHanStatus,
        [switch]$UseRawVerStatus,
        [string]$RawVerStatus = "",
        [switch]$UseRawHanStatus,
        [string]$RawHanStatus = "",
        [string]$VerPorcelain = "",
        [int]$VerStatusExit = 0,
        [string]$VerWorkingTreeLabel = "Clean",
        [string]$SourceDocDash = "",
        [string]$VerifyDocDash = "",
        [string]$HandoverDocDash = "",
        [string]$ExternalReportDash = "",
        [string]$AdversarialZipScript = ""
    )

    if (Test-Path -LiteralPath $BaseDir) { Remove-Item -LiteralPath $BaseDir -Recurse -Force }
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

    $repoDir = Join-Path $BaseDir "repo"
    New-Item -ItemType Directory -Path $repoDir, (Join-Path $repoDir "backend"), (Join-Path $repoDir "frontend") -Force | Out-Null

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
    $commitHash = (Invoke-GitSafe $repoDir @("rev-parse", "HEAD")).ToLowerInvariant()

    $releaseDir = Join-Path $repoDir "release-output\v1.6.5"
    $evSecDir = Join-Path $releaseDir "evidence\security"
    New-Item -ItemType Directory -Path $releaseDir, $evSecDir -Force | Out-Null

    $srcZip = Join-Path $releaseDir "StockFlow_Final_v8_5.zip"
    $verZip = Join-Path $releaseDir "StockFlow_Final_Verification_v8_5.zip"
    $hanZip = Join-Path $releaseDir "StockFlow_Audit_Handover_v8_5.zip"
    $manifestPath = Join-Path $releaseDir "StockFlow_Release_Checksums_v8_5.txt"

    # Stage Source ZIP
    $srcStage = Join-Path $BaseDir "stage_src"
    New-Item -ItemType Directory -Path (Join-Path $srcStage "backend"), (Join-Path $srcStage "frontend") -Force | Out-Null
    Copy-Item (Join-Path $repoDir ".gitignore") $srcStage -Force
    Copy-Item (Join-Path $repoDir ".env.example") $srcStage -Force
    Copy-Item (Join-Path $repoDir "backend\.env.example") (Join-Path $srcStage "backend") -Force
    Copy-Item (Join-Path $repoDir "frontend\.env.example") (Join-Path $srcStage "frontend") -Force
    $srcReadme = if ($SourceDocDash) { "# Fixture Repo`nBad dash: $SourceDocDash`n" } else { "# Fixture Repo`nClean readme.`n" }
    [System.IO.File]::WriteAllText((Join-Path $srcStage "README.md"), $srcReadme, $utf8NoBom)
    Copy-Item (Join-Path $repoDir "docker-compose.yml") $srcStage -Force
    if ($IncludeHistoricalManifestInSource) {
        [System.IO.File]::WriteAllText((Join-Path $srcStage "StockFlow_Release_Checksums_v8_2.txt"), "stale", $utf8NoBom)
    }
    New-PortableZipArchive -SourceDirectory $srcStage -DestinationZipPath $srcZip | Out-Null

    # Stage Handover ZIP
    $hanCommit = if ($OverrideHanCommit) { $OverrideHanCommit } else { $commitHash }
    $hanStage = Join-Path $BaseDir "stage_han"
    New-Item -ItemType Directory -Path (Join-Path $hanStage "source\root"), (Join-Path $hanStage "source\backend"), (Join-Path $hanStage "source\frontend"), (Join-Path $hanStage "evidence\security"), (Join-Path $hanStage "documentation") -Force | Out-Null
    Copy-Item (Join-Path $repoDir ".env.example") (Join-Path $hanStage "source\root\.env.example") -Force
    Copy-Item (Join-Path $repoDir "backend\.env.example") (Join-Path $hanStage "source\backend\.env.example") -Force
    Copy-Item (Join-Path $repoDir "frontend\.env.example") (Join-Path $hanStage "source\frontend\.env.example") -Force
    $hanReadme = if ($HandoverDocDash) { "# Handover Docs`nBad dash: $HandoverDocDash`n" } else { "# Handover Docs`nClean ASCII.`n" }
    [System.IO.File]::WriteAllText((Join-Path $hanStage "documentation\README.md"), $hanReadme, $utf8NoBom)
    New-FormattedGitEvidenceFiles -GitOutDir (Join-Path $hanStage "evidence\git") -BranchName $BranchName -CommitHash $hanCommit -WorkDir $repoDir -OmitStatusFile:$OmitHanStatus -UseRawStatusOverride:$UseRawHanStatus -RawStatusOverride $RawHanStatus

    New-FormattedScanReport -OutPath (Join-Path $hanStage "evidence\security\secret_scan_repository.txt") -ScanTarget $repoDir -FilesScanned 6
    New-FormattedScanReport -OutPath (Join-Path $hanStage "evidence\security\source_package_scan.txt") -ScanTarget $srcZip -FilesScanned 6

    if (-not $OmitHandoverManifest) {
        $fakeRow = if ($IncludeMissingVerifiedClaimInHandover) { "| source/root/missing.txt | Yes | 10 | 0000000000000000000000000000000000000000000000000000000000000000 | Verified |" } else { "" }
        $hanManifestTxt = New-HandoverManifestFromStage -StageDir $hanStage -BranchName $BranchName -CommitHash $hanCommit -ExtraFakeRow $fakeRow -OmitLastFile:$ExtraUnlistedHandoverFile -CorruptFirstSha:$CorruptHandoverSha -CorruptFirstSize:$CorruptHandoverSize -DuplicateFirstRow:$DuplicateManifestRow -MarkFirstMissing:$MarkInventoryMissing
        [System.IO.File]::WriteAllText((Join-Path $hanStage "AUDIT_FILE_MANIFEST.md"), $hanManifestTxt, $utf8NoBom)
    }
    New-PortableZipArchive -SourceDirectory $hanStage -DestinationZipPath $hanZip | Out-Null

    # Security scans (all 4 files outside ZIP + 3 pre-package inside Verification ZIP)
    $repScanPath = Join-Path $evSecDir "secret_scan_repository.txt"
    $srcScanPath = Join-Path $evSecDir "source_package_scan.txt"
    $hanScanPath = Join-Path $evSecDir "audit_handover_package_scan.txt"
    $verScanPath = Join-Path $evSecDir "verification_package_scan.txt"
    New-FormattedScanReport -OutPath $repScanPath -ScanTarget $repoDir -FilesScanned 6
    New-FormattedScanReport -OutPath $srcScanPath -ScanTarget $srcZip -FilesScanned 6
    New-FormattedScanReport -OutPath $hanScanPath -ScanTarget $hanZip -FilesScanned 9

    # Stage Verification ZIP
    $verCommit = if ($OverrideVerCommit) { $OverrideVerCommit } else { $commitHash }
    $verStage = Join-Path $BaseDir "stage_ver"
    New-Item -ItemType Directory -Path (Join-Path $verStage "evidence\security"), (Join-Path $verStage "documentation") -Force | Out-Null
    Copy-Item $repScanPath (Join-Path $verStage "evidence\security\secret_scan_repository.txt") -Force
    Copy-Item $srcScanPath (Join-Path $verStage "evidence\security\source_package_scan.txt") -Force
    Copy-Item $hanScanPath (Join-Path $verStage "evidence\security\audit_handover_package_scan.txt") -Force
    $verReadme = if ($VerifyDocDash) { "# Verification Docs`nBad dash: $VerifyDocDash`n" } else { "# Verification Docs`nClean ASCII.`n" }
    [System.IO.File]::WriteAllText((Join-Path $verStage "documentation\README.md"), $verReadme, $utf8NoBom)
    New-FormattedGitEvidenceFiles -GitOutDir (Join-Path $verStage "evidence\git") -BranchName $BranchName -CommitHash $verCommit -WorkDir $repoDir -StatusExitCode $VerStatusExit -StatusPorcelainText $VerPorcelain -WorkingTreeLabel $VerWorkingTreeLabel -OmitStatusFile:$OmitVerStatus -UseRawStatusOverride:$UseRawVerStatus -RawStatusOverride $RawVerStatus
    New-PortableZipArchive -SourceDirectory $verStage -DestinationZipPath $verZip | Out-Null

    # Optional Python ZIP adversarial mutation for Gate 14 negative tests
    if (-not [string]::IsNullOrWhiteSpace($AdversarialZipScript)) {
        $pyInfo = Find-PythonExecutable
        $mutScript = Join-Path $BaseDir "mutate_zip.py"
        [System.IO.File]::WriteAllText($mutScript, $AdversarialZipScript, $utf8NoBom)
        & $pyInfo.Path $mutScript $srcZip
        if ($LASTEXITCODE -ne 0) { throw "Python ZIP mutation failed for $srcZip" }
    }

    # Generate Verification ZIP secret scan (post-package)
    New-FormattedScanReport -OutPath $verScanPath -ScanTarget $verZip -FilesScanned 8

    if (-not [string]::IsNullOrWhiteSpace($ExternalReportDash)) {
        [System.IO.File]::WriteAllText((Join-Path $releaseDir "FINAL_RELEASE_REPORT_V1_6_5.md"), "# Final Report`nBad dash: $ExternalReportDash`n", $utf8NoBom)
    }

    Update-FixtureChecksumsManifest -ManifestPath $manifestPath -BranchName $BranchName -CommitHash $commitHash -SrcZip $srcZip -VerZip $verZip -HanZip $hanZip

    return [PSCustomObject]@{
        BaseDir = $BaseDir; RepoDir = $repoDir; ReleaseDir = $releaseDir; CommitHash = $commitHash; BranchName = $BranchName
        ManifestPath = $manifestPath; SourceZip = $srcZip; VerifyZip = $verZip; HandoverZip = $hanZip; SecurityDir = $evSecDir
    }
}

function Assert-Scenario {
    param(
        [int]$Index,
        [int]$Total,
        [string]$Title,
        [bool]$ExpectPass,
        [string]$ExpectedGatePrefix = "",
        [string]$Category = "",
        [PSCustomObject]$Result
    )
    Write-TestLog "`n[Scenario $("{0:D2}" -f $Index)/$Total] $Title -> EXPECT $(if ($ExpectPass) { 'PASS' } else { "FAIL ($ExpectedGatePrefix)" })" $Category
    $detail = Get-GateFailureLine $Result.Output
    Write-TestLog "ExitCode: $($Result.ExitCode) | Detail: $detail" $Category

    if ($ExpectPass) {
        if ($Result.ExitCode -ne 0) {
            Write-TestLog "Full Output:`n$($Result.Output)" $Category
            throw "Scenario $Index FAILED: Expected exit code 0, got $($Result.ExitCode)."
        }
        Write-TestLog "[Scenario $("{0:D2}" -f $Index) PASSED] Exit code 0 verified." $Category
    } else {
        if ($Result.ExitCode -eq 0) {
            throw "Scenario $Index FAILED: Verifier allowed violation ($Title)!"
        }
        if ($ExpectedGatePrefix -and $Result.Output -notmatch "\[$ExpectedGatePrefix\]\s+FAIL") {
            Write-TestLog "Full Output:`n$($Result.Output)" $Category
            throw "Scenario $Index FAILED: Expected failure at $ExpectedGatePrefix, got: $detail"
        }
        Write-TestLog "[Scenario $("{0:D2}" -f $Index) PASSED] Properly rejected at $ExpectedGatePrefix (Exit: $($Result.ExitCode))." $Category
    }
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_verifier_v165_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$totalScenarios = 44
$passed = 0

try {
    # --- GROUP A: CORE BASELINE (S01..S11) ---
    $f1 = New-IsolatedFixture (Join-Path $workRoot "s01")
    Assert-Scenario 1 $totalScenarios "All gates pass cleanly (v1.6.5 baseline + bidirectional manifest + 4 scans + 3-engine ZIP)" $true "" "Core" (Invoke-Verifier $f1.RepoDir $f1.ReleaseDir); $passed++
    # Also record positive pass in category logs
    foreach ($c in @("AuditManifest", "GitEvidence", "ZipPortability")) {
        Write-TestLog "[Baseline Positive PASS] Clean fixture passed Gate 09, Gate 12, and Gate 14 (Exit: 0)" $c
    }

    $f2 = New-IsolatedFixture (Join-Path $workRoot "s02")
    $fakeC = if ($f2.CommitHash -eq ("0" * 40)) { "f" * 40 } else { "0" * 40 }
    [IO.File]::WriteAllText($f2.ManifestPath, ([IO.File]::ReadAllText($f2.ManifestPath)).Replace($f2.CommitHash, $fakeC), $utf8NoBom)
    Assert-Scenario 2 $totalScenarios "Full commit hash mismatch" $false "GATE-04" "" (Invoke-Verifier $f2.RepoDir $f2.ReleaseDir); $passed++

    $f3 = New-IsolatedFixture (Join-Path $workRoot "s03") -BranchName "wrong-branch"
    Assert-Scenario 3 $totalScenarios "Active branch mismatch" $false "GATE-03" "" (Invoke-Verifier $f3.RepoDir $f3.ReleaseDir -Branch "fix/stockflow-v16-5-zip-portability"); $passed++

    $f4 = New-IsolatedFixture (Join-Path $workRoot "s04")
    [IO.File]::AppendAllText((Join-Path $f4.RepoDir "README.md"), "dirty edit`n", $utf8NoBom)
    Assert-Scenario 4 $totalScenarios "Modified tracked file (dirty repo working tree)" $false "GATE-05" "" (Invoke-Verifier $f4.RepoDir $f4.ReleaseDir); $passed++

    $f5 = New-IsolatedFixture (Join-Path $workRoot "s05")
    [IO.File]::WriteAllText((Join-Path $f5.RepoDir "stray.txt"), "untracked", $utf8NoBom)
    Assert-Scenario 5 $totalScenarios "Untracked file in repo working tree" $false "GATE-05" "" (Invoke-Verifier $f5.RepoDir $f5.ReleaseDir); $passed++

    $f6 = New-IsolatedFixture (Join-Path $workRoot "s06")
    Assert-Scenario 6 $totalScenarios "Git binary unavailable on PATH" $false "GATE-01" "" (Invoke-Verifier $f6.RepoDir $f6.ReleaseDir -CustomPathEnv "$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\WindowsPowerShell\v1.0"); $passed++

    $f7 = New-IsolatedFixture (Join-Path $workRoot "s07")
    Remove-Item -LiteralPath $f7.ManifestPath -Force
    Assert-Scenario 7 $totalScenarios "External checksum manifest missing" $false "GATE-02" "" (Invoke-Verifier $f7.RepoDir $f7.ReleaseDir); $passed++

    $f8 = New-IsolatedFixture (Join-Path $workRoot "s08")
    [IO.File]::WriteAllText($f8.ManifestPath, "CORRUPT MANIFEST DATA", $utf8NoBom)
    Assert-Scenario 8 $totalScenarios "Corrupt / truncated checksum manifest" $false "GATE-02" "" (Invoke-Verifier $f8.RepoDir $f8.ReleaseDir); $passed++

    $f9 = New-IsolatedFixture (Join-Path $workRoot "s09")
    Remove-Item -LiteralPath $f9.HandoverZip -Force
    Assert-Scenario 9 $totalScenarios "Release ZIP archive missing" $false "GATE-02" "" (Invoke-Verifier $f9.RepoDir $f9.ReleaseDir); $passed++

    $f10 = New-IsolatedFixture (Join-Path $workRoot "s10")
    [IO.File]::WriteAllText($f10.ManifestPath, ([regex]::Replace([IO.File]::ReadAllText($f10.ManifestPath), 'SHA-256:\s*[A-F0-9]{64}', ('SHA-256: ' + ('0' * 64)), 1)), $utf8NoBom)
    Assert-Scenario 10 $totalScenarios "SHA-256 checksum mismatch in external manifest" $false "GATE-06" "" (Invoke-Verifier $f10.RepoDir $f10.ReleaseDir); $passed++

    $f11 = New-IsolatedFixture (Join-Path $workRoot "s11") -IncludeHistoricalManifestInSource
    Assert-Scenario 11 $totalScenarios "Historical checksum manifest embedded in Source ZIP" $false "GATE-08" "" (Invoke-Verifier $f11.RepoDir $f11.ReleaseDir); $passed++

    # --- GROUP B: GATE 09 AUDIT HANDOVER MANIFEST BIDIRECTIONAL TESTS (S12..S18) ---
    $f12 = New-IsolatedFixture (Join-Path $workRoot "s12") -IncludeMissingVerifiedClaimInHandover
    Assert-Scenario 12 $totalScenarios "Handover false Verified claim for missing file" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f12.RepoDir $f12.ReleaseDir); $passed++

    $f13 = New-IsolatedFixture (Join-Path $workRoot "s13") -CorruptHandoverSha
    Assert-Scenario 13 $totalScenarios "Handover inventory file SHA-256 mismatch" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f13.RepoDir $f13.ReleaseDir); $passed++

    $f14 = New-IsolatedFixture (Join-Path $workRoot "s14") -CorruptHandoverSize
    Assert-Scenario 14 $totalScenarios "Handover inventory file byte Size mismatch" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f14.RepoDir $f14.ReleaseDir); $passed++

    $f15 = New-IsolatedFixture (Join-Path $workRoot "s15") -ExtraUnlistedHandoverFile
    Assert-Scenario 15 $totalScenarios "Extra unlisted file inside Handover ZIP (Archive-to-Manifest check)" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f15.RepoDir $f15.ReleaseDir); $passed++

    $f16 = New-IsolatedFixture (Join-Path $workRoot "s16") -DuplicateManifestRow
    Assert-Scenario 16 $totalScenarios "Duplicate normalized archive path row in AUDIT_FILE_MANIFEST.md" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f16.RepoDir $f16.ReleaseDir); $passed++

    $f17 = New-IsolatedFixture (Join-Path $workRoot "s17") -OmitHandoverManifest
    Assert-Scenario 17 $totalScenarios "AUDIT_FILE_MANIFEST.md missing from Handover ZIP" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f17.RepoDir $f17.ReleaseDir); $passed++

    $f18 = New-IsolatedFixture (Join-Path $workRoot "s18") -MarkInventoryMissing
    Assert-Scenario 18 $totalScenarios "Inventory entry marked Missing instead of Verified" $false "GATE-09" "AuditManifest" (Invoke-Verifier $f18.RepoDir $f18.ReleaseDir); $passed++

    # --- GROUP C: GATE 11 SECRET SCAN EVIDENCE COMPLETENESS TESTS (S19..S24) ---
    $f19 = New-IsolatedFixture (Join-Path $workRoot "s19")
    Remove-Item (Join-Path $f19.SecurityDir "secret_scan_repository.txt") -Force
    Assert-Scenario 19 $totalScenarios "Missing secret_scan_repository.txt report" $false "GATE-11" "" (Invoke-Verifier $f19.RepoDir $f19.ReleaseDir); $passed++

    $f20 = New-IsolatedFixture (Join-Path $workRoot "s20")
    Remove-Item (Join-Path $f20.SecurityDir "source_package_scan.txt") -Force
    Assert-Scenario 20 $totalScenarios "Missing source_package_scan.txt report" $false "GATE-11" "" (Invoke-Verifier $f20.RepoDir $f20.ReleaseDir); $passed++

    $f21 = New-IsolatedFixture (Join-Path $workRoot "s21")
    Remove-Item (Join-Path $f21.SecurityDir "verification_package_scan.txt") -Force
    Assert-Scenario 21 $totalScenarios "Missing verification_package_scan.txt report" $false "GATE-11" "" (Invoke-Verifier $f21.RepoDir $f21.ReleaseDir); $passed++

    $f22 = New-IsolatedFixture (Join-Path $workRoot "s22")
    Remove-Item (Join-Path $f22.SecurityDir "audit_handover_package_scan.txt") -Force
    Assert-Scenario 22 $totalScenarios "Missing audit_handover_package_scan.txt report" $false "GATE-11" "" (Invoke-Verifier $f22.RepoDir $f22.ReleaseDir); $passed++

    $f23 = New-IsolatedFixture (Join-Path $workRoot "s23")
    New-FormattedScanReport -OutPath (Join-Path $f23.SecurityDir "verification_package_scan.txt") -ScanTarget $f23.VerifyZip -Findings 1 -ExitCode 1 -Status "FAILED"
    Assert-Scenario 23 $totalScenarios "Secret scan report shows FAILED / Findings > 0" $false "GATE-11" "" (Invoke-Verifier $f23.RepoDir $f23.ReleaseDir); $passed++

    $f24 = New-IsolatedFixture (Join-Path $workRoot "s24")
    New-FormattedScanReport -OutPath (Join-Path $f24.SecurityDir "verification_package_scan.txt") -ScanTarget $f24.RepoDir -Findings 0 -ExitCode 0 -Status "100% CLEAN"
    Assert-Scenario 24 $totalScenarios "Secret scan report points to wrong target (repository instead of Verification ZIP)" $false "GATE-11" "" (Invoke-Verifier $f24.RepoDir $f24.ReleaseDir); $passed++

    # --- GROUP D: GATE 12 GIT EVIDENCE COMPLETENESS & FAIL-CLOSED TESTS (S25..S33) ---
    $f25 = New-IsolatedFixture (Join-Path $workRoot "s25") -OverrideVerCommit ("1" * 40)
    Assert-Scenario 25 $totalScenarios "Verification ZIP commit stale independently (Handover valid)" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f25.RepoDir $f25.ReleaseDir); $passed++

    $f26 = New-IsolatedFixture (Join-Path $workRoot "s26") -OverrideHanCommit ("2" * 40)
    Assert-Scenario 26 $totalScenarios "Handover ZIP commit stale independently (Verification valid)" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f26.RepoDir $f26.ReleaseDir); $passed++

    $f27 = New-IsolatedFixture (Join-Path $workRoot "s27") -OmitVerStatus
    Assert-Scenario 27 $totalScenarios "Verification ZIP git_status.txt missing" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f27.RepoDir $f27.ReleaseDir); $passed++

    $f28 = New-IsolatedFixture (Join-Path $workRoot "s28") -OmitHanStatus
    Assert-Scenario 28 $totalScenarios "Handover ZIP git_status.txt missing" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f28.RepoDir $f28.ReleaseDir); $passed++

    $f29 = New-IsolatedFixture (Join-Path $workRoot "s29") -UseRawVerStatus -RawVerStatus ""
    Assert-Scenario 29 $totalScenarios "Verification ZIP git_status.txt completely empty (no metadata)" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f29.RepoDir $f29.ReleaseDir); $passed++

    $f30 = New-IsolatedFixture (Join-Path $workRoot "s30") -UseRawHanStatus -RawHanStatus "CLEAN`n"
    Assert-Scenario 30 $totalScenarios "Handover ZIP git_status.txt lacks command/timestamp/marker metadata" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f30.RepoDir $f30.ReleaseDir); $passed++

    $f31 = New-IsolatedFixture (Join-Path $workRoot "s31") -VerPorcelain "?? stray_untracked.txt" -VerWorkingTreeLabel "Dirty"
    Assert-Scenario 31 $totalScenarios "Verification git_status.txt evidence contains untracked file" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f31.RepoDir $f31.ReleaseDir); $passed++

    $f32 = New-IsolatedFixture (Join-Path $workRoot "s32") -VerPorcelain " M README.md" -VerWorkingTreeLabel "Dirty"
    Assert-Scenario 32 $totalScenarios "Verification git_status.txt evidence contains modified file" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f32.RepoDir $f32.ReleaseDir); $passed++

    $f33 = New-IsolatedFixture (Join-Path $workRoot "s33") -VerStatusExit 128 -VerWorkingTreeLabel "Error"
    Assert-Scenario 33 $totalScenarios "Verification git_status.txt records Git command failure Exit Code 128" $false "GATE-12" "GitEvidence" (Invoke-Verifier $f33.RepoDir $f33.ReleaseDir); $passed++

    # --- GROUP E: GATE 13 WRITING CONSTRAINT DOCUMENTATION TESTS (S34..S37) ---
    $enDash = [string][char]0x2013
    $emDash = [string][char]0x2014

    $f34 = New-IsolatedFixture (Join-Path $workRoot "s34") -SourceDocDash $enDash
    Assert-Scenario 34 $totalScenarios "En dash (U+2013) inside Markdown in Source ZIP" $false "GATE-13" "" (Invoke-Verifier $f34.RepoDir $f34.ReleaseDir); $passed++

    $f35 = New-IsolatedFixture (Join-Path $workRoot "s35") -VerifyDocDash $emDash
    Assert-Scenario 35 $totalScenarios "Em dash (U+2014) inside Markdown in Verification ZIP" $false "GATE-13" "" (Invoke-Verifier $f35.RepoDir $f35.ReleaseDir); $passed++

    $f36 = New-IsolatedFixture (Join-Path $workRoot "s36") -HandoverDocDash $enDash
    Assert-Scenario 36 $totalScenarios "En dash (U+2013) inside Markdown in Handover ZIP" $false "GATE-13" "" (Invoke-Verifier $f36.RepoDir $f36.ReleaseDir); $passed++

    $f37 = New-IsolatedFixture (Join-Path $workRoot "s37") -ExternalReportDash $emDash
    Assert-Scenario 37 $totalScenarios "Em dash (U+2014) inside external release report" $false "GATE-13" "" (Invoke-Verifier $f37.RepoDir $f37.ReleaseDir); $passed++

    # --- GROUP F: GATE 14 ZIP PORTABILITY & STRUCTURE VALIDATION TESTS (S38..S44) ---
    $f38 = New-IsolatedFixture (Join-Path $workRoot "s38") -AdversarialZipScript @"
import sys, zipfile
zp = sys.argv[1]
with zipfile.ZipFile(zp, 'a') as zf:
    zi = zipfile.ZipInfo('placeholder')
    zi.filename = 'docs\\evil.txt'
    zf.writestr(zi, b'backslash payload')
"@
    Assert-Scenario 38 $totalScenarios "Backslash path separator entry inside ZIP" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f38.RepoDir $f38.ReleaseDir); $passed++

    $f39 = New-IsolatedFixture (Join-Path $workRoot "s39") -AdversarialZipScript @"
import sys, zipfile
zp = sys.argv[1]
with zipfile.ZipFile(zp, 'a') as zf:
    zi = zipfile.ZipInfo('placeholder')
    zi.filename = '/abs/evil.txt'
    zf.writestr(zi, b'absolute path payload')
"@
    Assert-Scenario 39 $totalScenarios "Absolute leading slash entry inside ZIP" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f39.RepoDir $f39.ReleaseDir); $passed++

    $f40 = New-IsolatedFixture (Join-Path $workRoot "s40") -AdversarialZipScript @"
import sys, zipfile
zp = sys.argv[1]
with zipfile.ZipFile(zp, 'a') as zf:
    zi = zipfile.ZipInfo('placeholder')
    zi.filename = '../escape.txt'
    zf.writestr(zi, b'traversal payload')
"@
    Assert-Scenario 40 $totalScenarios "Parent traversal ../ entry inside ZIP" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f40.RepoDir $f40.ReleaseDir); $passed++

    $f41 = New-IsolatedFixture (Join-Path $workRoot "s41") -AdversarialZipScript @"
import sys, zipfile
zp = sys.argv[1]
with zipfile.ZipFile(zp, 'a') as zf:
    zi = zipfile.ZipInfo('placeholder')
    zi.filename = 'README.md'
    zf.writestr(zi, b'duplicate entry')
"@
    Assert-Scenario 41 $totalScenarios "Duplicate normalized entry inside ZIP" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f41.RepoDir $f41.ReleaseDir); $passed++

    $f42 = New-IsolatedFixture (Join-Path $workRoot "s42") -AdversarialZipScript @"
import sys, struct
zp = sys.argv[1]
data = bytearray(open(zp, 'rb').read())
# Corrupt CRC32 field (offset 14..18 of first PK\x03\x04 local header) and central dir entry
pos = data.find(b'PK\x03\x04')
assert pos >= 0
data[pos + 14] ^= 0xFF
cd = data.find(b'PK\x01\x02')
assert cd >= 0
data[cd + 16] ^= 0xFF
with open(zp, 'wb') as f:
    f.write(data)
"@
    Assert-Scenario 42 $totalScenarios "Corrupt CRC inside ZIP archive payload" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f42.RepoDir $f42.ReleaseDir); $passed++

    $f43 = New-IsolatedFixture (Join-Path $workRoot "s43") -AdversarialZipScript @"
import sys, zipfile
zp = sys.argv[1]
with zipfile.ZipFile(zp, 'a') as zf:
    zi = zipfile.ZipInfo('placeholder')
    zi.filename = 'readme.md'
    zf.writestr(zi, b'windows case collision')
"@
    Assert-Scenario 43 $totalScenarios "Case-insensitive filename collision inside ZIP (README.md vs readme.md)" $false "GATE-14" "ZipPortability" (Invoke-Verifier $f43.RepoDir $f43.ReleaseDir); $passed++

    $f44 = New-IsolatedFixture (Join-Path $workRoot "s44")
    $r44 = Invoke-Verifier $f44.RepoDir $f44.ReleaseDir
    Assert-Scenario 44 $totalScenarios "Valid POSIX ZIPs extract cleanly across Python, Info-ZIP, and .NET with 3-way parity" $true "" "ZipPortability" $r44
    if ($r44.Output -notmatch '\[GATE-14\]\s+PASS') {
        throw "Scenario 44 FAILED: GATE-14 PASS marker not observed in verifier output!"
    }
    $passed++

    foreach ($footer in @(
        "`n======================================================================",
        " StockFlow v1.6.5 Release Verifier Test Suite Summary:",
        " Passed: $passed / $totalScenarios (100% PASS)",
        "======================================================================"
    )) {
        Write-TestLog $footer
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputReportPath)) {
        $dir = Split-Path -Parent $OutputReportPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllLines($OutputReportPath, $logLines, $utf8NoBom)
    }
    foreach ($pair in @(
        @{ Path = $AuditManifestReportPath; List = $catLogs.AuditManifest; Label = "Gate 09 Audit Manifest Negative & Positive Tests" },
        @{ Path = $GitEvidenceReportPath; List = $catLogs.GitEvidence; Label = "Gate 12 Git Evidence Negative & Positive Tests" },
        @{ Path = $ZipPortabilityReportPath; List = $catLogs.ZipPortability; Label = "Gate 14 ZIP Portability Negative & Positive Tests" }
    )) {
        if (-not [string]::IsNullOrWhiteSpace($pair.Path)) {
            $d = Split-Path -Parent $pair.Path
            if ($d -and -not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            $pair.List.Add("")
            $pair.List.Add("Category: $($pair.Label) | Suite Overall: $passed / $totalScenarios PASSED (0 Failures)")
            [System.IO.File]::WriteAllLines($pair.Path, $pair.List, $utf8NoBom)
        }
    }
    exit 0
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
