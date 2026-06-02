import csv, os, subprocess, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INI=ROOT/"reconstructed_ini/Cassava.full.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WXF=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"/"agmerra_0001_217_DZA_NF.txt"
INI_TXT="\r\n".join(INI.read_text().splitlines())+"\r\n"
WX_TXT="\r\n".join(WXF.read_text().splitlines())+"\r\n"
AUTH={1981:(0.969,88.402),1982:(0.829,42.718),1983:(9.626,264.899),1984:(5.743,170.090),1985:(2.849,120.553),1986:(0.0,0.0)}
def run(period):
    d=tempfile.mkdtemp()
    Path(d,"Cassava.ini").write_text(INI_TXT)
    Path(d,"wx.txt").write_text(WX_TXT)
    env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
    subprocess.run(["wine",str(CAP),"Cassava.ini",*period,"365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
    res={}
    for gf in Path(d).glob("Cassava_*.txt"):
        fh=open(gf); rd=csv.reader(fh,delimiter="\t"); next(rd,None)
        for row in rd:
            if len(row)>=16:
                res[int(row[10])]=(int(row[8]),int(row[9]),float(row[14]),float(row[15]))
        fh.close()
    shutil.rmtree(d,ignore_errors=True); return res
for label,period in [("end1985",("01","01","1980","12","31","1985")),
                     ("end1986",("01","01","1980","12","31","1986"))]:
    r=run(period)
    print(f"\n=== {label} ===")
    print("year | mon day | leaf      tuber    | auth leaf  auth tuber | tuber%")
    for y in sorted(r):
        mo,dy,lf,tb=r[y]
        a=AUTH.get(y)
        te=f"{(tb-a[1])/a[1]*100:+6.1f}" if (a and a[1]>0) else "   -- "
        al=f"{a[0]:.3f}" if a else "  -- "
        at=f"{a[1]:.3f}" if a else "  -- "
        print(f"{y} | {mo:2d} {dy:2d}  | {lf:8.3f} {tb:9.3f} | {al:>8}  {at:>9} | {te}")
