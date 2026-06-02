import csv, os, subprocess, tempfile, shutil, statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PAPER=ROOT/"paper_zenodo"; INI=PAPER/"Cassava.paper.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WX=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"
PERIOD=("01","01","1980","12","31","1985")
CELLS=[f"agmerra_0001_{n}_DZA_NF" for n in range(217,250,2)]
def build_ini(fungus):
    lines=INI.read_text().splitlines()
    for i,ln in enumerate(lines):
        if "include CMB (mealy bug)" in ln or "Epidinocarsis lopezi" in ln or "Epidinocarsis diversicornis" in ln:
            lines[i]=ln.replace("f","T",1)
        if "include fungus mortality" in ln and fungus:
            lines[i]=ln.replace("F","T",1)
    return "\r\n".join(lines)+"\r\n"
def authors():
    out={}
    for f in sorted(PAPER.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh:
            rd=csv.reader(fh,delimiter="\t"); next(rd)
            for row in rd:
                if len(row)<16: continue
                out[(row[3].split("\\")[-1].replace(".txt",""),int(row[10]))]=(float(row[14]),float(row[15]))
    return out
def run(cell,fungus):
    d=tempfile.mkdtemp()
    try:
        Path(d,"Cassava.ini").write_text(build_ini(fungus))
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
                    out[int(row[10])]=(float(row[14]),float(row[15]))
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
A=authors()
for fungus in (False,True):
    lerr=[]; terr=[]
    for cell in CELLS:
        r=run(cell,fungus)
        for yr in [1981,1982,1983,1984,1985]:
            key=(cell,yr)
            if key in A and yr in r:
                al,at=A[key]; ml,mt=r[yr]
                if at>1: terr.append(abs(mt-at)/at*100)
                if al>0.1: lerr.append(abs(ml-al)/al*100)
    tag="MB+fungus ON" if fungus else "MB ON only"
    print(f"{tag:14s}: median tuber err={statistics.median(terr):5.1f}%  median leaf err={statistics.median(lerr):5.1f}%  (n={len(terr)})")
