"""p1f: precip-residual sweep WITH the mealybug subsystem ON (Delphi golden master).

Resolves the ~16% residual left after Finding 5 (MB-on). Scales the rain column
by {0.25,1,2,4} for cells 217 (coastal), 241 & 245 (desert) and compares leaf/tuber
to the authors' shipped outputs.

Result (REPORT.md Finding 6): no uniform factor works -- wet coastal cell 217
wants x1.0, dry desert cells 241/245 want x0.25 (cell 245 near-exact, <0.1% leaf).
That cell-dependence is the spatial-coarsening fingerprint: our native AgMERRA
over-rains dry cells ~4x vs the authors' coarse product. Corroborates
casas-gis .../DivPrcpBy4.pl. Run from reproduction/ with the netCDF venv python.
"""

import csv, os, shutil, subprocess, tempfile
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p1","scripts/p1_validate_paper_cells.py")
p1=importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
base=p1.SHIPPED_INI.read_text().splitlines()
FLAGS=["include CMB (mealy bug)","Include parasite Epidinocarsis lopezi","Include parasitoid Epidinocarsis diversicornis"]
LEAF,TUBER=14,15
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
    lines=text.replace("\r\n","\n").split("\n")
    out=lines[:3]
    for ln in lines[3:]:
        p=ln.split()
        if len(p)>=9:
            p[6]=f"{float(p[6])*factor:.3f}"
            out.append(" ".join(p))
        elif ln.strip():
            out.append(ln)
    return "\r\n".join(out)+"\r\n"
def run(cell,factor):
    d=tempfile.mkdtemp(prefix="rm_")
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
                    if len(r)>15:
                        try: out[int(r[10])]=(float(r[LEAF]),float(r[TUBER]))
                        except: pass
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
def authors(cell):
    out={}
    for f in sorted(p1.PAPER_DIR.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd=csv.reader(fh,delimiter='\t'); next(rd,None)
            for r in rd:
                if len(r)>15 and p1.cell_of(r[3])==cell:
                    try: out[int(r[10])]=(float(r[LEAF]),float(r[TUBER]))
                    except: pass
    return out
factors=[0.25,1.0,2.0,4.0]
for cell in ("agmerra_0001_217_DZA_NF","agmerra_0001_241_DZA_NF","agmerra_0001_245_DZA_NF"):
    cid=cell.split('_')[2]; au=authors(cell)
    runs={f:run(cell,f) for f in factors}
    print(f"\n=== cell {cid}  leaf(authors vs precip-scaled) ===")
    for yr in (1981,1983,1985):
        a=au.get(yr,(0,0))
        s=" ".join(f"x{f}:{runs[f].get(yr,(0,0))[0]:6.2f}" for f in factors)
        print(f"  {yr} A_leaf={a[0]:6.2f} | {s}")
    print(f"  -- tuber --")
    for yr in (1981,1983,1985):
        a=au.get(yr,(0,0))
        s=" ".join(f"x{f}:{runs[f].get(yr,(0,0))[1]:7.1f}" for f in factors)
        print(f"  {yr} A_tub ={a[1]:6.1f} | {s}")
