$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "zip-utils.ps1")

$staging = "temp_remediated_staging"
$outputZip = "audit\StockFlow_Remediated_v2.zip"

if (Test-Path $staging) {
    Remove-Item -Recurse -Force $staging
}
if (Test-Path $outputZip) {
    Remove-Item -Force $outputZip
}

New-Item -ItemType Directory -Path $staging | Out-Null
New-Item -ItemType Directory -Path "$staging\backend" | Out-Null
New-Item -ItemType Directory -Path "$staging\frontend" | Out-Null
New-Item -ItemType Directory -Path "$staging\docs" | Out-Null

Write-Host "Copying root files..."
Copy-Item "docker-compose.yml" "$staging\"
Copy-Item ".env.example" "$staging\"
Copy-Item "README.md" "$staging\"
if (Test-Path "package.json") { Copy-Item "package.json" "$staging\" }
if (Test-Path "package-lock.json") { Copy-Item "package-lock.json" "$staging\" }

Write-Host "Copying docs..."
Copy-Item -Recurse "docs\*" "$staging\docs\"

Write-Host "Copying backend files..."
Get-ChildItem -Path "backend" -Exclude "node_modules", "dist", ".env", ".env.*" | ForEach-Object {
    Copy-Item -Recurse $_.FullName "$staging\backend\"
}

Write-Host "Copying frontend files..."
Get-ChildItem -Path "frontend" -Exclude "node_modules", ".next", ".env", ".env.*", "tsconfig.tsbuildinfo", "test-results" | ForEach-Object {
    Copy-Item -Recurse $_.FullName "$staging\frontend\"
}

Write-Host "Verifying no forbidden items in staging..."
$forbidden = Get-ChildItem -Recurse -Path $staging -Include "node_modules", ".next", ".git", ".env"
if ($forbidden.Count -gt 0) {
    Write-Error "Forbidden items found: $($forbidden.FullName -join ', ')"
    exit 1
}

Write-Host "Compressing to $outputZip with POSIX '/' paths..."
New-PortableZipArchive -SourceDirectory (Resolve-Path $staging).Path -DestinationZipPath (Join-Path (Resolve-Path "audit").Path "StockFlow_Remediated_v2.zip") | Out-Null

Remove-Item -Recurse -Force $staging

$zipItem = Get-Item $outputZip
Write-Host "Success! Created $outputZip (Size: $([math]::Round($zipItem.Length / 1MB, 2)) MB)"
