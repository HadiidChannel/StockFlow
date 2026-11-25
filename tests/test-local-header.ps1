# ==============================================================================
# StockFlow v1.6.6 - Binary Local File Header & Central Directory Test Matrix
# File: tests/test-local-header.ps1
# Description: Constructs 32 real byte-level ZIP fixtures (LH-01 through LH-32)
#              in an isolated temporary directory and invokes the actual raw
#              ZIP header validator in scripts/zip-utils.ps1.
#              Zero mocks; never touches release ZIPs or project root files.
# Target OS: Windows (PowerShell 7+ / Windows PowerShell 5.1)
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputReportPath,

    [Parameter(Mandatory = $false)]
    [switch]$NoThrowOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$zipUtilsPath = Join-Path $projectRoot "scripts\zip-utils.ps1"

. $zipUtilsPath

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$pyInfo = Find-PythonExecutable
if ($null -eq $pyInfo) {
    throw "Python 3 executable is required to construct binary ZIP test fixtures."
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stockflow_lh_tests_" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

$fixtureGenPy = Join-Path $workRoot "build_lh_fixtures.py"
$pyBuilderSource = @'
import json
import os
import struct
import sys
import zlib

out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)

def dos_dt(year=2026, month=11, day=26, hour=1, minute=2, sec=4):
    dos_time = ((hour & 0x1F) << 11) | ((minute & 0x3F) << 5) | ((sec // 2) & 0x1F)
    dos_date = (((year - 1980) & 0x7F) << 9) | ((month & 0x0F) << 5) | (day & 0x1F)
    return dos_time, dos_date

def make_entry(
    name_bytes,
    payload,
    method=8,
    flag=0x0800,
    mtime=None,
    mdate=None,
    lh_extra=b"",
    cd_extra=b"",
    ext_attr=0,
    use_dd=False,
    dd_with_sig=True,
    override_lh=None,
    override_cd=None,
    override_dd=None,
):
    tm, dt = dos_dt()
    if mtime is None: mtime = tm
    if mdate is None: mdate = dt
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    if method == 0:
        comp = payload
    elif method == 8:
        comp_obj = zlib.compressobj(6, zlib.DEFLATED, -zlib.MAX_WBITS)
        comp = comp_obj.compress(payload) + comp_obj.flush()
    else:
        comp = payload
    uncomp_len = len(payload)
    comp_len = len(comp)

    lh_f = flag
    cd_f = flag
    lh_m = method
    cd_m = method
    lh_tm, cd_tm = mtime, mtime
    lh_dt, cd_dt = mdate, mdate
    lh_crc, cd_crc = (0 if use_dd else crc), crc
    lh_cs, cd_cs = (0 if use_dd else comp_len), comp_len
    lh_us, cd_us = (0 if use_dd else uncomp_len), uncomp_len
    lh_fn = name_bytes
    cd_fn = name_bytes
    lh_ex = lh_extra
    cd_ex = cd_extra
    lh_ex_len = len(lh_ex)
    cd_ex_len = len(cd_ex)
    lh_fn_len = len(lh_fn)
    cd_fn_len = len(cd_fn)
    lh_sig = b"PK\x03\x04"
    cd_sig = b"PK\x01\x02"

    if override_lh:
        lh_sig = override_lh.get("sig", lh_sig)
        lh_f = override_lh.get("flag", lh_f)
        lh_m = override_lh.get("method", lh_m)
        lh_tm = override_lh.get("mtime", lh_tm)
        lh_dt = override_lh.get("mdate", lh_dt)
        lh_crc = override_lh.get("crc", lh_crc)
        lh_cs = override_lh.get("cs", lh_cs)
        lh_us = override_lh.get("us", lh_us)
        lh_fn = override_lh.get("fn", lh_fn)
        lh_fn_len = override_lh.get("fn_len", len(lh_fn))
        lh_ex = override_lh.get("ex", lh_ex)
        lh_ex_len = override_lh.get("ex_len", len(lh_ex))

    if override_cd:
        cd_sig = override_cd.get("sig", cd_sig)
        cd_f = override_cd.get("flag", cd_f)
        cd_m = override_cd.get("method", cd_m)
        cd_tm = override_cd.get("mtime", cd_tm)
        cd_dt = override_cd.get("mdate", cd_dt)
        cd_crc = override_cd.get("crc", cd_crc)
        cd_cs = override_cd.get("cs", cd_cs)
        cd_us = override_cd.get("us", cd_us)
        cd_fn = override_cd.get("fn", cd_fn)
        cd_fn_len = override_cd.get("fn_len", len(cd_fn))
        cd_ex = override_cd.get("ex", cd_ex)
        cd_ex_len = override_cd.get("ex_len", len(cd_ex))

    lh_hdr = lh_sig + struct.pack(
        "<HHHHHIIIHH",
        20, lh_f, lh_m, lh_tm, lh_dt, lh_crc, lh_cs, lh_us, lh_fn_len, lh_ex_len
    ) + lh_fn + lh_ex

    dd_bytes = b""
    if use_dd:
        dd_crc = crc
        dd_cs = comp_len
        dd_us = uncomp_len
        if override_dd:
            if override_dd.get("omit", False):
                dd_bytes = b""
            else:
                dd_crc = override_dd.get("crc", dd_crc)
                dd_cs = override_dd.get("cs", dd_cs)
                dd_us = override_dd.get("us", dd_us)
                if dd_with_sig:
                    dd_bytes = b"PK\x07\x08" + struct.pack("<III", dd_crc, dd_cs, dd_us)
                else:
                    dd_bytes = struct.pack("<III", dd_crc, dd_cs, dd_us)
        else:
            if dd_with_sig:
                dd_bytes = b"PK\x07\x08" + struct.pack("<III", dd_crc, dd_cs, dd_us)
            else:
                dd_bytes = struct.pack("<III", dd_crc, dd_cs, dd_us)

    return {
        "lh_bytes": lh_hdr + comp + dd_bytes,
        "cd_meta": (cd_sig, 20, 20, cd_f, cd_m, cd_tm, cd_dt, cd_crc, cd_cs, cd_us, cd_fn_len, cd_ex_len, 0, 0, 0, ext_attr),
        "cd_tail": cd_fn + cd_ex,
    }

def build_zip(path, entry_specs, override_lh_offsets=None, truncate_lh=0, truncate_cd=0, append_zip64_broken=False):
    buf = bytearray()
    offsets = []
    for idx, sp in enumerate(entry_specs):
        off = len(buf)
        offsets.append(off)
        buf.extend(sp["lh_bytes"])
    if truncate_lh > 0:
        buf = buf[:-truncate_lh]
    cd_offset = len(buf)
    cd_buf = bytearray()
    for idx, sp in enumerate(entry_specs):
        meta = sp["cd_meta"]
        off = offsets[idx]
        if override_lh_offsets and idx in override_lh_offsets:
            off = override_lh_offsets[idx]
        cd_rec = meta[0] + struct.pack(
            "<HHHHHHIIIHHHHHII",
            meta[1], meta[2], meta[3], meta[4], meta[5], meta[6],
            meta[7], meta[8], meta[9], meta[10], meta[11], meta[12],
            meta[13], meta[14], meta[15], off
        ) + sp["cd_tail"]
        cd_buf.extend(cd_rec)
    if truncate_cd > 0:
        cd_buf = cd_buf[:-truncate_cd]
    cd_size = len(cd_buf)
    buf.extend(cd_buf)
    cnt = len(entry_specs)
    eocd_cd_sz = cd_size if not append_zip64_broken else 0xFFFFFFFF
    eocd_cd_off = cd_offset if not append_zip64_broken else 0xFFFFFFFF
    eocd_cnt = cnt if not append_zip64_broken else 0xFFFF
    eocd = b"PK\x05\x06" + struct.pack("<HHHHIIH", 0, 0, eocd_cnt, eocd_cnt, eocd_cd_sz, eocd_cd_off, 0)
    buf.extend(eocd)
    with open(path, "wb") as f:
        f.write(buf)

cases = []
def add_case(cid, desc, expect_pass, filename, entry_specs, **kw):
    zp = os.path.join(out_dir, filename)
    build_zip(zp, entry_specs, **kw)
    cases.append({"id": cid, "desc": desc, "expectPass": expect_pass, "zipPath": zp})

# POSITIVE LH-01..LH-10
add_case("LH-01", "Valid STORE entry", True, "lh01_store.zip", [make_entry(b"hello.txt", b"Hello Store Payload", method=0)])
add_case("LH-02", "Valid DEFLATE entry", True, "lh02_deflate.zip", [make_entry(b"src/app.ts", b"console.log('deflate');\n" * 5, method=8)])
add_case("LH-03", "Valid UTF-8 filename", True, "lh03_utf8.zip", [make_entry("docs/laporan-stok-\u00e9dition.txt".encode("utf-8"), b"utf8 body", flag=0x0800)])
add_case("LH-04", "Valid directory entry + child file", True, "lh04_dir.zip", [
    make_entry(b"docs/", b"", method=0, ext_attr=(0x41ED << 16)),
    make_entry(b"docs/readme.txt", b"inside dir", method=8)
])
add_case("LH-05", "Valid multiple-entry archive", True, "lh05_multi.zip", [
    make_entry(b"a/one.txt", b"first", method=0),
    make_entry(b"b/two.txt", b"second payload", method=8),
    make_entry(b"c/three.json", b'{"ok":true}', method=8)
])
add_case("LH-06", "Valid Data Descriptor archive", True, "lh06_dd.zip", [
    make_entry(b"stream1.txt", b"streamed content 1234567890", method=8, flag=0x0808, use_dd=True, dd_with_sig=True)
])
add_case("LH-07", "Valid Data Descriptor with 0x08074B50 signature", True, "lh07_dd_sig.zip", [
    make_entry(b"stream_sig.txt", b"dd signed payload", method=8, flag=0x0808, use_dd=True, dd_with_sig=True)
])
add_case("LH-08", "Valid Data Descriptor without signature", True, "lh08_dd_nosig.zip", [
    make_entry(b"stream_nosig.txt", b"dd unsigned payload", method=8, flag=0x0808, use_dd=True, dd_with_sig=False)
])
valid_ext_ts = struct.pack("<HHBI", 0x5455, 5, 1, 1764100000)
add_case("LH-09", "Valid archive with structured Extra Field (0x5455 Extended Timestamp)", True, "lh09_extra.zip", [
    make_entry(b"extra.txt", b"with timestamp extra field", method=8, lh_extra=valid_ext_ts, cd_extra=valid_ext_ts)
])
add_case("LH-10", "Valid standard StockFlow-style POSIX DEFLATE archive", True, "lh10_stockflow.zip", [
    make_entry(b"README.md", b"# StockFlow Sample\n", method=8, flag=0x0800),
    make_entry(b"backend/package.json", b'{"name":"stockflow-backend"}\n', method=8, flag=0x0800)
])

# NEGATIVE LH-11..LH-32
add_case("LH-11", "Local filename length shorter than Central Directory", False, "lh11_fn_shorter.zip", [
    make_entry(b"backend/app.ts", b"code", override_lh={"fn": b"back"})
])
add_case("LH-12", "Local filename length longer than Central Directory", False, "lh12_fn_longer.zip", [
    make_entry(b"app.ts", b"code", override_lh={"fn": b"app.ts_extra_bytes"})
])
add_case("LH-13", "Raw filename byte differs with identical length", False, "lh13_fn_bytediff.zip", [
    make_entry(b"source/app.ts", b"code", override_lh={"fn": b"source\\app.ts"})
])
add_case("LH-14", "Corrupt Local Header signature", False, "lh14_lh_sig.zip", [
    make_entry(b"a.txt", b"abc", override_lh={"sig": b"PK\x99\x99"})
])
add_case("LH-15", "Corrupt Central Directory signature", False, "lh15_cd_sig.zip", [
    make_entry(b"a.txt", b"abc", override_cd={"sig": b"PK\x01\x99"})
])
add_case("LH-16", "Local Header offset outside archive bounds", False, "lh16_lh_offset_oob.zip", [
    make_entry(b"a.txt", b"abc")
], override_lh_offsets={0: 999999})
add_case("LH-17", "Fixed Local Header truncated (<30 bytes before CD)", False, "lh17_lh_trunc.zip", [
    make_entry(b"a.txt", b"abcdef", method=0)
], truncate_lh=15)
add_case("LH-18", "Local Filename or Extra Field truncated past CD", False, "lh18_fn_ex_trunc.zip", [
    make_entry(b"filename.txt", b"abcdef", method=0, override_lh={"ex_len": 500})
])
add_case("LH-19", "Compression method mismatch (LH=0 STORE vs CD=8 DEFLATE)", False, "lh19_method_mismatch.zip", [
    make_entry(b"a.txt", b"payload", method=8, override_lh={"method": 0})
])
add_case("LH-20", "Required General Purpose Flag mismatch (LH UTF-8 off vs CD UTF-8 on)", False, "lh20_flag_mismatch.zip", [
    make_entry(b"a.txt", b"payload", flag=0x0800, override_lh={"flag": 0x0000})
])
add_case("LH-21", "CRC-32 mismatch on non-Data-Descriptor entry", False, "lh21_crc_mismatch.zip", [
    make_entry(b"a.txt", b"payload", override_lh={"crc": 0xDEADBEEF})
])
add_case("LH-22", "Compressed size mismatch between LH and CD", False, "lh22_csize_mismatch.zip", [
    make_entry(b"a.txt", b"payload", method=0, override_lh={"cs": 99})
])
add_case("LH-23", "Uncompressed size mismatch between LH and CD", False, "lh23_usize_mismatch.zip", [
    make_entry(b"a.txt", b"payload", override_lh={"us": 999})
])
add_case("LH-24", "Data Descriptor missing when bit 3 (0x0008) is set", False, "lh24_dd_missing.zip", [
    make_entry(b"stream.txt", b"streamed data", flag=0x0808, use_dd=True, override_dd={"omit": True})
])
add_case("LH-25", "Data Descriptor CRC-32 mismatch", False, "lh25_dd_crc.zip", [
    make_entry(b"stream.txt", b"streamed data", flag=0x0808, use_dd=True, override_dd={"crc": 0x12345678})
])
add_case("LH-26", "Data Descriptor compressed/uncompressed size mismatch", False, "lh26_dd_size.zip", [
    make_entry(b"stream.txt", b"streamed data", flag=0x0808, use_dd=True, override_dd={"us": 999})
])
bad_extra_tlv = struct.pack("<HH", 0x5455, 400) + b"\x01\x02"
add_case("LH-27", "Extra Field internal TLV length exceeds block boundary", False, "lh27_extra_oob.zip", [
    make_entry(b"a.txt", b"abc", cd_extra=bad_extra_tlv)
])
add_case("LH-28", "Invalid Local Header offset overlap across multiple entries", False, "lh28_lh_overlap.zip", [
    make_entry(b"first.txt", b"111111"),
    make_entry(b"second.txt", b"222222")
], override_lh_offsets={1: 10})
add_case("LH-29", "Truncated Central Directory", False, "lh29_cd_trunc.zip", [
    make_entry(b"a.txt", b"abc")
], truncate_cd=10)
add_case("LH-30", "Unsupported encryption flag (bit 0 = 0x0001)", False, "lh30_encrypted.zip", [
    make_entry(b"secret.txt", b"encrypted", flag=0x0801)
])
add_case("LH-31", "Unsupported compression method (method = 99)", False, "lh31_unsup_method.zip", [
    make_entry(b"weird.bin", b"data", method=99)
])
bad_z64_extra = struct.pack("<HHQ", 0x0001, 8, 12345)
add_case("LH-32", "Invalid ZIP64 sentinel / broken ZIP64 extra field", False, "lh32_bad_zip64.zip", [
    make_entry(b"big.bin", b"data", method=0, cd_extra=bad_z64_extra, override_cd={"us": 0xFFFFFFFF, "cs": 0xFFFFFFFF})
], append_zip64_broken=True)

with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as mf:
    json.dump(cases, mf, indent=2)
print(f"Generated {len(cases)} ZIP fixtures cleanly.")
'@

$logLines = [System.Collections.Generic.List[string]]::new()
function Write-LHLog([string]$msg) {
    Write-Host $msg
    $logLines.Add($msg)
}

try {
    [System.IO.File]::WriteAllText($fixtureGenPy, $pyBuilderSource, $utf8NoBom)
    $fixtureDir = Join-Path $workRoot "fixtures"
    $genOut = (& $pyInfo.Path $fixtureGenPy $fixtureDir 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate binary ZIP fixtures: $genOut"
    }

    $casesJson = Get-Content -LiteralPath (Join-Path $fixtureDir "manifest.json") -Raw | ConvertFrom-Json
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')

    Write-LHLog "================================================================================"
    Write-LHLog "STOCKFLOW v1.6.6 - LOCAL FILE HEADER & CENTRAL DIRECTORY BINARY TEST SUITE"
    Write-LHLog "================================================================================"
    Write-LHLog "Timestamp: $ts"
    Write-LHLog "Target Validator: $zipUtilsPath (Test-ZipArchiveEntries)"
    Write-LHLog "Fixture Generator Output: $genOut"
    Write-LHLog "Total Test Cases: $($casesJson.Count) (Positive: 10, Negative: 22)"
    Write-LHLog ""

    $passedTests = 0
    $failedTests = 0

    foreach ($tc in $casesJson) {
        $res = Test-ZipArchiveEntries -ZipPath $tc.zipPath
        $actualPass = [bool]$res.Valid
        $expectedPass = [bool]$tc.expectPass
        $matched = ($actualPass -eq $expectedPass)

        if ($matched) { $passedTests++ } else { $failedTests++ }
        $outcomeLabel = if ($matched) { "TEST PASS" } else { "TEST FAIL" }
        $validatorStatus = if ($actualPass) { "VALID" } else { "REJECTED ($($res.Violations -join '; '))" }

        Write-LHLog ("[{0}] {1} | Expected={2} | Actual={3} | {4}" -f $tc.id, $tc.desc, $(if ($expectedPass) { "PASS" } else { "FAIL" }), $validatorStatus, $outcomeLabel)
    }

    Write-LHLog ""
    Write-LHLog "--------------------------------------------------------------------------------"
    Write-LHLog "Summary: $passedTests / $($casesJson.Count) Test Scenarios Matched Expectation (Failures: $failedTests)"
    $overallExit = if ($failedTests -eq 0) { 0 } else { 1 }
    Write-LHLog "Exit Code: $overallExit"
    Write-LHLog "================================================================================"

    if (-not [string]::IsNullOrWhiteSpace($OutputReportPath)) {
        $dir = Split-Path -Parent $OutputReportPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllLines($OutputReportPath, $logLines, $utf8NoBom)
    }

    if ($overallExit -ne 0 -and -not $NoThrowOnFailure) {
        exit 1
    }
    exit $overallExit
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
