# ==============================================================================
# StockFlow - Fail-Closed Official Release Integrity Verifier (v1.6.5)
# Script: scripts/verify-release.ps1
# Description: Strictly enforces all 14 fail-closed release quality gates:
#              GATE-01: Git binary & worktree integrity
#              GATE-02: Archive & manifest existence + schema validation
#              GATE-03: Active branch matches expected & manifest
#              GATE-04: 40-char HEAD commit matches manifest
#              GATE-05: Working tree clean
#              GATE-06: Byte sizes & SHA-256 checksums across all 3 ZIPs
#              GATE-14: Pre-extraction POSIX entry safety + 3-engine extraction
#                       parity (Python zipfile, Info-ZIP unzip, .NET ZipFile)
#              GATE-07: .NET Extraction non-empty file integrity check
#              GATE-08: Source hygiene, 3 env templates, 0 embedded manifests
#              GATE-09: Bidirectional Audit Handover manifest <-> archive checks
#              GATE-10: Loopback 127.0.0.1 Docker Compose port bindings
#              GATE-11: All 4 secret scan reports valid/targeted + live ZIP scan
#              GATE-12: Independent Git evidence & marker-complete git_status.txt
#              GATE-13: Zero en dash / em dash across all 3 ZIPs + evidence + report
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDirectory,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedBranch = "fix/stockflow-v16-5-zip-portability",

    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion = "v1.6.5",

    [Parameter(Mandatory = $false)]
    [string]$OutputSummaryPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPortabilityPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputDashCheckPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "zip-utils.ps1")

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $repoRoot = (Resolve-Path $RepositoryRoot).Path
}

if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
    $releaseDir = Join-Path $repoRoot "release-output\v1.6.5"
} else {
    $releaseDir = (Resolve-Path $TargetDirectory).Path
}

$sourceZipName = "StockFlow_Final_v8_5.zip"
$verifyZipName = "StockFlow_Final_Verification_v8_5.zip"
$handoverZipName = "StockFlow_Audit_Handover_v8_5.zip"
$manifestName = "StockFlow_Release_Checksums_v8_5.txt"

$sourceZipPath = Join-Path $releaseDir $sourceZipName
$verifyZipPath = Join-Path $releaseDir $verifyZipName
$handoverZipPath = Join-Path $releaseDir $handoverZipName
$manifestPath = Join-Path $releaseDir $manifestName
$scannerScript = Join-Path $scriptDir "scan-secrets.ps1"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$gateRecords = [System.Collections.Generic.List[object]]::new()
$totalGates = 14
$checksPassed = 0
$tempTestDir = $null

