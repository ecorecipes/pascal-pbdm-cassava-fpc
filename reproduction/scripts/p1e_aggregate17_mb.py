import csv, os, shutil, subprocess, tempfile, statistics
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p1","scripts/p1_validate_paper_cells.py")
p1=importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
LEAF=14; TUBER=15
base=p1.SHIPPED_INI.read_text().splitlines()
MB={"include CMB (mealy bug)","Include parasite Epidinocarsis lopezi","Include parasitoid Epidinocarsis diversicornis"}
def make_ini(mb):
    lines=base[:]
    for i,ln in enumerate(lines):
        if "randseed {" in ln: lines[i]="0         "+ln.split(None,1)[1]
        if mb and any(k in ln for k in MB): lines[i]="T          \t"+ln.split(None,1)[1]
    return "\r\n".join(lines)+"\r\n"
def run(cell,mb):
    d=tempfile.mkdtemp(prefix="ag_")
    try:
        Path(d,"Cassava.ini").write_text(make_ini(mb))
        wx=(p1.WX_DIR/(cell+".txt")).read_text().replace("\r\n","\n").replace("\n","\r\n")
        Path(d,"wx.txt").write_text(wx)
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
cells=[f"agmerra_0001_{i}_DZA_NF" for i in range(217,250,2)]
def relerr(o,a):
    return abs(o-a)/a if a>1e-6 else (0 if o<1e-6 else 1)
for label,mb in (("MB-off (shipped ini)",False),("MB-on (paper run)",True)):
    le=[];te=[]
    for cell in cells:
        au=authors(cell); ou=run(cell,mb)
        for yr in (1981,1982,1983,1984,1985):
            if yr in au and yr in ou:
                le.append(relerr(ou[yr][0],au[yr][0])); te.append(relerr(ou[yr][1],au[yr][1]))
    print(f"{label:24s}  n={len(te)}  median tuber relerr={statistics.median(te):.2f}  mean={statistics.mean(te):.2f}  | leaf median={statistics.median(le):.2f}")
