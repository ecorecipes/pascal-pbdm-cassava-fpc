#!/usr/bin/env python3
"""Controlled sensitivity test: A. lopezi adult-stage (mbn[6]) coefficient.

Compares the current source value (1.000) against the commented alternative
(0.514) in para.pas, holding cells, seed, and everything else constant.

Runs cm-only and cm-al for a sample of cassava-belt cells with a FIXED
random seed, using the current binary and a patched (0.514) binary, then
reports the Al-alone contrast (cm-al - cm-only) for each.
"""
import sys
import subprocess
import random
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_scenarios import make_cassava_ini, SCENARIOS  # noqa
from collect_results import collect_cell_outputs, compute_cell_means  # noqa

REPRO = Path(__file__).resolve().parent.parent
FPC_ROOT = REPRO.parent
WX_DIR = FPC_ROOT.parent / "data" / "agmerra-pascal-weather-africa-1980-2010"
BIN_CURRENT = FPC_ROOT / "cassava" / "cassava"           # 1.000
BIN_PATCHED = Path("/tmp/cassava_patched/cassava")        # 0.514
SEED = 42
N_CELLS = 40
WORKDIR = Path("/tmp/lopezi_test")


def ini_with_seed(scenario_name):
    s = make_cassava_ini(SCENARIOS[scenario_name])
    # replace the trailing randseed value (0) with a fixed positive seed
    return s.replace("0         randseed", f"{SEED}        randseed")


def select_belt_cells(n):
    """Pick n cells whose cassava-only mean tuber is in (1500, 20000).

    Reads the pre-collected cassava-only.csv summary (fast); _cell is the
    weather-file basename.
    """
    import csv
    cells = []
    with open(REPRO / "summaries" / "cassava-only.csv") as f:
        for r in csv.DictReader(f):
            try:
                t = float(r["tuber"])
            except (ValueError, KeyError):
                continue
            if 1500 < t < 20000:
                cells.append(r["_cell"])
    random.Random(123).shuffle(cells)
    return cells[:n]


def run(binary, scenario_name, wx_name, tag):
    cell_dir = WORKDIR / tag / wx_name
    cell_dir.mkdir(parents=True, exist_ok=True)
    (cell_dir / "Cassava.ini").write_text(ini_with_seed(scenario_name))
    period = SCENARIOS[scenario_name]["period"]
    dates = [f"{period[0]:02d}", f"{period[1]:02d}", str(period[2]),
             f"{period[3]:02d}", f"{period[4]:02d}", str(period[5])]
    wx_path = WX_DIR / (wx_name + ".txt")
    cmd = [str(binary), "Cassava.ini", *dates, "365", str(wx_path)]
    r = subprocess.run(cmd, cwd=str(cell_dir), capture_output=True,
                       text=True, timeout=300)
    if r.returncode != 0:
        return None
    recs = collect_cell_outputs(cell_dir)
    if not recs:
        return None
    m = compute_cell_means(recs)
    return m.get("tuber", None)


def main():
    cells = select_belt_cells(N_CELLS)
    print(f"Selected {len(cells)} belt cells, fixed seed={SEED}\n")
    print(f"{'cell':28} {'cm-only':>9} {'al@1.0':>9} {'al@0.514':>9} "
          f"{'eff@1.0':>8} {'eff@0.514':>9}")
    eff_cur, eff_pat = [], []
    for wx in cells:
        t_co = run(BIN_CURRENT, "cm-only", wx, "cmonly")
        t_cur = run(BIN_CURRENT, "cm-al", wx, "cur")
        t_pat = run(BIN_PATCHED, "cm-al", wx, "pat")
        if None in (t_co, t_cur, t_pat):
            print(f"{wx:28} SKIP (run failed)")
            continue
        if not all(-100 < v < 20000 for v in (t_co, t_cur, t_pat)):
            print(f"{wx:28} SKIP (blowup)")
            continue
        e_cur = t_cur - t_co
        e_pat = t_pat - t_co
        eff_cur.append(e_cur)
        eff_pat.append(e_pat)
        print(f"{wx:28} {t_co:9.1f} {t_cur:9.1f} {t_pat:9.1f} "
              f"{e_cur:8.1f} {e_pat:9.1f}")

    if eff_cur:
        mc = sum(eff_cur) / len(eff_cur)
        mp = sum(eff_pat) / len(eff_pat)
        print(f"\nn={len(eff_cur)}")
        print(f"Mean Al-alone effect @ 1.000 (current): {mc:8.1f} g")
        print(f"Mean Al-alone effect @ 0.514 (patched): {mp:8.1f} g")
        print(f"Paper A. lopezi (Al+):                    575.8 g")
        print(f"Ratio patched/current: {mp/mc:.3f}")


if __name__ == "__main__":
    main()
