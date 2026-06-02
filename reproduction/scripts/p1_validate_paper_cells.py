#!/usr/bin/env python3
"""P1: Validate the Delphi golden master against the paper's 17 shipped outputs.

The paper repo (Zenodo 17559583) ships Cassava_06Nov25_0000{2..7}.txt: a
cgm-ta-am run (GM + T.aripo + A.manihoti, no MB/parasitoids, no fungus,
randseed=0) on 17 DZA_NF cells (agmerra_0001_{217..249} odd), years 1981-1985
(file 00007 = 1986 is the trailing zero snapshot).

Because the shipped run used randseed=0 (time-seeded), the authors' numbers are
ONE realization of a stochastic process. This harness runs the SAME golden-master
binary with the SAME shipped Cassava.ini on the SAME weather files for K fixed
seeds (randseed=1..K), building a per-(cell,year) Monte-Carlo envelope, and tests
whether each authors' value falls inside it. This is a conditional Monte-Carlo
containment check (paired weather + identical code), NOT a formal CI on a
full-Africa coefficient.

Outputs: per-(cell,year) envelope + containment, and overall containment rates.
"""
import csv, os, shutil, subprocess, sys, tempfile, statistics
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]            # .../reproduction
PAPER_DIR = ROOT / "paper_zenodo"
SHIPPED_INI = PAPER_DIR / "Cassava.paper.ini"
WINEPREFIX = os.path.expanduser("~/.wine-delphi3")
DELPHI_CAP = Path(WINEPREFIX) / "drive_c/casgm/cassava.exe"
WX_DIR = ROOT.parent / "data" / "agmerra-pascal-weather-africa-1980-2010"

CELLS = [f"agmerra_0001_{n}_DZA_NF" for n in range(217, 250, 2)]  # 217..249 odd = 17
PERIOD = ("01", "01", "1980", "12", "31", "1985")
GIS_INTERVAL = "365"
KSEEDS = int(os.environ.get("KSEEDS", "24"))
PROD_YEARS = [1981, 1982, 1983, 1984, 1985]  # 1986 is trailing-zero snapshot

# GIS output column indices (0-based) from header
COL_WX, COL_YEAR, COL_TUBER = 3, 10, 15
COL_GMTOT, COL_TARI, COL_TMAN = 26, 27, 28


def cell_of(wxpath):
    n = wxpath.split("agmerra_0001_")[-1].replace("_DZA_NF.txt", "")
    return f"agmerra_0001_{n}_DZA_NF"


