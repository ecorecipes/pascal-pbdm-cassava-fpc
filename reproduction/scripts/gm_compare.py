#!/usr/bin/env python3
"""Delphi golden-master vs FPC deterministic comparison harness.

Runs cm-only and cm-fungi scenarios on an identical cell subset with a FIXED
randseed across three binaries:
  - delphi_cap   : genuine Delphi 3 golden master, legacy source, 0.45 fungal cap
  - delphi_unc   : genuine Delphi 3 golden master, 0.45 -> 1.00 (uncapped)
  - fpc_arm64    : native FPC port (0.45 cap, == legacy source)

Purpose: with Delphi x87 the FP precision variable is eliminated, so
  (a) delphi_cap vs fpc_arm64 measures PORT FIDELITY (should be ~precision-level),
  (b) delphi_cap vs delphi_unc isolates the 0.45 source PARAMETER's effect on the
      fungal (P) yield rescue -- a pure inputs/parameters difference vs the paper.
"""
import csv, os, shutil, subprocess, sys, tempfile, statistics
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

WINEPREFIX = os.path.expanduser("~/.wine-delphi3")
_REPO = Path(__file__).resolve().parents[2]
WX_DIR = _REPO / "data" / "agmerra-pascal-weather-africa-1980-2010"
ARM64_BIN = _REPO / "cassava" / "cassava"
DELPHI_CAP = Path(WINEPREFIX) / "drive_c/casgm/cassava.exe"
DELPHI_UNC = Path(WINEPREFIX) / "drive_c/casgmunc/cassava.exe"

PERIOD = ("01", "01", "1980", "12", "31", "1990")  # CM period
GIS_INTERVAL = "365"
RANDSEED = 1  # fixed -> deterministic (Delphi LCG; FPC rng unit emulates it)

SCEN = {
    "cm-only":  dict(cmb=True, fungi=False),
    "cm-fungi": dict(cmb=True, fungi=True),
}

def make_ini(cmb, fungi, randseed):
    tf = lambda b: "T" if b else "F"
    return f"""\
10    number of plants (also depends on 'varnplants' below)
1     distribution (1 in rows, 2 scattered)
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
{tf(cmb)}          \tinclude CMB (mealy bug) Phenacoccus manihoti
2         \tCMB ndelay
0.5        \tCMB beta
0.05  2.37  CMB rateem (from Fabres & Boussiengue, 1981) at 24 C dry season
68   \t   \tnr days after cas start for cmb start 07 19 1983 CMBSTART 
0.5        \tprobability each plant will get immigrants each day
0.5  80    \tmean nr to imm, %+- (i.e., 0.5 80 -> 0.1 to 0.9)
*********A. lopezi******************************
F       \tInclude parasite Epidinocarsis lopezi
25      \tlevel of mb larvae required to attract start of el immig.
0.05      \tprobability each plant will get immigrants each day
0.5  50   \tmean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
*********A. diversicornis***********************
F          \tInclude parasitoid Epidinocarsis diversicornis
25        \tlevel of mb larvae required to attract start of ed immig.
0.05      \t probability each plant will get immigrants each day
0.5  50    \tmean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
F        \tinclude Green Mite Mononychellus tanojoa
6 25 1980   GM START DATE
0.1       \tprobability each plant will get immigrants each day
0.05  50\tnumber to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
F       include gm pred1 T. aripo
0.05      total mass GM to attract p1 start
0.20      prob. each plant receives adult visitors daily after start 
F       include gm pred2 A. manihoti
0.3      total mass GM to attract p2 start
0.1      prob. each plant receives adult visitor daily after start 
**********************************************
F          include Coccid predator Hyperaspis jucunda (*** really slows program down)
001        HJ ndelay - days to stress
100.5      hjmblev - level of totcmb mass to start hj
0.05       prob. each plant get immig. each day
0.005 10   mean nr to imm, %+- (i.e., 0.5 50 -> 0.25 to 0.75)
**********************************************
{tf(fungi)}          include fungus mortality (rain mortality)
1\t      milsecdelay - slow program for graphics
2         immigmethod, 1 source unknown, 2 daily migrant pool
{randseed}         randseed {{if 0 then use different sequences each time, if >0 then use same sequence each time.}}
"""

def mean_tuber_excl_first(summ_path):
    ys = []
    with open(summ_path) as f:
        rd = csv.reader(f, delimiter="\t")
        next(rd, None)
        for row in rd:
            if len(row) < 16: continue
            try:
                y = int(float(row[10])); t = float(row[15])
            except: continue
            if t == 0.0: continue
            ys.append((y, t))
    ys.sort()
    ys = ys[1:]  # exclude first year
    return statistics.fmean(t for _, t in ys) if ys else 0.0

