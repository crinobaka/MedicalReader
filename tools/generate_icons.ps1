$ErrorActionPreference = 'Stop'

Write-Host 'Generating MedicalReader launcher icons from assets/branding/favicon.ico ...'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'flutter_launcher_icons failed.' }

Write-Host 'Launcher icons generated successfully.'
Write-Host 'Source: assets/branding/favicon.ico'
