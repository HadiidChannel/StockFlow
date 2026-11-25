# ==============================================================================
# StockFlow - Cross-Platform POSIX ZIP Creation & Validation Utilities (v1.6.5)
# Script: scripts/zip-utils.ps1
# Description: Shared helper functions eliminating backslash path separators,
#              enforcing strict archive entry hygiene, and validating cross-
#              platform extraction parity across Python zipfile, Info-ZIP
#              unzip, and .NET System.IO.Compression.ZipFile.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

function New-PortableZipArchive {
    <#
    .SYNOPSIS
    Creates a deterministic POSIX-compatible ZIP archive using '/' path separators.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$DestinationZipPath,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePatterns = @()
    )

    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw "SourceDirectory does not exist: $SourceDirectory"
    }

    $sourceRoot = [System.IO.Path]::GetFullPath($SourceDirectory).TrimEnd('\', '/')
    $destFull = [System.IO.Path]::GetFullPath($DestinationZipPath)
    $destDir = Split-Path -Parent $destFull
    if (-not [string]::IsNullOrWhiteSpace($destDir) -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $destFull) {
        Remove-Item -LiteralPath $destFull -Force
    }

    # Check for symlink/reparse directories inside staging tree before walking files
    $allItems = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force -ErrorAction Stop)
    foreach ($it in $allItems) {
        if ($it.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to archive symbolic link or reparse point: $($it.FullName)"
        }
    }

    $fileItems = @($allItems | Where-Object { -not $_.PSIsContainer })
    $entriesToWrite = [System.Collections.Generic.List[object]]::new()
    $exactSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $caseSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($fi in $fileItems) {
        $fullPath = [System.IO.Path]::GetFullPath($fi.FullName)
        if (-not $fullPath.StartsWith($sourceRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "File escapes source root '$sourceRoot': $fullPath"
        }

        $rel = $fullPath.Substring($sourceRoot.Length).TrimStart('\', '/')
        $entryName = $rel.Replace('\', '/')

        $skip = $false
        foreach ($pat in @($ExcludePatterns)) {
            if (-not [string]::IsNullOrWhiteSpace($pat) -and ($entryName -match $pat -or $rel -match $pat)) {
                $skip = $true
                break
            }
        }
        if ($skip) { continue }

        if ([string]::IsNullOrWhiteSpace($entryName)) {
            throw "Empty normalized archive entry name generated for '$fullPath'."
        }
        if ($entryName.Contains('\')) {
            throw "Backslash detected in normalized entry '$entryName'."
        }
        if ($entryName.StartsWith("/") -or $entryName -match '^[A-Za-z]:') {
            throw "Absolute path or drive letter forbidden in archive entry: '$entryName'."
        }
        $segments = @($entryName.Split('/'))
        foreach ($seg in $segments) {
            if ([string]::IsNullOrEmpty($seg) -or $seg -eq "." -or $seg -eq "..") {
                throw "Invalid or traversal path segment in archive entry: '$entryName'."
            }
        }
        if (-not $exactSeen.Add($entryName)) {
            throw "Duplicate normalized archive entry detected: '$entryName'."
        }
        if (-not $caseSeen.Add($entryName)) {
            throw "Case-insensitive archive entry collision detected on Windows: '$entryName'."
        }

        $entriesToWrite.Add([PSCustomObject]@{
            EntryName = $entryName
            SourcePath = $fullPath
        })
    }

    $sortedEntries = @($entriesToWrite | Sort-Object -Property EntryName -CaseSensitive)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    $zipStream = [System.IO.File]::Open($destFull, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $false, $utf8NoBom)
        try {
            foreach ($item in $sortedEntries) {
                $entry = $archive.CreateEntry($item.EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $mtimeUtc = [System.IO.File]::GetLastWriteTimeUtc($item.SourcePath)
                if ($mtimeUtc.Year -lt 1980) {
                    $mtimeUtc = [DateTime]::new(1980, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
                }
                $entry.LastWriteTime = [DateTimeOffset]::new($mtimeUtc)

                $srcStream = [System.IO.File]::Open($item.SourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
                try {
                    $dstStream = $entry.Open()
                    try {
                        $srcStream.CopyTo($dstStream)
                    } finally {
                        $dstStream.Dispose()
                    }
                } finally {
                    $srcStream.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }

    return [PSCustomObject]@{
        ZipPath = $destFull
        EntryCount = $sortedEntries.Count
    }
}

function Get-RawZipCentralDirectoryEntries {
    <#
    .SYNOPSIS
    Parses raw ZIP Central Directory (PK 01 02) & Local File Header (PK 03 04) bytes
    directly without Windows .NET/Python backslash-to-slash translation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $bytes = [System.IO.File]::ReadAllBytes($ZipPath)
    $len = $bytes.Length
    if ($len -lt 22) {
        throw "Invalid ZIP file (too small: $len bytes)"
    }

    $eocdPos = -1
    $minSearch = [Math]::Max(0, $len - 65557)
    for ($pos = $len - 22; $pos -ge $minSearch; $pos--) {
        if ($bytes[$pos] -eq 0x50 -and $bytes[$pos + 1] -eq 0x4B -and $bytes[$pos + 2] -eq 0x05 -and $bytes[$pos + 3] -eq 0x06) {
            $commentLen = [int][System.BitConverter]::ToUInt16($bytes, $pos + 20)
            if (($pos + 22 + $commentLen) -eq $len) {
                $eocdPos = $pos
                break
            }
        }
    }
    if ($eocdPos -lt 0) {
        throw "End of Central Directory (PK 05 06) record not found in ZIP"
    }

    $diskEntries = [int][System.BitConverter]::ToUInt16($bytes, $eocdPos + 10)
    $cdSize = [int64][System.BitConverter]::ToUInt32($bytes, $eocdPos + 12)
    $cdOffset = [int64][System.BitConverter]::ToUInt32($bytes, $eocdPos + 16)

    if ($cdOffset + $cdSize -gt $eocdPos) {
        throw "Central Directory bounds exceed EOCD offset in ZIP"
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $cur = [int]$cdOffset
    $cdEnd = [int]($cdOffset + $cdSize)
    $parsedCount = 0

    while ($cur -lt $cdEnd) {
        if ($cur + 46 -gt $cdEnd) {
            throw "Truncated Central Directory entry at offset $cur"
        }
        if ($bytes[$cur] -ne 0x50 -or $bytes[$cur + 1] -ne 0x4B -or $bytes[$cur + 2] -ne 0x01 -or $bytes[$cur + 3] -ne 0x02) {
            throw "Invalid Central Directory signature at offset $cur"
        }

        $bitFlag = [int][System.BitConverter]::ToUInt16($bytes, $cur + 8)
        $fnLen = [int][System.BitConverter]::ToUInt16($bytes, $cur + 28)
        $exLen = [int][System.BitConverter]::ToUInt16($bytes, $cur + 30)
        $cmLen = [int][System.BitConverter]::ToUInt16($bytes, $cur + 32)
        $extAttr = [uint32][System.BitConverter]::ToUInt32($bytes, $cur + 38)
        $lhOffset = [int][System.BitConverter]::ToUInt32($bytes, $cur + 42)

        if ($cur + 46 + $fnLen + $exLen + $cmLen -gt $cdEnd) {
            throw "Central Directory entry extends past CD end at offset $cur"
        }

        $rawName = if ($fnLen -gt 0) {
            [System.Text.Encoding]::UTF8.GetString($bytes, $cur + 46, $fnLen)
        } else {
            ""
        }
        $hasRawBackslash = $false
        for ($bi = 0; $bi -lt $fnLen; $bi++) {
            if ($bytes[$cur + 46 + $bi] -eq 0x5C) { $hasRawBackslash = $true; break }
        }

        # Validate matching Local File Header (PK 03 04) raw bytes too
        $lhMismatch = $false
        if ($lhOffset -lt 0 -or ($lhOffset + 30) -gt $cdOffset) {
            $lhMismatch = $true
        } elseif ($bytes[$lhOffset] -ne 0x50 -or $bytes[$lhOffset + 1] -ne 0x4B -or $bytes[$lhOffset + 2] -ne 0x03 -or $bytes[$lhOffset + 3] -ne 0x04) {
            $lhMismatch = $true
        } else {
            $lhFnLen = [int][System.BitConverter]::ToUInt16($bytes, $lhOffset + 26)
            if (($lhOffset + 30 + $lhFnLen) -gt $cdOffset) {
                $lhMismatch = $true
            } elseif ($lhFnLen -eq $fnLen) {
                for ($li = 0; $li -lt $fnLen; $li++) {
                    if ($bytes[$lhOffset + 30 + $li] -ne $bytes[$cur + 46 + $li]) {
                        $lhMismatch = $true
                        break
                    }
                    if ($bytes[$lhOffset + 30 + $li] -eq 0x5C) { $hasRawBackslash = $true }
                }
            } else {
                # Check raw backslashes in Local Header filename if lengths differ
                for ($li = 0; $li -lt $lhFnLen; $li++) {
                    if ($bytes[$lhOffset + 30 + $li] -eq 0x5C) { $hasRawBackslash = $true }
                }
            }
        }

        $entries.Add([PSCustomObject]@{
            RawName = $rawName
            ExternalAttributes = $extAttr
            HasRawBackslash = $hasRawBackslash
            LocalHeaderMismatch = $lhMismatch
            BitFlag = $bitFlag
        })

        $cur += 46 + $fnLen + $exLen + $cmLen
        $parsedCount++
    }

    if ($parsedCount -ne $diskEntries) {
        throw "Central Directory entry count mismatch: parsed=$parsedCount vs EOCD=$diskEntries"
    }

    return @($entries)
}

function Test-ZipArchiveEntries {
    <#
    .SYNOPSIS
    Validates raw ZIP directory entries prior to extraction against backslash paths,
    traversal, absolute paths, drive letters, symlinks, duplicates, and case collisions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        return [PSCustomObject]@{
            Valid = $false
            ZipPath = $ZipPath
            EntryCount = 0
            FileEntryCount = 0
            DirectoryEntryCount = 0
            BackslashCount = 0
            SymlinkCount = 0
            Violations = @("Archive does not exist: $ZipPath")
            FileEntries = @()
            AllEntries = @()
        }
    }

    $zipFull = [System.IO.Path]::GetFullPath($ZipPath)
    $violations = [System.Collections.Generic.List[string]]::new()
    $allEntries = [System.Collections.Generic.List[string]]::new()
    $fileEntries = [System.Collections.Generic.List[string]]::new()
    $exactFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $exactAll = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $caseFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $backslashCount = 0
    $symlinkCount = 0
    $dirCount = 0
    $simRoot = [System.IO.Path]::GetFullPath("C:\stockflow_sim_root").TrimEnd('\') + "\"

    $archive = $null
    try {
        $rawEntries = Get-RawZipCentralDirectoryEntries -ZipPath $zipFull
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zipFull)

        foreach ($entry in $rawEntries) {
            $rawName = $entry.RawName
            $allEntries.Add($rawName)

            if ([string]::IsNullOrWhiteSpace($rawName)) {
                $violations.Add("Empty ZIP entry name found")
                continue
            }

            if ($rawName.IndexOf([char]0) -ge 0) {
                $violations.Add("Null byte detected in ZIP entry: '$rawName'")
            }

            if ($entry.HasRawBackslash -or $rawName.Contains('\')) {
                $backslashCount++
                $violations.Add("Backslash path separator (0x5C) in raw ZIP entry: '$rawName'")
            }

            if ($entry.LocalHeaderMismatch) {
                $violations.Add("Local File Header filename mismatch with Central Directory on '$rawName'")
            }

            if ($rawName.StartsWith("/") -or $rawName.StartsWith("\")) {
                $violations.Add("Absolute leading slash in ZIP entry: '$rawName'")
            }

            if ($rawName -match '^[A-Za-z]:' -or $rawName -match '^//' -or $rawName -match '^\\\\') {
                $violations.Add("Drive letter or UNC path in ZIP entry: '$rawName'")
            }

            $unixMode = (($entry.ExternalAttributes -shr 16) -band 0xF000)
            if ($unixMode -eq 0xA000) {
                $symlinkCount++
                $violations.Add("Symbolic link entry forbidden in ZIP: '$rawName'")
            }

            $isDirEntry = $rawName.EndsWith("/")
            $trimmed = $rawName.TrimEnd('/')
            $normUnified = $trimmed.Replace('\', '/')

            if ([string]::IsNullOrEmpty($normUnified) -and -not $isDirEntry) {
                $violations.Add("Invalid empty normalized entry: '$rawName'")
                continue
            }

            if (-not [string]::IsNullOrEmpty($normUnified)) {
                $parts = @($normUnified.Split('/'))
                foreach ($p in $parts) {
                    if ($p -eq ".." -or $p -eq "." -or [string]::IsNullOrEmpty($p)) {
                        $violations.Add("Unsafe traversal or empty path component in ZIP entry: '$rawName'")
                    }
                }

                try {
                    $resolved = [System.IO.Path]::GetFullPath((Join-Path $simRoot ($normUnified.Replace('/', '\'))))
                    if (-not $resolved.StartsWith($simRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $violations.Add("Entry escapes extraction root: '$rawName'")
                    }
                } catch {
                    $violations.Add("Invalid filesystem characters or path error for entry '$rawName': $($_.Exception.Message)")
                }
            }

            $normExact = if ($isDirEntry) { $normUnified + "/" } else { $normUnified }
            if (-not $exactAll.Add($normExact)) {
                $violations.Add("Duplicate normalized ZIP entry: '$rawName'")
            }

            if ($isDirEntry) {
                $dirCount++
            } else {
                $fileEntries.Add($normUnified)
                if (-not $exactFiles.Add($normUnified)) {
                    $violations.Add("Duplicate normalized file entry: '$rawName'")
                } elseif (-not $caseFiles.Add($normUnified)) {
                    $violations.Add("Case-insensitive path collision on Windows: '$rawName'")
                }
            }
        }
    } catch {
        $violations.Add("Failed to inspect ZIP directory: $($_.Exception.Message)")
    } finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    if ($allEntries.Count -eq 0) {
        $violations.Add("Archive contains 0 entries")
    } elseif ($fileEntries.Count -eq 0) {
        $violations.Add("Archive contains 0 file entries")
    }

    return [PSCustomObject]@{
        Valid = ($violations.Count -eq 0)
        ZipPath = $zipFull
        EntryCount = $allEntries.Count
        FileEntryCount = $fileEntries.Count
        DirectoryEntryCount = $dirCount
        BackslashCount = $backslashCount
        SymlinkCount = $symlinkCount
        Violations = @($violations)
        FileEntries = @($fileEntries)
        AllEntries = @($allEntries)
    }
}

function Find-PythonExecutable {
    <#
    .SYNOPSIS
    Finds a working Python 3 executable with zipfile support, skipping broken MS Store stubs.
    #>
    [CmdletBinding()]
    param()

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($cmdName in @("python.exe", "python3.exe", "py.exe")) {
        $cmds = @(Get-Command $cmdName -All -ErrorAction SilentlyContinue)
        foreach ($c in $cmds) {
            if (-not [string]::IsNullOrWhiteSpace($c.Source) -and $c.Source -notmatch 'WindowsApps\\python') {
                $candidates.Add($c.Source)
            }
        }
    }

    $localPy313 = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
    if (Test-Path -LiteralPath $localPy313 -PathType Leaf) { $candidates.Add($localPy313) }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($cand in @($candidates | Select-Object -Unique)) {
            $verOut = (& $cand --version 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $verOut -match '^Python\s+3\.') {
                return [PSCustomObject]@{
                    Path = $cand
                    Version = $verOut
                }
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return $null
}

function Find-InfoZipExecutable {
    <#
    .SYNOPSIS
    Finds Info-ZIP unzip executable on PATH or Git for Windows installation and verifies execution.
    #>
    [CmdletBinding()]
    param()

    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($cmdName in @("unzip.exe", "unzip")) {
        $cmds = @(Get-Command $cmdName -All -ErrorAction SilentlyContinue)
        foreach ($c in $cmds) {
            if (-not [string]::IsNullOrWhiteSpace($c.Source)) {
                $candidates.Add($c.Source)
            }
        }
    }
    foreach ($stdPath in @("C:\Program Files\Git\usr\bin\unzip.exe", "C:\Program Files\Git\bin\unzip.exe", "C:\Program Files (x86)\Git\usr\bin\unzip.exe")) {
        if (Test-Path -LiteralPath $stdPath -PathType Leaf) {
            $candidates.Add($stdPath)
        }
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        foreach ($cand in @($candidates | Select-Object -Unique)) {
            $verOut = (& $cand -v 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $verOut -match 'Info-ZIP') {
                $firstLine = (($verOut -split "`r?`n" | Select-Object -First 1) -replace '\s+Maintained.*$', '').Trim()
                return [PSCustomObject]@{
                    Path = $cand
                    Version = $firstLine
                }
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return $null
}

function Get-TreeInventoryMap {
    <#
    .SYNOPSIS
    Builds an ordered directory list and relative file -> Size/SHA-256 map for an extracted directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir
    )

    $baseFull = [System.IO.Path]::GetFullPath($RootDir).TrimEnd('\', '/')
    $dirs = @(Get-ChildItem -LiteralPath $baseFull -Recurse -Directory | ForEach-Object {
        $_.FullName.Substring($baseFull.Length).TrimStart('\', '/').Replace('\', '/')
    } | Sort-Object -CaseSensitive)

    $files = @(Get-ChildItem -LiteralPath $baseFull -Recurse -File)
    $fileMap = @{}
    $sortedRelFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($baseFull.Length).TrimStart('\', '/').Replace('\', '/')
        $sha = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        $fileMap[$rel] = [PSCustomObject]@{
            Size = [int64]$f.Length
            Sha256 = $sha
        }
        $sortedRelFiles.Add($rel)
    }
    $sortedFileList = @($sortedRelFiles | Sort-Object -CaseSensitive)

    return [PSCustomObject]@{
        Directories = $dirs
        DirectoryCount = $dirs.Count
        Files = $sortedFileList
        FileCount = $sortedFileList.Count
        FileMap = $fileMap
    }
}

function Invoke-CrossPlatformZipValidation {
    <#
    .SYNOPSIS
    Tests an archive against ZIP structure safety rules, Python zipfile, Info-ZIP unzip,
    and .NET extraction, and verifies 100% 3-way directory, count, size, and SHA-256 parity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [string]$ArchiveLabel,

        [Parameter(Mandatory = $true)]
        [string]$TempWorkRoot
    )

    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    $zipFull = [System.IO.Path]::GetFullPath($ZipPath)

    # 1. Pre-extraction ZIP directory entry inspection
    $structResult = Test-ZipArchiveEntries -ZipPath $zipFull
    if (-not $structResult.Valid) {
        return [PSCustomObject]@{
            Passed = $false
            EnvironmentBlocked = $false
            Label = $ArchiveLabel
            ZipPath = $zipFull
            Timestamp = $ts
            FailureReason = "ZIP structural validation failed: $($structResult.Violations -join '; ')"
            Structure = $structResult
            ReportLines = @(
                "=== ARCHIVE: $ArchiveLabel ===",
                "Path: $zipFull",
                "Timestamp: $ts",
                "Entry Count: $($structResult.EntryCount) | File Entries: $($structResult.FileEntryCount) | Backslashes: $($structResult.BackslashCount)",
                "Structure Validation: FAIL ($($structResult.Violations -join '; '))"
            )
        }
    }

    # 2. Discover required cross-platform tools (Python + Info-ZIP + .NET)
    $pyInfo = Find-PythonExecutable
    if ($null -eq $pyInfo) {
        return [PSCustomObject]@{
            Passed = $false
            EnvironmentBlocked = $true
            Label = $ArchiveLabel
            ZipPath = $zipFull
            Timestamp = $ts
            FailureReason = "NOT VERIFIED - ENVIRONMENT BLOCKED: Python 3 executable unavailable"
            Structure = $structResult
            ReportLines = @("=== ARCHIVE: $ArchiveLabel ===", "Status: NOT VERIFIED - ENVIRONMENT BLOCKED (Python 3 unavailable)")
        }
    }

    $uzInfo = Find-InfoZipExecutable
    if ($null -eq $uzInfo) {
        return [PSCustomObject]@{
            Passed = $false
            EnvironmentBlocked = $true
            Label = $ArchiveLabel
            ZipPath = $zipFull
            Timestamp = $ts
            FailureReason = "NOT VERIFIED - ENVIRONMENT BLOCKED: Info-ZIP unzip executable unavailable or blocked"
            Structure = $structResult
            ReportLines = @("=== ARCHIVE: $ArchiveLabel ===", "Status: NOT VERIFIED - ENVIRONMENT BLOCKED (Info-ZIP unzip unavailable)")
        }
    }

    $dotnetRuntimeVer = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
    $psVer = $PSVersionTable.PSVersion.ToString()

    $subWork = Join-Path $TempWorkRoot ("xplat_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    $pyExtractDir = Join-Path $subWork "py_out"
    $uzExtractDir = Join-Path $subWork "infozip_out"
    $dnExtractDir = Join-Path $subWork "dotnet_out"
    $pyHelperPath = Join-Path $subWork "py_zip_check.py"
    New-Item -ItemType Directory -Path $pyExtractDir, $uzExtractDir, $dnExtractDir -Force | Out-Null

    $pyScriptContent = @'
import os
import posixpath
import re
import struct
import sys
import zipfile

zip_path = sys.argv[1]
target_dir = os.path.abspath(sys.argv[2])

# Raw binary Central Directory check against Windows zipfile '/' translation
with open(zip_path, "rb") as raw_f:
    raw_bytes = raw_f.read()
eocd_pos = raw_bytes.rfind(b"PK\x05\x06")
if eocd_pos < 0:
    print("INVALID_EOCD", file=sys.stderr)
    sys.exit(2)
cd_size, cd_offset = struct.unpack_from("<II", raw_bytes, eocd_pos + 12)
cur = cd_offset
while cur < cd_offset + cd_size:
    if raw_bytes[cur:cur + 4] != b"PK\x01\x02":
        print(f"INVALID_CD:{cur}", file=sys.stderr)
        sys.exit(2)
    fn_len, ex_len, cm_len = struct.unpack_from("<HHH", raw_bytes, cur + 28)
    raw_fn = raw_bytes[cur + 46:cur + 46 + fn_len]
    if b"\\" in raw_fn:
        print(f"RAW_BACKSLASH:{raw_fn!r}", file=sys.stderr)
        sys.exit(3)
    cur += 46 + fn_len + ex_len + cm_len

with zipfile.ZipFile(zip_path, "r") as zf:
    bad_member = zf.testzip()
    if bad_member is not None:
        print(f"CRC_FAIL:{bad_member}", file=sys.stderr)
        sys.exit(2)

    seen_exact = set()
    seen_lower = set()
    for info in zf.infolist():
        name = info.filename
        if "\\" in name:
            print(f"BACKSLASH:{name}", file=sys.stderr)
            sys.exit(3)
        if name.startswith("/") or re.match(r"^[A-Za-z]:", name):
            print(f"ABS_PATH:{name}", file=sys.stderr)
            sys.exit(4)
        unix_type = (info.external_attr >> 16) & 0o170000
        if unix_type == 0o120000:
            print(f"SYMLINK:{name}", file=sys.stderr)
            sys.exit(5)

        stripped = name.rstrip("/")
        if stripped:
            parts = stripped.split("/")
            if any(p in ("", ".", "..") for p in parts):
                print(f"TRAVERSAL:{name}", file=sys.stderr)
                sys.exit(6)

        norm_posix = posixpath.normpath(stripped) if stripped else ""
        if name.endswith("/") and norm_posix:
            norm_key = norm_posix + "/"
        else:
            norm_key = norm_posix
        if norm_key in seen_exact:
            print(f"DUPLICATE:{name}", file=sys.stderr)
            sys.exit(7)
        seen_exact.add(norm_key)

        if not info.is_dir():
            low = norm_key.lower()
            if low in seen_lower:
                print(f"CASE_COLLISION:{name}", file=sys.stderr)
                sys.exit(8)
            seen_lower.add(low)

        dest_path = os.path.abspath(os.path.join(target_dir, *stripped.split("/"))) if stripped else target_dir
        if os.path.commonpath([target_dir, dest_path]) != target_dir:
            print(f"ESCAPE:{name}", file=sys.stderr)
            sys.exit(9)

    zf.extractall(target_dir)
    print(f"PYTHON_OK:entries={len(zf.infolist())}")
'@
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($pyHelperPath, $pyScriptContent, $utf8NoBom)

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # Step A: Python CRC + Validation + Extraction
        $pyTs = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $pyOut = (& $pyInfo.Path $pyHelperPath $zipFull $pyExtractDir 2>&1 | Out-String).Trim()
        $pyExit = $LASTEXITCODE
        if ($pyExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Python zipfile check/extraction failed (Exit $pyExit): $pyOut"
                Structure = $structResult; ReportLines = @("FAIL: Python extraction failed ($pyOut)")
            }
        }

        # Step B: Info-ZIP CRC (-t) + Extraction (-o -d)
        $uzTs = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $uzTestOut = (& $uzInfo.Path -t -qq $zipFull 2>&1 | Out-String).Trim()
        $uzTestExit = $LASTEXITCODE
        if ($uzTestExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Info-ZIP CRC test (-t) failed (Exit $uzTestExit): $uzTestOut"
                Structure = $structResult; ReportLines = @("FAIL: Info-ZIP -t failed ($uzTestOut)")
            }
        }

        $uzExtOut = (& $uzInfo.Path -q -o $zipFull -d $uzExtractDir 2>&1 | Out-String).Trim()
        $uzExtExit = $LASTEXITCODE
        if ($uzExtExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Info-ZIP extraction failed (Exit $uzExtExit): $uzExtOut"
                Structure = $structResult; ReportLines = @("FAIL: Info-ZIP extract failed ($uzExtOut)")
            }
        }

        # Step C: .NET ZipFile extraction
        $dnTs = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $dnExit = 0
        $dnErr = ""
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFull, $dnExtractDir)
        } catch {
            $dnExit = 1
            $dnErr = $_.Exception.Message
        }
        if ($dnExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = ".NET ZipFile extraction failed: $dnErr"
                Structure = $structResult; ReportLines = @("FAIL: .NET extract failed ($dnErr)")
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }

    # Step D: 3-Way Parity Comparison (Directories, File Counts, Paths, Sizes, SHA-256)
    $invPy = Get-TreeInventoryMap -RootDir $pyExtractDir
    $invUz = Get-TreeInventoryMap -RootDir $uzExtractDir
    $invDn = Get-TreeInventoryMap -RootDir $dnExtractDir

    $parityErrors = [System.Collections.Generic.List[string]]::new()
    if ($invPy.FileCount -ne $invUz.FileCount -or $invPy.FileCount -ne $invDn.FileCount) {
        $parityErrors.Add("Extracted file count mismatch: Python=$($invPy.FileCount), Info-ZIP=$($invUz.FileCount), .NET=$($invDn.FileCount)")
    }
    if ($invPy.DirectoryCount -ne $invUz.DirectoryCount -or $invPy.DirectoryCount -ne $invDn.DirectoryCount) {
        $parityErrors.Add("Extracted directory count mismatch: Python=$($invPy.DirectoryCount), Info-ZIP=$($invUz.DirectoryCount), .NET=$($invDn.DirectoryCount)")
    }

    $dirJoinPy = $invPy.Directories -join "`n"
    $dirJoinUz = $invUz.Directories -join "`n"
    $dirJoinDn = $invDn.Directories -join "`n"
    if ($dirJoinPy -cne $dirJoinUz -or $dirJoinPy -cne $dirJoinDn) {
        $parityErrors.Add("Directory structure set mismatch across Python / Info-ZIP / .NET")
    }

    $hashMatchedCount = 0
    foreach ($relFile in $invPy.Files) {
        if (-not $invUz.FileMap.ContainsKey($relFile)) {
            $parityErrors.Add("Missing in Info-ZIP output: $relFile")
            continue
        }
        if (-not $invDn.FileMap.ContainsKey($relFile)) {
            $parityErrors.Add("Missing in .NET output: $relFile")
            continue
        }
        $mPy = $invPy.FileMap[$relFile]
        $mUz = $invUz.FileMap[$relFile]
        $mDn = $invDn.FileMap[$relFile]

        if ($mPy.Size -ne $mUz.Size -or $mPy.Size -ne $mDn.Size) {
            $parityErrors.Add("Byte size mismatch on '$relFile': py=$($mPy.Size), uz=$($mUz.Size), dn=$($mDn.Size)")
            continue
        }
        if ($mPy.Sha256 -cne $mUz.Sha256 -or $mPy.Sha256 -cne $mDn.Sha256) {
            $parityErrors.Add("SHA-256 mismatch on '$relFile' across extractors")
            continue
        }
        $hashMatchedCount++
    }

    if ($parityErrors.Count -gt 0) {
        return [PSCustomObject]@{
            Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
            FailureReason = "3-way cross-platform parity check failed: $($parityErrors -join '; ')"
            Structure = $structResult; ReportLines = @("FAIL: Parity mismatch ($($parityErrors -join '; '))")
        }
    }

    $lines = @(
        "=== ARCHIVE: $ArchiveLabel ===",
        "Zip Path: $zipFull",
        "Timestamp: $ts",
        "Total ZIP Entries: $($structResult.EntryCount) | File Entries: $($structResult.FileEntryCount) | Backslash Entries: $($structResult.BackslashCount)",
        "Path Hygiene (No '\', No Absolute, No Drive, No '..', No Duplicates, No Case Collisions, No Symlinks): PASS",
        "Extracted Directory Count: $($invPy.DirectoryCount) (Python / Info-ZIP / .NET identical)",
        "Extracted File Count: $($invPy.FileCount) (Python / Info-ZIP / .NET identical)",
        "--- Extractor 1: Python zipfile ($($pyInfo.Version)) ---",
        "Timestamp: $pyTs | Command: python py_zip_check.py <zip> <py_out> | CRC testzip(): PASS | Extraction: PASS | Exit Code: $pyExit",
        "--- Extractor 2: Info-ZIP ($($uzInfo.Version)) ---",
        "Timestamp: $uzTs | Command 1: unzip -t -qq <zip> | CRC Exit Code: $uzTestExit | Command 2: unzip -q -o <zip> -d <infozip_out> | Extract Exit Code: $uzExtExit",
        "--- Extractor 3: .NET System.IO.Compression.ZipFile (PS $psVer / $dotnetRuntimeVer) ---",
        "Timestamp: $dnTs | Command: [System.IO.Compression.ZipFile]::ExtractToDirectory(<zip>, <dotnet_out>) | Extraction: PASS | Exit Code: $dnExit",
        "3-Way Parity (Directory Tree + File Count + Byte Sizes + SHA-256): PASS ($hashMatchedCount / $($invPy.FileCount) files identical)",
        ""
    )

    return [PSCustomObject]@{
        Passed = $true
        EnvironmentBlocked = $false
        Label = $ArchiveLabel
        ZipPath = $zipFull
        Timestamp = $ts
        EntryCount = $structResult.EntryCount
        DirectoryCount = $invPy.DirectoryCount
        FileCount = $invPy.FileCount
        BackslashCount = $structResult.BackslashCount
        HashMatchedCount = $hashMatchedCount
        PythonVersion = $pyInfo.Version
        InfoZipVersion = $uzInfo.Version
        DotNetVersion = "$dotnetRuntimeVer (PS $psVer)"
        Structure = $structResult
        ReportLines = $lines
    }
}
