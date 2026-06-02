#!/usr/bin/env python3
"""
Generate Cassava.ini files and run paper-reproduction scenarios.

Scenarios from Gutierrez et al. (2025) Sci. Rep.
  CM biological control:  1980-1990 (10,172 alternating Africa cells)
  CGM biological control: 1990-2000 (same cell selection)
"""

import argparse
import csv
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

# ---------------------------------------------------------------------------
# Scenario definitions
# ---------------------------------------------------------------------------

# Flags: (CMB, A.lopezi, A.diversicornis, GM, pred1_T.aripo, pred2_A.manihoti,
#          Hyperaspis, fungi)
# Period: (start_month, start_day, start_year, end_month, end_day, end_year)

SCENARIOS = {
    # --- CM biological control (1980-1990) ---
    "cassava-only": {
        "desc": "Potential yield baseline (no arthropods)",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": False, "al": False, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cm-only": {
        "desc": "CM damage without biological control",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": False, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cm-al": {
        "desc": "CM + A. lopezi",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": True, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cm-ad": {
        "desc": "CM + A. diversicornis",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": False, "ad": True,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cm-al-ad": {
        "desc": "CM + both parasitoids",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": True, "ad": True,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cm-fungi": {
        "desc": "CM + pathogen mortality only",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": False, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    "cm-al-fungi": {
        "desc": "CM + A. lopezi + pathogen",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": True, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    "cm-ad-fungi": {
        "desc": "CM + A. diversicornis + pathogen",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": False, "ad": True,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    "cm-al-ad-fungi": {
        "desc": "CM + both parasitoids + pathogen",
        "period": (1, 1, 1980, 12, 31, 1990),
        "cmb": True, "al": True, "ad": True,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    # --- CGM biological control (1990-2000) ---
    "cassava-only-cgm": {
        "desc": "Potential yield baseline for CGM period (no arthropods)",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": False, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cgm-only": {
        "desc": "CGM damage without predators",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cgm-ta": {
        "desc": "CGM + T. aripo",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": True, "pred2": False,
        "hyperaspis": False, "fungi": False,
    },
    "cgm-am": {
        "desc": "CGM + A. manihoti",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": False, "pred2": True,
        "hyperaspis": False, "fungi": False,
    },
    "cgm-ta-am": {
        "desc": "CGM + both predators",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": True, "pred2": True,
        "hyperaspis": False, "fungi": False,
    },
    # --- CGM with fungi (pathogen/rainfall mortality) ---
    "cgm-only-fungi": {
        "desc": "CGM + pathogen mortality only",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": False, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    "cgm-ta-fungi": {
        "desc": "CGM + T. aripo + pathogen",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": True, "pred2": False,
        "hyperaspis": False, "fungi": True,
    },
    "cgm-am-fungi": {
        "desc": "CGM + A. manihoti + pathogen",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": False, "pred2": True,
        "hyperaspis": False, "fungi": True,
    },
    "cgm-ta-am-fungi": {
        "desc": "CGM + both predators + pathogen",
        "period": (1, 1, 1990, 12, 31, 2000),
        "cmb": False, "al": False, "ad": False,
        "gm": True, "pred1": True, "pred2": True,
        "hyperaspis": False, "fungi": True,
    },
}

# ---------------------------------------------------------------------------
# Cassava.ini template
# ---------------------------------------------------------------------------

def tf(b):
    return "T" if b else "F"

def make_cassava_ini(scenario):
    """Generate a Cassava.ini string for a given scenario dict."""
    s = scenario
    # GM start date — use same year as simulation start for CGM scenarios
    gm_start_year = s["period"][2]
    # Original INI uses distribution=1 (rows with ±20% perturbation).
    # "Randomly spaced" in the paper refers to the perturbation, not scattered mode.
    distribution = s.get("distribution", 1)
    return f"""\
10    number of plants (also depends on 'varnplants' below)
{distribution}     distribution (1 in rows, 2 scattered)
*** switches for seasonal variations.  % variation set in Setsvar.pas *****
F \t  varnplants vary number of plants each season 
f     varnitro  scale initial N up or down each season 
f     varwater  scale initial water up or down each season
f     varspacing  scale plant spacing  each season
f     varcmbstart vary  cmb start date
f     varcmbnm1 vary mean cmb initial number
f     varcmbprob vary prob of infestation
f     varcmbimm vary mean number immigrating
f     varedstart start of ed immig.
f     varedprob probability of a plant getting ed each day
f     varedimm mean number ed immigrating each day
f     varelstart start of el immig.
f     varelprob probability of a plant getting el each day
f     varelimm   mean number el immigrating each day
f     vargmstart start date of gmite
f     vargmprob prob. each plant gets 1 gmite each day
f     varp1prob prob. each plant gets 1 gmite pred1 each day
f     varp2prob prob. each plant gets 1 gmite pred2 each day
f     varp1alpha
f     varp2alpha
F     use presence/absence logic for insects each year
*******************
1         \tdays over which to distribute the plantings
0.0         temps adjustment assuming Celsius
0.0         solar adjustment assuming wx data is in watts.  Converted to langleys in wxread.
0.0         precip adjustment assuming mm
0.0         rel humidity adjustment %
0.0         wind adjustment km/hr
1 \t\t\tvariety. 1 TMS30572(Red) 2 TMS4(2)1425 3 Isunikankiyan 4 TMS91934 5 ODONDBO 
1           CBFACT  1 or 2,  single or double branching pattern
20.0        % variation in initial stick mass
1.00        plant spacing within row (WM) (1.5)
1.00        distance between rows (WM) (0.8)
20.0        +-% spread for plant location
20.0        +-% spread for row spacing
*********soil water and nitrogen *************
1250.0       PWP (Permanent wilting point)
1475.0       SOILW1475.0
1550.0       SOILWMAX1500.0
120000.0     ORG g. initial organic matter/m**2
9.5          SOILN initial residual inorganic soil nitr.
20.0         phosphate (ppm) (13.5 near optimal, Tamo p25)
u            nitrogen distr. u uniform,g gradient,r random
20.0         % variation in nitrogen (in gradient or random)
1            gradient direction. # 1 left to right,2 tb,3 rl,4 bt
u            water distr. u uniform, g gradient,r random
20.0         % variation in water (in gradient or random)
1            gradient direction. 1 left to right,2 tb,3 rl,4 bt
*****************************************************
1         \ttabular/graphic output every how many days
F         \tsave daily output to disk file CassavaDaily.txt
T\t      \tWrite Summary file (CassavaSummaries.txt)
2         \tGis output target 1 ArcInfo(Casas), 2 Grass(Luigi)
******** CMB ***********************************
{tf(s['cmb'])}          \tinclude CMB (mealy bug) Phenacoccus manihoti
2         \tCMB ndelay
0.5        \tCMB beta
0.05  2.37  CMB rateem (from Fabres & Boussiengue, 1981) at 24 C dry season
68   \t   \tnr days after cas start for cmb start 07 19 1983 CMBSTART 
0.5        \tprobability each plant will get immigrants each day
0.5  80    \tmean nr to imm, %+- (i.e., 0.5 80 -> 0.1 to 0.9)
*********A. lopezi******************************
{tf(s['al'])}       \tInclude parasite Epidinocarsis lopezi
25      \tlevel of mb larvae required to attract start of el immig.
0.05      \tprobability each plant will get immigrants each day
0.5  50   \tmean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
*********A. diversicornis***********************
{tf(s['ad'])}          \tInclude parasitoid Epidinocarsis diversicornis
25        \tlevel of mb larvae required to attract start of ed immig.
0.05      \t probability each plant will get immigrants each day
0.5  50    \tmean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
{tf(s['gm'])}        \tinclude Green Mite Mononychellus tanojoa
6 25 {gm_start_year}   GM START DATE
0.1       \tprobability each plant will get immigrants each day
0.05  50\tnumber to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
{tf(s['pred1'])}       include gm pred1 T. aripo
0.05      total mass GM to attract p1 start
0.20      prob. each plant receives adult visitors daily after start 
{tf(s['pred2'])}       include gm pred2 A. manihoti
0.3      total mass GM to attract p2 start
0.1      prob. each plant receives adult visitor daily after start 
**********************************************
F          include Coccid predator Hyperaspis jucunda (*** really slows program down)
001        HJ ndelay - days to stress
100.5      hjmblev - level of totcmb mass to start hj
0.05       prob. each plant get immig. each day
0.005 10   mean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
{tf(s['fungi'])}          include fungus mortality (rain mortality)
1\t      milsecdelay - slow program for graphics
2         immigmethod, 1 source unknown, 2 daily migrant pool
0         randseed {{if 0 then use different sequences each time, if >0 then use same sequence each time.}}
"""


# ---------------------------------------------------------------------------
# Cell selection
# ---------------------------------------------------------------------------

def load_manifest(manifest_path):
    """Load the weather file manifest and return list of (name, lon, lat) tuples."""
    cells = []
    with open(manifest_path) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            cells.append((row["output_name"], float(row["lon"]), float(row["lat"])))
    return cells


def select_alternating_cells(cells):
    """Select every-other cell in both lat and lon dimensions (~10,172 cells)."""
    sorted_lats = sorted(set(lat for _, _, lat in cells))
    sorted_lons = sorted(set(lon for _, lon, _ in cells))
    lat_idx = {v: i for i, v in enumerate(sorted_lats)}
    lon_idx = {v: i for i, v in enumerate(sorted_lons)}
    return [
        (name, lon, lat) for name, lon, lat in cells
        if lat_idx[lat] % 2 == 0 and lon_idx[lon] % 2 == 0
    ]


PILOT_CELLS = [
    # 10 geographically diverse cells across Africa
    # (approximate targets; actual selection picks nearest available cell)
    (-4.0, 8.0),    # Gulf of Guinea / Ivory Coast
    (12.0, 8.0),    # Nigeria
    (30.0, 0.0),    # Uganda/DRC
    (38.0, 7.0),    # Ethiopia
    (26.0, -4.0),   # DRC
    (18.0, -10.0),  # Angola
    (32.0, -14.0),  # Malawi/Mozambique
    (28.0, -25.0),  # South Africa
    (46.0, -19.0),  # Madagascar
    (8.0, 25.0),    # Sudan/Sahel
]

def select_pilot_cells(cells, n=10):
    """Select a small geographically diverse pilot set."""
    selected = []
    used = set()
    for target_lon, target_lat in PILOT_CELLS[:n]:
        best = None
        best_dist = float("inf")
        for name, lon, lat in cells:
            if name in used:
                continue
            d = (lon - target_lon)**2 + (lat - target_lat)**2
            if d < best_dist:
                best_dist = d
                best = (name, lon, lat)
        if best:
            selected.append(best)
            used.add(best[0])
    return selected


# ---------------------------------------------------------------------------
# Run logic
# ---------------------------------------------------------------------------

def _run_one_cell(args_tuple):
    """Worker function for parallel cell execution."""
    cassava_bin, cell_dir, cmd_dates, gis_interval, wx_path, ini_content = args_tuple
    cell_dir = Path(cell_dir)
    cell_dir.mkdir(parents=True, exist_ok=True)
    (cell_dir / "Cassava.ini").write_text(ini_content)

    cmd = [
        str(cassava_bin), "Cassava.ini",
        *cmd_dates,
        gis_interval, str(wx_path),
    ]
    try:
        result = subprocess.run(
            cmd, cwd=str(cell_dir),
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            errlog = cell_dir / "error.log"
            errlog.write_text(result.stdout + "\n" + result.stderr)
            return False, cell_dir.name, result.returncode
        return True, cell_dir.name, 0
    except subprocess.TimeoutExpired:
        return False, cell_dir.name, -1


def run_scenario(scenario_name, scenario, cell_list, cassava_bin, wx_dir,
                 output_base, dry_run=False, workers=1):
    """Run a single scenario across all cells in cell_list."""
    period = scenario["period"]
    cmd_dates = [
        f"{period[0]:02d}", f"{period[1]:02d}", str(period[2]),
        f"{period[3]:02d}", f"{period[4]:02d}", str(period[5]),
    ]
    gis_interval = "365"

    scenario_dir = output_base / scenario_name
    scenario_dir.mkdir(parents=True, exist_ok=True)

    # Write cell manifest
    cells_tsv = scenario_dir / "cells.tsv"
    with open(cells_tsv, "w") as f:
        f.write("wxfile\tlon\tlat\n")
        for name, lon, lat in cell_list:
            f.write(f"{name}\t{lon}\t{lat}\n")

    ini_content = make_cassava_ini(scenario)

    # Write shared Cassava.ini for reference
    (scenario_dir / "Cassava.ini").write_text(ini_content)

    total = len(cell_list)
    completed = 0
    failed = 0

    if dry_run:
        for i, (wx_name, lon, lat) in enumerate(cell_list, 1):
            print(f"  [{i}/{total}] DRY-RUN {wx_name} ({lon}, {lat})")
            completed += 1
        return completed, failed

    # Build task list, skipping already-completed cells (resume support)
    tasks = []
    skipped = 0
    already_done = 0
    for wx_name, lon, lat in cell_list:
        wx_path = wx_dir / wx_name
        if not wx_path.exists():
            skipped += 1
            failed += 1
            continue
        cell_dir = scenario_dir / wx_name.replace(".txt", "")
        # Check if cell already has GIS output (resume support)
        gis_files = list(cell_dir.glob("Cassava_*.txt")) if cell_dir.exists() else []
        if gis_files:
            already_done += 1
            completed += 1
            continue
        tasks.append((
            str(cassava_bin), str(cell_dir), cmd_dates,
            gis_interval, str(wx_path), ini_content,
        ))
    if skipped:
        print(f"  Skipped {skipped} cells (weather file not found)", flush=True)
    if already_done:
        print(f"  Resuming: {already_done} cells already complete", flush=True)

    if workers > 1 and len(tasks) > 1:
        # Parallel execution
        done = 0
        with ProcessPoolExecutor(max_workers=workers) as executor:
            futures = {executor.submit(_run_one_cell, t): t for t in tasks}
            for future in as_completed(futures):
                ok, cell_name, rc = future.result()
                if ok:
                    completed += 1
                else:
                    failed += 1
                done += 1
                if done % 500 == 0 or done == len(tasks):
                    print(f"  [{done}/{len(tasks)}] {completed} done, {failed} failed", flush=True)
    else:
        # Serial execution
        for i, t in enumerate(tasks, 1):
            ok, cell_name, rc = _run_one_cell(t)
            if ok:
                completed += 1
            else:
                failed += 1
            if i % 100 == 0 or i == len(tasks):
                print(f"  [{i}/{len(tasks)}] OK ({completed} done, {failed} failed)", flush=True)

    return completed, failed


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Run paper-reproduction scenarios for Gutierrez et al. (2025)")
    parser.add_argument("--pilot", action="store_true",
                        help="Use 10 diverse pilot cells instead of full grid")
    parser.add_argument("--max-cells", type=int, default=0,
                        help="Limit to first N cells (0 = all selected)")
    parser.add_argument("--scenarios", type=str, default="",
                        help="Comma-separated scenario names (default: all)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print commands without executing")
    parser.add_argument("--cassava-bin", type=str, default="",
                        help="Path to cassava binary (default: auto-detect)")
    parser.add_argument("--wx-dir", type=str, default="",
                        help="Path to weather data directory")
    parser.add_argument("--output-dir", type=str, default="",
                        help="Output base directory")
    parser.add_argument("--workers", "-j", type=int, default=1,
                        help="Number of parallel workers (default: 1)")
    args = parser.parse_args()

    # Resolve paths
    script_dir = Path(__file__).resolve().parent
    repo_dir = script_dir.parent.parent  # pascal-pbdm-cassava-fpc/../..
    repro_dir = script_dir.parent        # reproduction/

    if args.cassava_bin:
        cassava_bin = Path(args.cassava_bin)
    else:
        cassava_bin = repro_dir.parent / "cassava" / "cassava"
    if not cassava_bin.exists():
        print(f"ERROR: cassava binary not found at {cassava_bin}")
        print("Build it first: cd ../cassava && fpc -Mdelphi cassava.pas")
        sys.exit(1)

    if args.wx_dir:
        wx_dir = Path(args.wx_dir)
    else:
        wx_dir = repo_dir.parent / "data" / "agmerra-pascal-weather-africa-1980-2010"
    if not wx_dir.exists():
        print(f"ERROR: weather data directory not found at {wx_dir}")
        sys.exit(1)

    manifest = wx_dir / "_manifest.tsv"
    if not manifest.exists():
        print(f"ERROR: manifest not found at {manifest}")
        sys.exit(1)

    if args.output_dir:
        output_base = Path(args.output_dir)
    else:
        output_base = repro_dir / "output"
    output_base.mkdir(parents=True, exist_ok=True)

    # Load and select cells
    all_cells = load_manifest(manifest)
    if args.pilot:
        cells = select_pilot_cells(all_cells)
        print(f"Pilot mode: {len(cells)} cells selected")
    else:
        cells = select_alternating_cells(all_cells)
        print(f"Full mode: {len(cells)} alternating cells selected")

    if args.max_cells > 0:
        cells = cells[:args.max_cells]
        print(f"Limited to {len(cells)} cells")

    # Select scenarios
    if args.scenarios:
        scenario_names = [s.strip() for s in args.scenarios.split(",")]
        for name in scenario_names:
            if name not in SCENARIOS:
                print(f"ERROR: unknown scenario '{name}'")
                print(f"Available: {', '.join(SCENARIOS.keys())}")
                sys.exit(1)
    else:
        scenario_names = list(SCENARIOS.keys())

    print(f"Scenarios: {', '.join(scenario_names)}", flush=True)
    print(f"Output: {output_base}", flush=True)
    print(flush=True)

    # Run each scenario
    for name in scenario_names:
        scenario = SCENARIOS[name]
        print(f"=== {name}: {scenario['desc']} ===", flush=True)
        period = scenario["period"]
        print(f"    Period: {period[2]}-{period[5]}, {len(cells)} cells", flush=True)
        completed, failed = run_scenario(
            name, scenario, cells, cassava_bin, wx_dir, output_base,
            dry_run=args.dry_run, workers=args.workers,
        )
        print(f"    Completed: {completed}, Failed: {failed}", flush=True)
        print(flush=True)

    print("Done.", flush=True)


if __name__ == "__main__":
    main()
