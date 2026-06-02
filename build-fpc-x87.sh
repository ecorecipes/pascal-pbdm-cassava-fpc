#!/usr/bin/env bash
# Build the cassava port as a 32-bit x87 (i386-win32) binary under wine, so its
# floating-point arithmetic matches Delphi 3's 80-bit extended x87 model. Used
# only for bit-level comparison against the legacy Delphi golden master; the
# native arm64 build (build-fpc.sh) is the modernization target.
#
# Prereqs (one-time):
#   - wine prefix at $WINEPREFIX with FPC 3.2.2 i386-win32 installed at C:\FPC
#   - the cassava sources copied/synced into the build dir below
# See PORTING_NOTES.md "Arithmetic matching" for details.
set -euo pipefail

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-delphi3}"
export WINEDEBUG="${WINEDEBUG:--all}"
export MVK_CONFIG_LOG_LEVEL="${MVK_CONFIG_LOG_LEVEL:-0}"

SRC="$(cd "$(dirname "$0")/cassava" && pwd)"
DST="${X87_BUILD_DIR:-$WINEPREFIX/drive_c/casx87}"
FPC_I386='C:\FPC\bin\i386-win32\fpc.exe'

mkdir -p "$DST"
# sync sources (preserve any inputs already staged in $DST, e.g. Cassava.ini, wx)
cp "$SRC"/*.pas "$SRC"/*.PAS "$DST"/ 2>/dev/null || true

cd "$DST"
rm -f ./*.o ./*.ppu cassava.exe
wine "$FPC_I386" -Mdelphi cassava.pas

echo
echo "Built x87 cassava.exe in: $DST"
echo "Run e.g.:"
echo "  cd '$DST' && wine cassava.exe Cassava.ini 01 01 1980 12 31 1985 365 wxcrlf.txt"
