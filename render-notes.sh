#!/usr/bin/env bash
# Render PORTING_NOTES.md to HTML, Word (.docx), and PDF with pandoc.
# The outputs are git-ignored; regenerate them on demand with:  ./render-notes.sh
#
# Requirements:
#   - pandoc            (brew install pandoc)
#   - xelatex           (for the PDF; from MacTeX/TeX Live)
#   - Fonts: "STIX Two Text" + "Menlo" (both ship with macOS)
set -euo pipefail

cd "$(dirname "$0")"

SRC="PORTING_NOTES.md"
TITLE="Free Pascal porting notes"

command -v pandoc >/dev/null 2>&1 || { echo "error: pandoc not found on PATH" >&2; exit 1; }

# Glyphs that STIX Two Text lacks in body text -> fall back to Menlo (PDF only).
HEADER="$(mktemp -t pn-header.XXXXXX.tex)"
trap 'rm -f "$HEADER"' EXIT
cat > "$HEADER" <<'TEX'
\usepackage{newunicodechar}
\newfontfamily{\symfallback}{Menlo}
\newunicodechar{→}{{\symfallback →}}
\newunicodechar{≤}{{\symfallback ≤}}
\newunicodechar{≥}{{\symfallback ≥}}
\newunicodechar{✓}{{\symfallback ✓}}
TEX

echo "Rendering $SRC ..."

pandoc "$SRC" -s --toc --metadata title="$TITLE" -o PORTING_NOTES.html
echo "  -> PORTING_NOTES.html"

pandoc "$SRC" -s --toc --metadata title="$TITLE" -o PORTING_NOTES.docx
echo "  -> PORTING_NOTES.docx"

if command -v xelatex >/dev/null 2>&1; then
  pandoc "$SRC" -s --toc --metadata title="$TITLE" \
    --pdf-engine=xelatex \
    -V geometry:margin=1in -V colorlinks=true \
    -V mainfont="STIX Two Text" -V monofont="Menlo" -V monofontoptions="Scale=0.85" \
    -H "$HEADER" \
    -o PORTING_NOTES.pdf
  echo "  -> PORTING_NOTES.pdf"
else
  echo "  !! xelatex not found; skipped PORTING_NOTES.pdf" >&2
fi

echo "Done."
