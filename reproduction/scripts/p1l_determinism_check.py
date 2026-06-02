import csv, os, subprocess, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INI=ROOT/"reconstructed_ini/Cassava.full.ini"
PAPER=ROOT/"paper_zenodo"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WX=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"
PERIOD=("01","01","1980","12","31","1986")
cell="agmerra_0001_217_DZA_NF"
INI_TXT="\r\n".join(INI.read_text().splitlines())+"\r\n"
def run():
    d=tempfile.mkdtemp()
    Path(d,"Cassava.ini").write_text(INI_TXT)
    wx="\r\n".join((WX/(cell+".txt")).read_text().splitlines())+"\r\n"
    Path(d,"wx.txt").write_text(wx)
    env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
    subprocess.run(["wine",str(CAP),"Cassava.ini",*PERIOD,"365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
    out={}
    for gf in Path(d).glob("Cassava_*.txt"):
        fh=open(gf); rd=csv.reader(fh,delimiter="\t"); next(rd,None)
        for row in rd:
            if len(row)<41: continue
            out[int(row[10])]=[float(row[c]) for c in (14,15,26,33,35,38)]  # leaf,tuber,gmtot,mb5,ed1,el1
        fh.close()
    shutil.rmtree(d,ignore_errors=True)
    return out
r1=run(); r2=run()
print("DETERMINISM identical:", bool(r1) and all(r1[y]==r2[y] for y in r1), " nyears:",len(r1))
A={}
for f in sorted(PAPER.glob("Cassava_06Nov25_0000*.txt")):
    fh=open(f); rd=csv.reader(fh,delimiter="\t"); next(rd)
    for row in rd:
        if cell in row[3]: A[int(row[10])]=[float(row[c]) for c in (14,15,26,33,35,38)]
    fh.close()
print("\ncell 217 [leaf tuber gmtot mb5 ed1 el1]  A=authors M=full-ini")
for y in sorted(set(A)|set(r1)):
    if y in A: print(f"{y} A: "+" ".join(f"{x:9.3f}" for x in A[y]))
    if y in r1: print(f"{y} M: "+" ".join(f"{x:9.3f}" for x in r1[y]))
