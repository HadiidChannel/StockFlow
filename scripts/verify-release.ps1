# ==============================================================================
# StockFlow - Fail-Closed Official Release Integrity Verifier (v1.6.4)
# Script: scripts/verify-release.ps1
# Description: Strictly validates Git integrity, release manifests, checksums,
#              Source ZIP hygiene, Audit Handover completeness & manifest
#              accuracy, Compose loopback bindings, secret scans, and dash rules.
#              Every gate is fail-closed: any mismatch exits immediately with
#              non-zero status and NEVER increments passed count on failure.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetDirectory,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedBranch = "fix/stockflow-v16-4-release-integrity",

    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion = "v1.6.4",

    [Parameter(Mandatory = $false)]
    [string]$OutputSummaryPath,

    [Parameter(Mandatory = $false)]
    [string]$VerificationScanOutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
} else {
    $repoRoot = (Resolve-Path $RepositoryRoot).Path
}

if ([string]::IsNullOrWhiteSpace($TargetDirectory)) {
    $releaseDir = Join-Path $repoRoot "release-output\v1.6.4"
} else {
    $releaseDir = (Resolve-Path $TargetDirectory).Path
}

$sourceZipName = "StockFlow_Final_v8_4.zip"
$verifyZipName = "StockFlow_Final_Verification_v8_4.zip"
$handoverZipName = "StockFlow_Audit_Handover_v8_4.zip"
$manifestName = "StockFlow_Release_Checksums_v8_4.txt"

