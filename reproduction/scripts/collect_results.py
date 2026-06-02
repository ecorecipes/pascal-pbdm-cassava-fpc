#!/usr/bin/env python3
"""
Collect paper-reproduction scenario outputs into summary tables.

Reads annual GIS output files from each scenario/cell directory and
produces per-scenario summary CSVs with cell-level means (excluding
the first simulation year, per the paper's methodology).
"""

import argparse
import csv
import os
import re
import sys
from collections import defaultdict
from multiprocessing import Pool, cpu_count
from pathlib import Path


def parse_gis_file(filepath):
    """Parse a single Cassava_*_*.txt GIS output file.

    Returns a dict of column_name -> value (all values as float).
    """
    with open(filepath) as f:
        header = f.readline().strip().split("\t")
        data_line = f.readline().strip().split("\t")

    record = {}
    for col, val in zip(header, data_line):
        col = col.strip()
        try:
            record[col] = float(val)
        except (ValueError, TypeError):
            record[col] = val
    return record


def collect_cell_outputs(cell_dir):
    """Collect all annual GIS output files from a cell directory.

    Returns list of (year_index, record_dict) sorted by year index.
    The year_index is the 5-digit suffix (00001, 00002, ...).
    """
    gis_files = sorted(cell_dir.glob("Cassava_*_*.txt"))
    results = []
    for gf in gis_files:
        match = re.search(r"_(\d{5})\.txt$", gf.name)
        if not match:
            continue
        year_idx = int(match.group(1))
        try:
            record = parse_gis_file(gf)
            record["_year_index"] = year_idx
            results.append((year_idx, record))
        except Exception as e:
            print(f"  Warning: failed to parse {gf}: {e}", file=sys.stderr)
    return results


# Key output columns from the GIS files
KEY_COLUMNS = [
    "Long", "Lat", "rain", "Yeardd", "Root", "Stem/Yr", "LeafYr",
    "TonsAcreYr", "NrCuts",
    # CM columns (present when CMB=T)
    "CmmothEgg", "CmmothLar", "CmmothPup", "CmmothAdl",
    # Parasitoid columns
    "TDDAMoth", "TDDBMoth",
    # GM columns (present when GM=T)
    # Additional columns vary by scenario
]


def compute_cell_means(yearly_records, skip_first=True):
    """Compute mean values across years for a cell.

    Args:
        yearly_records: list of (year_index, record_dict)
        skip_first: if True, skip the equilibration year (first real year)

    Returns dict of column_name -> mean_value
    """
    # Always exclude zero-year records (dd=0): the last GIS file per cell
    # contains an empty initialization record for the year after simulation ends.
    # Also exclude first real year if skip_first (paper methodology: "data from
    # the first year were excluded").
    # Note: GisOutput.pas already skips GisFileIndex=1 (the very first year),
    # so the first written file is the SECOND simulation year. Per the paper,
    # the first simulation year (1980/1990) is already absent from GIS output.
    # We only need to filter out the zero-year sentinel.
    records = []
    for idx, r in yearly_records:
        dd_val = r.get('dd', None)
        if isinstance(dd_val, (int, float)) and dd_val == 0:
            continue  # skip zero-year sentinel
        records.append(r)

    if not records:
        return {}

    # Find all numeric columns
    numeric_cols = set()
    for r in records:
        for k, v in r.items():
            if k.startswith("_"):
                continue
            if isinstance(v, (int, float)):
                numeric_cols.add(k)

    means = {}
    for col in sorted(numeric_cols):
        vals = [r[col] for r in records if col in r and isinstance(r.get(col), (int, float))]
        if vals:
            means[col] = sum(vals) / len(vals)
    means["_n_years"] = len(records)
    return means


def _process_one_cell(cell_dir_str):
    """Process a single cell directory (for multiprocessing)."""
    cell_dir = Path(cell_dir_str)
    yearly = collect_cell_outputs(cell_dir)
    if not yearly:
        return None
    means = compute_cell_means(yearly, skip_first=True)
    if means:
        means["_cell"] = cell_dir.name
        return means
    return None


def collect_scenario(scenario_dir, workers=None):
    """Collect results for one scenario across all cells.

    Returns list of dicts, one per cell, with mean values.
    Uses multiprocessing for speed.
    """
    cells_tsv = scenario_dir / "cells.tsv"
    if not cells_tsv.exists():
        return []

    cell_dirs = sorted(str(d) for d in scenario_dir.iterdir() if d.is_dir())
    if not cell_dirs:
        return []

    if workers is None:
        workers = min(cpu_count(), 8)

    with Pool(workers) as pool:
        raw = pool.map(_process_one_cell, cell_dirs, chunksize=64)

    return [r for r in raw if r is not None]


def write_summary_csv(results, output_path):
    """Write summary results to a CSV file."""
    if not results:
        return

    # Collect all column names
    all_cols = set()
    for r in results:
        all_cols.update(r.keys())

    # Order: _cell first, then sorted columns, _n_years last
    meta_cols = ["_cell", "_n_years"]
    data_cols = sorted(c for c in all_cols if not c.startswith("_"))
    fieldnames = meta_cols + data_cols

    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in results:
            writer.writerow(r)


def main():
    parser = argparse.ArgumentParser(
        description="Collect reproduction scenario outputs into summary tables")
    parser.add_argument("--output-dir", type=str, default="",
                        help="Output base directory (default: reproduction/output)")
    parser.add_argument("--scenarios", type=str, default="",
                        help="Comma-separated scenario names (default: all found)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repro_dir = script_dir.parent

    if args.output_dir:
        output_base = Path(args.output_dir)
    else:
        output_base = repro_dir / "output"

    if not output_base.exists():
        print(f"ERROR: output directory not found at {output_base}")
        sys.exit(1)

    if args.scenarios:
        scenario_names = [s.strip() for s in args.scenarios.split(",")]
    else:
        scenario_names = sorted(
            d.name for d in output_base.iterdir()
            if d.is_dir() and (d / "cells.tsv").exists()
        )

    if not scenario_names:
        print("No completed scenarios found.")
        sys.exit(0)

    summaries_dir = repro_dir / "summaries"
    summaries_dir.mkdir(parents=True, exist_ok=True)

    for name in scenario_names:
        scenario_dir = output_base / name
        if not scenario_dir.exists():
            print(f"SKIP {name}: directory not found")
            continue

        print(f"Collecting {name}...")
        results = collect_scenario(scenario_dir)
        if results:
            out_csv = summaries_dir / f"{name}.csv"
            write_summary_csv(results, out_csv)
            print(f"  {len(results)} cells -> {out_csv}")
        else:
            print(f"  No results found")

    print("\nDone. Summaries written to:", summaries_dir)


if __name__ == "__main__":
    main()
