import os, subprocess, tempfile, shutil, statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
INI=ROOT/"reconstructed_ini/Cassava.full.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
WXF=ROOT.parent/"data"/"agmerra-pascal-weather-africa-1980-2010"/"agmerra_0001_217_DZA_NF.txt"
lines=INI.read_text().splitlines(); lines[53]='T'+lines[53][1:]
INI_TXT="\r\n".join(lines)+"\r\n"; WX_TXT="\r\n".join(WXF.read_text().splitlines())+"\r\n"
d=tempfile.mkdtemp()
Path(d,"Cassava.ini").write_text(INI_TXT); Path(d,"wx.txt").write_text(WX_TXT)
env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
subprocess.run(["wine",str(CAP),"Cassava.ini","01","01","1980","12","31","1985","365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
rows=Path(d,"CassavaDaily.txt").read_text().splitlines()[3:]
agg={}
for r in rows:
    p=r.split('\t')
    if len(p)<15: continue
    try: yr=int(p[0]); mo=int(p[2])
    except: continue
    agg.setdefault((yr,mo),[]).append((float(p[6]),float(p[7]),float(p[9]),float(p[10]),float(p[12])/10,float(p[14])/10))
for tgt in (1981,1982,1983,1984,1985):
    print(f"\n=== {tgt} ===  (sd/wsd: 1.0=no stress, lower=more stress)")
    print(" mo |  rain  leaf   tuber   resv  minResv   sd   wsd")
    for mo in range(1,13):
        v=agg.get((tgt,mo))
        if not v: continue
        rain=sum(x[0] for x in v); leaf=statistics.mean(x[1] for x in v); tub=statistics.mean(x[2] for x in v)
        resv=statistics.mean(x[3] for x in v); minr=min(x[3] for x in v); sd=statistics.mean(x[4] for x in v); wsd=statistics.mean(x[5] for x in v)
        print(f" {mo:2d} | {rain:5.0f} {leaf:6.2f} {tub:7.1f} {resv:6.2f} {minr:7.3f} {sd:5.2f} {wsd:5.2f}")
shutil.rmtree(d,ignore_errors=True)
