#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEGACY_ROOT="$(cd "$ROOT/.." && pwd)/pascal-pbdm-cassava/cassava"
RUN_ROOT="${TMPDIR:-/tmp}/pbdm-cassava-fpc-synthetic-compare"

"$ROOT/build-fpc.sh" >/tmp/pbdm-synthetic-compare-build.log

make_weather() {
  local out_dir="$1"
  python3 - "$out_dir" <<'PY'
from datetime import date, timedelta
from pathlib import Path
import math
import sys

out_dir = Path(sys.argv[1])
start = date(1980, 1, 1)
end = date(1985, 12, 31)
with (out_dir / "synthetic_wx.txt").open("w") as f:
    f.write("synthetic_0001\tgenerated weather for FPC port smoke comparison\n")
    f.write("0.1250 35.8750\n")
    f.write("month day year tmax tmin solar rain rh wind\n")
    d = start
    while d <= end:
        doy = d.timetuple().tm_yday
        tmean = 24.0 + 4.0 * math.sin(2 * math.pi * (doy - 80) / 365.0)
        rain = 8.0 if doy % 9 == 0 else 0.0
        solar = 210.0 + 35.0 * math.sin(2 * math.pi * (doy - 30) / 365.0)
        rh = 60.0 + (10.0 if rain else 0.0)
        f.write(
            f"{d.month} {d.day} {d.year} {tmean + 6:.2f} {tmean - 6:.2f} "
            f"{solar:.2f} {rain:.2f} {rh:.2f} 1.50\n"
        )
        d += timedelta(days=1)
PY
}

prepare_run_dir() {
  local scenario="$1"
  local run_dir="$RUN_ROOT/$scenario"
  rm -rf "$run_dir"
  mkdir -p "$run_dir"
  cp "$ROOT/cassava/cassava" "$run_dir/"
  cp "$ROOT/cassava/Cassava.ini" "$run_dir/"
  make_weather "$run_dir"
  printf '%s\n' "$run_dir"
}

run_model() {
  local run_dir="$1"
  (cd "$run_dir" && ./cassava Cassava.ini 01 01 1980 12 31 1985 365 synthetic_wx.txt >run.stdout 2>run.stderr)
}

run_default() {
  local run_dir
  run_dir="$(prepare_run_dir default)"
  run_model "$run_dir"
}

run_cmb_schema() {
  local run_dir
  run_dir="$(prepare_run_dir cmb-schema)"
  python3 - "$run_dir/Cassava.ini" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
for idx in (57, 65, 70):  # file lines 58, 66, 71: CMB, EL, ED toggles
    lines[idx] = "T" + lines[idx][1:]
lines[96] = "1         randseed {if 0 then use different sequences each time, if >0 then use same sequence each time.}"
path.write_text("\n".join(lines) + "\n")
PY
  run_model "$run_dir"
}

run_default
run_cmb_schema

python3 - "$LEGACY_ROOT" "$RUN_ROOT" <<'PY'
from pathlib import Path
import sys

legacy = Path(sys.argv[1])
run_root = Path(sys.argv[2])
legacy_files = sorted(legacy.glob("Cassava_*.txt"))
if not legacy_files:
    raise SystemExit("No legacy Cassava_*.txt files found for header comparison")

legacy_header = legacy_files[0].read_text(errors="replace").splitlines()[0].split("\t")

def gis_files(scenario):
    files = sorted((run_root / scenario).glob("Cassava_*.txt"))
    if len(files) != 6:
        raise SystemExit(f"{scenario}: expected 6 GIS files, found {len(files)}")
    return files

def header(path):
    return path.read_text(errors="replace").splitlines()[0].split("\t")

def first_data_width(path):
    lines = path.read_text(errors="replace").splitlines()
    if len(lines) < 2:
        raise SystemExit(f"{path}: missing first data row")
    return len(lines[1].split("\t"))

default_files = gis_files("default")
default_header = header(default_files[0])
if legacy_header[: len(default_header)] != default_header:
    raise SystemExit("default scenario header is not a prefix of legacy header")

cmb_files = gis_files("cmb-schema")
cmb_header = header(cmb_files[0])
if cmb_header != legacy_header:
    raise SystemExit("CMB schema scenario header does not exactly match legacy header")

for path in default_files + cmb_files:
    h = header(path)
    width = first_data_width(path)
    if width != len(h):
        raise SystemExit(f"{path}: first data row has {width} columns, header has {len(h)}")
    if (path.parent / "run.stderr").stat().st_size != 0:
        raise SystemExit(f"{path.parent}: stderr is not empty")

print(f"Run root: {run_root}")
print(f"Default scenario: {len(default_files)} GIS files, {len(default_header)} columns (legacy prefix OK)")
print(f"CMB schema scenario: {len(cmb_files)} GIS files, {len(cmb_header)} columns (legacy header exact)")
print("Synthetic output comparison passed")
PY
