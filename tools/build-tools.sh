#!/usr/bin/env bash
# Build the NetCDF-linked Free Pascal data tools:
#   - agmerra_to_pascal_weather   (AgMERRA NetCDF4 -> Pascal weather text)
#   - download_cropgrids          (CROPGRIDS cassava grid downloader)
#   - build_cassava_mask          (African cassava weather-points mask builder)
#
# Requires: fpc, and the NetCDF C library + headers (libnetcdf). The build flags
# are discovered portably via `nc-config`. Install NetCDF with:
#   macOS:  brew install netcdf
#   Debian: sudo apt install libnetcdf-dev
set -euo pipefail

cd "$(dirname "$0")"

command -v fpc       >/dev/null 2>&1 || { echo "error: fpc not found on PATH" >&2; exit 1; }
command -v nc-config >/dev/null 2>&1 || {
  echo "error: nc-config not found. Install NetCDF (brew install netcdf /" >&2
  echo "       apt install libnetcdf-dev) so libnetcdf and its headers are available." >&2
  exit 1
}

INC="$(nc-config --includedir)"
LIB="$(nc-config --libdir)"
echo "Using NetCDF headers: $INC"
echo "Using NetCDF library: $LIB"
echo

for tool in agmerra_to_pascal_weather download_cropgrids build_cassava_mask; do
  echo "Building $tool ..."
  fpc -Mdelphi -Fi"$INC" -Fl"$LIB" -k-L"$LIB" -k-lnetcdf "$tool.pas" >/dev/null
  echo "  -> tools/$tool"
done

echo
echo "Done. Tools built in: $(pwd)"
