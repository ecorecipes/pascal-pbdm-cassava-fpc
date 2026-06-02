import csv, os, subprocess, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PAPER=ROOT/"paper_zenodo"; INI=PAPER/"Cassava.paper.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WX=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"
PERIOD=("01","01","1980","12","31","1985")
def build_ini(fungus=False, hyper=False):
    lines=INI.read_text().splitlines()
    for i,ln in enumerate(lines):
        if "include CMB (mealy bug)" in ln or "Include parasite Epidinocarsis lopezi" in ln or "Include parasitoid Epidinocarsis diversicornis" in ln:
            lines[i]=ln.replace("f","T",1)
        if "include fungus mortality" in ln and fungus:
            lines[i]=ln.replace("F","T",1)
        if "include Coccid predator Hyperaspis" in ln and hyper:
            lines[i]=ln.replace("F","T",1)
    return "\r\n".join(lines)+"\r\n"
def authors(cell):
    out={}
    for f in sorted(PAPER.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd=csv.reader(fh,delimiter="\t"); next(rd)
            for row in rd:
                if len(row)<16: continue
                if cell in row[3]: out[int(row[10])]=row
    return out
def run(cell,**kw):
    d=tempfile.mkdtemp()
    try:
        Path(d,"Cassava.ini").write_text(build_ini(**kw))
        wx=(WX/(cell+".txt")).read_text().replace("\r\n","\n").replace("\n","\r\n")
        Path(d,"wx.txt").write_text(wx)
        env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(["wine",str(CAP),"Cassava.ini",*PERIOD,"365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
        out={}
        for gf in Path(d).glob("Cassava_*.txt"):
            with open(gf) as fh:
                rd=csv.reader(fh,delimiter="\t"); next(rd,None)
                for row in rd:
                    if len(row)<16: continue
                    out[int(row[10])]=(float(row[14]),float(row[15]))  # leaf,tuber
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
cell="agmerra_0001_217_DZA_NF"
A=authors(cell)
print(f"cell 217  leaf/tuber  (authors | mbon | +fungus | +hyper | +both)")
base=run(cell); fg=run(cell,fungus=True); hy=run(cell,hyper=True); bo=run(cell,fungus=True,hyper=True)
for yr in [1981,1982,1983,1984,1985]:
    a=(float(A[yr][14]),float(A[yr][15]))
    print(f"  {yr} leaf : {a[0]:8.3f} | {base[yr][0]:8.3f} | {fg[yr][0]:8.3f} | {hy[yr][0]:8.3f} | {bo[yr][0]:8.3f}")
    print(f"  {yr} tuber: {a[1]:8.3f} | {base[yr][1]:8.3f} | {fg[yr][1]:8.3f} | {hy[yr][1]:8.3f} | {bo[yr][1]:8.3f}")
