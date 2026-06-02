#!/usr/bin/env python3
"""
Fit the paper's CM Eq. 7 to cell x year observations from the cache, under
several BELT-DEFINITION hypotheses, and compare each variant to the paper's
known anchors:

  Eq.1 means: CM=0.860, Al=0.533, Ad=0.386, P=0.499  ;  N ~ 350,451
  Eq.1 coeffs: a=3464.8 CM=-1085 Al=958.0 Ad=666.1 P=378.2
               AdAl=-687.9 AdP=-260.5 AlP=-317.7 AdAlP=220.9
  Eq.1 marginals: CM=-1085 Al=575.8 Ad=233.1 P=153.8

Paper drops the FIRST simulation year before analysis.
"""
import csv
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).parent
CACHE = HERE.parent / "cache" / "cellyear_cm.csv"
MASK = pathlib.Path.home() / "Projects" / "pbdm" / "data" / "cropgrids" / "cassava_africa_mask_agmerra.csv"

SCN = {  # scenario -> (CM, Al, Ad, P)
    "cassava-only":   (0, 0, 0, 0),
    "cm-only":        (1, 0, 0, 0),
    "cm-al":          (1, 1, 0, 0),
    "cm-ad":          (1, 0, 1, 0),
    "cm-al-ad":       (1, 1, 1, 0),
    "cm-fungi":       (1, 0, 0, 1),
    "cm-al-fungi":    (1, 1, 0, 1),
    "cm-ad-fungi":    (1, 0, 1, 1),
    "cm-al-ad-fungi": (1, 1, 1, 1),
}
SCN_IDX = {n: i for i, n in enumerate(SCN)}
DUM = np.array([SCN[n] for n in SCN], dtype=float)  # 9x4

PAPER = dict(a=3464.8, CM=-1085.0, Al=958.0, Ad=666.1, P=378.2,
             AdAl=-687.9, AdP=-260.5, AlP=-317.7, AdAlP=220.9)
PMEAN = dict(CM=0.860, Al=0.533, Ad=0.386, P=0.499)
PMARG = dict(CM=-1085.0, Al=575.8, Ad=233.1, P=153.8)
NAMES = ["a", "CM", "Al", "Ad", "P", "AdAl", "AdP", "AlP", "AdAlP"]


def load():
    rows = []
    with open(CACHE) as f:
        r = csv.reader(f)
        next(r)
        for s, cell, year, lon, lat, tub, *_ in r:
            rows.append((SCN_IDX[s], cell, int(year), float(lon), float(lat), float(tub)))
    scn = np.array([x[0] for x in rows], dtype=np.int8)
    cell = np.array([x[1] for x in rows])
    year = np.array([x[2] for x in rows], dtype=np.int16)
    lon = np.array([x[3] for x in rows])
    lat = np.array([x[4] for x in rows])
    tub = np.array([x[5] for x in rows])
    return scn, cell, year, lon, lat, tub


def load_mask():
    coords = set()
    if MASK.exists():
        with open(MASK) as f:
            for row in csv.DictReader(f):
                coords.add((round(float(row["lon"]), 4), round(float(row["lat"]), 4)))
    return coords


def design(scn):
    cm, al, ad, p = DUM[scn].T
    return np.column_stack([cm, al, ad, p, ad*al, ad*p, al*p, ad*al*p])