function Write-SummaryIfRequested([string]$overallStatus) {
    if ([string]::IsNullOrWhiteSpace($OutputSummaryPath)) {
        return
    }
    $sumDir = Split-Path -Parent $OutputSummaryPath
    if (-not [string]::IsNullOrWhiteSpace($sumDir) -and -not (Test-Path -LiteralPath $sumDir)) {
        New-Item -ItemType Directory -Path $sumDir -Force | Out-Null
    }
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# StockFlow $ExpectedVersion Release Verification Summary")
    $md.Add("")
    $md.Add("- Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $md.Add("- Repository Root: $repoRoot")
    $md.Add("- Target Release Directory: $releaseDir")
    $md.Add("- Passed Gates: $checksPassed / $totalGates")
    $md.Add("- Overall Status: $overallStatus")
    $md.Add("")
    $md.Add("## Gate Results Matrix (GATE-01 through GATE-14)")
    $md.Add("")
    $md.Add("| Gate ID | Criteria | Command | Actual Result | Exit Code | Status | Evidence File |")
    $md.Add("| :--- | :--- | :--- | :--- | :---: | :---: | :--- |")
    $sortedRecords = @($gateRecords | Sort-Object { [int]($_.GateId -replace 'GATE-', '') })
    foreach ($rec in $sortedRecords) {
        $safeActual = ($rec.ActualResult -replace '\|', '/' -replace "`r?`n", ' ').Trim()
        $safeCmd = ($rec.Command -replace '\|', '/' -replace "`r?`n", ' ').Trim()
        $md.Add("| $($rec.GateId) | $($rec.Criteria) | ``$safeCmd`` | $safeActual | $($rec.ExitCode) | $($rec.Status) | $($rec.EvidenceFile) |")
    }
    [System.IO.File]::WriteAllLines($OutputSummaryPath, $md, $utf8NoBom)
}

function Fail-Gate([string]$gateId, [string]$criteria, [string]$command, [string]$reason, [string]$evidenceFile = "-") {
    Write-Host "[$gateId] FAIL - $reason"
    $gateRecords.Add([PSCustomObject]@{
        GateId = $gateId
        Criteria = $criteria
        Command = $command
        ActualResult = $reason
        ExitCode = 1
        Status = "FAIL"
        EvidenceFile = $evidenceFile
    })
    Write-SummaryIfRequested "FAILED"
    if ($null -ne $tempTestDir -and (Test-Path -LiteralPath $tempTestDir)) {
        Remove-Item -LiteralPath $tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

function Pass-Gate([string]$gateId, [string]$criteria, [string]$command, [string]$actualResult, [string]$evidenceFile = "-") {
    $script:checksPassed++
    Write-Host "[$gateId] PASS - $actualResult"
    $gateRecords.Add([PSCustomObject]@{
        GateId = $gateId
        Criteria = $criteria
        Command = $command
        ActualResult = $actualResult
        ExitCode = 0
        Status = "PASS"
        EvidenceFile = $evidenceFile
    })
}

function Invoke-GitStrict([string[]]$gitArgs) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $allArgs = @("-C", $repoRoot) + $gitArgs
        $output = & git.exe $allArgs 2>&1 | Out-String
        return [PSCustomObject]@{
            Output = $output
            ExitCode = $LASTEXITCODE
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

Write-Host "======================================================================"
Write-Host " StockFlow Fail-Closed Release Verification Gate ($ExpectedVersion)"
Write-Host " Repository: $repoRoot"
Write-Host " Directory:  $releaseDir"
Write-Host " Gates:      $totalGates Strict Fail-Closed Checks"
Write-Host "======================================================================"

try {
    # --------------------------------------------------------------------------
    # GATE-01: Git Executable & Worktree Integrity
    # --------------------------------------------------------------------------
    $gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -eq $gitCmd) { $gitCmd = Get-Command git -ErrorAction SilentlyContinue }
    if ($null -eq $gitCmd) {
        Fail-Gate "GATE-01" "Git binary available and worktree valid" "git.exe rev-parse --is-inside-work-tree" "Git executable is not available on PATH"
    }
    $wtCheck = Invoke-GitStrict @("rev-parse", "--is-inside-work-tree")
    if ($wtCheck.ExitCode -ne 0 -or $wtCheck.Output.Trim() -ne "true") {
        Fail-Gate "GATE-01" "Git binary available and worktree valid" "git rev-parse --is-inside-work-tree" "Target path '$repoRoot' is not a valid Git worktree (Exit: $($wtCheck.ExitCode))"
    }
    Pass-Gate "GATE-01" "Git binary available and worktree valid" "git rev-parse --is-inside-work-tree" "Git binary available and '$repoRoot' verified as active worktree" "evidence/git/git_identity_verification.txt"

    # --------------------------------------------------------------------------
    # GATE-02: Release Artifacts & External Manifest Existence and Structure
    # --------------------------------------------------------------------------
    foreach ($art in @($sourceZipPath, $verifyZipPath, $handoverZipPath, $manifestPath)) {
        if (-not (Test-Path -LiteralPath $art -PathType Leaf)) {
            Fail-Gate "GATE-02" "All 3 release ZIPs and external manifest exist and valid" "Test-Path $art" "Required release artifact missing: $art"
        }
        if ((Get-Item -LiteralPath $art).Length -le 0) {
            Fail-Gate "GATE-02" "All 3 release ZIPs and external manifest exist and valid" "Get-Item $art" "Release artifact is empty (0 bytes): $art"
        }
    }

    $manifestRaw = Get-Content -LiteralPath $manifestPath -Raw
    if ([string]::IsNullOrWhiteSpace($manifestRaw)) {
        Fail-Gate "GATE-02" "External manifest schema valid" "Parse $manifestName" "External manifest is empty or unreadable"
    }

    $mVersion = [regex]::Match($manifestRaw, '(?m)^Release Version:\s*(\S+)\s*$')
    $mBranch  = [regex]::Match($manifestRaw, '(?m)^Git Branch:\s*(\S+)\s*$')
    $mCommit  = [regex]::Match($manifestRaw, '(?m)^Git Commit:\s*([a-f0-9]{40})\s*$')
    $mTree    = [regex]::Match($manifestRaw, '(?m)^Working Tree:\s*(.+?)\s*$')

    if (-not $mVersion.Success -or -not $mBranch.Success -or -not $mCommit.Success -or -not $mTree.Success) {
        Fail-Gate "GATE-02" "External manifest schema valid" "Parse header fields of $manifestName" "Manifest is corrupt or missing required header fields"
    }
    if ($mVersion.Groups[1].Value -cne $ExpectedVersion) {
        Fail-Gate "GATE-02" "External manifest version match" "Compare Release Version" "Manifest Release Version '$($mVersion.Groups[1].Value)' does not match '$ExpectedVersion'"
    }

    $manifestBranch = $mBranch.Groups[1].Value.Trim()
    $manifestCommit = $mCommit.Groups[1].Value.Trim().ToLowerInvariant()
    $manifestTree   = $mTree.Groups[1].Value.Trim()

    $pkgSpecs = @(
        @{ Index = 1; ExpectedName = $sourceZipName; Path = $sourceZipPath },
        @{ Index = 2; ExpectedName = $verifyZipName; Path = $verifyZipPath },
        @{ Index = 3; ExpectedName = $handoverZipName; Path = $handoverZipPath }
    )
    $parsedPackages = @{}
    foreach ($ps in $pkgSpecs) {
        $idx = $ps.Index
        $pkgPattern = "(?ms)^Package ${idx}:\s*\r?\nName:\s*(\S+)\s*\r?\nDescription:\s*[^\r\n]+\r?\nSize:\s*(\d+)\s*bytes\s*\r?\nSHA-256:\s*([A-Fa-f0-9]{64})\s*$"
        $pm = [regex]::Match($manifestRaw, $pkgPattern)
        if (-not $pm.Success) {
            Fail-Gate "GATE-02" "Manifest package block $idx valid" "Parse Package $idx in $manifestName" "Manifest missing or malformed Package $idx block"
        }
        if ($pm.Groups[1].Value.Trim() -cne $ps.ExpectedName) {
            Fail-Gate "GATE-02" "Manifest package block $idx name valid" "Check Package $idx Name" "Package $idx Name mismatches expected '$($ps.ExpectedName)'"
        }
        $parsedPackages[$idx] = @{
            Name = $pm.Groups[1].Value.Trim()
            Size = [int64]$pm.Groups[2].Value.Trim()
            Hash = $pm.Groups[3].Value.Trim().ToUpperInvariant()
            Path = $ps.Path
        }
    }
    Pass-Gate "GATE-02" "All 3 ZIPs and well-formed manifest exist" "Inspect $releaseDir deliverables" "Verified 3 ZIPs and complete manifest ($manifestName)" $manifestName

    # --------------------------------------------------------------------------
    # GATE-03: Git Branch Validation
    # --------------------------------------------------------------------------
    $branchRes = Invoke-GitStrict @("branch", "--show-current")
    if ($branchRes.ExitCode -ne 0) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Failed to query active branch (Exit: $($branchRes.ExitCode))"
    }
    $actualBranch = $branchRes.Output.Trim()
    if ([string]::IsNullOrWhiteSpace($actualBranch) -or $actualBranch -cne $ExpectedBranch -or $actualBranch -cne $manifestBranch) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Branch mismatch (actual='$actualBranch', expected='$ExpectedBranch', manifest='$manifestBranch')"
    }
    Pass-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Branch exact match: $actualBranch" "evidence/git/git_branch.txt"

    # --------------------------------------------------------------------------
    # GATE-04: Full 40-Character Commit Hash Exact Validation
    # --------------------------------------------------------------------------
    $headRes = Invoke-GitStrict @("rev-parse", "HEAD")
    if ($headRes.ExitCode -ne 0) {
        Fail-Gate "GATE-04" "Full 40-character HEAD commit matches manifest" "git rev-parse HEAD" "Failed to resolve Git HEAD commit (Exit: $($headRes.ExitCode))"
    }
    $actualHeadCommit = $headRes.Output.Trim().ToLowerInvariant()
    if ($actualHeadCommit -notmatch '^[a-f0-9]{40}$' -or $actualHeadCommit -cne $manifestCommit) {
        Fail-Gate "GATE-04" "Full 40-character HEAD commit matches manifest" "Compare git rev-parse HEAD with manifest" "Git commit mismatch (HEAD='$actualHeadCommit' vs Manifest='$manifestCommit')"
    }
    Pass-Gate "GATE-04" "Full 40-character HEAD commit matches manifest" "git rev-parse HEAD" "Full 40-char commit exact match: $actualHeadCommit" "evidence/git/git_commit.txt"

    # --------------------------------------------------------------------------
    # GATE-05: Clean Working Tree Verification
    # --------------------------------------------------------------------------
    $statusRes = Invoke-GitStrict @("status", "--porcelain", "--untracked-files=all")
    if ($statusRes.ExitCode -ne 0) {
        Fail-Gate "GATE-05" "Git working tree completely clean" "git status --porcelain --untracked-files=all" "Failed to query git status (Exit: $($statusRes.ExitCode))"
    }
    if (-not [string]::IsNullOrWhiteSpace($statusRes.Output)) {
        $dirtyPreview = ($statusRes.Output.Trim() -split "`r?`n" | Select-Object -First 5) -join "; "
        Fail-Gate "GATE-05" "Git working tree completely clean" "git status --porcelain --untracked-files=all" "Dirty Git working tree detected: $dirtyPreview"
    }
    if ($manifestTree -cne "Clean") {
        Fail-Gate "GATE-05" "Manifest declares Clean working tree" "Check Working Tree field in manifest" "Manifest Working Tree is '$manifestTree', expected 'Clean'"
    }
    Pass-Gate "GATE-05" "Git working tree completely clean" "git status --porcelain --untracked-files=all" "Working tree verified clean (0 modified, staged, or untracked changes)" "evidence/git/git_status.txt"

    # --------------------------------------------------------------------------
    # GATE-06: Byte Size & SHA-256 Checksum Comparison Across All 3 Packages
    # --------------------------------------------------------------------------
    foreach ($idx in @(1, 2, 3)) {
        $pkg = $parsedPackages[$idx]
        $actualLen = (Get-Item -LiteralPath $pkg.Path).Length
        $actualSha = (Get-FileHash -LiteralPath $pkg.Path -Algorithm SHA256).Hash.ToUpperInvariant()

        if ($actualLen -ne $pkg.Size) {
            Fail-Gate "GATE-06" "Exact byte size match for $($pkg.Name)" "Get-Item $($pkg.Name)" "Size mismatch for $($pkg.Name): actual=$actualLen bytes, manifest=$($pkg.Size) bytes"
        }
        if ($actualSha -cne $pkg.Hash) {
            Fail-Gate "GATE-06" "Exact SHA-256 match for $($pkg.Name)" "Get-FileHash $($pkg.Name) -Algorithm SHA256" "SHA-256 mismatch for $($pkg.Name): actual=$actualSha, manifest=$($pkg.Hash)"
        }
    }
    Pass-Gate "GATE-06" "Byte sizes and SHA-256 match across all 3 ZIPs" "Get-FileHash -Algorithm SHA256" "All 3 ZIP byte sizes and SHA-256 hashes match external manifest 100%" $manifestName

    # --------------------------------------------------------------------------
    # GATE-14 (Pre-Extraction Guard + 3-Engine Cross-Platform Extraction Parity)
    # Executed BEFORE extracting ZIP payloads onto host filesystem for safety.
    # --------------------------------------------------------------------------
    $tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_gate165_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $tempTestDir -Force | Out-Null

    $portLines = [System.Collections.Generic.List[string]]::new()
    $portLines.Add("================================================================================")
    $portLines.Add("STOCKFLOW $ExpectedVersion - CROSS-PLATFORM ZIP PORTABILITY & 3-WAY EXTRACTION REPORT")
    $portLines.Add("================================================================================")
    $portLines.Add("Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $portLines.Add("Target Directory: $releaseDir")
    $portLines.Add("Required Extractors: Python zipfile | Info-ZIP unzip | .NET ZipFile")
    $portLines.Add("")

    $xplatWork = Join-Path $tempTestDir "portability"
    New-Item -ItemType Directory -Path $xplatWork -Force | Out-Null

    $xplatSummaryParts = [System.Collections.Generic.List[string]]::new()
    foreach ($zipCheck in @(
        @{ Label = $sourceZipName; Path = $sourceZipPath },
        @{ Label = $verifyZipName; Path = $verifyZipPath },
        @{ Label = $handoverZipName; Path = $handoverZipPath }
    )) {
        $xpRes = Invoke-CrossPlatformZipValidation -ZipPath $zipCheck.Path -ArchiveLabel $zipCheck.Label -TempWorkRoot $xplatWork
        foreach ($rl in $xpRes.ReportLines) { $portLines.Add($rl) }
        if (-not $xpRes.Passed) {
            if (-not [string]::IsNullOrWhiteSpace($OutputPortabilityPath)) {
                $pDir = Split-Path -Parent $OutputPortabilityPath
                if ($pDir -and -not (Test-Path -LiteralPath $pDir)) { New-Item -ItemType Directory -Path $pDir -Force | Out-Null }
                [System.IO.File]::WriteAllLines($OutputPortabilityPath, $portLines, $utf8NoBom)
            }
            Fail-Gate "GATE-14" "POSIX ZIP hygiene & 3-engine cross-platform parity" "Python + Info-ZIP + .NET on $($zipCheck.Label)" $xpRes.FailureReason "evidence/portability/zip_portability_verification.txt"
        }
        $xplatSummaryParts.Add("$($zipCheck.Label)=$($xpRes.EntryCount) entries/0 backslashes/3-way match")
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputPortabilityPath)) {
        $pDir = Split-Path -Parent $OutputPortabilityPath
        if ($pDir -and -not (Test-Path -LiteralPath $pDir)) { New-Item -ItemType Directory -Path $pDir -Force | Out-Null }
        [System.IO.File]::WriteAllLines($OutputPortabilityPath, $portLines, $utf8NoBom)
    }
    Pass-Gate "GATE-14" "POSIX ZIP hygiene & 3-engine cross-platform parity (Python/Info-ZIP/.NET)" "Validate entries + CRC + Python/Info-ZIP/.NET extraction & 3-way SHA-256 parity" ($xplatSummaryParts -join "; ") "evidence/portability/zip_portability_verification.txt"

    # --------------------------------------------------------------------------
    # GATE-07: Safe Archive Extraction Integrity Verification
    # --------------------------------------------------------------------------
    $srcExtDir = Join-Path $tempTestDir "source"
    $verExtDir = Join-Path $tempTestDir "verify"
    $hanExtDir = Join-Path $tempTestDir "handover"

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($sourceZipPath, $srcExtDir)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($verifyZipPath, $verExtDir)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($handoverZipPath, $hanExtDir)
    } catch {
        Fail-Gate "GATE-07" "All 3 ZIP archives extract cleanly via .NET" "ZipFile::ExtractToDirectory" "Archive extraction error: $($_.Exception.Message)"
    }

    $srcFiles = @(Get-ChildItem -LiteralPath $srcExtDir -Recurse -File)
    $verFiles = @(Get-ChildItem -LiteralPath $verExtDir -Recurse -File)
    $hanFiles = @(Get-ChildItem -LiteralPath $hanExtDir -Recurse -File)

    if ($srcFiles.Count -eq 0 -or $verFiles.Count -eq 0 -or $hanFiles.Count -eq 0) {
        Fail-Gate "GATE-07" "Extracted ZIPs are non-empty" "Count extracted files" "One or more archives extracted 0 files ($($srcFiles.Count) / $($verFiles.Count) / $($hanFiles.Count))"
    }
    Pass-Gate "GATE-07" "All 3 ZIP archives extract cleanly" "ZipFile::ExtractToDirectory on 3 ZIPs" "Clean extraction: Source=$($srcFiles.Count) files, Verification=$($verFiles.Count) files, Handover=$($hanFiles.Count) files" "release_verification_summary.md"

    # --------------------------------------------------------------------------
    # GATE-08: Source Package Hygiene, Env Templates & Manifest Exclusion
    # --------------------------------------------------------------------------
    foreach ($tpl in @(".env.example", "backend\.env.example", "frontend\.env.example")) {
        if (-not (Test-Path -LiteralPath (Join-Path $srcExtDir $tpl) -PathType Leaf)) {
            Fail-Gate "GATE-08" "Required environment templates present in Source ZIP" "Test-Path $tpl" "Required template '$tpl' missing from Source ZIP"
        }
    }
    foreach ($fb in @(".env", ".env.local", ".secrets", "release-output", "audit")) {
        if (Test-Path -LiteralPath (Join-Path $srcExtDir $fb)) {
            Fail-Gate "GATE-08" "Sensitive / build dirs excluded from Source ZIP" "Check absent $fb" "Forbidden sensitive or build path '$fb' found in Source ZIP"
        }
    }
    foreach ($dirCheck in @(@($sourceZipName, $srcExtDir), @($verifyZipName, $verExtDir), @($handoverZipName, $hanExtDir))) {
        $label = $dirCheck[0]
        $rootCheck = $dirCheck[1]
        $leakedManifests = @(Get-ChildItem -LiteralPath $rootCheck -Recurse -File | Where-Object {
            $_.Name -match '^StockFlow_Release_Checksums.*\.txt$' -or $_.Name -eq 'RELEASE_CHECKSUMS.txt'
        })
        if ($leakedManifests.Count -gt 0) {
            $names = ($leakedManifests | ForEach-Object { $_.FullName.Substring($rootCheck.Length).TrimStart('\', '/') }) -join ", "
            Fail-Gate "GATE-08" "No historical/external checksum manifests inside ZIPs" "Scan checksum manifests in $label" "Checksum manifest file(s) embedded inside ${label}: $names"
        }
    }
    Pass-Gate "GATE-08" "Source hygiene, 3 env templates, and zero embedded checksum manifests" "Inspect Source/Verify/Handover extracted contents" "All 3 env templates present; zero secrets and zero embedded checksum manifests in any ZIP" "evidence/release/source_package_verification.txt"

    # --------------------------------------------------------------------------
    # GATE-09: Bidirectional Audit Handover Completeness & Manifest Accuracy
    # --------------------------------------------------------------------------
    $hanManifestPath = Join-Path $hanExtDir "AUDIT_FILE_MANIFEST.md"
    if (-not (Test-Path -LiteralPath $hanManifestPath -PathType Leaf)) {
        Fail-Gate "GATE-09" "Bidirectional Audit Handover manifest accuracy" "Test-Path AUDIT_FILE_MANIFEST.md" "AUDIT_FILE_MANIFEST.md missing inside Handover ZIP"
    }

    $hanManifestLines = [System.IO.File]::ReadAllLines($hanManifestPath)
    $inExternalSection = $false
    $isInventorySection = $false
    $colIndex = @{}
    $inventoryManifestSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $traceRowsChecked = 0

    foreach ($line in $hanManifestLines) {
        if ($line -match '^##\s+.*External Post-') {
            $inExternalSection = $true
            $isInventorySection = $false
            $colIndex = @{}
            continue
        }
        if ($line -match '^##\s+.*Complete Handover Archive File Inventory') {
            $inExternalSection = $false
            $isInventorySection = $true
            $colIndex = @{}
            continue
        }
        if ($line -match '^##\s+') {
            $inExternalSection = $false
            $isInventorySection = $false
            $colIndex = @{}
            continue
        }
        if ($inExternalSection) { continue }

        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith("|")) {
            $colIndex = @{}
            continue
        }

        $rawCells = @($trimmed.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($rawCells.Count -eq 0 -or $rawCells[0] -match '^:?-{2,}:?$') { continue }

        if ($rawCells -contains "Archive Path" -and ($rawCells -contains "Verification Status" -or $rawCells -contains "File Exists")) {
            $colIndex = @{}
            for ($ci = 0; $ci -lt $rawCells.Count; $ci++) {
                $colIndex[$rawCells[$ci]] = $ci
            }
            continue
        }

        if ($colIndex.ContainsKey("Archive Path") -and $rawCells.Count -gt $colIndex["Archive Path"]) {
            $archPathCell = $rawCells[$colIndex["Archive Path"]]
            $existsCell = if ($colIndex.ContainsKey("File Exists") -and $rawCells.Count -gt $colIndex["File Exists"]) { $rawCells[$colIndex["File Exists"]] } else { "" }
            $sizeCell = if ($colIndex.ContainsKey("Size (bytes)") -and $rawCells.Count -gt $colIndex["Size (bytes)"]) { $rawCells[$colIndex["Size (bytes)"]] } else { "" }
            $shaCell = if ($colIndex.ContainsKey("SHA-256") -and $rawCells.Count -gt $colIndex["SHA-256"]) { $rawCells[$colIndex["SHA-256"]] } else { "" }
            $statusCell = if ($colIndex.ContainsKey("Verification Status") -and $rawCells.Count -gt $colIndex["Verification Status"]) { $rawCells[$colIndex["Verification Status"]] } else { "" }

            if ($statusCell -in @("Missing", "Not Verified", "Hash Mismatch", "Size Mismatch") -or ($statusCell -ne "Verified" -and -not [string]::IsNullOrWhiteSpace($statusCell))) {
                Fail-Gate "GATE-09" "Bidirectional Audit Handover manifest accuracy" "Validate status in $hanManifestPath" "Invalid verification status '$statusCell' on '$archPathCell'"
            }
            if ([string]::IsNullOrWhiteSpace($archPathCell)) {
                Fail-Gate "GATE-09" "Bidirectional Audit Handover manifest accuracy" "Parse Archive Path" "Manifest row contains empty Archive Path"
            }
            if ($existsCell -ne "Yes" -or $statusCell -ne "Verified") {
                Fail-Gate "GATE-09" "Bidirectional Audit Handover manifest accuracy" "Check row status" "Row '$archPathCell' does not state File Exists=Yes & Status=Verified"
            }

            if ($isInventorySection) {
                if ($archPathCell -eq "AUDIT_FILE_MANIFEST.md") {
                    Fail-Gate "GATE-09" "Non-self-referential inventory rule" "Check self-reference" "AUDIT_FILE_MANIFEST.md illegally listed inside its own SHA-256 inventory"
                }
                if (-not $inventoryManifestSet.Add($archPathCell)) {
                    Fail-Gate "GATE-09" "Zero duplicate inventory paths" "Check uniqueness of '$archPathCell'" "Duplicate normalized path in AUDIT_FILE_MANIFEST.md inventory: '$archPathCell'"
                }
            } else {
                $traceRowsChecked++
            }

            $candidatePath = Join-Path $hanExtDir ($archPathCell.Replace('/', '\'))
            if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                Fail-Gate "GATE-09" "Manifest -> Archive existence check" "Test-Path $archPathCell" "Manifest claims '$archPathCell' is Verified but file is MISSING from Handover ZIP!"
            }

            $actualItem = Get-Item -LiteralPath $candidatePath
            if (-not [string]::IsNullOrWhiteSpace($sizeCell)) {
                $parsedSize = 0L
                if (-not [int64]::TryParse($sizeCell, [ref]$parsedSize)) {
                    Fail-Gate "GATE-09" "Manifest -> Archive byte size validation" "Parse size for $archPathCell" "Invalid size value '$sizeCell' for '$archPathCell'"
                }
                if ([int64]$actualItem.Length -ne $parsedSize) {
                    Fail-Gate "GATE-09" "Manifest -> Archive byte size match" "Compare size of $archPathCell" "Size Mismatch on '$archPathCell': actual=$($actualItem.Length) vs manifest=$parsedSize"
                }
            } elseif ($isInventorySection) {
                Fail-Gate "GATE-09" "Inventory byte size required" "Check Size column" "Missing Size (bytes) in inventory for '$archPathCell'"
            }

            if ($shaCell -notmatch '^[A-Fa-f0-9]{64}$') {
                Fail-Gate "GATE-09" "Manifest SHA-256 format required" "Validate SHA-256 for $archPathCell" "Missing or invalid 64-char SHA-256 '$shaCell' for '$archPathCell'"
            }
            $actualEntrySha = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($actualEntrySha -cne $shaCell.ToUpperInvariant()) {
                Fail-Gate "GATE-09" "Manifest -> Archive SHA-256 match" "Compare SHA-256 of $archPathCell" "Hash Mismatch on '$archPathCell' (actual=$actualEntrySha vs manifest=$($shaCell.ToUpperInvariant()))"
            }
        }
    }

    if ($inventoryManifestSet.Count -eq 0) {
        Fail-Gate "GATE-09" "Audit Handover inventory non-empty" "Parse Section Complete Handover Archive File Inventory" "AUDIT_FILE_MANIFEST.md contains zero inventory file rows"
    }

    # Reverse Direction: Archive -> Manifest (reject ANY extra unlisted or disallowed path)
    $extraFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($hf in $hanFiles) {
        $relUnix = $hf.FullName.Substring($hanExtDir.Length).TrimStart('\', '/').Replace('\', '/')
        if ($relUnix -eq "AUDIT_FILE_MANIFEST.md") { continue }
        if ($relUnix -notmatch '^(?:source|evidence|documentation)/') {
            Fail-Gate "GATE-09" "Handover archive top-level structure policy" "Inspect path $relUnix" "File outside allowed handover directories (source/, evidence/, documentation/): '$relUnix'"
        }
        if (-not $inventoryManifestSet.Contains($relUnix)) {
            $extraFiles.Add($relUnix)
        }
    }
    if ($extraFiles.Count -gt 0) {
        Fail-Gate "GATE-09" "Archive -> Manifest exact match (0 unlisted files)" "Reverse compare Handover ZIP files vs manifest" "Extra unlisted file(s) found inside Handover ZIP: $($extraFiles -join ', ')"
    }
    Pass-Gate "GATE-09" "Bidirectional Audit Handover completeness & accuracy" "Verify Manifest <-> Handover ZIP ($($inventoryManifestSet.Count) inventory + AUDIT_FILE_MANIFEST.md)" "Bidirectional match 100%: $($inventoryManifestSet.Count) inventory verified (+1 manifest), 0 Missing, 0 Extra, 0 Duplicates, 0 Mismatches" "evidence/handover/audit_handover_completeness.txt"

    # --------------------------------------------------------------------------
    # GATE-10: Loopback Port Binding Enforcement Across Compose Files
    # --------------------------------------------------------------------------
    $composeFiles = @(Get-ChildItem -LiteralPath $srcExtDir -Filter "docker-compose*.yml")
    foreach ($cf in $composeFiles) {
        $yamlLines = [System.IO.File]::ReadAllLines($cf.FullName)
        $inPortsBlock = $false
        $portsIndent = -1
        foreach ($yl in $yamlLines) {
            if ($yl -match '^\s*#' -or [string]::IsNullOrWhiteSpace($yl)) { continue }
            if ($yl -match '^(\s*)ports:\s*(?:#.*)?$') {
                $inPortsBlock = $true
                $portsIndent = $matches[1].Length
                continue
            }
            if ($inPortsBlock) {
                $curIndent = ($yl -replace '^(\s*).*', '$1').Length
                if ($yl -match '^\s*-\s*(.+)$' -and $curIndent -ge $portsIndent) {
                    $rawPort = $matches[1].Trim().Trim('"', "'")
                    if ($rawPort -notmatch '^(?:127\.0\.0\.1|\$\{[A-Za-z0-9_]+:-127\.0\.0\.1\}):') {
                        Fail-Gate "GATE-10" "All Compose ports bound strictly to 127.0.0.1" "Inspect $($cf.Name) ports:" "Non-loopback port mapping '$rawPort' found in $($cf.Name)"
                    }
                } elseif ($curIndent -le $portsIndent) {
                    $inPortsBlock = $false
                }
            }
        }
    }
    Pass-Gate "GATE-10" "All Compose ports bound strictly to 127.0.0.1" "Inspect docker-compose*.yml ports blocks" "Checked $($composeFiles.Count) compose file(s); 100% bound to loopback 127.0.0.1" "evidence/docker/docker_compose_verification.txt"

    # --------------------------------------------------------------------------
    # GATE-11: All 4 Secret Scan Reports Present/Targeted/Clean + Live ZIP Scans
    # --------------------------------------------------------------------------
    $secEvDir = Join-Path $releaseDir "evidence\security"
    $requiredScanReports = @(
        @{ File = "secret_scan_repository.txt"; Kind = "repo"; ExpectedMatch = [regex]::Escape((Split-Path -Leaf $repoRoot)) },
        @{ File = "source_package_scan.txt"; Kind = "zip"; ExpectedMatch = [regex]::Escape($sourceZipName) },
        @{ File = "verification_package_scan.txt"; Kind = "zip"; ExpectedMatch = [regex]::Escape($verifyZipName) },
        @{ File = "audit_handover_package_scan.txt"; Kind = "zip"; ExpectedMatch = [regex]::Escape($handoverZipName) }
    )

    foreach ($sr in $requiredScanReports) {
        $rpPath = Join-Path $secEvDir $sr.File
        if (-not (Test-Path -LiteralPath $rpPath -PathType Leaf)) {
            Fail-Gate "GATE-11" "All 4 secret scan reports exist" "Test-Path $($sr.File)" "Required security scan report missing: $rpPath"
        }
        $rpRaw = [System.IO.File]::ReadAllText($rpPath)
        $mTarget = [regex]::Match($rpRaw, '(?m)^Scan Target:\s*(.+?)\s*$')
        $mFound  = [regex]::Match($rpRaw, '(?m)^Total Findings:\s*(\d+)\s*$')
        $mStatus = [regex]::Match($rpRaw, '(?m)^Scan Status:\s*(.+?)\s*$')
        $mExit   = [regex]::Match($rpRaw, '(?m)^Exit Code:\s*(\d+)\s*$')
        $mCount  = [regex]::Match($rpRaw, '(?m)^Total Files Scanned:\s*(\d+)\s*$')

        if (-not $mTarget.Success -or -not $mFound.Success -or -not $mStatus.Success -or -not $mExit.Success -or -not $mCount.Success) {
            Fail-Gate "GATE-11" "Secret scan report schema complete" "Parse $($sr.File)" "Scan report '$($sr.File)' missing required metadata fields (Target/Findings/Status/Exit Code/Files Scanned)"
        }
        $tVal = $mTarget.Groups[1].Value.Trim()
        if ($sr.Kind -eq "repo") {
            if ($tVal -match '\.zip$') {
                Fail-Gate "GATE-11" "Repository scan report targets repository" "Verify target in $($sr.File)" "Repository scan '$($sr.File)' wrongly targets ZIP archive '$tVal'"
            }
            if ($tVal -notmatch $sr.ExpectedMatch) {
                Fail-Gate "GATE-11" "Repository scan report targets active repository" "Verify target in $($sr.File)" "Repository scan target '$tVal' mismatches expected repository '$repoRoot'"
            }
        } else {
            if ($tVal -notmatch ($sr.ExpectedMatch + '$')) {
                Fail-Gate "GATE-11" "Package scan report targets exact ZIP" "Verify target in $($sr.File)" "Scan report '$($sr.File)' targets wrong artifact '$tVal', expected '$($sr.ExpectedMatch)'"
            }
        }
        if ([int]$mFound.Groups[1].Value -ne 0 -or $mStatus.Groups[1].Value.Trim() -cne "100% CLEAN" -or [int]$mExit.Groups[1].Value -ne 0) {
            Fail-Gate "GATE-11" "Secret scan report passed cleanly" "Check Findings & Exit in $($sr.File)" "Security scan report '$($sr.File)' did not pass cleanly (Findings=$($mFound.Groups[1].Value), Status=$($mStatus.Groups[1].Value.Trim()), Exit=$($mExit.Groups[1].Value))"
        }
        if ([int]$mCount.Groups[1].Value -le 0) {
            Fail-Gate "GATE-11" "Secret scan inspected >0 files" "Check Files Scanned in $($sr.File)" "Security scan report '$($sr.File)' recorded 0 scanned files"
        }
    }

    # Also run live verification scan on extracted Source, Verification, Handover contents
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($st in @(
            @{ Label = "Source ZIP"; Path = $srcExtDir },
            @{ Label = "Verification ZIP"; Path = $verExtDir },
            @{ Label = "Handover ZIP"; Path = $hanExtDir }
        )) {
            $scanOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scannerScript -TargetScanPath $st.Path 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $ErrorActionPreference = $prevEap
                Fail-Gate "GATE-11" "Live zero leaked credentials across extracted archives" "scan-secrets.ps1 -TargetScanPath $($st.Label)" "Secret scanner detected findings in $($st.Label) (Exit: $LASTEXITCODE)"
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Pass-Gate "GATE-11" "All 4 secret scan reports valid & live scans 100% CLEAN" "Verify 4 scan reports + live ZIP secret scans" "All 4 reports (repo, source, verification, handover) verified 100% CLEAN (Exit 0, 0 findings)" "evidence/security/verification_package_scan.txt"

    # --------------------------------------------------------------------------
    # GATE-12: Independent Git Evidence Verification (Verification ZIP & Handover ZIP)
    # --------------------------------------------------------------------------
    $gitAuditSummaries = [System.Collections.Generic.List[string]]::new()
    foreach ($evPkg in @(@("Verification ZIP", $verExtDir), @("Handover ZIP", $hanExtDir))) {
        $pkgLabel = $evPkg[0]
        $pkgRoot = $evPkg[1]
        $gitSubDir = Join-Path $pkgRoot "evidence\git"

        foreach ($reqGitFile in @("git_branch.txt", "git_commit.txt", "git_status.txt", "git_log.txt", "git_identity_verification.txt")) {
            $fp = Join-Path $gitSubDir $reqGitFile
            if (-not (Test-Path -LiteralPath $fp -PathType Leaf)) {
                Fail-Gate "GATE-12" "All 5 Git evidence files exist inside $pkgLabel" "Test-Path evidence/git/$reqGitFile in $pkgLabel" "Missing '$reqGitFile' inside $pkgLabel"
            }
        }

        $branchRaw = [System.IO.File]::ReadAllText((Join-Path $gitSubDir "git_branch.txt"))
        $commitRaw = [System.IO.File]::ReadAllText((Join-Path $gitSubDir "git_commit.txt"))
        $statusRaw = [System.IO.File]::ReadAllText((Join-Path $gitSubDir "git_status.txt"))

        $mBrVal = [regex]::Match($branchRaw, '(?m)^Branch:\s*(\S+)\s*$')
        $evBranchVal = if ($mBrVal.Success) { $mBrVal.Groups[1].Value.Trim() } else { $branchRaw.Trim() }
        if ($evBranchVal -cne $actualBranch -or $branchRaw -notmatch '(?m)^Timestamp:\s*\S+' -or $branchRaw -notmatch '(?m)^Exit Code:\s*0\s*$') {
            Fail-Gate "GATE-12" "Valid Branch evidence inside $pkgLabel" "Inspect git_branch.txt in $pkgLabel" "git_branch.txt invalid or mismatched in $pkgLabel (branch='$evBranchVal' vs HEAD branch='$actualBranch')"
        }

        $mCmVal = [regex]::Match($commitRaw, '(?m)^Commit:\s*([a-fA-F0-9]{40})\s*$')
        $evCommitVal = if ($mCmVal.Success) { $mCmVal.Groups[1].Value.Trim().ToLowerInvariant() } else { $commitRaw.Trim().ToLowerInvariant() }
        if ($evCommitVal -cne $actualHeadCommit -or $commitRaw -notmatch '(?m)^Timestamp:\s*\S+' -or $commitRaw -notmatch '(?m)^Exit Code:\s*0\s*$') {
            Fail-Gate "GATE-12" "Valid 40-char Commit evidence inside $pkgLabel" "Inspect git_commit.txt in $pkgLabel" "git_commit.txt invalid or mismatched in $pkgLabel (commit='$evCommitVal' vs HEAD='$actualHeadCommit')"
        }

        # Strict Fail-Closed validation on git_status.txt (reject empty files, missing metadata, non-zero exit, or non-empty porcelain section)
        if ([string]::IsNullOrWhiteSpace($statusRaw)) {
            Fail-Gate "GATE-12" "Non-empty metadata-complete git_status.txt in $pkgLabel" "Inspect git_status.txt in $pkgLabel" "git_status.txt inside $pkgLabel is completely empty (0 metadata)"
        }
        $mStCmd  = [regex]::Match($statusRaw, '(?m)^Command:\s*git status --porcelain --untracked-files=all\s*$')
        $mStTs   = [regex]::Match($statusRaw, '(?m)^Timestamp:\s*(.+?)\s*$')
        $mStWd   = [regex]::Match($statusRaw, '(?m)^Working Directory:\s*(.+?)\s*$')
        $mStExit = [regex]::Match($statusRaw, '(?m)^Exit Code:\s*(\d+)\s*$')
        $mStWt   = [regex]::Match($statusRaw, '(?m)^Working Tree:\s*(.+?)\s*$')
        $mMarkers = [regex]::Match($statusRaw, '(?m)^PORCELAIN_OUTPUT_BEGIN\r?\n([\s\S]*?)^PORCELAIN_OUTPUT_END(?:\r?\n|$)')

        if (-not $mStCmd.Success -or -not $mStTs.Success -or -not $mStWd.Success -or -not $mStExit.Success -or -not $mStWt.Success -or -not $mMarkers.Success) {
            Fail-Gate "GATE-12" "git_status.txt contains required metadata & markers in $pkgLabel" "Validate git_status.txt structure in $pkgLabel" "git_status.txt inside $pkgLabel is missing required metadata (Command/Timestamp/Working Directory/Exit Code/PORCELAIN_OUTPUT markers)"
        }
        if ([int]$mStExit.Groups[1].Value -ne 0) {
            Fail-Gate "GATE-12" "git status Exit Code == 0 in $pkgLabel" "Check Exit Code in git_status.txt" "git_status.txt inside $pkgLabel recorded command failure (Exit Code: $($mStExit.Groups[1].Value))"
        }
        $porcelainInner = $mMarkers.Groups[1].Value.Trim()
        if (-not [string]::IsNullOrEmpty($porcelainInner)) {
            Fail-Gate "GATE-12" "Empty porcelain block proving clean tree in $pkgLabel" "Check PORCELAIN_OUTPUT block in git_status.txt" "git_status.txt inside $pkgLabel contains uncommitted changes: $porcelainInner"
        }
        if ($mStWt.Groups[1].Value.Trim() -cne "Clean") {
            Fail-Gate "GATE-12" "Working Tree: Clean in $pkgLabel" "Check Working Tree status" "git_status.txt inside $pkgLabel reports '$($mStWt.Groups[1].Value.Trim())', expected 'Clean'"
        }
        $gitAuditSummaries.Add("$pkgLabel=OK($($evCommitVal.Substring(0,8))/Clean)")
    }
    Pass-Gate "GATE-12" "Independent Git evidence & metadata-complete git_status.txt verified across Verification & Handover ZIPs" "Verify 5 Git evidence files + metadata/markers in Verification & Handover ZIPs" ($gitAuditSummaries -join "; ") "evidence/git/git_status.txt"

    # --------------------------------------------------------------------------
    # GATE-13: Writing Constraint Verification Across ALL 3 ZIPs + Evidence + Report
    # --------------------------------------------------------------------------
    $enDashChar = [char]0x2013
    $emDashChar = [char]0x2014
    $dashViolations = [System.Collections.Generic.List[string]]::new()
    $dashReportLines = [System.Collections.Generic.List[string]]::new()
    $dashReportLines.Add("================================================================================")
    $dashReportLines.Add("STOCKFLOW $ExpectedVersion - MARKDOWN WRITING CONSTRAINT VERIFICATION")
    $dashReportLines.Add("================================================================================")
    $dashReportLines.Add("Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $dashReportLines.Add("Forbidden Characters: U+2013 (En Dash), U+2014 (Em Dash)")
    $dashReportLines.Add("")

    $srcMdFiles = @(Get-ChildItem -LiteralPath $srcExtDir -Filter "*.md" -Recurse -File)
    $verMdFiles = @(Get-ChildItem -LiteralPath $verExtDir -Filter "*.md" -Recurse -File)
    $hanMdFiles = @(Get-ChildItem -LiteralPath $hanExtDir -Filter "*.md" -Recurse -File)
    $evMdDir = Join-Path $releaseDir "evidence"
    $evMdFiles = @()
    if (Test-Path -LiteralPath $evMdDir) {
        $evMdFiles = @(Get-ChildItem -LiteralPath $evMdDir -Filter "*.md" -Recurse -File)
    }
    $extReportFiles = @(Get-ChildItem -LiteralPath $releaseDir -Filter "*.md" -File)

    $scopeDefs = @(
        @{ Label = "Source ZIP"; Root = $srcExtDir; Files = $srcMdFiles },
        @{ Label = "Verification ZIP"; Root = $verExtDir; Files = $verMdFiles },
        @{ Label = "Handover ZIP"; Root = $hanExtDir; Files = $hanMdFiles },
        @{ Label = "Release Evidence Markdown"; Root = $releaseDir; Files = $evMdFiles },
        @{ Label = "External Release Report(s)"; Root = $releaseDir; Files = $extReportFiles }
    )

    $totalMdChecked = 0
    foreach ($sc in $scopeDefs) {
        $fileList = @($sc.Files)
        $cnt = $fileList.Count
        $totalMdChecked += $cnt
        $scopeFails = 0
        foreach ($doc in $fileList) {
            if ($null -eq $doc) { continue }
            $text = [System.IO.File]::ReadAllText($doc.FullName)
            $relDoc = $doc.FullName.Substring($sc.Root.Length).TrimStart('\', '/').Replace('\', '/')
            if ($text.IndexOf($enDashChar) -ge 0) {
                $scopeFails++
                $dashViolations.Add("$($sc.Label)/${relDoc}: Contains en dash (U+2013)")
            }
            if ($text.IndexOf($emDashChar) -ge 0) {
                $scopeFails++
                $dashViolations.Add("$($sc.Label)/${relDoc}: Contains em dash (U+2014)")
            }
        }
        $dashReportLines.Add("- $($sc.Label): Checked $cnt markdown file(s) | Violations: $scopeFails")
    }
    $dashReportLines.Add("")
    $dashReportLines.Add("Total Markdown Files Checked Across All Scopes: $totalMdChecked")
    $dashReportLines.Add("Total Forbidden Dash Violations: $($dashViolations.Count)")
    $dashReportLines.Add("Overall Status: $(if ($dashViolations.Count -eq 0) { 'PASS (100% ASCII Dash Compliant)' } else { 'FAIL' })")

    if (-not [string]::IsNullOrWhiteSpace($OutputDashCheckPath)) {
        $dDir = Split-Path -Parent $OutputDashCheckPath
        if ($dDir -and -not (Test-Path -LiteralPath $dDir)) { New-Item -ItemType Directory -Path $dDir -Force | Out-Null }
        [System.IO.File]::WriteAllLines($OutputDashCheckPath, $dashReportLines, $utf8NoBom)
    }

    if ($dashViolations.Count -gt 0) {
        Fail-Gate "GATE-13" "Zero en dash / em dash in all ZIPs, evidence & external report" "Scan markdown files across all 3 ZIPs + evidence + report" ($dashViolations -join "; ")
    }
    Pass-Gate "GATE-13" "Zero en dash / em dash in all ZIPs, evidence & external report" "Scan $totalMdChecked markdown files across 3 ZIPs + evidence + external reports" "Checked $totalMdChecked markdown files (Src=$($srcMdFiles.Count), Ver=$($verMdFiles.Count), Han=$($hanMdFiles.Count), Ev=$($evMdFiles.Count), Ext=$($extReportFiles.Count)): 0 en/em dashes" "evidence/release/writing_constraint_verification.txt"

    Write-SummaryIfRequested "PASSED"

    Write-Host ""
    Write-Host "======================================================================"
    Write-Host " StockFlow Official Release Verification ($ExpectedVersion):"
    Write-Host " Gates Passed: $checksPassed / $totalGates (100% PASS)"
    Write-Host " Result: ALL FAIL-CLOSED RELEASE GATES VERIFIED"
    Write-Host "======================================================================"
    Write-Host ""
    exit 0
} finally {
    if ($null -ne $tempTestDir -and (Test-Path -LiteralPath $tempTestDir)) {
        Remove-Item -LiteralPath $tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
