import csv, os, subprocess, tempfile, shutil, statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INI=ROOT/"reconstructed_ini/Cassava.full.ini"; PAPER=ROOT/"paper_zenodo"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WX=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"
PERIOD=("01","01","1980","12","31","1985")
CELLS=[f"agmerra_0001_{n}_DZA_NF" for n in range(217,250,2)]
INI_TXT="\r\n".join(INI.read_text().splitlines())+"\r\n"
def run(cell):
    d=tempfile.mkdtemp()
    Path(d,"Cassava.ini").write_text(INI_TXT)
    Path(d,"wx.txt").write_text("\r\n".join((WX/(cell+".txt")).read_text().splitlines())+"\r\n")
    env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
    subprocess.run(["wine",str(CAP),"Cassava.ini",*PERIOD,"365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
    out={}
    for gf in Path(d).glob("Cassava_*.txt"):
        fh=open(gf); rd=csv.reader(fh,delimiter="\t"); next(rd,None)
        for row in rd:
            if len(row)<41: continue
            out[int(row[10])]=(float(row[14]),float(row[15]),float(row[38]))
        fh.close()
    shutil.rmtree(d,ignore_errors=True); return out
A={}
for f in sorted(PAPER.glob("Cassava_06Nov25_0000*.txt")):
    fh=open(f); rd=csv.reader(fh,delimiter="\t"); next(rd)
    for row in rd:
        if len(row)<41: continue
        A[(row[3].split("\\")[-1].replace(".txt",""),int(row[10]))]=(float(row[14]),float(row[15]),float(row[38]))
    fh.close()
peryr={y:{'leaf':[],'tuber':[],'el1':[]} for y in (1981,1982,1983,1984,1985)}
for cell in CELLS:
    r=run(cell)
    for y in peryr:
        k=(cell,y)
        if k in A and y in r:
            a=A[k]; m=r[y]
            if a[1]>1: peryr[y]['tuber'].append(abs(m[1]-a[1])/a[1]*100)
            if a[0]>0.1: peryr[y]['leaf'].append(abs(m[0]-a[0])/a[0]*100)
            if a[2]>1: peryr[y]['el1'].append(abs(m[2]-a[2])/a[2]*100)
print("year |  med tuber% | med leaf% | med el1(lopezi)%")
for y in sorted(peryr):
    d=peryr[y]
    mt=statistics.median(d['tuber']) if d['tuber'] else float('nan')
    ml=statistics.median(d['leaf']) if d['leaf'] else float('nan')
    me=statistics.median(d['el1']) if d['el1'] else float('nan')
    print(f"{y} |  {mt:9.1f} | {ml:8.1f} | {me:8.1f}   (n={len(d['tuber'])})")
allt=[e for y in peryr for e in peryr[y]['tuber']]
print(f"\nALL years median tuber%: {statistics.median(allt):.1f}  (n={len(allt)})")
t8184=[e for y in (1981,1982,1983,1984) for e in peryr[y]['tuber']]
print(f"1981-1984 median tuber%: {statistics.median(t8184):.1f}  (n={len(t8184)})")