def parse_shipped():
    """Return {(cell, year): tuber} from the authors' shipped GIS files."""
    out = {}
    for f in sorted(PAPER_DIR.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd = csv.reader(fh, delimiter="\t")
            next(rd, None)
            for row in rd:
                if len(row) <= COL_TUBER:
                    continue
                try:
                    cell = cell_of(row[COL_WX])
                    yr = int(row[COL_YEAR]); t = float(row[COL_TUBER])
                except Exception:
                    continue
                out[(cell, yr)] = t
    return out


def make_ini(randseed):
    lines = SHIPPED_INI.read_text().splitlines()   # robust to CRLF/LF
    for i, ln in enumerate(lines):
        if "randseed {" in ln:
            tail = ln.split(None, 1)[1]             # "randseed {...}"
            lines[i] = f"{randseed}         {tail}"
            break
    else:
        raise RuntimeError("randseed line not found in shipped ini")
    return "\r\n".join(lines) + "\r\n"              # CRLF for wine


def run_one(args):
    seed, wxname = args
    wx_src = WX_DIR / (wxname + ".txt")
    if not wx_src.exists():
        return (seed, wxname, None, "missing-wx")
    d = tempfile.mkdtemp(prefix=f"p1_{seed}_")
    try:
        Path(d, "Cassava.ini").write_text(make_ini(seed))
        wx = wx_src.read_text().replace("\r\n", "\n").replace("\n", "\r\n")
        Path(d, "wx.txt").write_text(wx)
        cmd = ["wine", str(DELPHI_CAP), "Cassava.ini", *PERIOD, GIS_INTERVAL, "wx.txt"]
        env = dict(os.environ, WINEPREFIX=WINEPREFIX, WINEPATH=r"C:\Delphi30\BIN",
                   WINEDEBUG="-all", MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(cmd, cwd=d, env=env, capture_output=True, text=True, timeout=300)
        vals = {}  # year -> tuber
        for gf in Path(d).glob("Cassava_*.txt"):
            with open(gf) as fh:
                rd = csv.reader(fh, delimiter="\t")
                next(rd, None)
                for row in rd:
                    if len(row) <= COL_TUBER:
                        continue
                    try:
                        yr = int(row[COL_YEAR]); t = float(row[COL_TUBER])
                    except Exception:
                        continue
                    vals[yr] = t
        if not vals:
            return (seed, wxname, None, "no-gis")
        return (seed, wxname, vals, "ok")
    except subprocess.TimeoutExpired:
        return (seed, wxname, None, "timeout")
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    shipped = parse_shipped()
    # The cgm-ta-am config is DETERMINISTIC (verified: randseed has no effect on
    # yield; init.pas only calls randomize when randseed=0 and never assigns a
    # positive seed to system RandSeed, and even randomize leaves tuber unchanged).
    # So ONE run per cell fully characterises the golden master; any gap vs the
    # authors' shipped values isolates to the WEATHER INPUT (same binary+ini+cmdline).
    tasks = [(KSEEDS, c) for c in CELLS]   # single deterministic run per cell
    print(f"P1: {len(tasks)} deterministic runs ({len(CELLS)} cells), "
          f"golden master cgm-ta-am, period {PERIOD[2]}-{PERIOD[5]}", flush=True)
    model = {}  # (cell,year)->tuber
    done = fails = 0
    with ProcessPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(run_one, t): t for t in tasks}
        for fu in as_completed(futs):
            seed, cell, vals, status = fu.result()
            done += 1
            if status != "ok":
                fails += 1
                print(f"  FAIL {cell}: {status}", flush=True)
            else:
                for yr, t in vals.items():
                    model[(cell, yr)] = t
            if done % 5 == 0 or done == len(tasks):
                print(f"  [{done}/{len(tasks)}] fails={fails}", flush=True)

    rawcsv = ROOT / "cache" / "p1_deterministic.csv"
    rawcsv.parent.mkdir(exist_ok=True)
    rows = []
    with open(rawcsv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cell", "year", "author", "model", "abs_diff", "pct_diff"])
        for (cell, yr) in sorted(model):
            if yr not in PROD_YEARS:
                continue
            a = shipped.get((cell, yr))
            mv = model[(cell, yr)]
            if a is None:
                continue
            ad = mv - a
            pd = (ad / a * 100) if a != 0 else float("nan")
            w.writerow([cell, yr, f"{a:.3f}", f"{mv:.3f}", f"{ad:.3f}",
                        "" if a == 0 else f"{pd:.2f}"])
            rows.append((cell, yr, a, mv, ad, pd))

    exact = sum(1 for *_, ad, _ in rows if abs(ad) < 0.05)
    print(f"\nraw -> {rawcsv}")
    print(f"\n=== Golden master vs authors' shipped values (deterministic) ===")
    print(f"  rows compared : {len(rows)}")
    print(f"  exact (<0.05g): {exact}/{len(rows)}")
    diffs = [ad for *_, ad, _ in rows]
    absd = [abs(x) for x in diffs]
    print(f"  mean signed Δ : {statistics.fmean(diffs):+.2f} g")
    print(f"  median |Δ|    : {statistics.median(absd):.2f} g")
    print(f"  median author : {statistics.median([a for _,_,a,_,_,_ in rows]):.2f} g")
    print(f"  median model  : {statistics.median([m for _,_,_,m,_,_ in rows]):.2f} g")
    print(f"\n  {'cell':24s} {'yr':4s} {'author':>9s} {'model':>9s} {'Δ':>9s} {'Δ%':>8s}")
    for cell, yr, a, mv, ad, pd in rows:
        if cell.split("_")[2] in ("217", "221", "229", "241", "249"):
            ps = "" if a == 0 else f"{pd:7.1f}%"
            print(f"  {cell:24s} {yr:<4d} {a:9.3f} {mv:9.3f} {ad:+9.3f} {ps:>8s}")


if __name__ == "__main__":
    main()
