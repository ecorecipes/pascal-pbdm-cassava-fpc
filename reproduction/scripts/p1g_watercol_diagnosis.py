"""p1g: water-column diagnostic that RETRACTS the precip story (Delphi golden master, MB-ON).

Compares authors vs ours at native precip (x1) and quarter precip (x0.25) for the
soil-water columns (evapsoil, avgev, fielddem, wvgwd, sdlsr, nsdlsr, wsd) plus
leaf/tuber, cells 245 and 217.

Result (REPORT.md Finding 7): at cell 245 our NATIVE precip reproduces the authors'
evapsoil/avgev bit-for-bit; x0.25 makes the water balance worse. => precip is
already correct and the Finding-6 ''x0.25 leaf match'' was a compensating
coincidence. The true residual is solar/RH (leaf supply/demand sdlsr differs while
water matches). Coarsening per the manuscript is checkerboard cell-selection
(''10,172 cells in alternating latitude-longitude''), not weather averaging.
Run from reproduction/ with the netCDF venv python.
"""

import csv, os, shutil, subprocess, tempfile
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p1","scripts/p1_validate_paper_cells.py")
p1=importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
base=p1.SHIPPED_INI.read_text().splitlines()
FLAGS=["include CMB (mealy bug)","Include parasite Epidinocarsis lopezi","Include parasitoid Epidinocarsis diversicornis"]
# 0-based indices
COLS={"leaf":14,"tuber":15,"sdlsr":17,"nsdlsr":18,"wsd":19,"lai":21,
      "evapsoil":22,"fielddem":23,"avgev":24,"wvgwd":25}
def make_ini():
    lines=base[:]
    for i,ln in enumerate(lines):
        if "randseed {" in ln:
            tail=ln.split(None,1)[1]; lines[i]=f"0         {tail}"
        for key in FLAGS:
            if key in ln:
                tail=ln.split(None,1)[1]; lines[i]=f"T          \t{tail}"
    return "\r\n".join(lines)+"\r\n"
def scale_wx(text,factor):
    lines=text.replace("\r\n","\n").split("\n"); out=lines[:3]
    for ln in lines[3:]:
        p=ln.split()
        if len(p)>=9:
            p[6]=f"{float(p[6])*factor:.3f}"; out.append(" ".join(p))
        elif ln.strip(): out.append(ln)
    return "\r\n".join(out)+"\r\n"
def rowvals(r):
    d={}
    for n,i in COLS.items():
        try: d[n]=float(r[i])
        except: d[n]=None
    return d
def run(cell,factor):
    d=tempfile.mkdtemp(prefix="wc_")
    try:
        Path(d,"Cassava.ini").write_text(make_ini())
        raw=(p1.WX_DIR/(cell+".txt")).read_text()
        Path(d,"wx.txt").write_text(scale_wx(raw,factor))
        env=dict(os.environ,WINEPREFIX=p1.WINEPREFIX,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(["wine",str(p1.DELPHI_CAP),"Cassava.ini","01","01","1980","12","31","1985",p1.GIS_INTERVAL,"wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
        out={}
        for gf in Path(d).glob("Cassava_*.txt"):
            with open(gf) as fh:
                rd=csv.reader(fh,delimiter='\t'); next(rd,None)
                for r in rd:
                    if len(r)>25:
                        try: out[int(r[10])]=rowvals(r)
                        except: pass
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
def authors(cell):
    out={}
    for f in sorted(p1.PAPER_DIR.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd=csv.reader(fh,delimiter='\t'); next(rd,None)
            for r in rd:
                if len(r)>25 and p1.cell_of(r[3])==cell:
                    try: out[int(r[10])]=rowvals(r)
                    except: pass
    return out
for cell in ("agmerra_0001_245_DZA_NF","agmerra_0001_217_DZA_NF"):
    cid=cell.split('_')[2]; au=authors(cell)
    x1=run(cell,1.0); x025=run(cell,0.25)
    print(f"\n===== cell {cid}: A=authors  N=ours(x1 native)  Q=ours(x0.25) =====")
    for yr in (1981,1983,1985):
        print(f" -- {yr} --")
        a=au.get(yr,{}); n=x1.get(yr,{}); q=x025.get(yr,{})
        for k in COLS:
            print(f"   {k:9s} A={a.get(k)!s:>9}  N={n.get(k)!s:>9}  Q={q.get(k)!s:>9}")
