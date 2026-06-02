import csv, os, shutil, subprocess, tempfile
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p1","scripts/p1_validate_paper_cells.py")
p1=importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
LEAF=14; TUBER=15
base=p1.SHIPPED_INI.read_text().splitlines()
FLAGS={"include CMB (mealy bug)":True,"Include parasite Epidinocarsis lopezi":True,
       "Include parasitoid Epidinocarsis diversicornis":True}
def make_ini(enable_mb):
    lines=base[:]
    for i,ln in enumerate(lines):
        if "randseed {" in ln:
            tail=ln.split(None,1)[1]; lines[i]=f"0         {tail}"
        if enable_mb:
            for key in FLAGS:
                if key in ln:
                    tail=ln.split(None,1)[1]; lines[i]=f"T          \t{tail}"
    return "\r\n".join(lines)+"\r\n"
def run(cell,enable_mb):
    d=tempfile.mkdtemp(prefix="fs_")
    try:
        Path(d,"Cassava.ini").write_text(make_ini(enable_mb))
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
for cell in ("agmerra_0001_217_DZA_NF","agmerra_0001_229_DZA_NF","agmerra_0001_241_DZA_NF","agmerra_0001_245_DZA_NF"):
    cid=cell.split('_')[2]; au=authors(cell); full=run(cell,True)
    print(f"\n=== {cid}  leaf/tuber  (full mealybug subsystem ON) ===")
    for yr in (1981,1982,1983,1984,1985):
        a=au.get(yr,(0,0)); f=full.get(yr,(0,0))
        print(f"  {yr}  authors {a[0]:7.2f}/{a[1]:7.1f}   ours {f[0]:7.2f}/{f[1]:7.1f}")
