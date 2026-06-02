import numpy as np, netCDF4 as nc
from pathlib import Path
_REPO = Path(__file__).resolve().parents[2]
_DATA = _REPO / "data"
LATI, LONI = 216, 0  # cell 217
MJ2W = 1_000_000.0/86_400.0
wxf=str(_DATA/"agmerra-pascal-weather-africa-1980-2010"/"agmerra_0001_217_DZA_NF.txt")
# load my wx into dict by (m,d,y)
mine={}
for l in open(wxf):
    p=l.split()
    if len(p)<9 or not p[0].isdigit(): continue
    m,d,y=int(p[0]),int(p[1]),int(p[2])
    mine[(m,d,y)]=[float(x) for x in p[3:9]]  # tmax tmin solar rain rh wind
VAR=[("tmax",0.01,1),("tmin",0.01,1),("srad",0.01,MJ2W),("prate",0.1,1),("rhstmax",0.01,1),("wndspd",0.01,1)]
col=[0,1,2,3,4,5]  # tmax tmin solar rain rh wind order in mine
for yr in range(1980,1986):
    ds={v:nc.Dataset(str(_DATA/"agmerra-cache"/f"AgMERRA_{yr}_{v}.nc4")) for v,_,_ in VAR}
    ndays=ds["tmax"].variables["tmax"].shape[0]
    import datetime
    maxd=[0]*6
    for ti in range(ndays):
        dt=datetime.date(yr,1,1)+datetime.timedelta(days=ti)
        key=(dt.month,dt.day,yr)
        if key not in mine: continue
        for ci,(v,sc,conv) in enumerate(VAR):
            raw=float(ds[v].variables[v][ti,LATI,LONI])*conv  # maskandscale auto-applies scale
            mv=mine[key][ci]
            maxd[ci]=max(maxd[ci],abs(raw-mv))
    print(yr, " ".join(f"{VAR[i][0]}:{maxd[i]:.4f}" for i in range(6)))
    for v in ds.values(): v.close()
