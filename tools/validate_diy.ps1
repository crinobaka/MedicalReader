param(
    [string]$ThemeFile = "assets/ui/reader_theme.json",
    [string]$TemplateDirectory = "assets/book_templates"
)

$ErrorActionPreference = 'Stop'

function Assert-Property($Object, [string]$Name) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        throw "Missing required field: $Name"
    }
}

if (-not (Test-Path $ThemeFile)) { throw "Theme file not found: $ThemeFile" }
$theme = Get-Content $ThemeFile -Raw -Encoding UTF8 | ConvertFrom-Json

Assert-Property $theme 'version'
Assert-Property $theme 'preset'
Assert-Property $theme 'chrome'
Assert-Property $theme 'layout'

if (@('google','apple','github','custom') -notcontains $theme.preset) {
    throw "Unsupported preset '$($theme.preset)'. Use google, apple, github or custom."
}

foreach ($section in @('topBar','bottomBar','leftPanel','rightPanel')) {
    if ($null -eq $theme.layout.PSObject.Properties[$section]) { throw "Missing layout section: $section" }
    foreach ($flag in @('visible','collapsed','overlay','persistent')) {
        if ($null -eq $theme.layout.$section.PSObject.Properties[$flag]) {
            throw "Missing layout flag: $section.$flag"
        }
        if ($theme.layout.$section.$flag -isnot [bool]) {
            throw "Layout flag must be boolean: $section.$flag"
        }
    }
}

foreach ($field in @('surface','foreground','accent','muted','border')) {
    if ($null -eq $theme.chrome.PSObject.Properties[$field]) { throw "Missing chrome color: $field" }
    if ($theme.chrome.$field -notmatch '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$') {
        throw "Invalid color in chrome.$field: $($theme.chrome.$field)"
    }
}

if (-not (Test-Path $TemplateDirectory)) { throw "Template directory not found: $TemplateDirectory" }
foreach ($file in Get-ChildItem $TemplateDirectory -Filter '*.json') {
    if ($file.Name -eq 'README.md') { continue }
    try {
        $template = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Property $template 'version'
        Assert-Property $template 'id'
        Assert-Property $template 'name'
    } catch {
        throw "Invalid template '$($file.FullName)': $($_.Exception.Message)"
    }
}

Write-Host "DIY validation passed: theme + book templates are valid."
