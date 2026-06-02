"""
Test whether the CM marginal-effect discrepancy is a regression-DESIGN artifact.

Hypothesis: the current analysis includes the cassava-only (CM+=0) baseline plus a
CM+ dummy plus all pairwise interactions. Because agents (Al, Ad, P) only ever
appear WITH CM, columns like Al+ and Al+xCM+ are perfectly collinear, so lstsq
splits the combined effect arbitrarily and the marginal-effect formula inflates
Al+/Ad+. The paper instead regresses the agent factorial within CM-present
scenarios (CM constant, absorbed into intercept).

Method A: current design (cassava-only baseline + CM+ dummy + all interactions).
Method B: CM-present scenarios only; regress on Al+/Ad+/P+ factorial + interactions.
Method C: simple balanced contrasts (mean-of-means over the factorial).
"""
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from analyze_results import load_scenario, cell_in_cassava_mask  # noqa

BASE = Path(__file__).resolve().parent.parent
SUM = BASE / "summaries"

PAPER = {'CM+': -1085.0, 'Al+': 575.8, 'Ad+': 233.1, 'P+': 153.8}

CM_DUMMIES = {
    'cassava-only':   {'CM+': 0, 'Al+': 0, 'Ad+': 0, 'P+': 0},
    'cm-only':        {'CM+': 1, 'Al+': 0, 'Ad+': 0, 'P+': 0},
    'cm-fungi':       {'CM+': 1, 'Al+': 0, 'Ad+': 0, 'P+': 1},
    'cm-al':          {'CM+': 1, 'Al+': 1, 'Ad+': 0, 'P+': 0},
    'cm-al-fungi':    {'CM+': 1, 'Al+': 1, 'Ad+': 0, 'P+': 1},
    'cm-ad':          {'CM+': 1, 'Al+': 0, 'Ad+': 1, 'P+': 0},
    'cm-ad-fungi':    {'CM+': 1, 'Al+': 0, 'Ad+': 1, 'P+': 1},
    'cm-al-ad':       {'CM+': 1, 'Al+': 1, 'Ad+': 1, 'P+': 0},
    'cm-al-ad-fungi': {'CM+': 1, 'Al+': 1, 'Ad+': 1, 'P+': 1},
}


def load_all():
    data = {}
    for name in CM_DUMMIES:
        rows = load_scenario(SUM, name)
        d = {}
        for r in rows:
            d[r['_cell']] = r
        data[name] = d
    return data


def belt_cells(data):
    co = data['cassava-only']
    belt = set()
    for cell, r in co.items():
        if r.get('tuber', 0) > 1500 and cell_in_cassava_mask(r):
            belt.add(cell)
    # restrict to cells present in ALL scenarios (balanced design)
    for name in CM_DUMMIES:
        belt &= set(data[name].keys())
    # drop cells with implausible (blown-up) tuber in any scenario
    good = set()
    for cell in belt:
        ok = True
        for name in CM_DUMMIES:
            v = data[name][cell]['tuber']
            if not (-100.0 <= v <= 20000.0):
                ok = False
                break
        if ok:
            good.add(cell)
    return good


def fit(X, Y, names):
    Xfull = np.column_stack([np.ones(len(Y))] + [X[:, i] for i in range(X.shape[1])])
    col = ['intercept'] + list(names)
    k = X.shape[1]
    for i in range(k):
        for j in range(i + 1, k):
            Xfull = np.column_stack([Xfull, X[:, i] * X[:, j]])
            col.append(f"{names[i]}x{names[j]}")
    beta, *_ = np.linalg.lstsq(Xfull, Y, rcond=None)
    return beta, col


def marginal(beta, col, names, X):
    means = {n: np.mean(X[:, i]) for i, n in enumerate(names)}
    out = {}
    for t in names:
        eff = 0.0
        for cn, b in zip(col, beta):
            if cn == t:
                eff += b
            elif 'x' in cn:
                parts = cn.split('x')
                if t in parts:
                    other = parts[0] if parts[1] == t else parts[1]
                    eff += b * means.get(other, 0)
        out[t] = eff
    return out, means


def build(data, belt, scen_names, dummy_keys):
    Y, X = [], []
    for name in scen_names:
        d = CM_DUMMIES[name]
        for cell in belt:
            Y.append(data[name][cell]['tuber'])
            X.append([d[k] for k in dummy_keys])
    return np.array(Y, float), np.array(X, float)


def main():
    data = load_all()
    belt = belt_cells(data)
    print(f"Balanced belt cells: {len(belt)}\n")

    # ----- Method A: current full design -----
    keysA = ['Ad+', 'Al+', 'CM+', 'P+']
    Y, X = build(data, belt, list(CM_DUMMIES.keys()), keysA)
    beta, col = fit(X, Y, keysA)
    margA, _ = marginal(beta, col, keysA, X)

    # ----- Method B: CM-present only, agent factorial -----
    cm_present = [n for n in CM_DUMMIES if n != 'cassava-only']
    keysB = ['Ad+', 'Al+', 'P+']
    Yb, Xb = build(data, belt, cm_present, keysB)
    betaB, colB = fit(Xb, Yb, keysB)
    margB, _ = marginal(betaB, colB, keysB, Xb)
    # CM+ effect = cassava-only mean - mean over cm-present scenarios baseline (cm-only)
    co_mean = np.mean([data['cassava-only'][c]['tuber'] for c in belt])
    cmonly_mean = np.mean([data['cm-only'][c]['tuber'] for c in belt])
    margB['CM+'] = cmonly_mean - co_mean

    # ----- Method C: simple balanced main-effect contrasts (within CM-present) -----
    def contrast(agent):
        on = [n for n in cm_present if CM_DUMMIES[n][agent] == 1]
        off = [n for n in cm_present if CM_DUMMIES[n][agent] == 0]
        on_m = np.mean([data[n][c]['tuber'] for n in on for c in belt])
        off_m = np.mean([data[n][c]['tuber'] for n in off for c in belt])
        return on_m - off_m
    margC = {a: contrast(a) for a in ['Al+', 'Ad+', 'P+']}
    margC['CM+'] = cmonly_mean - co_mean

    print(f"{'Effect':6} | {'Paper':>8} | {'A:current':>10} | {'B:CMpresent':>12} | {'C:contrast':>11}")
    print("-" * 60)
    for e in ['CM+', 'Al+', 'Ad+', 'P+']:
        print(f"{e:6} | {PAPER[e]:8.1f} | {margA.get(e,0):10.1f} | "
              f"{margB.get(e,0):12.1f} | {margC.get(e,0):11.1f}")
    print()
    for label, m in [('A', margA), ('B', margB), ('C', margC)]:
        rec = m.get('Al+',0)+m.get('Ad+',0)+m.get('P+',0)
        print(f"Method {label}: total recovery (Al+Ad+P) = {rec:.1f} g  "
              f"(paper {sum(v for k,v in PAPER.items() if k!='CM+'):.1f})")


if __name__ == '__main__':
    main()
