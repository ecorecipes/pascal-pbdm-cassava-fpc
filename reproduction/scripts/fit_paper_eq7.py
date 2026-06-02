#!/usr/bin/env python3
"""
Fit the EXACT paper Eq. 7 CM regression to our cell-mean summaries and compare
fitted coefficients + marginal effects to the paper.

Paper Eq. 7 (CM subsystem):
  grams_root = 3464.8 - 1085 CM+ + 958.0 Al+ + 666.1 Ad+ + 378.2 P+
               - 687.9 Ad+Al+ - 260.5 Ad+P+ - 317.7 Al+P+ + 220.9 Ad+Al+P+
               R^2 = 0.171

Design (note: NO CM interaction terms; CM is main-effect only):
  predictors = [CM, Al, Ad, P, Ad*Al, Ad*P, Al*P, Ad*Al*P]

Reported marginals (derivative at empirical mean of OTHER dummies):
  dY/dAl+ = 575.8, dY/dAd+ = 233.1, dY/dP+ = 153.8, dY/dCM+ = -1085
"""
import csv
import pathlib
import sys

import numpy as np

HERE = pathlib.Path(__file__).parent
SUMM = HERE.parent / "summaries"
MASK = pathlib.Path.home() / "Projects" / "pbdm" / "data" / "cropgrids" / "cassava_africa_mask_agmerra.csv"

# scenario -> (CM, Al, Ad, P)
CM_SCENARIOS = {
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

PAPER = {
    "a": 3464.8, "CM": -1085.0, "Al": 958.0, "Ad": 666.1, "P": 378.2,
    "AdAl": -687.9, "AdP": -260.5, "AlP": -317.7, "AdAlP": 220.9,
}
PAPER_MARG = {"CM+": -1085.0, "Al+": 575.8, "Ad+": 233.1, "P+": 153.8}


def load_means(name):
    d = {}
    with open(SUMM / f"{name}.csv") as f:
        for row in csv.DictReader(f):
            try:
                d[row["_cell"]] = (float(row["tuber"]), float(row["Long"]), float(row["Lat"]))
            except (ValueError, KeyError):
                pass
    return d


def load_mask():
    coords = set()
    if MASK.exists():
        with open(MASK) as f:
            for row in csv.DictReader(f):
                coords.add((round(float(row["lon"]), 4), round(float(row["lat"]), 4)))
    return coords


def design_row(cm, al, ad, p):
    return [cm, al, ad, p, ad*al, ad*p, al*p, ad*al*p]


def main():
    mask = load_mask()
    data = {name: load_means(name) for name in CM_SCENARIOS}

    # Belt: cassava-only mean tuber > 1500 AND in cassava mask
    base = data["cassava-only"]
    belt = set()
    for cell, (tub, lon, lat) in base.items():
        if tub > 1500 and (not mask or (round(lon, 4), round(lat, 4)) in mask):
            belt.add(cell)
    print(f"Belt cells: {len(belt)}")

    # Build regression on cells where ALL 9 scenarios present
    Y, X = [], []
    dummies_used = []
    for cell in belt:
        if not all(cell in data[n] for n in CM_SCENARIOS):
            continue
        for name, (cm, al, ad, p) in CM_SCENARIOS.items():
            tub = data[name][cell][0]
            Y.append(tub)
            X.append(design_row(cm, al, ad, p))
            dummies_used.append((cm, al, ad, p))
    Y = np.array(Y)
    X = np.array(X, dtype=float)
    print(f"Observations: {len(Y)} ({len(Y)//9} complete cells x 9 scenarios)")

    Xf = np.hstack([np.ones((len(Y), 1)), X])
    beta, *_ = np.linalg.lstsq(Xf, Y, rcond=None)
    resid = Y - Xf @ beta
    r2 = 1.0 - np.sum(resid**2) / np.sum((Y - Y.mean())**2)

    names = ["a", "CM", "Al", "Ad", "P", "AdAl", "AdP", "AlP", "AdAlP"]
    print("\n=== Fitted Eq. 7 coefficients vs paper ===")
    print(f"{'term':<8}{'fitted':>12}{'paper':>12}{'ratio':>10}")
    for i, nm in enumerate(names):
        pv = PAPER[nm]
        ratio = beta[i] / pv if pv else float('nan')
        print(f"{nm:<8}{beta[i]:>12.1f}{pv:>12.1f}{ratio:>10.3f}")
    print(f"R^2 = {r2:.3f}  (paper 0.171)")

    # Marginals at empirical mean of OTHER dummies
    arr = np.array(dummies_used, dtype=float)  # columns CM,Al,Ad,P
    mCM, mAl, mAd, mP = arr.mean(axis=0)
    mAdP = (arr[:, 2] * arr[:, 3]).mean()
    mAlP = (arr[:, 1] * arr[:, 3]).mean()
    mAdAl = (arr[:, 2] * arr[:, 1]).mean()
    b = dict(zip(names, beta))
    # dY/dAl = b_Al + b_AdAl*E[Ad] + b_AlP*E[P] + b_AdAlP*E[Ad*P]
    marg = {
        "CM+": b["CM"],
        "Al+": b["Al"] + b["AdAl"]*mAd + b["AlP"]*mP + b["AdAlP"]*mAdP,
        "Ad+": b["Ad"] + b["AdAl"]*mAl + b["AdP"]*mP + b["AdAlP"]*mAlP,
        "P+":  b["P"]  + b["AdP"]*mAd  + b["AlP"]*mAl + b["AdAlP"]*mAdAl,
    }
    print(f"\nDummy means: CM={mCM:.3f} Al={mAl:.3f} Ad={mAd:.3f} P={mP:.3f}")
    print("=== Marginal effects vs paper ===")
    print(f"{'effect':<8}{'fitted':>12}{'paper':>12}")
    for k in ["CM+", "Al+", "Ad+", "P+"]:
        print(f"{k:<8}{marg[k]:>12.1f}{PAPER_MARG[k]:>12.1f}")
    tot = marg["Al+"] + marg["Ad+"] + marg["P+"]
    print(f"\nTotal recovery (Al+Ad+P) = {tot:.1f} g  (paper 962.7)")
    print(f"Recovery %% = {tot/abs(marg['CM+'])*100:.1f}%  (paper ~89%)")


if __name__ == "__main__":
    main()
