[CmdletBinding()]
param(
    [switch]$SkipAnalyze,
    [switch]$SkipTest,
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "`n== $Name ==" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

if (-not $SkipPubGet) {
    Invoke-Step 'Flutter pub get' { flutter pub get }
}

if (-not $SkipAnalyze) {
    Invoke-Step 'Flutter analyze' { flutter analyze }
}

if (-not $SkipTest) {
    Invoke-Step 'Flutter test' { flutter test }
}

Write-Host "`nRelease sanity checks" -ForegroundColor Cyan
$required = @(
    'assets/branding/favicon.ico',
    'tools/directory_generator.ps1',
    'tools/reader_template_generator.ps1',
    'lib/features/reader/controllers/reader_interaction_controller.dart',
    'lib/features/reader/controllers/reader_layout_controller.dart',
    'lib/features/search/controllers/search_page_controller.dart'
)

$missing = @($required | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
    throw "Required project files are missing: $($missing -join ', ')"
}

Write-Host 'All requested release checks passed.' -ForegroundColor Green
