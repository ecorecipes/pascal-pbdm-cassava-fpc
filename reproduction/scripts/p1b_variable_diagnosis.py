import csv, os, shutil, subprocess, tempfile
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location("p1", "scripts/p1_validate_paper_cells.py")
p1 = importlib.util.module_from_spec(spec); spec.loader.exec_module(p1)
PAPER_DIR = p1.PAPER_DIR
# cols: dd11 root12 stem13 leaf14 tuber15 leafnum16 ... lai21 ... gmtot26 TariNum27 TManNum28
IDX={"dd":11,"leaf":14,"tuber":15,"lai":21,"gmtot":26,"tari":27}
def parse(fh):
    out={}; rd=csv.reader(fh,delimiter="\t"); next(rd,None)
    for r in rd:
        if len(r)<=28: continue
        try:
            cell=p1.cell_of(r[3]); yr=int(r[10])
            out[(cell,yr)]={k:float(r[i]) for k,i in IDX.items()}
        except: pass
    return out
def parse_authors():
    out={}
    for f in sorted(PAPER_DIR.glob("Cassava_06Nov25_0000*.txt")):
        with open(f) as fh: out.update(parse(fh))
    return out
def run(cell):
    d=tempfile.mkdtemp(prefix="v_")
    try:
        Path(d,"Cassava.ini").write_text(p1.make_ini(0))
        wx=(p1.WX_DIR/(cell+".txt")).read_text().replace("\r\n","\n").replace("\n","\r\n")
        Path(d,"wx.txt").write_text(wx)
        cmd=["wine",str(p1.DELPHI_CAP),"Cassava.ini",*p1.PERIOD,p1.GIS_INTERVAL,"wx.txt"]
        env=dict(os.environ,WINEPREFIX=p1.WINEPREFIX,WINEPATH=r"C:\Delphi30\BIN",WINEDEBUG="-all",MVK_CONFIG_LOG_LEVEL="0")
        subprocess.run(cmd,cwd=d,env=env,capture_output=True,text=True,timeout=300)
        out={}
        for gf in Path(d).glob("Cassava_*.txt"):
            with open(gf) as fh:
                for (c,yr),v in parse(fh).items(): out[yr]=v
        return out
    finally: shutil.rmtree(d,ignore_errors=True)
auth=parse_authors()
hdr=["dd","leaf","lai","gmtot","tari","tuber"]
print("cell yr  "+" ".join(f"{h+'_a':>9s} {h+'_o':>9s}" for h in hdr))
for n in (217,229):
    cell=f"agmerra_0001_{n}_DZA_NF"; our=run(cell)
    for yr in (1981,1983,1985):
        da=auth.get((cell,yr)); do=our.get(yr)
        if da and do:
            print(f"{n} {yr} "+" ".join(f"{da[h]:9.2f} {do[h]:9.2f}" for h in hdr))
