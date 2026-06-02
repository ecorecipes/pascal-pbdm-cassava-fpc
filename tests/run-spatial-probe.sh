#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
fpc -Mdelphi -Fu../cassava spatial_probe.pas >/tmp/pbdm-spatial-probe-build.log
./spatial_probe
