#requires -Version 5.1
<#
.SYNOPSIS
    Build the NetCDF-linked Free Pascal data tools.

.DESCRIPTION
    PowerShell equivalent of build-tools.sh. Builds:
      - agmerra_to_pascal_weather   (AgMERRA NetCDF4 -> Pascal weather text)
      - download_cropgrids          (CROPGRIDS cassava grid downloader)
      - build_cassava_mask          (African cassava weather-points mask builder)

    Requires: fpc, and the NetCDF C library + headers (libnetcdf).

    The NetCDF include/library directories are resolved in this order:
      1. -IncludeDir / -LibDir parameters
      2. the NETCDF_DIR environment variable (expects NETCDF_DIR\include, NETCDF_DIR\lib)
      3. `nc-config --includedir` / `nc-config --libdir` (if nc-config is on PATH)

    Install NetCDF with:
      Windows (conda):  conda install -c conda-forge netcdf-c
      Windows (vcpkg):  vcpkg install netcdf-c   (then pass -IncludeDir/-LibDir)
      macOS:            brew install netcdf
      Debian/Ubuntu:    sudo apt install libnetcdf-dev
#>
[CmdletBinding()]
param(
    [string]$IncludeDir,
    [string]$LibDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command fpc -ErrorAction SilentlyContinue)) {
    throw "fpc (Free Pascal Compiler) not found on PATH. Install it from https://www.freepascal.org/."
}

# Resolve NetCDF include/lib directories.
if (-not $IncludeDir -and $env:NETCDF_DIR) {
    $IncludeDir = Join-Path $env:NETCDF_DIR 'include'
}
if (-not $LibDir -and $env:NETCDF_DIR) {
    $LibDir = Join-Path $env:NETCDF_DIR 'lib'
}
if ((-not $IncludeDir -or -not $LibDir) -and (Get-Command nc-config -ErrorAction SilentlyContinue)) {
    if (-not $IncludeDir) { $IncludeDir = (& nc-config --includedir).Trim() }
    if (-not $LibDir)     { $LibDir     = (& nc-config --libdir).Trim() }
}

if (-not $IncludeDir -or -not $LibDir) {
    throw @"
Could not locate NetCDF headers/libraries.
Pass them explicitly, e.g.:
  .\tools\build-tools.ps1 -IncludeDir C:\path\to\netcdf\include -LibDir C:\path\to\netcdf\lib
or set the NETCDF_DIR environment variable, or install nc-config on PATH.
"@
}

if (-not (Test-Path $IncludeDir)) { throw "NetCDF include dir not found: $IncludeDir" }
if (-not (Test-Path $LibDir))     { throw "NetCDF library dir not found: $LibDir" }

Write-Host "Using NetCDF headers: $IncludeDir"
Write-Host "Using NetCDF library: $LibDir"
Write-Host ""

Push-Location $PSScriptRoot
try {
    foreach ($tool in 'agmerra_to_pascal_weather', 'download_cropgrids', 'build_cassava_mask') {
        Write-Host "Building $tool ..."
        & fpc -Mdelphi "-Fi$IncludeDir" "-Fl$LibDir" "-k-L$LibDir" '-k-lnetcdf' "$tool.pas"
        if ($LASTEXITCODE -ne 0) {
            throw "fpc failed building $tool (exit code $LASTEXITCODE)."
        }
        Write-Host "  -> tools/$tool"
    }
    Write-Host ""
    Write-Host "Done. Tools built in: $PSScriptRoot"
}
finally {
    Pop-Location
}
