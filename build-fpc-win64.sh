#!/usr/bin/env bash
# Build the cassava port as a 64-bit x86_64-win64 (SSE2 scalar-double) binary under
# wine. This is a DIAGNOSTIC target: it runs on the same machine as the native arm64
# build but uses the SSE2 IEEE-754 64-bit-double backend instead of x87. It is
# bit-identical to the arm64 build and diverges from the i386 x87 / Delphi builds,
# which proves the x87-vs-64-bit-double intermediate precision (not CPU architecture)
# governs the divergence. See PORTING_NOTES.md "DECISIVE: x86_64-win64 FPC (SSE2) is
# bit-identical to arm64 (NEON)".
#
# Prereqs (one-time):
#   - win64 wine prefix at $WINEPREFIX with FPC 3.2.2 i386-win32 installed at C:\FPC
#   - the x86_64-win64 cross package installed on top:
#       fpc-3.2.2.i386-win32.cross.x86_64-win64.exe  (SourceForge Win32/3.2.2/)
#       wine fpc-cross-x64.exe /VERYSILENT /SUPPRESSMSGBOXES /DIR="C:\FPC"
#     This adds C:\FPC\bin\i386-win32\ppcrossx64.exe and the x86_64-win64 RTL.
set -euo pipefail

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-delphi3}"
export WINEDEBUG="${WINEDEBUG:--all}"
export MVK_CONFIG_LOG_LEVEL="${MVK_CONFIG_LOG_LEVEL:-0}"

SRC="$(cd "$(dirname "$0")/cassava" && pwd)"
DST="${WIN64_BUILD_DIR:-$WINEPREFIX/drive_c/cas64}"
PPCROSSX64='C:\FPC\bin\i386-win32\ppcrossx64.exe'

mkdir -p "$DST"
# sync sources (preserve any inputs already staged in $DST, e.g. Cassava.ini, wx)
cp "$SRC"/*.pas "$SRC"/*.PAS "$DST"/ 2>/dev/null || true

cd "$DST"
rm -f ./*.o ./*.ppu cassava.exe
wine "$PPCROSSX64" -Mdelphi -Twin64 cassava.pas

echo
echo "Built x86_64-win64 cassava.exe in: $DST"
echo "Run e.g.:"
echo "  cd '$DST' && wine cassava.exe Cassava.det.ini 01 01 1980 12 31 1985 365 wxcrlf.txt"
