# ==============================================================================
# StockFlow - Cross-Platform POSIX ZIP Creation & Binary Header Validator (v1.6.6)
# Script: scripts/zip-utils.ps1
# Description: Deterministic POSIX '/' ZIP archive builder, exhaustive binary
#              Local File Header <-> Central Directory consistency validator
#              (signatures, filename length & raw bytes, flags, compression method,
#              mod time/date, CRC-32, sizes, Data Descriptors, Extra Fields,
#              ZIP64 structures, offset/span bounds), and 3-engine extraction
#              parity tester (Python zipfile, Info-ZIP unzip, .NET ZipFile).
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

function Test-ZipExtraFieldBlock {
    <#
    .SYNOPSIS
    Validates structural integrity of a ZIP Extra Field block (TLV subfields,
    bounds, duplicate critical IDs, and ZIP64 Extra Field 0x0001 sizing).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [int64]$Offset,

        [Parameter(Mandatory = $true)]
        [int64]$Length,

        [Parameter(Mandatory = $true)]
        [int64]$BufferLimit,

        [Parameter(Mandatory = $true)]
        [string]$ScopeLabel,

        [Parameter(Mandatory = $false)]
        [bool]$Needs64Uncomp = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Needs64Comp = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Needs64Offset = $false
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $z64Info = $null

    if ($Offset -lt 0 -or $Length -lt 0 -or ($Offset + $Length) -gt $BufferLimit) {
        $errors.Add("Extra Field bounds overflow in $ScopeLabel (offset=$Offset, len=$Length, limit=$BufferLimit)")
        return [PSCustomObject]@{ Errors = @($errors); Zip64Info = $null }
    }
    if ($Length -eq 0) {
        return [PSCustomObject]@{ Errors = @(); Zip64Info = $null }
    }

    $criticalIds = @([uint16]0x0001, [uint16]0x7075, [uint16]0x5455, [uint16]0x000A)
    $seenCritical = [System.Collections.Generic.HashSet[uint16]]::new()
    $pos = [int]$Offset
    $endPos = [int]($Offset + $Length)

    while ($pos -lt $endPos) {
        if ($pos + 4 -gt $endPos) {
            $errors.Add("Truncated Extra Field subfield header in $ScopeLabel at byte $pos")
            break
        }
        $headerId = [System.BitConverter]::ToUInt16($Bytes, $pos)
        $dataSize = [int][System.BitConverter]::ToUInt16($Bytes, $pos + 2)
        if ($pos + 4 + $dataSize -gt $endPos) {
            $errors.Add("Extra Field subfield 0x$($headerId.ToString('X4')) length ($dataSize) exceeds $ScopeLabel block boundary")
            break
        }
        if ($criticalIds -contains $headerId) {
            if (-not $seenCritical.Add($headerId)) {
                $errors.Add("Duplicate critical Extra Field 0x$($headerId.ToString('X4')) in $ScopeLabel")
            }
        }
        if ($headerId -eq 0x0001) {
            $dataStart = $pos + 4
            $cursor = $dataStart
            $reqMin = 0
            if ($Needs64Uncomp) { $reqMin += 8 }
            if ($Needs64Comp) { $reqMin += 8 }
            if ($Needs64Offset) { $reqMin += 8 }

            if ($ScopeLabel -eq "Local" -and ($Needs64Uncomp -or $Needs64Comp) -and $dataSize -lt 16) {
                $errors.Add("Invalid ZIP64 Extra Field in Local Header: size=$dataSize (requires >= 16 bytes for both 64-bit sizes)")
            } elseif ($dataSize -lt $reqMin) {
                $errors.Add("Truncated ZIP64 Extra Field 0x0001 in ${ScopeLabel}: size=$dataSize < required $reqMin bytes")
            } else {
                $zUncomp = $null; $zComp = $null; $zOff = $null
                if ($Needs64Uncomp) {
                    $zUncomp = [System.BitConverter]::ToUInt64($Bytes, $cursor); $cursor += 8
                }
                if ($Needs64Comp) {
                    $zComp = [System.BitConverter]::ToUInt64($Bytes, $cursor); $cursor += 8
                }
                if ($Needs64Offset) {
                    $zOff = [System.BitConverter]::ToUInt64($Bytes, $cursor); $cursor += 8
                }
                $remaining = ($dataStart + $dataSize) - $cursor
                if ($remaining -ne 0 -and $remaining -ne 4) {
                    $errors.Add("Malformed trailing bytes ($remaining) in ZIP64 Extra Field 0x0001 ($ScopeLabel)")
                }
                $z64Info = [PSCustomObject]@{
                    UncompressedSize = $zUncomp
                    CompressedSize = $zComp
                    LocalHeaderOffset = $zOff
                }
            }
        }
        $pos += 4 + $dataSize
    }

    return [PSCustomObject]@{
        Errors = @($errors)
        Zip64Info = $z64Info
    }
}

