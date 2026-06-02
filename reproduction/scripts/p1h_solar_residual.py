"""p1h: confirms the residual is SOLAR radiation (Delphi golden master, MB-ON, cell 245).

Scales solar (idx5) and RH (idx7) in the wx file and compares leaf / sdlsr / evapsoil
to the authors. Result (REPORT.md Finding 7): authors leaf (33.3) lies between our
solar x1.0 (30.4) and x1.1 (37.6); solar x1.1 makes the leaf supply/demand index
sdlsr match the authors EXACTLY (0.07/0.2/0.2) while evapsoil stays matched across
all solar scalings -> our AgMERRA solar reconstruction is ~5-8% low at this cell.
RH has only a tiny effect. Confirms residual = solar/RH input reconstruction, not
precip/coarsening/code. Run from reproduction/ with the netCDF venv python.
"""

import csv, os, shutil, subprocess, tempfile
from pathlib import Path
import importlib.util
spec=importlib.util.spec_from_file_location("p1","scripts/p1_validate_paper_cells.py")
p1=importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
base=p1.SHIPPED_INI.read_text().splitlines()
FLAGS=["include CMB (mealy bug)","Include parasite Epidinocarsis lopezi","Include parasitoid Epidinocarsis diversicornis"]
COLS={"leaf":14,"tuber":15,"sdlsr":17,"evapsoil":22,"avgev":24}
def make_ini():
    lines=base[:]
    for i,ln in enumerate(lines):
        if "randseed {" in ln:
            tail=ln.split(None,1)[1]; lines[i]=f"0         {tail}"
        for key in FLAGS:
            if key in ln:
                tail=ln.split(None,1)[1]; lines[i]=f"T          \t{tail}"
    return "\r\n".join(lines)+"\r\n"
def scale_wx(text,sf,rf):
    lines=text.replace("\r\n","\n").split("\n"); out=lines[:3]
    for ln in lines[3:]:
        p=ln.split()
        if len(p)>=9:
            p[5]=f"{float(p[5])*sf:.3f}"   # solar idx5
            p[7]=f"{min(float(p[7])*rf,100.0):.3f}"  # rh idx7
            out.append(" ".join(p))
        elif ln.strip(): out.append(ln)
    return "\r\n".join(out)+"\r\n"
def run(cell,sf,rf):
    d=tempfile.mkdtemp(prefix="so_")
    try:
        Path(d,"Cassava.ini").write_text(make_ini())
        raw=(p1.WX_DIR/(cell+".txt")).read_text()
        Path(d,"wx.txt").write_text(scale_wx(raw,sf,rf))
        env=dict(os.environ,WINEPREFIX=p1.WINEPREFIX,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(["wine",str(p1.DELPHI_CAP),"Cassava.ini","01","01","1980","12","31","1985",p1.GIS_INTERVAL,"wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
        out={}
        for gf in Path(d).glob("Cassava_*.txt"):
            with open(gf) as fh:
                rd=csv.reader(fh,delimiter='\t'); next(rd,None)
                for r in rd:
                    if len(r)>24:
                        try: out[int(r[10])]={k:float(r[i]) for k,i in COLS.items()}
                        except: pass
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
def authors(cell):
    out={}
    for f in sorted(p1.PAPER_DIR.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd=csv.reader(fh,delimiter='\t'); next(rd,None)
            for r in rd:
                if len(r)>24 and p1.cell_of(r[3])==cell:
                    try: out[int(r[10])]={k:float(r[i]) for k,i in COLS.items()}
                    except: pass
    return out
cell="agmerra_0001_245_DZA_NF"; au=authors(cell)
print("cell 245 MB-on: authors leaf vs solar/RH-scaled (evapsoil in parens)")
scenarios=[("solar x1.0",1.0,1.0),("solar x1.1",1.1,1.0),("solar x1.2",1.2,1.0),("RH x1.1",1.0,1.1),("RH x1.2",1.0,1.2)]
res={name:run(cell,sf,rf) for name,sf,rf in scenarios}
for yr in (1981,1983,1985):
    a=au.get(yr,{})
    print(f"\n {yr}: A leaf={a.get('leaf'):.2f} evapsoil={a.get('evapsoil'):.3f} sdlsr={a.get('sdlsr')}")
    for name,_,_ in scenarios:
        o=res[name].get(yr,{})
        print(f"    {name:11s} leaf={o.get('leaf'):6.2f} (evap={o.get('evapsoil'):.3f}, sdlsr={o.get('sdlsr')})")
