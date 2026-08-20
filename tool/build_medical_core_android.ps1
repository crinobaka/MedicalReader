$ErrorActionPreference = "Stop"

# MedicalReader 根目录
$projectRoot = Split-Path -Parent $PSScriptRoot

# Rust native engine
$rustProject = Join-Path $projectRoot "core\medical_core"

# Flutter Android native libraries 目录。
# cargo-ndk 会按照 ABI 自动生成：
# android/app/src/main/jniLibs/arm64-v8a/libmedical_core.so
$outputDir = Join-Path $projectRoot "android\app\src\main\jniLibs"

Write-Host ""
Write-Host "=== MedicalCore Android Build ===" -ForegroundColor Cyan
Write-Host "Rust project : $rustProject"
Write-Host "Output       : $outputDir"
Write-Host ""

# Android 真机目前以 arm64-v8a 为目标。
$rustTarget = "aarch64-linux-android"
$androidAbi = "arm64-v8a"

# 检查 Rust target。
$installedTargets = rustup target list --installed

if ($installedTargets -notcontains $rustTarget) {
    Write-Host "Installing Rust target: $rustTarget" -ForegroundColor Yellow
    rustup target add $rustTarget
}

# 检查 cargo-ndk。
$cargoNdk = Get-Command cargo-ndk -ErrorAction SilentlyContinue

if ($null -eq $cargoNdk) {
    Write-Host "cargo-ndk is not installed." -ForegroundColor Yellow
    Write-Host "Installing cargo-ndk..." -ForegroundColor Yellow

    cargo install cargo-ndk

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install cargo-ndk."
    }
}

# 创建 APK native library 输出目录。
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# 只构建 arm64-v8a。
#
# 不构建 x86/x86_64，避免开发阶段额外占用磁盘空间。
# 以后需要 Android Emulator 时再增加 ABI。
Push-Location $rustProject

try {
    cargo ndk `
        -t $androidAbi `
        -o $outputDir `
        build --release

    if ($LASTEXITCODE -ne 0) {
        throw "MedicalCore Android build failed."
    }
}
finally {
    Pop-Location
}

$nativeLibrary = Join-Path `
    $outputDir `
    "$androidAbi\libmedical_core.so"

if (-not (Test-Path $nativeLibrary)) {
    throw "Build finished but libmedical_core.so was not generated: $nativeLibrary"
}

Write-Host ""
Write-Host "MedicalCore Android library built successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Native library:" -ForegroundColor Cyan
Write-Host $nativeLibrary
Write-Host ""