def fit(tub, scn, label):
    X = design(scn)
    Xf = np.column_stack([np.ones(len(tub)), X])
    beta, *_ = np.linalg.lstsq(Xf, tub, rcond=None)
    resid = tub - Xf @ beta
    ss_res = float(np.sum(resid**2))
    ss_tot = float(np.sum((tub - tub.mean())**2))
    r2 = 1 - ss_res/ss_tot if ss_tot else float('nan')
    n, k = len(tub), X.shape[1]
    f_stat = (r2/k) / ((1-r2)/(n-k-1)) if r2 < 1 else float('nan')
    b = dict(zip(NAMES, beta))
    mCM, mAl, mAd, mP = DUM[scn].mean(axis=0)
    marg = dict(
        CM=b["CM"],
        Al=b["Al"] + b["AdAl"]*mAd + b["AlP"]*mP + b["AdAlP"]*mAd*mP,
        Ad=b["Ad"] + b["AdAl"]*mAl + b["AdP"]*mP + b["AdAlP"]*mAl*mP,
        P=b["P"] + b["AdP"]*mAd + b["AlP"]*mAl + b["AdAlP"]*mAd*mAl,
    )
    print(f"\n===== {label} =====")
    percn = np.bincount(scn, minlength=9)
    print("  per-scenario rows: " + " ".join(
        f"{nm}={percn[i]}" for i, nm in enumerate(SCN)))
    print(f"N={n:,}  R2={r2:.3f} (paper .171)  F={f_stat:,.0f}")
    print(f"means  CM={mCM:.3f} Al={mAl:.3f} Ad={mAd:.3f} P={mP:.3f}"
          f"   paper CM=.860 Al=.533 Ad=.386 P=.499")
    print(f"{'term':<7}{'fit':>10}{'paper':>10}{'ratio':>8}")
    for nm in NAMES:
        pv = PAPER[nm]
        print(f"{nm:<7}{b[nm]:>10.1f}{pv:>10.1f}{b[nm]/pv:>8.2f}")
    print(f"{'marg':<7}{'fit':>10}{'paper':>10}{'ratio':>8}")
    for nm in ["CM", "Al", "Ad", "P"]:
        print(f"{nm:<7}{marg[nm]:>10.1f}{PMARG[nm]:>10.1f}{marg[nm]/PMARG[nm]:>8.2f}")
    return b, marg


def main():
    scn, cell, year, lon, lat, tub = load()
    print(f"Loaded {len(tub):,} cell-year rows; years {year.min()}-{year.max()}")

    keep = year > year.min()  # drop first year
    scn, cell, year, lon, lat, tub = (a[keep] for a in (scn, cell, year, lon, lat, tub))
    print(f"After dropping first year ({year.min()-1}): {len(tub):,} rows")

    mask = load_mask()
    in_mask = np.array([(round(lo, 4), round(la, 4)) in mask for lo, la in zip(lon, lat)]) if mask else np.ones(len(tub), bool)

    # ---- Variant A: per-row yield>1500 (no mask) ----
    a = tub > 1500
    fit(tub[a], scn[a], "A: per-row tuber>1500, no mask")

    # ---- Variant A2: per-row yield>1500 AND mask ----
    a2 = (tub > 1500) & in_mask
    fit(tub[a2], scn[a2], "A2: per-row tuber>1500 + mask")

    # ---- Variant B: per-scenario cell-mean>1500 (no mask) ----
    # belt membership depends on each scenario's own 10-yr cell mean
    keepB = np.zeros(len(tub), bool)
    for si in range(9):
        sm = scn == si
        cells_s = cell[sm]
        tub_s = tub[sm]
        # mean per cell
        order = np.argsort(cells_s)
        cs, ts = cells_s[order], tub_s[order]
        uniq, start = np.unique(cs, return_index=True)
        means = np.add.reduceat(ts, start) / np.diff(np.append(start, len(ts)))
        good = set(uniq[means > 1500])
        keepB[sm] = np.array([c in good for c in cell[sm]])
    fit(tub[keepB], scn[keepB], "B: per-scenario cell-mean>1500, no mask")

    # ---- Variant C: baseline (cassava-only) cell-mean>1500, fixed geographic belt ----
    sm = scn == SCN_IDX["cassava-only"]
    cs, ts = cell[sm], tub[sm]
    order = np.argsort(cs)
    cs, ts = cs[order], ts[order]
    uniq, start = np.unique(cs, return_index=True)
    means = np.add.reduceat(ts, start) / np.diff(np.append(start, len(ts)))
    belt_cells = set(uniq[means > 1500])
    keepC = np.array([c in belt_cells for c in cell])
    fit(tub[keepC], scn[keepC], "C: baseline cell-mean>1500 (fixed belt), no mask")
    keepC2 = keepC & in_mask
    fit(tub[keepC2], scn[keepC2], "C2: baseline cell-mean>1500 + mask")


if __name__ == "__main__":
    main()
