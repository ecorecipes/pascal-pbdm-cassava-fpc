#requires -Version 5.1
<#
.SYNOPSIS
    Render PORTING_NOTES.md to HTML, Word (.docx), and PDF with pandoc.

.DESCRIPTION
    PowerShell equivalent of render-notes.sh. The outputs are git-ignored;
    regenerate them on demand with:  .\render-notes.ps1

    Requirements:
      - pandoc            (winget install JohnMacFarlane.Pandoc / choco install pandoc)
      - xelatex           (for the PDF; from MiKTeX or TeX Live)
      - Fonts: a Unicode serif body font and a monospace font (defaults below).

.PARAMETER MainFont
    Body font for the PDF. Default: "STIX Two Text".

.PARAMETER MonoFont
    Monospace font for the PDF and for the symbol fallback. Default: "Consolas"
    on Windows, "Menlo" elsewhere.
#>
[CmdletBinding()]
param(
    [string]$MainFont = 'STIX Two Text',
    [string]$MonoFont
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$onWindows = ($env:OS -eq 'Windows_NT')
if (-not $MonoFont) {
    $MonoFont = if ($onWindows) { 'Consolas' } else { 'Menlo' }
}

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    throw "pandoc not found on PATH. Install it from https://pandoc.org/installing.html."
}

Set-Location $PSScriptRoot
$src   = 'PORTING_NOTES.md'
$title = 'Free Pascal porting notes'

Write-Host "Rendering $src ..."

& pandoc $src -s --toc --metadata "title=$title" -o PORTING_NOTES.html
if ($LASTEXITCODE -ne 0) { throw "pandoc failed rendering HTML." }
Write-Host "  -> PORTING_NOTES.html"

& pandoc $src -s --toc --metadata "title=$title" -o PORTING_NOTES.docx
if ($LASTEXITCODE -ne 0) { throw "pandoc failed rendering DOCX." }
Write-Host "  -> PORTING_NOTES.docx"

if (Get-Command xelatex -ErrorAction SilentlyContinue) {
    # Glyphs that the body font may lack -> fall back to the monospace font (PDF only).
    $header = New-TemporaryFile
    try {
        $headerTex = @"
\usepackage{newunicodechar}
\newfontfamily{\symfallback}{$MonoFont}
\newunicodechar{$([char]0x2192)}{{\symfallback $([char]0x2192)}}
\newunicodechar{$([char]0x2264)}{{\symfallback $([char]0x2264)}}
\newunicodechar{$([char]0x2265)}{{\symfallback $([char]0x2265)}}
\newunicodechar{$([char]0x2713)}{{\symfallback $([char]0x2713)}}
"@
        Set-Content -Path $header.FullName -Value $headerTex -Encoding UTF8

        & pandoc $src -s --toc --metadata "title=$title" `
            --pdf-engine=xelatex `
            -V geometry:margin=1in -V colorlinks=true `
            -V mainfont="$MainFont" -V monofont="$MonoFont" -V monofontoptions="Scale=0.85" `
            -H $header.FullName `
            -o PORTING_NOTES.pdf
        if ($LASTEXITCODE -ne 0) { throw "pandoc failed rendering PDF." }
        Write-Host "  -> PORTING_NOTES.pdf"
    }
    finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $header.FullName
    }
}
else {
    Write-Warning "xelatex not found; skipped PORTING_NOTES.pdf"
}

Write-Host "Done."