function Inspect-ZipBinaryHeaders {
    <#
    .SYNOPSIS
    Performs exhaustive byte-level verification of EOCD, Central Directory,
    Local File Headers, Extra Fields, Data Descriptors, ZIP64 structures,
    bounds, and span completeness for every entry in a ZIP archive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $zipFull = [System.IO.Path]::GetFullPath($ZipPath)
    $fileInfo = Get-Item -LiteralPath $zipFull -ErrorAction Stop
    $bytes = [System.IO.File]::ReadAllBytes($zipFull)
    $len = [int64]$bytes.Length

    $counts = [ordered]@{
        ArchiveName = $fileInfo.Name
        ArchivePath = $zipFull
        ArchiveSize = [int64]$len
        TotalEntries = 0
        ValidEntries = 0
        InvalidEntries = 0
        ValidDirectoryEntries = 0
        LocalHeaderSignatureErrors = 0
        CentralDirectorySignatureErrors = 0
        FilenameLengthMismatches = 0
        FilenameByteMismatches = 0
        GeneralPurposeFlagMismatches = 0
        CompressionMethodMismatches = 0
        ModTimeDateMismatches = 0
        CrcMismatches = 0
        CompressedSizeMismatches = 0
        UncompressedSizeMismatches = 0
        DataDescriptorErrors = 0
        ExtraFieldErrors = 0
        BoundsViolations = 0
        Zip64Status = "Not Used"
        DuplicateLocalHeaderOffsets = 0
    }

    $fatalError = $null
    $entryResults = [System.Collections.Generic.List[object]]::new()
    $errorMessages = [System.Collections.Generic.List[string]]::new()

    if ($len -lt 22) {
        $counts.BoundsViolations++
        $counts.InvalidEntries = 1
        $errorMessages.Add("Archive smaller than 22-byte minimum ZIP EOCD ($len bytes)")
        return [PSCustomObject]@{
            Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
        }
    }

    # 1. Locate End of Central Directory (PK 05 06)
    $eocdPos = [int64]-1
    $minSearch = [Math]::Max([int64]0, $len - 65557)
    for ($pos = $len - 22; $pos -ge $minSearch; $pos--) {
        if ($bytes[$pos] -eq 0x50 -and $bytes[$pos + 1] -eq 0x4B -and $bytes[$pos + 2] -eq 0x05 -and $bytes[$pos + 3] -eq 0x06) {
            $cLen = [int64][System.BitConverter]::ToUInt16($bytes, [int]($pos + 20))
            if (($pos + 22 + $cLen) -eq $len) {
                $eocdPos = $pos
                break
            }
        }
    }
    if ($eocdPos -lt 0) {
        $counts.CentralDirectorySignatureErrors++
        $counts.InvalidEntries = 1
        $errorMessages.Add("End of Central Directory (0x06054B50) not found at archive tail")
        return [PSCustomObject]@{
            Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
        }
    }

    $diskNum = [int64][System.BitConverter]::ToUInt16($bytes, [int]($eocdPos + 4))
    $cdStartDisk = [int64][System.BitConverter]::ToUInt16($bytes, [int]($eocdPos + 6))
    $diskEntries = [int64][System.BitConverter]::ToUInt16($bytes, [int]($eocdPos + 8))
    $totalEntries = [int64][System.BitConverter]::ToUInt16($bytes, [int]($eocdPos + 10))
    $cdSize = [int64][System.BitConverter]::ToUInt32($bytes, [int]($eocdPos + 12))
    $cdOffset = [int64][System.BitConverter]::ToUInt32($bytes, [int]($eocdPos + 16))
    $cdLimitEnd = $eocdPos

    if ($diskNum -ne 0 -or $cdStartDisk -ne 0 -or $diskEntries -ne $totalEntries) {
        $counts.BoundsViolations++
        $errorMessages.Add("Multi-disk split ZIP archives are not supported (disk=$diskNum, cdDisk=$cdStartDisk)")
    }

    # 2. Check ZIP64 Locator (PK 06 07) & ZIP64 EOCD (PK 06 06)
    $hasZip64SentinelEocd = ($totalEntries -eq 0xFFFF -or $cdSize -eq 0xFFFFFFFF -or $cdOffset -eq 0xFFFFFFFF)
    $hasLocatorBytes = ($eocdPos -ge 20 -and $bytes[$eocdPos - 20] -eq 0x50 -and $bytes[$eocdPos - 19] -eq 0x4B -and $bytes[$eocdPos - 18] -eq 0x06 -and $bytes[$eocdPos - 17] -eq 0x07)

    if ($hasZip64SentinelEocd -or $hasLocatorBytes) {
        if (-not $hasLocatorBytes) {
            $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE"
            $counts.BoundsViolations++
            $counts.InvalidEntries = 1
            $errorMessages.Add("UNSUPPORTED ZIP64 STRUCTURE: ZIP64 EOCD sentinel values present without PK 06 07 Locator")
            return [PSCustomObject]@{
                Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
            }
        }
        $locPos = $eocdPos - 20
        $z64EocdOffU = [System.BitConverter]::ToUInt64($bytes, [int]($locPos + 8))
        if ($z64EocdOffU -gt [uint64]($locPos - 56)) {
            $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE"
            $counts.BoundsViolations++
            $counts.InvalidEntries = 1
            $errorMessages.Add("Invalid ZIP64 EOCD offset in Locator ($z64EocdOffU)")
            return [PSCustomObject]@{
                Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
            }
        }
        $z64Off = [int64]$z64EocdOffU
        if ($bytes[$z64Off] -ne 0x50 -or $bytes[$z64Off + 1] -ne 0x4B -or $bytes[$z64Off + 2] -ne 0x06 -or $bytes[$z64Off + 3] -ne 0x06) {
            $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE"
            $counts.CentralDirectorySignatureErrors++
            $counts.InvalidEntries = 1
            $errorMessages.Add("Invalid ZIP64 EOCD signature (expected PK 06 06 at offset $z64Off)")
            return [PSCustomObject]@{
                Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
            }
        }
        $z64Entries = [System.BitConverter]::ToUInt64($bytes, [int]($z64Off + 32))
        $z64CdSize = [System.BitConverter]::ToUInt64($bytes, [int]($z64Off + 40))
        $z64CdOff = [System.BitConverter]::ToUInt64($bytes, [int]($z64Off + 48))
        if ($z64Entries -gt [uint64][int]::MaxValue -or $z64CdSize -gt [uint64]$z64Off -or $z64CdOff -gt [uint64]$z64Off) {
            $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE"
            $counts.BoundsViolations++
            $counts.InvalidEntries = 1
            $errorMessages.Add("ZIP64 EOCD boundaries exceed archive structure")
            return [PSCustomObject]@{
                Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
            }
        }
        $totalEntries = [int64]$z64Entries
        $cdSize = [int64]$z64CdSize
        $cdOffset = [int64]$z64CdOff
        $cdLimitEnd = $z64Off
        $counts.Zip64Status = "Supported & Valid"
    }

    if ($cdOffset -lt 0 -or $cdSize -lt 0 -or ($cdOffset + $cdSize) -gt $cdLimitEnd) {
        $counts.BoundsViolations++
        $counts.InvalidEntries = 1
        $errorMessages.Add("Central Directory bounds exceed archive structure (cdOffset=$cdOffset, cdSize=$cdSize, limit=$cdLimitEnd)")
        return [PSCustomObject]@{
            Valid = $false; Counts = $counts; Entries = @(); Errors = @($errorMessages); FatalError = $errorMessages[0]
        }
    }

    $counts.TotalEntries = [int]$totalEntries
    $cur = $cdOffset
    $cdEnd = $cdOffset + $cdSize
    $parsedCount = 0
    $seenLhOffsets = [System.Collections.Generic.HashSet[int64]]::new()
    $spans = [System.Collections.Generic.List[object]]::new()

    # Allowed General Purpose Bit Flags: Bits 1-2 (compression options 0x0006), Bit 3 (DD 0x0008), Bit 11 (UTF-8 0x0800)
    $allowedFlagMask = 0x080E

    while ($cur -lt $cdEnd) {
        if (($cur + 46) -gt $cdEnd) {
            $counts.CentralDirectorySignatureErrors++
            $counts.BoundsViolations++
            $fatalError = "Truncated Central Directory File Header at byte offset $cur"
            $errorMessages.Add($fatalError)
            break
        }
        if ($bytes[$cur] -ne 0x50 -or $bytes[$cur + 1] -ne 0x4B -or $bytes[$cur + 2] -ne 0x01 -or $bytes[$cur + 3] -ne 0x02) {
            $counts.CentralDirectorySignatureErrors++
            $fatalError = "Invalid Central Directory signature (expected 0x02014B50) at offset $cur"
            $errorMessages.Add($fatalError)
            break
        }

        $cdVerNeed  = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 6))
        $cdFlag     = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 8))
        $cdMethod   = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 10))
        $cdModTime  = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 12))
        $cdModDate  = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 14))
        $cdCrc      = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($cur + 16))
        $cdComp32   = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($cur + 20))
        $cdUncomp32 = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($cur + 24))
        $cdFnLen    = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 28))
        $cdExLen    = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 30))
        $cdCmLen    = [int][System.BitConverter]::ToUInt16($bytes, [int]($cur + 32))
        $cdExtAttr  = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($cur + 38))
        $cdLhOff32  = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($cur + 42))

        $entryErrs = [System.Collections.Generic.List[string]]::new()

        if (($cur + 46 + $cdFnLen + $cdExLen + $cdCmLen) -gt $cdEnd) {
            $counts.BoundsViolations++
            $fatalError = "Central Directory entry extends beyond CD boundary at offset $cur"
            $errorMessages.Add($fatalError)
            break
        }

        $rawName = if ($cdFnLen -gt 0) {
            [System.Text.Encoding]::UTF8.GetString($bytes, [int]($cur + 46), $cdFnLen)
        } else {
            ""
        }

        $hasRawBackslash = $false
        for ($bi = 0; $bi -lt $cdFnLen; $bi++) {
            if ($bytes[$cur + 46 + $bi] -eq 0x5C) { $hasRawBackslash = $true; break }
        }

        $need64Uncomp = ($cdUncomp32 -eq 0xFFFFFFFF)
        $need64Comp = ($cdComp32 -eq 0xFFFFFFFF)
        $need64Offset = ($cdLhOff32 -eq 0xFFFFFFFF)
        $isEntryZip64 = ($need64Uncomp -or $need64Comp -or $need64Offset)

        # Validate Central Directory Extra Field
        $cdExOffset = [int64]($cur + 46 + $cdFnLen)
        $cdExCheck = Test-ZipExtraFieldBlock -Bytes $bytes -Offset $cdExOffset -Length $cdExLen -BufferLimit $cdEnd -ScopeLabel "CentralDirectory" -Needs64Uncomp $need64Uncomp -Needs64Comp $need64Comp -Needs64Offset $need64Offset
        if (@($cdExCheck.Errors).Count -gt 0) {
            $counts.ExtraFieldErrors += @($cdExCheck.Errors).Count
            if ($isEntryZip64 -and $counts.Zip64Status -eq "Not Used") {
                $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE"
            }
            foreach ($ce in $cdExCheck.Errors) { $entryErrs.Add("[$rawName] $ce") }
        }

        $effUncompSize = [int64]$cdUncomp32
        $effCompSize = [int64]$cdComp32
        $effLhOffset = [int64]$cdLhOff32
        if ($isEntryZip64) {
            if ($null -eq $cdExCheck.Zip64Info) {
                if ($counts.Zip64Status -eq "Not Used") { $counts.Zip64Status = "UNSUPPORTED ZIP64 STRUCTURE" }
                $counts.ExtraFieldErrors++
                $entryErrs.Add("[$rawName] UNSUPPORTED ZIP64 STRUCTURE: Entry uses 0xFFFFFFFF sentinel without valid ZIP64 Extra Field 0x0001")
            } else {
                if ($need64Uncomp) { $effUncompSize = [int64]$cdExCheck.Zip64Info.UncompressedSize }
                if ($need64Comp) { $effCompSize = [int64]$cdExCheck.Zip64Info.CompressedSize }
                if ($need64Offset) { $effLhOffset = [int64]$cdExCheck.Zip64Info.LocalHeaderOffset }
                if ($counts.Zip64Status -eq "Not Used") { $counts.Zip64Status = "Supported & Valid" }
            }
        }

        # Check flags & compression method on Central Directory
        if (($cdFlag -band 0x0001) -ne 0) {
            $counts.GeneralPurposeFlagMismatches++
            $entryErrs.Add("[$rawName] Unsupported encryption flag set (bit 0 = 0x0001) in Central Directory")
        }
        if (($cdFlag -band (-bnot ($allowedFlagMask -bor 0x0001))) -ne 0) {
            $counts.GeneralPurposeFlagMismatches++
            $entryErrs.Add("[$rawName] Unsupported or reserved General Purpose Bit Flag 0x$($cdFlag.ToString('X4')) in Central Directory")
        }
        if ($cdMethod -notin @(0, 8)) {
            $counts.CompressionMethodMismatches++
            $entryErrs.Add("[$rawName] Unsupported compression method ($cdMethod); only STORE (0) and DEFLATE (8) are permitted")
        }

        # Validate Local File Header offset & presence
        if ($effLhOffset -lt 0 -or ($effLhOffset + 30) -gt $cdOffset) {
            $counts.BoundsViolations++
            $entryErrs.Add("[$rawName] Local File Header offset ($effLhOffset) out of archive bounds (cdOffset=$cdOffset)")
        } else {
            if (-not $seenLhOffsets.Add($effLhOffset)) {
                $counts.DuplicateLocalHeaderOffsets++
                $entryErrs.Add("[$rawName] Duplicate Local File Header offset detected: $effLhOffset")
            }

            if ($bytes[$effLhOffset] -ne 0x50 -or $bytes[$effLhOffset + 1] -ne 0x4B -or $bytes[$effLhOffset + 2] -ne 0x03 -or $bytes[$effLhOffset + 3] -ne 0x04) {
                $counts.LocalHeaderSignatureErrors++
                $entryErrs.Add("[$rawName] Corrupt Local File Header signature (expected 0x04034B50) at offset $effLhOffset")
            } else {
                $lhVerNeed  = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 4))
                $lhFlag     = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 6))
                $lhMethod   = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 8))
                $lhModTime  = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 10))
                $lhModDate  = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 12))
                $lhCrc      = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($effLhOffset + 14))
                $lhComp32   = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($effLhOffset + 18))
                $lhUncomp32 = [uint32][System.BitConverter]::ToUInt32($bytes, [int]($effLhOffset + 22))
                $lhFnLen    = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 26))
                $lhExLen    = [int][System.BitConverter]::ToUInt16($bytes, [int]($effLhOffset + 28))

                # Filename length MUST match strictly
                if ($lhFnLen -ne $cdFnLen) {
                    $counts.FilenameLengthMismatches++
                    $entryErrs.Add("[$rawName] Local File Header filename length mismatch (LH=$lhFnLen vs CD=$cdFnLen)")
                }

                # Check LH variable fields bounds
                $lhHeaderTotalEnd = $effLhOffset + 30 + $lhFnLen + $lhExLen
                if ($lhHeaderTotalEnd -gt $cdOffset) {
                    $counts.BoundsViolations++
                    $entryErrs.Add("[$rawName] Local File Header filename or extra field truncated past Central Directory (end=$lhHeaderTotalEnd > cdOffset=$cdOffset)")
                } else {
                    # Scan raw LH filename for backslashes AND compare exact bytes when lengths match
                    for ($li = 0; $li -lt $lhFnLen; $li++) {
                        if ($bytes[$effLhOffset + 30 + $li] -eq 0x5C) { $hasRawBackslash = $true }
                    }
                    if ($lhFnLen -eq $cdFnLen) {
                        for ($li = 0; $li -lt $cdFnLen; $li++) {
                            if ($bytes[$effLhOffset + 30 + $li] -ne $bytes[$cur + 46 + $li]) {
                                $counts.FilenameByteMismatches++
                                $entryErrs.Add("[$rawName] Local File Header raw filename byte mismatch at index $li (LH=0x$($bytes[$effLhOffset + 30 + $li].ToString('X2')) vs CD=0x$($bytes[$cur + 46 + $li].ToString('X2')))")
                                break
                            }
                        }
                    }

                    # Validate Local Extra Field
                    $lhExCheck = Test-ZipExtraFieldBlock -Bytes $bytes -Offset ($effLhOffset + 30 + $lhFnLen) -Length $lhExLen -BufferLimit $cdOffset -ScopeLabel "Local" -Needs64Uncomp ($lhUncomp32 -eq 0xFFFFFFFF) -Needs64Comp ($lhComp32 -eq 0xFFFFFFFF) -Needs64Offset $false
                    if (@($lhExCheck.Errors).Count -gt 0) {
                        $counts.ExtraFieldErrors += @($lhExCheck.Errors).Count
                        foreach ($le in $lhExCheck.Errors) { $entryErrs.Add("[$rawName] $le") }
                    }

                    # General Purpose Bit Flags consistency
                    if (($lhFlag -band 0x0001) -ne 0) {
                        $counts.GeneralPurposeFlagMismatches++
                        $entryErrs.Add("[$rawName] Unsupported encryption flag in Local File Header")
                    }
                    if ($lhFlag -ne $cdFlag) {
                        $counts.GeneralPurposeFlagMismatches++
                        $entryErrs.Add("[$rawName] General Purpose Bit Flag mismatch (LH=0x$($lhFlag.ToString('X4')) vs CD=0x$($cdFlag.ToString('X4')))")
                    }

                    # Compression method consistency
                    if ($lhMethod -ne $cdMethod) {
                        $counts.CompressionMethodMismatches++
                        $entryErrs.Add("[$rawName] Compression method mismatch (LH=$lhMethod vs CD=$cdMethod)")
                    }

                    # Modification time and date consistency
                    if ($lhModTime -ne $cdModTime -or $lhModDate -ne $cdModDate) {
                        $counts.ModTimeDateMismatches++
                        $entryErrs.Add("[$rawName] Modification time/date mismatch (LH=$lhModDate/$lhModTime vs CD=$cdModDate/$cdModTime)")
                    }

                    # Data payload bounds + CRC/Sizes/Data Descriptor validation
                    $hasDataDesc = (($cdFlag -band 0x0008) -ne 0)
                    $dataEnd = $lhHeaderTotalEnd + $effCompSize
                    if ($effCompSize -lt 0 -or $dataEnd -gt $cdOffset) {
                        $counts.BoundsViolations++
                        $entryErrs.Add("[$rawName] Compressed payload extends past Central Directory (dataEnd=$dataEnd > cdOffset=$cdOffset)")
                    } else {
                        $spanEnd = $dataEnd
                        if (-not $hasDataDesc) {
                            if ($lhCrc -ne $cdCrc) {
                                $counts.CrcMismatches++
                                $entryErrs.Add("[$rawName] CRC-32 mismatch on non-Data-Descriptor entry (LH=0x$($lhCrc.ToString('X8')) vs CD=0x$($cdCrc.ToString('X8')))")
                            }
                            $lhCompVal = if ($lhComp32 -eq 0xFFFFFFFF -and $null -ne $lhExCheck.Zip64Info -and $null -ne $lhExCheck.Zip64Info.CompressedSize) { [int64]$lhExCheck.Zip64Info.CompressedSize } else { [int64]$lhComp32 }
                            $lhUncompVal = if ($lhUncomp32 -eq 0xFFFFFFFF -and $null -ne $lhExCheck.Zip64Info -and $null -ne $lhExCheck.Zip64Info.UncompressedSize) { [int64]$lhExCheck.Zip64Info.UncompressedSize } else { [int64]$lhUncomp32 }

                            if ($lhCompVal -ne $effCompSize) {
                                $counts.CompressedSizeMismatches++
                                $entryErrs.Add("[$rawName] Compressed size mismatch (LH=$lhCompVal vs CD=$effCompSize)")
                            }
                            if ($lhUncompVal -ne $effUncompSize) {
                                $counts.UncompressedSizeMismatches++
                                $entryErrs.Add("[$rawName] Uncompressed size mismatch (LH=$lhUncompVal vs CD=$effUncompSize)")
                            }
                        } else {
                            # Bit 3 Data Descriptor enabled: LH CRC/sizes may be 0 or match CD
                            if (($lhCrc -ne 0 -and $lhCrc -ne $cdCrc) -or ($lhComp32 -ne 0 -and [int64]$lhComp32 -ne $effCompSize) -or ($lhUncomp32 -ne 0 -and [int64]$lhUncomp32 -ne $effUncompSize)) {
                                $counts.DataDescriptorErrors++
                                $entryErrs.Add("[$rawName] Non-zero Local Header CRC/sizes conflict with Central Directory under Data Descriptor mode")
                            }

                            $ddPos = $dataEnd
                            $szWidth = if ($isEntryZip64) { 8 } else { 4 }
                            $hasDdSig = (($ddPos + 4) -le $cdOffset -and $bytes[$ddPos] -eq 0x50 -and $bytes[$ddPos + 1] -eq 0x4B -and $bytes[$ddPos + 2] -eq 0x07 -and $bytes[$ddPos + 3] -eq 0x08)
                            $ddHeaderLen = if ($hasDdSig) { 4 } else { 0 }
                            $ddTotalLen = $ddHeaderLen + 4 + $szWidth + $szWidth

                            if (($ddPos + $ddTotalLen) -gt $cdOffset) {
                                $counts.DataDescriptorErrors++
                                $counts.BoundsViolations++
                                $entryErrs.Add("[$rawName] Missing or truncated Data Descriptor (needed $ddTotalLen bytes at $ddPos, cdOffset=$cdOffset)")
                            } else {
                                $ddFieldOff = [int]($ddPos + $ddHeaderLen)
                                $ddCrc = [uint32][System.BitConverter]::ToUInt32($bytes, $ddFieldOff)
                                if ($isEntryZip64) {
                                    $ddComp = [int64][System.BitConverter]::ToUInt64($bytes, $ddFieldOff + 4)
                                    $ddUncomp = [int64][System.BitConverter]::ToUInt64($bytes, $ddFieldOff + 12)
                                } else {
                                    $ddComp = [int64][System.BitConverter]::ToUInt32($bytes, $ddFieldOff + 4)
                                    $ddUncomp = [int64][System.BitConverter]::ToUInt32($bytes, $ddFieldOff + 8)
                                }

                                if ($ddCrc -ne $cdCrc) {
                                    $counts.DataDescriptorErrors++
                                    $counts.CrcMismatches++
                                    $entryErrs.Add("[$rawName] Data Descriptor CRC-32 mismatch (DD=0x$($ddCrc.ToString('X8')) vs CD=0x$($cdCrc.ToString('X8')))")
                                }
                                if ($ddComp -ne $effCompSize -or $ddUncomp -ne $effUncompSize) {
                                    $counts.DataDescriptorErrors++
                                    if ($ddComp -ne $effCompSize) { $counts.CompressedSizeMismatches++ }
                                    if ($ddUncomp -ne $effUncompSize) { $counts.UncompressedSizeMismatches++ }
                                    $entryErrs.Add("[$rawName] Data Descriptor size mismatch (DD comp=$ddComp/uncomp=$ddUncomp vs CD comp=$effCompSize/uncomp=$effUncompSize)")
                                }
                                $spanEnd = $ddPos + $ddTotalLen
                            }
                        }

                        $spans.Add([PSCustomObject]@{ Start = $effLhOffset; End = $spanEnd; Name = $rawName })
                    }
                }
            }
        }

        if ($rawName.EndsWith("/") -and $entryErrs.Count -eq 0) {
            $counts.ValidDirectoryEntries++
        }
        if ($entryErrs.Count -eq 0) {
            $counts.ValidEntries++
        } else {
            $counts.InvalidEntries++
            foreach ($msg in $entryErrs) { $errorMessages.Add($msg) }
        }

        $entryResults.Add([PSCustomObject]@{
            RawName = $rawName
            ExternalAttributes = $cdExtAttr
            HasRawBackslash = $hasRawBackslash
            BitFlag = $cdFlag
            CompressionMethod = $cdMethod
            Crc32Hex = "0x$($cdCrc.ToString('X8'))"
            CompressedSize = $effCompSize
            UncompressedSize = $effUncompSize
            LocalHeaderOffset = $effLhOffset
            ModTime = $cdModTime
            ModDate = $cdModDate
            DataDescriptor = (($cdFlag -band 0x0008) -ne 0)
            HeaderValid = ($entryErrs.Count -eq 0)
        })

        $cur += 46 + $cdFnLen + $cdExLen + $cdCmLen
        $parsedCount++
    }

    if ($null -eq $fatalError) {
        if ($parsedCount -ne $totalEntries -or $cur -ne $cdEnd) {
            $counts.BoundsViolations++
            $errorMessages.Add("Central Directory count/end mismatch: parsed=$parsedCount vs expected=$totalEntries, cur=$cur vs cdEnd=$cdEnd")
        }

        # Check span non-overlap & ensure zero unindexed orphan Local File Headers (PK 03 04)
        $sortedSpans = @($spans | Sort-Object -Property Start)
        for ($si = 0; $si -lt $sortedSpans.Count; $si++) {
            if ($si -gt 0 -and $sortedSpans[$si].Start -lt $sortedSpans[$si - 1].End) {
                $counts.BoundsViolations++
                $errorMessages.Add("Overlapping Local Header/data spans: '$($sortedSpans[$si - 1].Name)' ($($sortedSpans[$si - 1].Start)..$($sortedSpans[$si - 1].End)) overlaps '$($sortedSpans[$si].Name)' ($($sortedSpans[$si].Start)..$($sortedSpans[$si].End))")
            }
            $gapStart = if ($si -eq 0) { [int64]0 } else { $sortedSpans[$si - 1].End }
            $gapEnd = $sortedSpans[$si].Start
            if ($gapEnd -gt $gapStart) {
                for ($gp = $gapStart; $gp -le ($gapEnd - 4); $gp++) {
                    if ($bytes[$gp] -eq 0x50 -and $bytes[$gp + 1] -eq 0x4B -and $bytes[$gp + 2] -eq 0x03 -and $bytes[$gp + 3] -eq 0x04) {
                        $counts.BoundsViolations++
                        $errorMessages.Add("Unreferenced orphan Local File Header (PK 03 04) detected at gap offset $gp before '$($sortedSpans[$si].Name)'")
                        break
                    }
                }
            }
        }
        if ($sortedSpans.Count -gt 0 -and $sortedSpans[-1].End -lt $cdOffset) {
            for ($gp = $sortedSpans[-1].End; $gp -le ($cdOffset - 4); $gp++) {
                if ($bytes[$gp] -eq 0x50 -and $bytes[$gp + 1] -eq 0x4B -and $bytes[$gp + 2] -eq 0x03 -and $bytes[$gp + 3] -eq 0x04) {
                    $counts.BoundsViolations++
                    $errorMessages.Add("Unreferenced orphan Local File Header (PK 03 04) detected in trailing gap at offset $gp")
                    break
                }
            }
        }
    }

    $isValid = ($null -eq $fatalError -and $errorMessages.Count -eq 0 -and $counts.InvalidEntries -eq 0 -and $counts.TotalEntries -gt 0)
    return [PSCustomObject]@{
        Valid = $isValid
        Counts = $counts
        Entries = @($entryResults)
        Errors = @($errorMessages)
        FatalError = $fatalError
    }
}

