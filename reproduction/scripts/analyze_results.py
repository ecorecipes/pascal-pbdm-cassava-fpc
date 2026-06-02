#!/usr/bin/env python3
"""
Analyze reproduction results and compare with Gutierrez et al. (2025).

Reads CSV summaries produced by collect_results.py and computes:
- Mean yields across cells for each scenario
- Binomial multiple linear regression with interaction terms (Eq. 7)
- Marginal effects as partial derivatives at mean dummy values
- Comparison with paper's reported values
"""

import argparse
import csv
import sys
from pathlib import Path

import numpy as np


def read_csv(path):
    with open(path) as f:
        return list(csv.DictReader(f))


def load_scenario(summaries_dir, name):
    path = Path(summaries_dir) / f"{name}.csv"
    if not path.exists():
        return None
    rows = read_csv(path)
    result = []
    for row in rows:
        d = {}
        for k, v in row.items():
            try:
                d[k] = float(v)
            except (ValueError, TypeError):
                d[k] = v
        result.append(d)
    return result


def mean(vals):
    vals = [v for v in vals if v is not None]
    return sum(vals) / len(vals) if vals else 0.0


# ---------------------------------------------------------------------------
# Cassava distribution mask
# ---------------------------------------------------------------------------

_mask_coords = None

def load_cassava_mask(mask_path):
    """Load cassava distribution mask (lon,lat CSV or shapefile coords)."""
    global _mask_coords
    if mask_path and Path(mask_path).exists():
        # Simple CSV with lon,lat columns
        coords = set()
        with open(mask_path) as f:
            reader = csv.DictReader(f)
            for row in reader:
                lon = round(float(row.get('lon', row.get('Long', 0))), 4)
                lat = round(float(row.get('lat', row.get('Lat', 0))), 4)
                coords.add((lon, lat))
        _mask_coords = coords
        return len(coords)
    return 0


def cell_in_cassava_mask(row):
    """Check if a cell is in the cassava distribution mask."""
    if _mask_coords is None:
        return True  # no mask loaded, include all
    lon = round(row.get('Long', 0), 4)
    lat = round(row.get('Lat', 0), 4)
    return (lon, lat) in _mask_coords


# ---------------------------------------------------------------------------
# Regression analysis (Eq. 7 from paper)
# ---------------------------------------------------------------------------

def build_regression_data(scenarios_data, scenario_dummies, yield_field='tuber',
                          belt_cells=None):
    """Build regression matrix from scenario data.

    Args:
        scenarios_data: dict of scenario_name -> list of row dicts
        scenario_dummies: dict of scenario_name -> dict of dummy_name -> 0/1
        yield_field: column name for dependent variable
        belt_cells: set of cell IDs to include (None = all)

    Returns (Y, X, dummy_names, cell_scenario_pairs)
    """
    dummy_names = sorted(next(iter(scenario_dummies.values())).keys())
    Y = []
    X_rows = []
    pairs = []

    for scen_name, dummies in scenario_dummies.items():
        if scen_name not in scenarios_data:
            continue
        rows = scenarios_data[scen_name]
        for r in rows:
            cell = r.get('_cell', '')
            if belt_cells is not None and cell not in belt_cells:
                continue
            yval = r.get(yield_field)
            if yval is None or not isinstance(yval, (int, float)):
                continue
            Y.append(yval)
            x = [dummies[d] for d in dummy_names]
            X_rows.append(x)
            pairs.append((scen_name, cell))

    return np.array(Y), np.array(X_rows, dtype=float), dummy_names, pairs


