import netCDF4, numpy as np, datetime, os, subprocess, tempfile, shutil, csv
from pathlib import Path
_REPO=Path(__file__).resolve().parents[2]
CACHE=_REPO/"data"/"agmerra-cache"
WXF=_REPO/"data"/"agmerra-pascal-weather-africa-1980-2010"/"agmerra_0001_217_DZA_NF.txt"
ROOT=_REPO/"reproduction"
INI=ROOT/"reconstructed_ini/Cassava.full.ini"
WP=os.path.expanduser("~/.wine-delphi3"); CAP=Path(WP)/"drive_c/casgm/cassava.exe"
INI_TXT="\r\n".join(INI.read_text().splitlines())+"\r\n"
AUTH={1981:88.402,1982:42.718,1983:264.899,1984:170.090,1985:120.553}
LAT_I,LON_I=216,0
YEARS=range(1980,1986)
# precompute coarsened prate per year for various block sizes
def block_avg(year,half):
    ds=netCDF4.Dataset(CACHE/f"AgMERRA_{year}_prate.nc4")
    g=ds.variables['prate'][:]  # (time,720,1440) scaled
    nt=g.shape[0]
    lat_lo=max(0,LAT_I-half); lat_hi=min(720,LAT_I+half+1)
    # longitude wraps
    lon_idx=[(LON_I+dx)%1440 for dx in range(-half,half+1)]
    sub=g[:,lat_lo:lat_hi,:][:,:,lon_idx]
    # mask fill (>500)
    sub=np.where(sub>500,np.nan,sub)
    out=np.nanmean(sub.reshape(nt,-1),axis=1)
    ds.close()
    return out  # per-day mean prate
# base wx lines
base=WXF.read_text().splitlines()
def make_wx(half):
    # build prate lookup per (year,doy)
    pr={y:block_avg(y,half) for y in YEARS}
    out=[]
    for i,l in enumerate(base):
        if i<3: out.append(l); continue
        p=l.split()
        if len(p)<9: out.append(l); continue
        y=int(p[2]); 
        if y in pr:
            dt=datetime.date(y,int(p[0]),int(p[1]))
            doy=(dt-datetime.date(y,1,1)).days
            arr=pr[y]
            if doy<len(arr):
                p[6]=f"{float(arr[doy]):.3f}"
        out.append(' '.join(p))
    return "\r\n".join(out)+"\r\n"
def run(wxtxt):
    d=tempfile.mkdtemp()
    Path(d,"Cassava.ini").write_text(INI_TXT); Path(d,"wx.txt").write_text(wxtxt)
    env=dict(os.environ,WINEPREFIX=WP,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
    subprocess.run(["wine",str(CAP),"Cassava.ini","01","01","1980","12","31","1985","365","wx.txt"],cwd=d,env=env,capture_output=True,text=True,timeout=300)
    res={}
    for gf in Path(d).glob("Cassava_*.txt"):
        fh=open(gf); rd=csv.reader(fh,delimiter="\t"); next(rd,None)
        for row in rd:
            if len(row)>=16: res[int(row[10])]=float(row[15])
        fh.close()
    shutil.rmtree(d,ignore_errors=True); return res
print("scheme       | t81   t82   t83   t84   t85  | mean|err|% (vs auth 88/43/265/170/121)")
def err(r):
    es=[abs(r.get(y,0)-AUTH[y])/AUTH[y]*100 for y in AUTH]
    return sum(es)/len(es)
# native baseline
rn=run(INI_TXT and "\r\n".join(base)+"\r\n")
print(f"native(1x1)  | {rn.get(1981,0):5.1f} {rn.get(1982,0):4.1f} {rn.get(1983,0):5.1f} {rn.get(1984,0):5.1f} {rn.get(1985,0):5.1f} | {err(rn):.1f}")
for half,name in [(1,"3x3"),(2,"5x5"),(4,"9x9")]:
    r=run(make_wx(half))
    print(f"{name:12s} | {r.get(1981,0):5.1f} {r.get(1982,0):4.1f} {r.get(1983,0):5.1f} {r.get(1984,0):5.1f} {r.get(1985,0):5.1f} | {err(r):.1f}")
