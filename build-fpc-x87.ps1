#requires -Version 5.1
<#
.SYNOPSIS
    Build the cassava port as a 32-bit i386 (x87) binary with Free Pascal.

.DESCRIPTION
    On Windows this produces an i386-win32 executable NATIVELY (no wine needed):
    the 32-bit FPC backend uses the 80-bit extended x87 FPU, so its floating-point
    arithmetic matches the legacy Delphi 3 golden master. Use it only for bit-level
    comparison against Delphi; the native build (build-fpc.ps1) is the
    modernization target.

    Requires the i386-win32 FPC compiler (ppc386.exe) to be installed. A default
    64-bit FPC install does not include it; add it via the FPC installer
    ("Cross-compiling" -> i386-win32) or install the 32-bit FPC distribution.

    See PORTING_NOTES.md "Arithmetic: x87 vs IEEE-754 64-bit" for details.
#>
[CmdletBinding()]
param(
    # Directory to build in. Defaults to a sibling build dir so the native build
    # artifacts in cassava/ are not clobbered.
    [string]$BuildDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command fpc -ErrorAction SilentlyContinue)) {
    throw "fpc (Free Pascal Compiler) not found on PATH. Install it from https://www.freepascal.org/."
}

$srcDir = Join-Path $PSScriptRoot 'cassava'
if (-not $BuildDir) {
    $BuildDir = Join-Path $PSScriptRoot 'build-x87'
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# Sync sources (preserve any inputs already staged in $BuildDir, e.g. Cassava.ini, wx).
Copy-Item (Join-Path $srcDir '*.pas') -Destination $BuildDir -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $srcDir '*.PAS') -Destination $BuildDir -Force -ErrorAction SilentlyContinue

Push-Location $BuildDir
try {
    Remove-Item -Force -ErrorAction SilentlyContinue *.o, *.ppu, cassava.exe

    # -Pi386 selects the 32-bit (x87) code generator; -Twin32 targets Windows 32-bit.
    & fpc -Mdelphi -Pi386 -Twin32 cassava.pas
    if ($LASTEXITCODE -ne 0) {
        throw "fpc (i386-win32) failed with exit code $LASTEXITCODE. Is the i386-win32 compiler (ppc386.exe) installed?"
    }

    Write-Host ""
    Write-Host "Built x87 cassava.exe in: $BuildDir"
    Write-Host "Run e.g.:"
    Write-Host "  cd `"$BuildDir`"; .\cassava.exe Cassava.ini 01 01 1980 12 31 1985 365 wxcrlf.txt"
}
finally {
    Pop-Location
}
