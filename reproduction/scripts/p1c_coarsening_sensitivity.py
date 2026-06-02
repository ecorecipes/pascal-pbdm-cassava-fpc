import netCDF4, numpy as np, pathlib
C=str(pathlib.Path(__file__).resolve().parents[2]/"data"/"agmerra-cache")
def nearest(a,v): return int(np.abs(np.asarray(a)-v).argmin())
# test an inland cell too: pick cell 241 / 229 coords from weather files
CELLS={217:(0.125,35.875)}
# read coords for a few cells
import pathlib
WX=pathlib.Path(__file__).resolve().parents[2]/"data"/"agmerra-pascal-weather-africa-1980-2010"
for n in (229,241,249):
    lon,lat=open(WX/f"agmerra_0001_{n}_DZA_NF.txt").readlines()[1].split()
    CELLS[n]=(float(lon),float(lat))
def landmean(sub):  # sub: (time, ny, nx) masked
    flat=sub.reshape(sub.shape[0],-1)
    return np.ma.mean(flat,axis=1)
for n,(LON,LAT) in CELLS.items():
    print(f"--- cell {n}  ({LON},{LAT}) ---")
    for yr in (1981,1983):
        out=f"  {yr}: "
        for var in ("tmax","prate"):
            ds=netCDF4.Dataset(f"{C}/AgMERRA_{yr}_{var}.nc4")
            lats=ds.variables["latitude"][:]; lons=ds.variables["longitude"][:]
            li=nearest(lats,LAT); oi=nearest(lons,LON%360)
            d=ds.variables[var][:]
            nat=d[:,li,oi]
            h=2; sub=d[:,max(0,li-h):li+h+1,max(0,oi-h):oi+h+1]
            cm=landmean(sub)
            agg=(lambda x:float(np.ma.sum(x))) if var=="prate" else (lambda x:float(np.ma.mean(x)))
            nv=agg(nat); cv=agg(cm)
            dpct=(cv-nv)/nv*100 if nv else 0
            out+=f"{var} nat={nv:7.2f} 5x5={cv:7.2f} ({dpct:+5.1f}%)  "
            ds.close()
        print(out)