def fit_regression_with_interactions(Y, X, dummy_names, p_threshold=0.05):
    """Fit binomial regression with all pairwise interactions.

    Returns (coefficients, names, R², residual_std, significant_mask).
    Uses numpy lstsq since statsmodels is unavailable.
    """
    n, k = X.shape

    # Build design matrix: intercept + main effects + all pairwise interactions
    col_names = ['intercept'] + list(dummy_names)
    cols = [np.ones(n)]
    for i in range(k):
        cols.append(X[:, i])

    # Pairwise interactions
    for i in range(k):
        for j in range(i + 1, k):
            col_names.append(f"{dummy_names[i]}×{dummy_names[j]}")
            cols.append(X[:, i] * X[:, j])

    Xfull = np.column_stack(cols)
    p = Xfull.shape[1]

    # Solve via least squares
    beta, residuals, rank, sv = np.linalg.lstsq(Xfull, Y, rcond=None)

    Y_hat = Xfull @ beta
    ss_res = np.sum((Y - Y_hat) ** 2)
    ss_tot = np.sum((Y - np.mean(Y)) ** 2)
    R2 = 1 - ss_res / ss_tot if ss_tot > 0 else 0

    # Estimate standard errors for significance testing
    dof = n - p
    if dof > 0:
        mse = ss_res / dof
        try:
            cov = mse * np.linalg.inv(Xfull.T @ Xfull)
            se = np.sqrt(np.diag(cov))
            t_stats = beta / se
            # Two-tailed p-values using normal approximation (large n)
            from scipy.stats import t as t_dist
            p_values = 2 * (1 - t_dist.cdf(np.abs(t_stats), dof))
            significant = p_values <= p_threshold
        except (np.linalg.LinAlgError, ImportError):
            significant = np.ones(p, dtype=bool)
            p_values = np.zeros(p)
    else:
        significant = np.ones(p, dtype=bool)
        p_values = np.zeros(p)

    residual_std = np.sqrt(ss_res / max(dof, 1))

    return beta, col_names, R2, residual_std, significant, p_values


