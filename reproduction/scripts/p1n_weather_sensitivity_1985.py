import csv, os, subprocess, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INI=ROOT/"reconstructed_ini/Cassava.full.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WXF=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"/"agmerra_0001_217_DZA_NF.txt"
INI_TXT="\r\n".join(INI.read_text().splitlines())+"\r\n"
AUTH={1981:88.402,1982:42.718,1983:264.899,1984:170.090,1985:120.553}
wxlines=WXF.read_text().splitlines()
def scale_wx(yr,col,f):
    out=[]
    for i,l in enumerate(wxlines):
        if i<3: out.append(l); continue
        p=l.split()
        if len(p)>=9 and (yr is None or int(p[2])==yr):
            p[col]=f"{float(p[col])*f:.3f}"
        out.append(' '.join(p))
    return "\r\n".join(out)+"\r\n"
def run(yr,col,f):
    d=tempfile.mkdtemp()
    Path(d,"Cassava.ini").write_text(INI_TXT); Path(d,"wx.txt").write_text(scale_wx(yr,col,f))
    env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
    subprocess.run(["wine",str(CAP),"Cassava.ini","01","01","1980","12","31","1985","365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
    res={}
    for gf in Path(d).glob("Cassava_*.txt"):
        fh=open(gf); rd=csv.reader(fh,delimiter="\t"); next(rd,None)
        for row in rd:
            if len(row)>=16: res[int(row[10])]=float(row[15])
        fh.close()
    shutil.rmtree(d,ignore_errors=True); return res
print("PRECIP 1985-only (1981-84 unchanged):  auth85=120.6")
print(" f85  | t85    85err%")
for f in (1.0,0.95,0.90,0.85,0.80):
    r=run(1985,6,f); e=(r.get(1985,0)-AUTH[1985])/AUTH[1985]*100
    print(f" {f:.2f} | {r.get(1985,0):5.1f}  {e:+6.1f}")
print("\nSOLAR all-years (col5) corrected:  auth85=120.6")
print(" fsol | t81   t82  t83   t84   t85   85err%")
for f in (1.0,1.10,0.90):
    r=run(None,5,f); e=(r.get(1985,0)-AUTH[1985])/AUTH[1985]*100
    print(f" {f:.2f} | {r.get(1981,0):5.1f} {r.get(1982,0):4.1f} {r.get(1983,0):5.1f} {r.get(1984,0):5.1f} {r.get(1985,0):5.1f}  {e:+6.1f}")
