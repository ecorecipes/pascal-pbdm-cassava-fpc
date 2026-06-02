#!/usr/bin/env python3
"""
One-time bulk extraction of per-cell, per-year GIS summary rows for the 9 CM
scenarios into a single compact cache CSV. Each Cassava_*.txt holds one data
row (one simulation year) with tuber + mb1..mb6.

The work is dominated by opening ~1M tiny files, so it is heavily I/O-bound.
Each scenario is extracted in its own worker process (writing its own shard
CSV); the shards are concatenated at the end.

Output: reproduction/cache/cellyear_cm.csv with columns:
  scenario, cell, year, lon, lat, tuber, mb1, mb2, mb3, mb4, mb5, mb6
"""
import csv
import os
import pathlib
import sys
import time
from concurrent.futures import ProcessPoolExecutor

HERE = pathlib.Path(__file__).parent
OUT = HERE.parent / "output"
CACHE = HERE.parent / "cache"
CACHE.mkdir(exist_ok=True)

SCENARIOS = [
    "cassava-only", "cm-only", "cm-al", "cm-ad", "cm-al-ad",
    "cm-fungi", "cm-al-fungi", "cm-ad-fungi", "cm-al-ad-fungi",
]

# 0-based indices into the tab-separated data line
I_WX, I_LON, I_LAT, I_YEAR, I_TUBER = 3, 4, 5, 10, 15
I_MB1 = 26  # mb1..mb6 -> 26..31

HEADER = ["scenario", "cell", "year", "lon", "lat", "tuber",
          "mb1", "mb2", "mb3", "mb4", "mb5", "mb6"]


def extract_scenario(scn):
    base = OUT / scn
    shard = CACHE / f"shard_{scn}.csv"
    n = 0
    t0 = time.time()
    if not base.is_dir():
        return (scn, 0, "MISSING")
    with open(shard, "w", newline="") as fh:
        w = csv.writer(fh)
        with os.scandir(base) as cells:
            for ce in cells:
                if not ce.is_dir():
                    continue
                cell = ce.name
                with os.scandir(ce.path) as files:
                    for fe in files:
                        nm = fe.name
                        if not (nm.startswith("Cassava_") and nm.endswith(".txt")):
                            continue
                        try:
                            with open(fe.path) as f:
                                f.readline()  # header
                                line = f.readline()
                        except OSError:
                            continue
                        if not line:
                            continue
                        p = line.rstrip("\n").split("\t")
                        if len(p) <= I_MB1 + 5:
                            continue
                        try:
                            row = [
                                scn, cell, int(float(p[I_YEAR])),
                                float(p[I_LON]), float(p[I_LAT]), float(p[I_TUBER]),
                                float(p[I_MB1]), float(p[I_MB1 + 1]), float(p[I_MB1 + 2]),
                                float(p[I_MB1 + 3]), float(p[I_MB1 + 4]), float(p[I_MB1 + 5]),
                            ]
                        except (ValueError, IndexError):
                            continue
                        w.writerow(row)
                        n += 1
    return (scn, n, f"{time.time()-t0:.1f}s")


def main():
    t0 = time.time()
    out_csv = CACHE / "cellyear_cm.csv"
    with ProcessPoolExecutor(max_workers=min(9, os.cpu_count() or 4)) as ex:
        for scn, n, info in ex.map(extract_scenario, SCENARIOS):
            print(f"{scn:<18} {n:>8} rows  ({info})", flush=True)

    # Concatenate shards into one cache CSV
    total = 0
    with open(out_csv, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADER)
        for scn in SCENARIOS:
            shard = CACHE / f"shard_{scn}.csv"
            if not shard.exists():
                continue
            with open(shard) as sf:
                for line in sf:
                    fh.write(line)
                    total += 1
            shard.unlink()
    print(f"TOTAL {total} rows -> {out_csv}  ({time.time()-t0:.1f}s)")


if __name__ == "__main__":
    main()
