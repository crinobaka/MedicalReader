$ErrorActionPreference = "Stop"

# ============================================================
# MedicalReader - MedicalCore Android Native Build
#
# IMPORTANT:
# - NDK version is FIXED to 23.1.7779620
# - DO NOT use cargo-ndk
# - Use cargo build only
# - Windows build is completely unaffected
# ============================================================


# ------------------------------------------------------------
# Project paths
# ------------------------------------------------------------

$projectRoot = Split-Path -Parent $PSScriptRoot

$rustProject = Join-Path `
    $projectRoot `
    "core\medical_core"

$outputDir = Join-Path `
    $projectRoot `
    "android\app\src\main\jniLibs"


# ------------------------------------------------------------
# Fixed Android NDK
# ------------------------------------------------------------

$ndk = "D:\Android\Sdk\ndk\23.1.7779620"

$toolchain = Join-Path `
    $ndk `
    "toolchains\llvm\prebuilt\windows-x86_64"

$ndkBin = Join-Path `
    $toolchain `
    "bin"

$sysroot = Join-Path `
    $toolchain `
    "sysroot"


Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " MedicalCore Android Build" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

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


$clang = Join-Path `
    $ndkBin `
    "clang.exe"

$clangxx = Join-Path `
    $ndkBin `
    "clang++.exe"

$llvmAr = Join-Path `
    $ndkBin `
    "llvm-ar.exe"

$androidLinker = Join-Path `
    $ndkBin `
    "aarch64-linux-android21-clang.cmd"


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
# Check patchelf
#
# We MUST replace:
#
#     libstdc++.so
#
# with:
#
#     libc++_shared.so
#
# Removing libstdc++.so is NOT sufficient because the native
# library still contains references to:
#
#     __gxx_personality_v0
#
# libc++_shared.so from the Android NDK provides that symbol.
# ------------------------------------------------------------

$patchelf = Get-Command patchelf.exe -ErrorAction SilentlyContinue

if ($null -eq $patchelf) {

    throw @"
patchelf.exe was not found.

This Android build requires patchelf because the generated
libmedical_core.so currently declares:

    NEEDED libstdc++.so

We must replace it with:

    NEEDED libc++_shared.so

Install patchelf in Git Bash/MSYS2, then run this script again.

For MSYS2:

    pacman -S patchelf

Do NOT change the Android NDK version.
Do NOT use cargo ndk.
"@
}


# ------------------------------------------------------------
# Rust target
# ------------------------------------------------------------

$rustTarget = "aarch64-linux-android"

$installedTargets = rustup target list --installed

if ($installedTargets -notcontains $rustTarget) {

    Write-Host ""
    Write-Host "Installing Rust target: $rustTarget" -ForegroundColor Yellow

    rustup target add $rustTarget

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Rust target: $rustTarget"
    }
}


# ------------------------------------------------------------
# GNU make
#
# mupdf-sys 0.8.0 invokes make internally.
# ------------------------------------------------------------

$make = Get-Command make.exe -ErrorAction SilentlyContinue

if ($null -eq $make) {

    throw @"
GNU make was not found.

mupdf-sys 0.8.0 requires make.

Please make sure Git Bash/MSYS make is available in PATH.

Current PATH:

$env:PATH
"@
}


# ------------------------------------------------------------
# Android C toolchain
#
# IMPORTANT:
#
# Do NOT pass a Windows absolute path as CC to mupdf-sys.
#
# mupdf-sys invokes make through /bin/sh.
#
# Therefore clang / clang++ / llvm-ar are exposed through PATH.
# ------------------------------------------------------------

$env:PATH = "$ndkBin;$env:PATH"

$env:CC_aarch64_linux_android = "clang"
$env:CXX_aarch64_linux_android = "clang++"
$env:AR_aarch64_linux_android = "llvm-ar"

${env:CC_aarch64-linux-android} = "clang"
${env:CXX_aarch64-linux-android} = "clang++"
${env:AR_aarch64-linux-android} = "llvm-ar"


# ------------------------------------------------------------
# Android API level
# ------------------------------------------------------------

${env:CFLAGS_aarch64-linux-android} = `
    "--target=aarch64-linux-android21 -stdlib=libc++"

${env:CXXFLAGS_aarch64-linux-android} = `
    "--target=aarch64-linux-android21 -stdlib=libc++"


# ------------------------------------------------------------
# Bindgen
#
# Git Bash/MSYS paths are used here intentionally.
# ------------------------------------------------------------