function Get-RawZipCentralDirectoryEntries {
    <#
    .SYNOPSIS
    Strict fail-closed wrapper returning raw entries only when full binary
    Central Directory & Local File Header consistency passes 100%.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath
    )

    $report = Inspect-ZipBinaryHeaders -ZipPath $ZipPath
    if (-not $report.Valid) {
        $reason = if ($report.Errors.Count -gt 0) { $report.Errors -join "; " } else { "Binary ZIP header validation failed" }
        throw $reason
    }
    return @($report.Entries)
}

function Test-ZipArchiveEntries {
    <#
    .SYNOPSIS
    Validates full binary ZIP headers (Local File Header <-> Central Directory)
    AND path security rules (no backslashes, no traversal, no absolute/drive paths,
    no symlinks, no duplicates, no case collisions).
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
            BinaryReport = $null
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

    $binReport = Inspect-ZipBinaryHeaders -ZipPath $zipFull
    if (-not $binReport.Valid) {
        foreach ($be in $binReport.Errors) {
            $violations.Add($be)
        }
    }

    $archive = $null
    try {
        foreach ($entry in $binReport.Entries) {
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

        if ($binReport.Valid) {
            try {
                $archive = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
            } catch {
                $violations.Add(".NET ZipFile::OpenRead failed: $($_.Exception.Message)")
            }
        }
    } finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }

    if ($binReport.Counts.TotalEntries -eq 0 -and $violations.Count -eq 0) {
        $violations.Add("Archive contains 0 entries")
    }

    return [PSCustomObject]@{
        Valid = ($violations.Count -eq 0)
        ZipPath = $zipFull
        EntryCount = $allEntries.Count
        FileEntryCount = $fileEntries.Count
        DirectoryEntryCount = $dirCount
        BackslashCount = $backslashCount
        SymlinkCount = $symlinkCount
        BinaryReport = $binReport
        Violations = @($violations)
        FileEntries = @($fileEntries)
        AllEntries = @($allEntries)
    }
}