$sourceZipPath = Join-Path $releaseDir $sourceZipName
$verifyZipPath = Join-Path $releaseDir $verifyZipName
$handoverZipPath = Join-Path $releaseDir $handoverZipName
$manifestPath = Join-Path $releaseDir $manifestName
$scannerScript = Join-Path $scriptDir "scan-secrets.ps1"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$gateRecords = [System.Collections.Generic.List[object]]::new()
$totalGates = 13
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
    $md.Add("# StockFlow v1.6.4 Release Verification Summary")
    $md.Add("")
    $md.Add("- Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $md.Add("- Repository Root: $repoRoot")
    $md.Add("- Target Release Directory: $releaseDir")
    $md.Add("- Passed Gates: $checksPassed / $totalGates")
    $md.Add("- Overall Status: $overallStatus")
    $md.Add("")
    $md.Add("## Gate Results Matrix")
    $md.Add("")
    $md.Add("| Gate ID | Criteria | Command | Actual Result | Exit Code | Status | Evidence File |")
    $md.Add("| :--- | :--- | :--- | :--- | :---: | :---: | :--- |")
    foreach ($rec in $gateRecords) {
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
    if ($null -eq $gitCmd) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    }
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
    $requiredArtifacts = @($sourceZipPath, $verifyZipPath, $handoverZipPath, $manifestPath)
    foreach ($art in $requiredArtifacts) {
        if (-not (Test-Path -LiteralPath $art)) {
            Fail-Gate "GATE-02" "All 3 release ZIPs and external manifest exist and valid" "Test-Path $art" "Required release artifact missing: $art"
        }
        if ((Get-Item -LiteralPath $art).Length -le 0) {
            Fail-Gate "GATE-02" "All 3 release ZIPs and external manifest exist and valid" "Get-Item $art" "Release artifact is empty (0 bytes): $art"
        }
    }

    $manifestRaw = Get-Content -LiteralPath $manifestPath -Raw
    if ([string]::IsNullOrWhiteSpace($manifestRaw)) {
        Fail-Gate "GATE-02" "All 3 release ZIPs and external manifest exist and valid" "Parse $manifestName" "External manifest is empty or unreadable"
    }

    $mVersion = [regex]::Match($manifestRaw, '(?m)^Release Version:\s*(\S+)\s*$')
    $mBranch  = [regex]::Match($manifestRaw, '(?m)^Git Branch:\s*(\S+)\s*$')
    $mCommit  = [regex]::Match($manifestRaw, '(?m)^Git Commit:\s*([a-f0-9]{40})\s*$')
    $mTree    = [regex]::Match($manifestRaw, '(?m)^Working Tree:\s*(.+?)\s*$')

    if (-not $mVersion.Success -or -not $mBranch.Success -or -not $mCommit.Success -or -not $mTree.Success) {
        Fail-Gate "GATE-02" "External manifest schema and metadata valid" "Parse header fields of $manifestName" "Manifest is corrupt or missing required header fields (Release Version / Git Branch / 40-char Git Commit / Working Tree)"
    }
    if ($mVersion.Groups[1].Value -cne $ExpectedVersion) {
        Fail-Gate "GATE-02" "External manifest release version match" "Compare Release Version in manifest" "Manifest Release Version '$($mVersion.Groups[1].Value)' does not match expected '$ExpectedVersion'"
    }

    $manifestBranch = $mBranch.Groups[1].Value.Trim()
    $manifestCommit = $mCommit.Groups[1].Value.Trim().ToLowerInvariant()
    $manifestTree   = $mTree.Groups[1].Value.Trim()

    # Parse Package 1, Package 2, Package 3 sections strictly
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
            Fail-Gate "GATE-02" "Manifest package block $idx name valid" "Check Package $idx Name" "Package $idx Name '$($pm.Groups[1].Value.Trim())' mismatches expected '$($ps.ExpectedName)'"
        }
        $parsedPackages[$idx] = @{
            Name = $pm.Groups[1].Value.Trim()
            Size = [int64]$pm.Groups[2].Value.Trim()
            Hash = $pm.Groups[3].Value.Trim().ToUpperInvariant()
            Path = $ps.Path
        }
    }
    Pass-Gate "GATE-02" "All 3 ZIPs and well-formed manifest exist" "Inspect $releaseDir deliverables" "Verified 3 ZIPs and complete manifest ($manifestName)" "StockFlow_Release_Checksums_v8_4.txt"

    # --------------------------------------------------------------------------
    # GATE-03: Git Branch Validation (Actual vs Expected vs Manifest)
    # --------------------------------------------------------------------------
    $branchRes = Invoke-GitStrict @("branch", "--show-current")
    if ($branchRes.ExitCode -ne 0) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Failed to query active branch (Exit: $($branchRes.ExitCode))"
    }
    $actualBranch = $branchRes.Output.Trim()
    if ([string]::IsNullOrWhiteSpace($actualBranch)) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Repository is in detached HEAD state; branch name required"
    }
    if ($actualBranch -cne $ExpectedBranch) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "git branch --show-current" "Active branch '$actualBranch' does not match expected '$ExpectedBranch'"
    }
    if ($actualBranch -cne $manifestBranch) {
        Fail-Gate "GATE-03" "Git branch matches expected and manifest" "Compare active branch with manifest" "Active branch '$actualBranch' mismatches manifest Git Branch '$manifestBranch'"
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
    if ($actualHeadCommit -notmatch '^[a-f0-9]{40}$') {
        Fail-Gate "GATE-04" "Full 40-character HEAD commit matches manifest" "git rev-parse HEAD" "Invalid 40-char commit hash returned from HEAD: '$actualHeadCommit'"
    }
    if ($actualHeadCommit -cne $manifestCommit) {
        Fail-Gate "GATE-04" "Full 40-character HEAD commit matches manifest" "Compare git rev-parse HEAD with manifest" "Git commit mismatch (HEAD: $actualHeadCommit vs Manifest: $manifestCommit)"
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
        Fail-Gate "GATE-05" "Manifest declares Clean working tree" "Check Working Tree field in manifest" "Manifest Working Tree field is '$manifestTree', expected 'Clean'"
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
    Pass-Gate "GATE-06" "Byte sizes and SHA-256 match across all 3 ZIPs" "Get-FileHash -Algorithm SHA256" "All 3 ZIP byte sizes and SHA-256 hashes match external manifest 100%" "StockFlow_Release_Checksums_v8_4.txt"

    # --------------------------------------------------------------------------
    # GATE-07: Archive Extraction Integrity Verification
    # --------------------------------------------------------------------------
    $tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_gate_extract_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $tempTestDir -Force | Out-Null

    $srcExtDir = Join-Path $tempTestDir "source"
    $verExtDir = Join-Path $tempTestDir "verify"
    $hanExtDir = Join-Path $tempTestDir "handover"

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($sourceZipPath, $srcExtDir)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($verifyZipPath, $verExtDir)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($handoverZipPath, $hanExtDir)
    } catch {
        Fail-Gate "GATE-07" "All 3 ZIP archives extract without corruption" "ZipFile::ExtractToDirectory" "Archive extraction error: $($_.Exception.Message)"
    }

    $srcFiles = @(Get-ChildItem -Path $srcExtDir -Recurse -File)
    $verFiles = @(Get-ChildItem -Path $verExtDir -Recurse -File)
    $hanFiles = @(Get-ChildItem -Path $hanExtDir -Recurse -File)

    if ($srcFiles.Count -eq 0 -or $verFiles.Count -eq 0 -or $hanFiles.Count -eq 0) {
        Fail-Gate "GATE-07" "Extracted ZIPs are non-empty" "Count extracted files" "One or more archives extracted 0 files ($($srcFiles.Count) / $($verFiles.Count) / $($hanFiles.Count))"
    }
    Pass-Gate "GATE-07" "All 3 ZIP archives extract cleanly" "ZipFile::ExtractToDirectory on 3 ZIPs" "Clean extraction: Source=$($srcFiles.Count) files, Verification=$($verFiles.Count) files, Handover=$($hanFiles.Count) files" "release_verification_summary.md"

    # --------------------------------------------------------------------------
    # GATE-08: Source Package Hygiene, Env Templates & Manifest Exclusion
    # --------------------------------------------------------------------------
    $requiredTemplates = @(".env.example", "backend\.env.example", "frontend\.env.example")
    foreach ($tpl in $requiredTemplates) {
        if (-not (Test-Path -LiteralPath (Join-Path $srcExtDir $tpl))) {
            Fail-Gate "GATE-08" "Required environment templates present in Source ZIP" "Test-Path $tpl" "Required template '$tpl' missing from Source ZIP"
        }
    }

    $forbiddenSourcePaths = @(".env", ".env.local", ".secrets", "release-output", "audit")
    foreach ($fb in $forbiddenSourcePaths) {
        if (Test-Path -LiteralPath (Join-Path $srcExtDir $fb)) {
            Fail-Gate "GATE-08" "Sensitive / build dirs excluded from Source ZIP" "Check absent $fb" "Forbidden sensitive or build path '$fb' found in Source ZIP"
        }
    }

    # Ensure NO checksum manifests exist anywhere inside ANY of the 3 ZIPs
    foreach ($dirCheck in @(@($sourceZipName, $srcExtDir), @($verifyZipName, $verExtDir), @($handoverZipName, $hanExtDir))) {
        $label = $dirCheck[0]
        $rootCheck = $dirCheck[1]
        $leakedManifests = @(Get-ChildItem -Path $rootCheck -Recurse -File | Where-Object {
            $_.Name -match '^StockFlow_Release_Checksums.*\.txt$' -or $_.Name -eq 'RELEASE_CHECKSUMS.txt'
        })
        if ($leakedManifests.Count -gt 0) {
            $names = ($leakedManifests | ForEach-Object { $_.FullName.Substring($rootCheck.Length).TrimStart('\', '/') }) -join ", "
            Fail-Gate "GATE-08" "No historical/external checksum manifests inside ZIPs" "Scan for checksum manifests in $label" "Checksum manifest file(s) illegally embedded inside ${label}: $names"
        }
    }
    Pass-Gate "GATE-08" "Source hygiene, 3 env templates, and zero embedded checksum manifests" "Inspect Source/Verify/Handover extracted contents" "All 3 env templates present; zero secrets and zero embedded checksum manifests in any ZIP" "evidence/release/source_package_verification.txt"

    # --------------------------------------------------------------------------
    # GATE-09: Audit Handover Completeness & Manifest Accuracy
    # --------------------------------------------------------------------------
    $hanManifestPath = Join-Path $hanExtDir "AUDIT_FILE_MANIFEST.md"
    if (-not (Test-Path -LiteralPath $hanManifestPath)) {
        Fail-Gate "GATE-09" "AUDIT_FILE_MANIFEST.md present and accurate in Handover ZIP" "Test-Path AUDIT_FILE_MANIFEST.md" "AUDIT_FILE_MANIFEST.md missing inside Handover ZIP"
    }

    $hanManifestLines = [System.IO.File]::ReadAllLines($hanManifestPath)
    $verifiedRowsChecked = 0
    $inExternalSection = $false
    $colIndex = @{}

    foreach ($line in $hanManifestLines) {
        if ($line -match '^##\s+.*External Post-(?:Verification|Packaging) Deliverables') {
            $inExternalSection = $true
            $colIndex = @{}
            continue
        }
        if ($line -match '^##\s+') {
            $inExternalSection = $false
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
        if ($rawCells.Count -eq 0) { continue }

        # Detect separator row (|:---|)
        if ($rawCells[0] -match '^:?-{2,}:?$') { continue }

        # Detect header row dynamically
        if ($rawCells -contains "Archive Path" -and ($rawCells -contains "Verification Status" -or $rawCells -contains "File Exists")) {
            $colIndex = @{}
            for ($ci = 0; $ci -lt $rawCells.Count; $ci++) {
                $colIndex[$rawCells[$ci]] = $ci
            }
            continue
        }

        if ($colIndex.ContainsKey("Archive Path") -and $rawCells.Count -gt $colIndex["Archive Path"]) {
            $archivePathCell = $rawCells[$colIndex["Archive Path"]]
            $fileExistsCell = if ($colIndex.ContainsKey("File Exists") -and $rawCells.Count -gt $colIndex["File Exists"]) { $rawCells[$colIndex["File Exists"]] } else { "" }
            $shaCell = if ($colIndex.ContainsKey("SHA-256") -and $rawCells.Count -gt $colIndex["SHA-256"]) { $rawCells[$colIndex["SHA-256"]] } else { "" }
            $statusCell = if ($colIndex.ContainsKey("Verification Status") -and $rawCells.Count -gt $colIndex["Verification Status"]) { $rawCells[$colIndex["Verification Status"]] } else { "" }

            if ($statusCell -eq "Missing" -or $statusCell -eq "Not Verified") {
                Fail-Gate "GATE-09" "Audit Handover manifest accuracy check" "Parse $hanManifestPath" "Handover manifest reports '$statusCell' for '$archivePathCell'"
            }
            if ($fileExistsCell -eq "Yes" -or $statusCell -eq "Verified") {
                $verifiedRowsChecked++
                if ([string]::IsNullOrWhiteSpace($archivePathCell)) {
                    Fail-Gate "GATE-09" "Audit Handover manifest accuracy check" "Parse $hanManifestPath" "Manifest row marked '$statusCell' with empty Archive Path"
                }
                $candidatePath = Join-Path $hanExtDir ($archivePathCell.Replace('/', '\'))
                if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                    Fail-Gate "GATE-09" "Audit Handover manifest accuracy check" "Verify $archivePathCell inside Handover ZIP" "Manifest claims '$archivePathCell' is '$statusCell' (Exists=$fileExistsCell) but file is MISSING from Handover ZIP!"
                }
                if ($shaCell -match '^[A-Fa-f0-9]{64}$') {
                    $actualEntrySha = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash.ToUpperInvariant()
                    if ($actualEntrySha -cne $shaCell.ToUpperInvariant()) {
                        Fail-Gate "GATE-09" "Audit Handover file hash check" "Get-FileHash $archivePathCell" "Manifest SHA-256 mismatch on '$archivePathCell' (actual=$actualEntrySha vs manifest=$($shaCell.ToUpperInvariant()))"
                    }
                }
            }
        }
    }

    if ($verifiedRowsChecked -eq 0) {
        Fail-Gate "GATE-09" "Audit Handover manifest contains verified file rows" "Parse $hanManifestPath" "AUDIT_FILE_MANIFEST.md contains zero verified archive rows"
    }
    Pass-Gate "GATE-09" "Audit Handover manifest matches actual archive files & hashes" "Verify AUDIT_FILE_MANIFEST.md against extracted Handover ZIP" "Verified $verifiedRowsChecked manifest file claims exist and match actual ZIP contents (0 Missing)" "evidence/release/audit_handover_completeness.txt"

    # --------------------------------------------------------------------------
    # GATE-10: Loopback Port Binding Enforcement Across Compose Files
    # --------------------------------------------------------------------------
    $composeFiles = @(Get-ChildItem -Path $srcExtDir -Filter "docker-compose*.yml")
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
    # GATE-11: Deep Secret Scan on All 3 Extracted Packages
    # --------------------------------------------------------------------------
    $scanTargets = @(
        @{ Label = "Source ZIP"; Path = $srcExtDir; Out = "" },
        @{ Label = "Verification ZIP"; Path = $verExtDir; Out = $VerificationScanOutputPath },
        @{ Label = "Handover ZIP"; Path = $hanExtDir; Out = "" }
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($st in $scanTargets) {
            $scanArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scannerScript, "-TargetScanPath", $st.Path)
            if (-not [string]::IsNullOrWhiteSpace($st.Out)) {
                $scanArgs += @("-OutputFile", $st.Out)
            }
            $scanOut = & powershell.exe $scanArgs 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                $ErrorActionPreference = $prevEap
                Fail-Gate "GATE-11" "Zero leaked credentials in all 3 packages" "scan-secrets.ps1 -TargetScanPath $($st.Label)" "Secret scanner detected findings in $($st.Label) (Exit: $LASTEXITCODE)"
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Pass-Gate "GATE-11" "Zero leaked credentials in all 3 packages" "scan-secrets.ps1 on extracted Source, Verification, Handover" "All 3 ZIP archives passed secret scanning with 0 findings" "evidence/security/secret_scan_repository.txt"

    # --------------------------------------------------------------------------
    # GATE-12: Git Evidence Consistency Inside Verification & Handover Archives
    # --------------------------------------------------------------------------
    foreach ($evPkg in @(@("Verification ZIP", $verExtDir), @("Handover ZIP", $hanExtDir))) {
        $pkgLabel = $evPkg[0]
        $pkgRoot = $evPkg[1]
        $evCommitPath = Join-Path $pkgRoot "evidence\git\git_commit.txt"
        $evBranchPath = Join-Path $pkgRoot "evidence\git\git_branch.txt"
        $evStatusPath = Join-Path $pkgRoot "evidence\git\git_status.txt"

        if (-not (Test-Path -LiteralPath $evCommitPath) -or -not (Test-Path -LiteralPath $evBranchPath) -or -not (Test-Path -LiteralPath $evStatusPath)) {
            Fail-Gate "GATE-12" "Git evidence files present inside $pkgLabel" "Check evidence/git/* in $pkgLabel" "Missing git evidence files (git_commit.txt / git_branch.txt / git_status.txt) in $pkgLabel"
        }
        $evCommitVal = ([System.IO.File]::ReadAllText($evCommitPath)).Trim().ToLowerInvariant()
        $evBranchVal = ([System.IO.File]::ReadAllText($evBranchPath)).Trim()
        $evStatusVal = ([System.IO.File]::ReadAllText($evStatusPath)).Trim()

        if ($evCommitVal -cne $actualHeadCommit) {
            Fail-Gate "GATE-12" "Git evidence commit matches HEAD" "Compare $pkgLabel git_commit.txt with HEAD" "Commit hash inside $pkgLabel ('$evCommitVal') mismatches HEAD ('$actualHeadCommit')"
        }
        if ($evBranchVal -cne $actualBranch) {
            Fail-Gate "GATE-12" "Git evidence branch matches HEAD branch" "Compare $pkgLabel git_branch.txt with branch" "Branch inside $pkgLabel ('$evBranchVal') mismatches active branch ('$actualBranch')"
        }
        if (-not [string]::IsNullOrWhiteSpace($evStatusVal) -and $evStatusVal -notmatch '^CLEAN') {
            Fail-Gate "GATE-12" "Git evidence status shows clean tree" "Inspect $pkgLabel git_status.txt" "git_status.txt inside $pkgLabel indicates dirty or unexpected status: $evStatusVal"
        }
    }
    Pass-Gate "GATE-12" "Git evidence in Verification & Handover matches HEAD and clean tree" "Compare extracted evidence/git/* with active Git HEAD" "Both Verification and Handover archives match commit $actualHeadCommit on $actualBranch (Clean)" "evidence/git/git_commit.txt"

    # --------------------------------------------------------------------------
    # GATE-13: Writing Constraint Verification (Zero En Dash, Zero Em Dash)
    # --------------------------------------------------------------------------
    $enDashChar = [char]0x2013
    $emDashChar = [char]0x2014
    $dashViolations = [System.Collections.Generic.List[string]]::new()
    $mdFilesToCheck = @(Get-ChildItem -Path $verExtDir -Filter "*.md" -Recurse) + @(Get-ChildItem -Path $hanExtDir -Filter "*.md" -Recurse)

    foreach ($doc in $mdFilesToCheck) {
        $text = [System.IO.File]::ReadAllText($doc.FullName)
        if ($text.IndexOf($enDashChar) -ge 0) {
            $dashViolations.Add("$($doc.Name): Contains en dash (U+2013)")
        }
        if ($text.IndexOf($emDashChar) -ge 0) {
            $dashViolations.Add("$($doc.Name): Contains em dash (U+2014)")
        }
    }
    if ($dashViolations.Count -gt 0) {
        Fail-Gate "GATE-13" "Zero en dash / em dash in documentation" "Scan markdown files for U+2013 / U+2014" ($dashViolations -join "; ")
    }
    Pass-Gate "GATE-13" "Zero en dash / em dash in documentation" "Scan $($mdFilesToCheck.Count) markdown docs for U+2013/U+2014" "Checked $($mdFilesToCheck.Count) markdown files: 0 en dashes, 0 em dashes" "release_verification_summary.md"

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