$sysrootUnix = $sysroot.Replace('\', '/')

$env:BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android = @(
    "--sysroot=$sysrootUnix"
    "-I$sysrootUnix/usr/include/aarch64-linux-android"
) -join " "


# ------------------------------------------------------------
# Cross compilation
# ------------------------------------------------------------

$env:PKG_CONFIG_ALLOW_CROSS = "1"


# ------------------------------------------------------------
# Output directory
# ------------------------------------------------------------

$abi = "arm64-v8a"

$abiOutputDir = Join-Path `
    $outputDir `
    $abi

New-Item `
    -ItemType Directory `
    -Force `
    -Path $abiOutputDir `
    | Out-Null


# ------------------------------------------------------------
# Build MedicalCore
#
# ABSOLUTELY NO cargo ndk.
#
# The Android Rust linker is supplied by .cargo/config.toml.
# ------------------------------------------------------------

Push-Location $rustProject

try {

    # Prevent shell environment from overriding .cargo/config.toml.

    Remove-Item `
        Env:RUSTFLAGS `
        -ErrorAction SilentlyContinue

    Remove-Item `
        Env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER `
        -ErrorAction SilentlyContinue


    Write-Host ""
    Write-Host "Cleaning Rust build..." -ForegroundColor Yellow

    cargo clean

    if ($LASTEXITCODE -ne 0) {
        throw "cargo clean failed."
    }


    Write-Host ""
    Write-Host "Building MedicalCore for Android..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Command:"
    Write-Host "cargo build --target aarch64-linux-android --release"
    Write-Host ""


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
# Locate generated native library
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
# FIX native C++ runtime dependency
#
# BEFORE:
#
#     NEEDED libstdc++.so
#
# AFTER:
#
#     NEEDED libc++_shared.so
#
# This is the critical fix for:
#
#     __gxx_personality_v0
#
# because Android NDK's libc++_shared.so exports:
#
#     __gxx_personality_v0
#
# ------------------------------------------------------------

Write-Host ""
Write-Host "Fixing native C++ runtime dependency..." -ForegroundColor Yellow

Write-Host ""
Write-Host "Replacing:" -ForegroundColor Cyan
Write-Host "    libstdc++.so"

Write-Host ""
Write-Host "With:" -ForegroundColor Cyan
Write-Host "    libc++_shared.so"
Write-Host ""


& $patchelf.Source `
    --replace-needed `
    "libstdc++.so" `
    "libc++_shared.so" `
    $nativeLibrary


if ($LASTEXITCODE -ne 0) {

    throw @"
Failed to replace libstdc++.so with libc++_shared.so.

Native library:

$nativeLibrary
"@
}


# ------------------------------------------------------------
# Copy MedicalCore native library
# ------------------------------------------------------------

$finalLibrary = Join-Path `
    $abiOutputDir `
    "libmedical_core.so"


Copy-Item `
    -Force `
    $nativeLibrary `
    $finalLibrary


if (-not (Test-Path $finalLibrary)) {

    throw "Failed to copy Android native library: $finalLibrary"
}


# ------------------------------------------------------------
# Copy libc++_shared.so
#
# IMPORTANT:
# It comes from the SAME NDK used above.
#
# NDK version remains:
#
#     23.1.7779620
# ------------------------------------------------------------

$libcxxShared = Join-Path `
    $sysroot `
    "usr\lib\aarch64-linux-android\libc++_shared.so"


if (-not (Test-Path $libcxxShared)) {

    throw @"
Android libc++_shared.so was not found:

$libcxxShared
"@
}


$finalLibcxx = Join-Path `
    $abiOutputDir `
    "libc++_shared.so"


Copy-Item `
    -Force `
    $libcxxShared `
    $finalLibcxx


if (-not (Test-Path $finalLibcxx)) {

    throw "Failed to copy libc++_shared.so: $finalLibcxx"
}


# ------------------------------------------------------------
# Final result
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " MedicalCore Android build succeeded." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "MedicalCore:" -ForegroundColor Cyan
Write-Host $finalLibrary

Write-Host ""
Write-Host "C++ runtime:" -ForegroundColor Cyan
Write-Host $finalLibcxx

Write-Host ""
Write-Host "Android ABI:" -ForegroundColor Cyan
Write-Host $abi

Write-Host ""
Write-Host "NDK:" -ForegroundColor Cyan
Write-Host $ndk

Write-Host ""