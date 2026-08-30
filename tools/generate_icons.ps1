$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'assets/branding/favicon.ico'

if (-not (Test-Path $source)) {
    throw "Icon source not found: $source"
}

Write-Host 'Generating MedicalReader launcher icons...'
Write-Host "Source: $source"

Push-Location $root
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

    dart run flutter_launcher_icons
    if ($LASTEXITCODE -ne 0) { throw 'flutter_launcher_icons failed.' }

    Write-Host 'Launcher icons generated successfully for Android and Windows.'
} finally {
    Pop-Location
}
