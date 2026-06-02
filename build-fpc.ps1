#requires -Version 5.1
<#
.SYNOPSIS
    Build the cassava PBDM port with Free Pascal (native target).

.DESCRIPTION
    PowerShell equivalent of build-fpc.sh for Windows users (and pwsh on any OS).
    Compiles cassava/cassava.pas in Delphi-compatibility mode. The resulting
    executable (cassava.exe on Windows, cassava elsewhere) is written next to
    the sources in the cassava/ directory.

    Requires: fpc (Free Pascal Compiler) on PATH.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command fpc -ErrorAction SilentlyContinue)) {
    throw "fpc (Free Pascal Compiler) not found on PATH. Install it from https://www.freepascal.org/."
}

$srcDir = Join-Path $PSScriptRoot 'cassava'
Push-Location $srcDir
try {
    & fpc -Mdelphi cassava.pas
    if ($LASTEXITCODE -ne 0) {
        throw "fpc failed with exit code $LASTEXITCODE."
    }
    Write-Host ""
    Write-Host "Built cassava in: $srcDir"
    Write-Host "Run e.g.:"
    Write-Host "  cd `"$srcDir`"; .\cassava.exe Cassava.det.ini 01 01 1980 12 31 1985 365 wx.det.txt"
}
finally {
    Pop-Location
}