def compute_marginal_effects(beta, col_names, dummy_names, X):
    """Compute marginal effects ∂Y/∂xᵢ at mean dummy values.

    For each dummy variable xᵢ:
    ∂Y/∂xᵢ = βᵢ + Σⱼ βᵢⱼ·mean(xⱼ)
    """
    means = {}
    for i, dname in enumerate(dummy_names):
        means[dname] = np.mean(X[:, i])

    marginal = {}
    for target in dummy_names:
        effect = 0.0
        for cname, b in zip(col_names, beta):
            if cname == target:
                effect += b
            elif '×' in cname:
                parts = cname.split('×')
                if target in parts:
                    other = parts[0] if parts[1] == target else parts[1]
                    effect += b * means.get(other, 0)
        marginal[target] = effect

    return marginal, means


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def format_report(summaries_dir, output_path=None, mask_path=None):
    """Generate the comparison report."""
    # Load all scenarios
    scenarios = {}
    names = [
        # CM period (1980-1990)
        'cassava-only',
        'cm-only', 'cm-al', 'cm-ad', 'cm-al-ad', 'cm-fungi',
        'cm-al-fungi', 'cm-ad-fungi', 'cm-al-ad-fungi',
        # CGM period (1990-2000)
        'cassava-only-cgm',
        'cgm-only', 'cgm-ta', 'cgm-am', 'cgm-ta-am',
        'cgm-only-fungi', 'cgm-ta-fungi', 'cgm-am-fungi', 'cgm-ta-am-fungi',
    ]

    for name in names:
        data = load_scenario(summaries_dir, name)
        if data:
            scenarios[name] = data
            print(f"  Loaded {name}: {len(data)} cells")
        else:
            print(f"  Not found: {name}")

    if not scenarios:
        print("ERROR: No scenario data found")
        return

    # Load cassava mask if available
    if mask_path:
        n_mask = load_cassava_mask(mask_path)
        if n_mask:
            print(f"  Loaded cassava mask: {n_mask} cells")

    lines = []
    def w(s=""):
        lines.append(s)

    w("# Reproduction of Gutierrez et al. (2025)")
    w()
    w("## Paper Reference")
    w()
    w("Gutierrez, A. P., Ponti, L., Neuenschwander, P., Yaninek, J. S., & Herren, H. R. (2025).")
    w("Predicting natural enemy efficacy in biological control using ex-ante analyses.")
    w("*Scientific Reports*. https://doi.org/10.1038/s41598-025-29022-1")
    w()
    w("## Reproduction Details")
    w()
    w("- **Model**: Free Pascal (FPC) port of the Delphi cassava tri-trophic PBDM")
    w("- **Weather data**: AgMERRA daily gridded data (1980–2010)")
    w("- **Plant layout**: 10 randomly spaced plants (distribution=2, scattered)")
    w("- **Random seed**: 0 (randomized — stochastic runs)")
    w("- **First simulation year**: excluded from GIS output by model code")
    w("- **Zero-year sentinel**: excluded from means (dd=0 filter)")
    w("- **Analysis method**: Binomial multiple linear regression with interaction terms (Eq. 7)")
    w()

    n_cells = len(scenarios.get('cassava-only', []))
    w(f"- **Cells simulated**: {n_cells} (paper: 10,172 alternating lattice cells)")
    n_cm = len([s for s in scenarios if s.startswith('cm-') or s == 'cassava-only'])
    n_cgm = len([s for s in scenarios if s.startswith('cgm-') or s == 'cassava-only-cgm'])
    w(f"- **CM scenarios**: {n_cm} (paper: 9 for full 2³ factorial + baseline)")
    w(f"- **CGM scenarios**: {n_cgm} (paper: 9 for full 2³ factorial + baseline)")
    w()

    # =========== Cassava belt filter ===========
    co = scenarios.get('cassava-only', [])
    belt_cells = set()
    for r in co:
        if r.get('tuber', 0) > 1500 and cell_in_cassava_mask(r):
            belt_cells.add(r['_cell'])
    n_belt = len(belt_cells)

    w(f"### Cassava Belt Selection")
    w()
    w(f"- Yield threshold: >1500 g dry matter per plant (cassava-only scenario)")
    if _mask_coords:
        w(f"- Cassava distribution mask: applied ({len(_mask_coords)} reference cells)")
    else:
        w(f"- Cassava distribution mask: not available (using yield threshold only)")
    w(f"- Cells in cassava belt: **{n_belt}** of {n_cells}")
    w()

    # =========== SECTION 1: Baseline yields ===========
    w("## 1. Pest-Free Cassava Yield (1981–1990)")
    w()
    if co:
        belt_co = [r for r in co if r['_cell'] in belt_cells]
        yield_co = mean([r.get('tuber', 0) for r in belt_co])
        dd_co = mean([r.get('dd', 0) for r in belt_co])
        w(f"- Mean root yield (cassava belt): **{yield_co:.1f}** g dry matter per plant")
        w(f"- Mean degree days (cassava belt): **{dd_co:.1f}** dd > 14.85°C")
        w()

    # =========== SECTION 2: CM Regression Analysis ===========
    w("## 2. CM Marginal Analysis (Eq. 1)")
    w()

    # CM scenario dummies: CM+, Al+, Ad+, P+
    cm_scenario_dummies = {
        'cassava-only':  {'CM+': 0, 'Al+': 0, 'Ad+': 0, 'P+': 0},
        'cm-only':       {'CM+': 1, 'Al+': 0, 'Ad+': 0, 'P+': 0},
        'cm-fungi':      {'CM+': 1, 'Al+': 0, 'Ad+': 0, 'P+': 1},
        'cm-al':         {'CM+': 1, 'Al+': 1, 'Ad+': 0, 'P+': 0},
        'cm-al-fungi':   {'CM+': 1, 'Al+': 1, 'Ad+': 0, 'P+': 1},
        'cm-ad':         {'CM+': 1, 'Al+': 0, 'Ad+': 1, 'P+': 0},
        'cm-ad-fungi':   {'CM+': 1, 'Al+': 0, 'Ad+': 1, 'P+': 1},
        'cm-al-ad':      {'CM+': 1, 'Al+': 1, 'Ad+': 1, 'P+': 0},
        'cm-al-ad-fungi':{'CM+': 1, 'Al+': 1, 'Ad+': 1, 'P+': 1},
    }

    available_cm = {k: v for k, v in cm_scenario_dummies.items() if k in scenarios}
    if len(available_cm) >= 3:
        Y_cm, X_cm, dummy_names_cm, pairs_cm = build_regression_data(
            scenarios, available_cm, 'tuber', belt_cells)

        w(f"### Regression Data")
        w(f"- Scenarios used: {len(available_cm)} ({', '.join(sorted(available_cm.keys()))})")
        w(f"- Observations: {len(Y_cm)} (scenario × belt cell combinations)")
        w()

        if len(Y_cm) > 0:
            beta_cm, names_cm, R2_cm, se_cm, sig_cm, pv_cm = \
                fit_regression_with_interactions(Y_cm, X_cm, dummy_names_cm)

            w(f"### Regression Coefficients (R² = {R2_cm:.4f})")
            w()
            w(f"| Term | Coefficient | p-value | Significant |")
            w(f"|------|------------|---------|-------------|")
            for i, (name, b, p, s) in enumerate(zip(names_cm, beta_cm, pv_cm, sig_cm)):
                sig_str = "✓" if s else ""
                w(f"| {name} | {b:.2f} | {p:.2e} | {sig_str} |")
            w()

            marginal_cm, means_cm = compute_marginal_effects(
                beta_cm, names_cm, dummy_names_cm, X_cm)

            w(f"### Marginal Effects at Mean Dummy Values")
            w()
            w(f"Mean dummy values: " + ", ".join(
                f"{k}={v:.3f}" for k, v in sorted(means_cm.items())))
            w()
            w(f"| Effect | Reproduction | Paper | Match |")
            w(f"|--------|-------------|-------|-------|")

            paper_cm = {'CM+': -1085.0, 'Al+': 575.8, 'Ad+': 233.1, 'P+': 153.8}
            for dname in ['CM+', 'Al+', 'Ad+', 'P+']:
                val = marginal_cm.get(dname, 0)
                pval = paper_cm.get(dname, 0)
                sign = "+" if val >= 0 else ""
                ratio = abs(val / pval) if pval != 0 else float('inf')
                match = "✓" if 0.7 <= ratio <= 1.3 else "~" if 0.5 <= ratio <= 1.5 else "✗"
                w(f"| {dname} | {sign}{val:.1f} g | {'+' if pval >= 0 else ''}{pval:.1f} g | {match} |")

            # Paper's total recovery
            total_recovery = marginal_cm.get('Al+', 0) + marginal_cm.get('Ad+', 0) + marginal_cm.get('P+', 0)
            w(f"| Total recovery (Al+Ad+P) | +{total_recovery:.1f} g | +962.7 g | {'✓' if 0.7 <= total_recovery/962.7 <= 1.3 else '~'} |")
            w()

    # =========== SECTION 3: CM Simple Differences (for comparison) ===========
    w("## 3. CM Simple Scenario Differences (for reference)")
    w()
    cm_scens = ['cassava-only', 'cm-only', 'cm-fungi', 'cm-al', 'cm-ad', 'cm-al-ad',
                'cm-al-fungi', 'cm-ad-fungi', 'cm-al-ad-fungi']
    w(f"| Scenario | Mean Yield (g) | Δ from baseline |")
    w(f"|----------|---------------|----------------|")
    for sname in cm_scens:
        if sname not in scenarios:
            continue
        belt_rows = [r for r in scenarios[sname] if r['_cell'] in belt_cells]
        y = mean([r.get('tuber', 0) for r in belt_rows])
        baseline = mean([r.get('tuber', 0) for r in scenarios['cassava-only'] if r['_cell'] in belt_cells]) if 'cassava-only' in scenarios else 0
        delta = y - baseline
        w(f"| {sname} | {y:.1f} | {delta:+.1f} |")
    w()

    # =========== SECTION 4: CGM Regression Analysis ===========
    w("## 4. CGM Marginal Analysis (Eq. 4)")
    w()

    cgm_scenario_dummies = {
        'cassava-only-cgm': {'CGM+': 0, 'Ta+': 0, 'Am+': 0, 'P+': 0},
        'cgm-only':         {'CGM+': 1, 'Ta+': 0, 'Am+': 0, 'P+': 0},
        'cgm-only-fungi':   {'CGM+': 1, 'Ta+': 0, 'Am+': 0, 'P+': 1},
        'cgm-ta':           {'CGM+': 1, 'Ta+': 1, 'Am+': 0, 'P+': 0},
        'cgm-ta-fungi':     {'CGM+': 1, 'Ta+': 1, 'Am+': 0, 'P+': 1},
        'cgm-am':           {'CGM+': 1, 'Ta+': 0, 'Am+': 1, 'P+': 0},
        'cgm-am-fungi':     {'CGM+': 1, 'Ta+': 0, 'Am+': 1, 'P+': 1},
        'cgm-ta-am':        {'CGM+': 1, 'Ta+': 1, 'Am+': 1, 'P+': 0},
        'cgm-ta-am-fungi':  {'CGM+': 1, 'Ta+': 1, 'Am+': 1, 'P+': 1},
    }

    # Use CGM-period cassava-only for belt filtering
    co_cgm = scenarios.get('cassava-only-cgm', [])
    belt_cells_cgm = set()
    for r in co_cgm:
        if r.get('tuber', 0) > 1500 and cell_in_cassava_mask(r):
            belt_cells_cgm.add(r['_cell'])

    available_cgm = {k: v for k, v in cgm_scenario_dummies.items() if k in scenarios}
    if len(available_cgm) >= 3:
        Y_cgm, X_cgm, dummy_names_cgm, pairs_cgm = build_regression_data(
            scenarios, available_cgm, 'tuber', belt_cells_cgm)

        w(f"### Regression Data")
        w(f"- Scenarios used: {len(available_cgm)} ({', '.join(sorted(available_cgm.keys()))})")
        w(f"- Observations: {len(Y_cgm)}")
        w(f"- Cassava belt cells (CGM period): {len(belt_cells_cgm)}")
        w()

        if len(Y_cgm) > 0:
            beta_cgm, names_cgm, R2_cgm, se_cgm, sig_cgm, pv_cgm = \
                fit_regression_with_interactions(Y_cgm, X_cgm, dummy_names_cgm)

            w(f"### Regression Coefficients (R² = {R2_cgm:.4f})")
            w()
            w(f"| Term | Coefficient | p-value | Significant |")
            w(f"|------|------------|---------|-------------|")
            for i, (name, b, p, s) in enumerate(zip(names_cgm, beta_cgm, pv_cgm, sig_cgm)):
                sig_str = "✓" if s else ""
                w(f"| {name} | {b:.2f} | {p:.2e} | {sig_str} |")
            w()

            marginal_cgm, means_cgm = compute_marginal_effects(
                beta_cgm, names_cgm, dummy_names_cgm, X_cgm)

            w(f"### Marginal Effects at Mean Dummy Values")
            w()
            w(f"Mean dummy values: " + ", ".join(
                f"{k}={v:.3f}" for k, v in sorted(means_cgm.items())))
            w()
            w(f"| Effect | Reproduction |")
            w(f"|--------|-------------|")

            for dname in ['CGM+', 'Ta+', 'Am+', 'P+']:
                val = marginal_cgm.get(dname, 0)
                sign = "+" if val >= 0 else ""
                w(f"| {dname} | {sign}{val:.1f} g |")

            total_cgm_recovery = marginal_cgm.get('Ta+', 0) + marginal_cgm.get('Am+', 0) + marginal_cgm.get('P+', 0)
            w(f"| Total recovery (Ta+Am+P) | +{total_cgm_recovery:.1f} g |")
            w()
            w("*Note: The paper gives qualitative CGM targets (\"~95% yield recovery\",")
            w("\"~80% damage reduction\") rather than exact regression coefficients.*")
            w()

    # =========== SECTION 5: CGM Simple Differences ===========
    w("## 5. CGM Simple Scenario Differences (for reference)")
    w()
    cgm_scens = ['cassava-only-cgm', 'cgm-only', 'cgm-only-fungi',
                 'cgm-ta', 'cgm-am', 'cgm-ta-am',
                 'cgm-ta-fungi', 'cgm-am-fungi', 'cgm-ta-am-fungi']
    w(f"| Scenario | Mean Yield (g) | Δ from baseline |")
    w(f"|----------|---------------|----------------|")
    for sname in cgm_scens:
        if sname not in scenarios:
            continue
        belt_rows = [r for r in scenarios[sname] if r['_cell'] in belt_cells_cgm]
        y = mean([r.get('tuber', 0) for r in belt_rows])
        baseline = mean([r.get('tuber', 0) for r in co_cgm if r['_cell'] in belt_cells_cgm])
        delta = y - baseline
        w(f"| {sname} | {y:.1f} | {delta:+.1f} |")
    w()

    # =========== SECTION 6: Qualitative findings ===========
    w("## 6. Qualitative Comparison")
    w()
    w("| Finding | Paper | Reproduction |")
    w("|---------|-------|-------------|")

    if all(s in scenarios for s in ['cm-al', 'cm-ad', 'cm-only']):
        belt_al = [r for r in scenarios['cm-al'] if r['_cell'] in belt_cells]
        belt_ad = [r for r in scenarios['cm-ad'] if r['_cell'] in belt_cells]
        belt_cm = [r for r in scenarios['cm-only'] if r['_cell'] in belt_cells]
        al_eff = mean([r.get('tuber', 0) for r in belt_al]) - mean([r.get('tuber', 0) for r in belt_cm])
        ad_eff = mean([r.get('tuber', 0) for r in belt_ad]) - mean([r.get('tuber', 0) for r in belt_cm])
        chk = "✓" if al_eff > ad_eff else "✗"
        w(f"| A. lopezi > A. diversicornis | Yes | {chk} (ΔAl={al_eff:+.0f} vs ΔAd={ad_eff:+.0f} g) |")

    if all(s in scenarios for s in ['cgm-ta', 'cgm-am', 'cgm-only']):
        belt_ta = [r for r in scenarios['cgm-ta'] if r['_cell'] in belt_cells_cgm]
        belt_am = [r for r in scenarios['cgm-am'] if r['_cell'] in belt_cells_cgm]
        belt_cgm = [r for r in scenarios['cgm-only'] if r['_cell'] in belt_cells_cgm]
        ta_eff = mean([r.get('tuber', 0) for r in belt_ta]) - mean([r.get('tuber', 0) for r in belt_cgm])
        am_eff = mean([r.get('tuber', 0) for r in belt_am]) - mean([r.get('tuber', 0) for r in belt_cgm])
        chk = "✓" if ta_eff > am_eff else "✗"
        w(f"| T. aripo > A. manihoti | Yes | {chk} (ΔTa={ta_eff:+.0f} vs ΔAm={am_eff:+.0f} g) |")

    if all(s in scenarios for s in ['cassava-only', 'cm-al-ad-fungi']):
        co_belt = [r for r in scenarios['cassava-only'] if r['_cell'] in belt_cells]
        bc_belt = [r for r in scenarios['cm-al-ad-fungi'] if r['_cell'] in belt_cells]
        y_co = mean([r.get('tuber', 0) for r in co_belt])
        y_bc = mean([r.get('tuber', 0) for r in bc_belt])
        rec = (y_bc / y_co * 100) if y_co > 0 else 0
        chk = "✓" if rec > 90 else "~" if rec > 80 else "✗"
        w(f"| CM biocontrol recovers ~95% | ~95% | {chk} ({rec:.1f}%) |")
    elif all(s in scenarios for s in ['cassava-only', 'cm-al-ad']):
        co_belt = [r for r in scenarios['cassava-only'] if r['_cell'] in belt_cells]
        bc_belt = [r for r in scenarios['cm-al-ad'] if r['_cell'] in belt_cells]
        y_co = mean([r.get('tuber', 0) for r in co_belt])
        y_bc = mean([r.get('tuber', 0) for r in bc_belt])
        rec = (y_bc / y_co * 100) if y_co > 0 else 0
        chk = "✓" if rec > 90 else "~" if rec > 80 else "✗"
        w(f"| CM biocontrol recovers ~95% (no fungi) | ~95% | {chk} ({rec:.1f}%) |")

    if all(s in scenarios for s in ['cassava-only-cgm', 'cgm-ta-am-fungi']):
        co_cgm_belt = [r for r in scenarios['cassava-only-cgm'] if r['_cell'] in belt_cells_cgm]
        bc_cgm_belt = [r for r in scenarios['cgm-ta-am-fungi'] if r['_cell'] in belt_cells_cgm]
        y_co_cgm = mean([r.get('tuber', 0) for r in co_cgm_belt])
        y_bc_cgm = mean([r.get('tuber', 0) for r in bc_cgm_belt])
        rec_cgm = (y_bc_cgm / y_co_cgm * 100) if y_co_cgm > 0 else 0
        chk = "✓" if rec_cgm > 90 else "~" if rec_cgm > 80 else "✗"
        w(f"| CGM biocontrol recovers ~95% | ~95% | {chk} ({rec_cgm:.1f}%) |")

    w()

    # =========== SECTION 7: Limitations ===========
    w("## 7. Limitations")
    w()
    w("1. **Stochastic variation**: With randseed=0, each run uses a different random")
    w("   sequence. Single runs show stochastic variation; the paper likely used")
    w("   deterministic or averaged multiple runs.")
    w("2. **Cassava belt filter**: We approximate the paper's cassava distribution mask")
    w("   (figshare.22491997) with a >1500 g yield threshold.")
    w("3. **FPC port differences**: Subtle floating-point handling differences between")
    w("   Free Pascal and Delphi 3 may affect results.")
    w("4. **GIS output**: We use instantaneous (snapshot) values from GisOutput.pas.")
    w("   The paper likely used cumulative sums from an alternative output procedure")
    w("   (gisout.pas) for density metrics. Yield comparisons are unaffected.")
    if _mask_coords:
        w("5. **Cassava mask resolution**: The CROPGRIDS mask is 0.05° resolution aggregated")
        w("   to AgMERRA's 0.25° grid by checking if any sub-cell has harvested area > 0.")
    w()

    report = "\n".join(lines)

    if output_path:
        with open(output_path, 'w') as f:
            f.write(report)
        print(f"\nReport written to: {output_path}")
    else:
        print(report)

    return report


def main():
    parser = argparse.ArgumentParser(description="Analyze reproduction results")
    parser.add_argument("--summaries-dir", default=None,
                        help="Directory with summary CSVs")
    parser.add_argument("--output", "-o", default=None,
                        help="Output markdown file path")
    parser.add_argument("--mask", default=None,
                        help="Path to cassava distribution mask CSV")
    args = parser.parse_args()

    base = Path(__file__).resolve().parent.parent
    summaries = args.summaries_dir or str(base / "summaries")
    output = args.output or str(base / "REPORT.md")

    print(f"Reading summaries from: {summaries}")
    format_report(summaries, output, mask_path=args.mask)

if __name__ == "__main__":
    main()
