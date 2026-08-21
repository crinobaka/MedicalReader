$ErrorActionPreference = "Stop"

# MedicalReader 根目录
$projectRoot = Split-Path -Parent $PSScriptRoot

# Rust native engine
$rustProject = Join-Path $projectRoot "core\medical_core"

# Android native library 输出目录
$outputDir = Join-Path $projectRoot "android\app\src\main\jniLibs"

# 固定 Android NDK
$ndk = "D:\Android\Sdk\ndk\23.1.7779620"
$toolchain = Join-Path $ndk "toolchains\llvm\prebuilt\windows-x86_64"
$ndkBin = Join-Path $toolchain "bin"
$sysroot = Join-Path $toolchain "sysroot"

Write-Host ""
Write-Host "=== MedicalCore Android Build ===" -ForegroundColor Cyan
Write-Host "Rust project : $rustProject"
Write-Host "Output       : $outputDir"
Write-Host "NDK          : $ndk"
Write-Host ""

# ------------------------------------------------------------
# Check NDK
# ------------------------------------------------------------

if (-not (Test-Path $ndk)) {
    throw "Android NDK not found: $ndk"
}

$clang = Join-Path $ndkBin "clang.exe"
$clangxx = Join-Path $ndkBin "clang++.exe"
$llvmAr = Join-Path $ndkBin "llvm-ar.exe"
$androidLinker = Join-Path $ndkBin "aarch64-linux-android21-clang.cmd"

foreach ($tool in @(
    $clang,
    $clangxx,
    $llvmAr,
    $androidLinker
)) {
    if (-not (Test-Path $tool)) {
        throw "Required Android tool not found: $tool"
    }
}

# ------------------------------------------------------------
# Rust target
# ------------------------------------------------------------

$rustTarget = "aarch64-linux-android"

$installedTargets = rustup target list --installed

if ($installedTargets -notcontains $rustTarget) {
    Write-Host "Installing Rust target: $rustTarget" -ForegroundColor Yellow
    rustup target add $rustTarget

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Rust target: $rustTarget"
    }
}

# ------------------------------------------------------------
# Make sure Git/MSYS make is available.
#
# mupdf-sys 0.8.0 uses make internally.
# We intentionally expose clang through PATH as "clang",
# instead of giving make a Windows absolute CC path.
# ------------------------------------------------------------

$make = Get-Command make.exe -ErrorAction SilentlyContinue

if ($null -eq $make) {
    throw @"
GNU make was not found.

Please make sure Git Bash / MSYS make is installed and available
to the process PATH.

Current PATH:
$env:PATH
"@
}

# ------------------------------------------------------------
# Android C toolchain
#
# IMPORTANT:
# Do NOT set CC to D:\...\clang here.
#
# mupdf-sys invokes make through /bin/sh.
# "clang" must be resolved through PATH so MSYS does not
# destroy the Windows path.
# ------------------------------------------------------------

$env:PATH = "$ndkBin;$env:PATH"

$env:CC_aarch64_linux_android = "clang"
$env:CXX_aarch64_linux_android = "clang++"
$env:AR_aarch64_linux_android = "llvm-ar"

$env:CC_aarch64_linux_android = "clang"
$env:CXX_aarch64_linux_android = "clang++"
$env:AR_aarch64_linux_android = "llvm-ar"

# Cargo/cc also recognizes the hyphenated form.
${env:CC_aarch64-linux-android} = "clang"
${env:CXX_aarch64-linux-android} = "clang++"
${env:AR_aarch64-linux-android} = "llvm-ar"

# Android API level.
${env:CFLAGS_aarch64-linux-android} = "--target=aarch64-linux-android21"
${env:CXXFLAGS_aarch64-linux-android} = "--target=aarch64-linux-android21"

# Bindgen needs the real sysroot.
$env:BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android = @(
    "--sysroot=$($sysroot.Replace('\','/'))"
    "-I$($sysroot.Replace('\','/'))/usr/include/aarch64-linux-android"
) -join " "

$env:PKG_CONFIG_ALLOW_CROSS = "1"

# ------------------------------------------------------------
# Output directory
# ------------------------------------------------------------

$abi = "arm64-v8a"
$abiOutputDir = Join-Path $outputDir $abi

New-Item -ItemType Directory -Force -Path $abiOutputDir | Out-Null

# ------------------------------------------------------------
# Build
#
# DO NOT use cargo ndk here.
#
# .cargo/config.toml supplies the Android Rust linker.
# ------------------------------------------------------------

Push-Location $rustProject

try {
    cargo clean

    if ($LASTEXITCODE -ne 0) {
        throw "cargo clean failed."
    }

    cargo build `
        --target $rustTarget `
        --release `
        -vv

    if ($LASTEXITCODE -ne 0) {
        throw "MedicalCore Android Rust build failed."
    }
}
finally {
    Pop-Location
}

# ------------------------------------------------------------
# Locate generated library
# ------------------------------------------------------------

$nativeLibrary = Join-Path `
    $rustProject `
    "target\$rustTarget\release\libmedical_core.so"

if (-not (Test-Path $nativeLibrary)) {
    throw @"
Rust build succeeded but libmedical_core.so was not found:

$nativeLibrary
"@
}

# ------------------------------------------------------------
# Copy into Flutter Android jniLibs
# ------------------------------------------------------------

Copy-Item `
    -Force `
    $nativeLibrary `
    (Join-Path $abiOutputDir "libmedical_core.so")

$finalLibrary = Join-Path `
    $abiOutputDir `
    "libmedical_core.so"

if (-not (Test-Path $finalLibrary)) {
    throw "Failed to copy Android native library: $finalLibrary"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "MedicalCore Android build succeeded." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Native library:" -ForegroundColor Cyan
Write-Host $finalLibrary
Write-Host ""