function Find-PythonExecutable {
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
    Validates binary ZIP headers, path hygiene, Python zipfile, Info-ZIP unzip,
    and .NET extraction with full 3-way SHA-256 and structure comparison.
    Returns separated extractor logs and raw byte inspection lines.
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

    $structResult = Test-ZipArchiveEntries -ZipPath $zipFull
    if (-not $structResult.Valid) {
        return [PSCustomObject]@{
            Passed = $false
            EnvironmentBlocked = $false
            Label = $ArchiveLabel
            ZipPath = $zipFull
            Timestamp = $ts
            FailureReason = "ZIP structural/header validation failed: $($structResult.Violations -join '; ')"
            Structure = $structResult
            ReportLines = @(
                "=== ARCHIVE: $ArchiveLabel ===",
                "Path: $zipFull",
                "Timestamp: $ts",
                "Structure/Header Validation: FAIL ($($structResult.Violations -join '; '))"
            )
            RawByteLines = @()
            PythonLogLines = @()
            InfoZipLogLines = @()
            DotNetLogLines = @()
        }
    }

    $pyInfo = Find-PythonExecutable
    if ($null -eq $pyInfo) {
        return [PSCustomObject]@{
            Passed = $false; EnvironmentBlocked = $true; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
            FailureReason = "NOT VERIFIED - ENVIRONMENT BLOCKED: Python 3 executable unavailable"
            Structure = $structResult
            ReportLines = @("=== ARCHIVE: $ArchiveLabel ===", "Status: NOT VERIFIED - ENVIRONMENT BLOCKED (Python 3 unavailable)")
            RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
        }
    }

    $uzInfo = Find-InfoZipExecutable
    if ($null -eq $uzInfo) {
        return [PSCustomObject]@{
            Passed = $false; EnvironmentBlocked = $true; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
            FailureReason = "NOT VERIFIED - ENVIRONMENT BLOCKED: Info-ZIP unzip executable unavailable or blocked"
            Structure = $structResult
            ReportLines = @("=== ARCHIVE: $ArchiveLabel ===", "Status: NOT VERIFIED - ENVIRONMENT BLOCKED (Info-ZIP unzip unavailable)")
            RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
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
        $pyTs = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $pyOut = (& $pyInfo.Path $pyHelperPath $zipFull $pyExtractDir 2>&1 | Out-String).Trim()
        $pyExit = $LASTEXITCODE
        if ($pyExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Python zipfile check/extraction failed (Exit $pyExit): $pyOut"
                Structure = $structResult; ReportLines = @("FAIL: Python extraction failed ($pyOut)")
                RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
            }
        }

        $uzTs = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        $uzTestOut = (& $uzInfo.Path -t -qq $zipFull 2>&1 | Out-String).Trim()
        $uzTestExit = $LASTEXITCODE
        if ($uzTestExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Info-ZIP CRC test (-t) failed (Exit $uzTestExit): $uzTestOut"
                Structure = $structResult; ReportLines = @("FAIL: Info-ZIP -t failed ($uzTestOut)")
                RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
            }
        }

        $uzExtOut = (& $uzInfo.Path -q -o $zipFull -d $uzExtractDir 2>&1 | Out-String).Trim()
        $uzExtExit = $LASTEXITCODE
        if ($uzExtExit -ne 0) {
            return [PSCustomObject]@{
                Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
                FailureReason = "Info-ZIP extraction failed (Exit $uzExtExit): $uzExtOut"
                Structure = $structResult; ReportLines = @("FAIL: Info-ZIP extract failed ($uzExtOut)")
                RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
            }
        }

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
                RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
            }
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }

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
    if (($invPy.Directories -join "`n") -cne ($invUz.Directories -join "`n") -or ($invPy.Directories -join "`n") -cne ($invDn.Directories -join "`n")) {
        $parityErrors.Add("Directory structure set mismatch across Python / Info-ZIP / .NET")
    }

    $hashMatchedCount = 0
    foreach ($relFile in $invPy.Files) {
        if (-not $invUz.FileMap.ContainsKey($relFile)) { $parityErrors.Add("Missing in Info-ZIP output: $relFile"); continue }
        if (-not $invDn.FileMap.ContainsKey($relFile)) { $parityErrors.Add("Missing in .NET output: $relFile"); continue }
        $mPy = $invPy.FileMap[$relFile]; $mUz = $invUz.FileMap[$relFile]; $mDn = $invDn.FileMap[$relFile]
        if ($mPy.Size -ne $mUz.Size -or $mPy.Size -ne $mDn.Size) { $parityErrors.Add("Byte size mismatch on '$relFile'"); continue }
        if ($mPy.Sha256 -cne $mUz.Sha256 -or $mPy.Sha256 -cne $mDn.Sha256) { $parityErrors.Add("SHA-256 mismatch on '$relFile'"); continue }
        $hashMatchedCount++
    }

    if ($parityErrors.Count -gt 0) {
        return [PSCustomObject]@{
            Passed = $false; EnvironmentBlocked = $false; Label = $ArchiveLabel; ZipPath = $zipFull; Timestamp = $ts
            FailureReason = "3-way cross-platform parity check failed: $($parityErrors -join '; ')"
            Structure = $structResult; ReportLines = @("FAIL: Parity mismatch ($($parityErrors -join '; '))")
            RawByteLines = @(); PythonLogLines = @(); InfoZipLogLines = @(); DotNetLogLines = @()
        }
    }

    $rawByteLines = [System.Collections.Generic.List[string]]::new()
    $rawByteLines.Add("=== RAW HEADER ENTRIES: $ArchiveLabel ($($structResult.BinaryReport.Counts.TotalEntries) entries, 0 backslashes) ===")
    foreach ($be in $structResult.BinaryReport.Entries) {
        $rawByteLines.Add("  [OK] Entry='$($be.RawName)' | Offset=$($be.LocalHeaderOffset) | Method=$($be.CompressionMethod) | Flag=0x$($be.BitFlag.ToString('X4')) | CRC=$($be.Crc32Hex) | Size=$($be.CompressedSize)/$($be.UncompressedSize) | DD=$($be.DataDescriptor)")
    }
    $rawByteLines.Add("")

    $pyLogLines = @(
        "=== PYTHON EXTRACTION LOG: $ArchiveLabel ===",
        "Timestamp: $pyTs | Tool: $($pyInfo.Version)",
        "Command: python py_zip_check.py $zipFull <py_out>",
        "Stdout: $pyOut | Exit Code: $pyExit",
        "Extracted Directories: $($invPy.DirectoryCount) | Extracted Files: $($invPy.FileCount) | Status: PASS",
        ""
    )
    $uzLogLines = @(
        "=== INFO-ZIP EXTRACTION LOG: $ArchiveLabel ===",
        "Timestamp: $uzTs | Tool: $($uzInfo.Version)",
        "Command 1 (CRC Test): unzip -t -qq $zipFull | Exit Code: $uzTestExit",
        "Command 2 (Extract):  unzip -q -o $zipFull -d <infozip_out> | Exit Code: $uzExtExit",
        "Extracted Directories: $($invUz.DirectoryCount) | Extracted Files: $($invUz.FileCount) | Status: PASS",
        ""
    )
    $dnLogLines = @(
        "=== .NET ZIPFILE EXTRACTION LOG: $ArchiveLabel ===",
        "Timestamp: $dnTs | Tool: PS $psVer / $dotnetRuntimeVer",
        "Command: [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFull, <dotnet_out>) | Exit Code: $dnExit",
        "Extracted Directories: $($invDn.DirectoryCount) | Extracted Files: $($invDn.FileCount) | Status: PASS",
        ""
    )

    $lines = @(
        "=== ARCHIVE: $ArchiveLabel ===",
        "Zip Path: $zipFull",
        "Timestamp: $ts",
        "Total ZIP Entries: $($structResult.EntryCount) | File Entries: $($structResult.FileEntryCount) | Backslash Entries: $($structResult.BackslashCount)",
        "Path Hygiene & Binary LH/CD Header Validation: PASS",
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
        RawByteLines = @($rawByteLines)
        PythonLogLines = @($pyLogLines)
        InfoZipLogLines = @($uzLogLines)
        DotNetLogLines = @($dnLogLines)
    }
}