def run_one(args):
    build, exe, is_wine, scen_name, cmb, fungi, cell = args
    wx_src = WX_DIR / (cell + ".txt")
    if not wx_src.exists():
        return (build, scen_name, cell, None)
    d = tempfile.mkdtemp(prefix=f"gm_{build}_{scen_name}_")
    try:
        ini = make_ini(cmb, fungi, RANDSEED)
        # wx: CRLF for wine, LF fine for native (FPC handles both -> use as-is)
        wx_txt = wx_src.read_text()
        if is_wine:
            ini = ini.replace("\n", "\r\n")
            wx_txt = wx_txt.replace("\r\n", "\n").replace("\n", "\r\n")
        Path(d, "Cassava.ini").write_text(ini)
        Path(d, "wx.txt").write_text(wx_txt)
        cmd = ([ "wine", str(exe) ] if is_wine else [ str(exe) ]) + \
              [ "Cassava.ini", *PERIOD, GIS_INTERVAL, "wx.txt" ]
        env = dict(os.environ, WINEPREFIX=WINEPREFIX, WINEPATH=r"C:\Delphi30\BIN",
                   WINEDEBUG="-all", MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(cmd, cwd=d, env=env, capture_output=True, text=True, timeout=300)
        sp = Path(d, "CassavaSummaries.txt")
        val = mean_tuber_excl_first(sp) if sp.exists() else None
        return (build, scen_name, cell, val)
    except subprocess.TimeoutExpired:
        return (build, scen_name, cell, None)
    finally:
        shutil.rmtree(d, ignore_errors=True)

def main():
    cells = [c.strip() for c in open("/tmp/gm_cells.txt") if c.strip()]
    builds = [
        ("delphi_cap", DELPHI_CAP, True),
        ("delphi_unc", DELPHI_UNC, True),
        ("fpc_arm64",  ARM64_BIN,  False),
    ]
    tasks = []
    for bname, exe, is_wine in builds:
        for sname, sp in SCEN.items():
            for cell in cells:
                tasks.append((bname, exe, is_wine, sname, sp["cmb"], sp["fungi"], cell))
    print(f"Running {len(tasks)} tasks ({len(cells)} cells x {len(SCEN)} scen x {len(builds)} builds)...", flush=True)
    results = {}  # (build,scen,cell)->val
    done = 0
    with ProcessPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(run_one, t): t for t in tasks}
        for fu in as_completed(futs):
            b, s, c, v = fu.result()
            results[(b, s, c)] = v
            done += 1
            if done % 20 == 0 or done == len(tasks):
                print(f"  [{done}/{len(tasks)}]", flush=True)
    # write raw
    out = Path("/tmp/gm_compare_raw.csv")
    with open(out, "w") as f:
        w = csv.writer(f); w.writerow(["build","scenario","cell","mean_tuber"])
        for (b, s, c), v in sorted(results.items()):
            w.writerow([b, s, c, "" if v is None else f"{v:.4f}"])
    print(f"raw -> {out}")
    # analysis: per build, per-cell fungal rescue = cm-fungi - cm-only
    print("\n=== Per-cell fungal rescue (cm-fungi - cm-only), median over cells ===")
    summary = {}
    for bname, _, _ in builds:
        resc = []; pair_ok = 0
        for c in cells:
            o = results.get((bname, "cm-only", c))
            fu = results.get((bname, "cm-fungi", c))
            if o and fu and o > 0:
                resc.append(fu - o); pair_ok += 1
        if resc:
            summary[bname] = (statistics.median(resc), statistics.fmean(resc), pair_ok)
            print(f"  {bname:11s}: median rescue {statistics.median(resc):+8.1f}  "
                  f"mean {statistics.fmean(resc):+8.1f}  (n={pair_ok})")
    # fidelity: delphi_cap vs fpc_arm64 per-cell % diff
    print("\n=== Port fidelity: delphi_cap vs fpc_arm64 (precision eliminated) ===")
    for sname in SCEN:
        diffs = []
        for c in cells:
            dc = results.get(("delphi_cap", sname, c))
            fp = results.get(("fpc_arm64", sname, c))
            if dc and fp and dc > 0:
                diffs.append(abs(fp - dc) / dc * 100)
        if diffs:
            print(f"  {sname:9s}: median |Δ| {statistics.median(diffs):.3f}%  "
                  f"max |Δ| {max(diffs):.3f}%  (n={len(diffs)})")

if __name__ == "__main__":
    main()
