#!/usr/bin/env python3
"""
Test whether remaining quantitative gaps vs the paper fall within stochastic
variation. With randseed=0, each run uses a time-based RNG seed, so repeated
runs of the same cell produce different results.

Strategy:
  1. Sample N cells from the cassava belt
  2. Run each cell R times for all 9 CM and 9 CGM scenarios
  3. For each replicate, compute the regression (Eq. 7) and marginal effects
  4. Report mean, std, and 95% CI for each marginal effect
  5. Check whether the paper's stated values fall within those CIs
"""

import argparse
import csv
import json
import os
import pathlib
import random
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np

# Import from sibling scripts
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from run_scenarios import (
    SCENARIOS, make_cassava_ini, load_manifest, select_alternating_cells,
)


# Paper's CM marginal effects (Table 1)
PAPER_CM = {
    "CM+": -1085.0,
    "Al+": 575.8,
    "Ad+": 233.1,
    "P+": 153.8,
}


def run_cell(cassava_bin, wx_path, ini_text, cmd_dates, work_dir):
    """Run one simulation, return (success, gis_files_content)."""
    work_dir.mkdir(parents=True, exist_ok=True)
    (work_dir / "Cassava.ini").write_text(ini_text)
    cmd = [str(cassava_bin), "Cassava.ini"] + cmd_dates + [str(wx_path)]
    result = subprocess.run(
        cmd, cwd=str(work_dir), capture_output=True, text=True, timeout=120
    )
    gis_files = sorted(work_dir.glob("Cassava_*.txt"))
    if not gis_files:
        return False, []
    rows = []
    for f in gis_files:
        for line in open(f):
            if line.startswith("CasGIS"):
                parts = line.split("\t")
                dd = float(parts[11])
                if dd > 0:
                    tuber = float(parts[15])
                    rows.append(tuber)
    # Clean up GIS files for next replicate
    for f in gis_files:
        f.unlink()
    for f in work_dir.glob("Cassava*.txt"):
        f.unlink(missing_ok=True)
    for f in work_dir.glob("GisFiles*.txt"):
        f.unlink(missing_ok=True)
    return True, rows


def _worker(args):
    """Worker for parallel execution: run one cell+scenario+replicate."""
    cassava_bin, wx_path, ini_text, cmd_dates, work_dir = args
    ok, tubers = run_cell(
        cassava_bin, wx_path, ini_text, cmd_dates, pathlib.Path(work_dir)
    )
    mean_tuber = float(np.mean(tubers)) if tubers else np.nan
    return ok, mean_tuber


def fit_regression(Y, X, n_predictors):
    """OLS regression with interaction terms. Returns coefficients."""
    n = len(Y)
    if n < n_predictors + 1:
        return None
    # Add intercept
    ones = np.ones((n, 1))
    Xf = np.hstack([ones, X])
    try:
        beta = np.linalg.lstsq(Xf, Y, rcond=None)[0]
    except np.linalg.LinAlgError:
        return None
    return beta


def compute_cm_marginal_effects(scenario_means):
    """Build regression data and compute CM marginal effects.
    
    scenario_means: dict of scenario_name -> array of per-cell mean tubers
    Returns dict of effect_name -> marginal_effect_value
    """
    # Build Y, X matrices for CM regression
    # Predictors: Al+, Ad+, CM+, P+ plus pairwise interactions
    cm_scenarios = {
        "cassava-only":    (0, 0, 0, 0),  # Al, Ad, CM, P
        "cm-only":         (0, 0, 1, 0),
        "cm-al":           (1, 0, 1, 0),
        "cm-ad":           (0, 1, 1, 0),
        "cm-al-ad":        (1, 1, 1, 0),
        "cm-fungi":        (0, 0, 1, 1),
        "cm-al-fungi":     (1, 0, 1, 1),
        "cm-ad-fungi":     (0, 1, 1, 1),
        "cm-al-ad-fungi":  (1, 1, 1, 1),
    }
    
    Y_list = []
    X_list = []
    
    for name, dummies in cm_scenarios.items():
        if name not in scenario_means:
            continue
        vals = scenario_means[name]
        n = len(vals)
        al, ad, cm, p = dummies
        for v in vals:
            if not np.isnan(v):
                Y_list.append(v)
                # Main effects + pairwise interactions
                row = [al, ad, cm, p,
                       al*ad, al*cm, al*p, ad*cm, ad*p, cm*p]
                X_list.append(row)
    
    Y = np.array(Y_list)
    X = np.array(X_list)
    
    beta = fit_regression(Y, X, X.shape[1])
    if beta is None:
        return None
    
    # Marginal effects at mean dummy values
    # With 9 scenarios in 2^3+1 design, mean of each dummy = 4/9
    d = 4.0 / 9.0
    
    # beta: [intercept, Al, Ad, CM, P, Al*Ad, Al*CM, Al*P, Ad*CM, Ad*P, CM*P]
    #         0         1   2   3   4  5      6      7     8      9     10
    effects = {
        "CM+": beta[3] + beta[6]*d + beta[8]*d + beta[10]*d,
        "Al+": beta[1] + beta[5]*d + beta[6]*d + beta[7]*d,
        "Ad+": beta[2] + beta[5]*d + beta[8]*d + beta[9]*d,
        "P+":  beta[4] + beta[7]*d + beta[9]*d + beta[10]*d,
    }
    
    r2 = 1.0 - np.sum((Y - np.hstack([np.ones((len(Y),1)), X]) @ beta)**2) / np.sum((Y - Y.mean())**2)
    effects["R2"] = r2
    
    return effects


def compute_cgm_marginal_effects(scenario_means):
    """Build regression data and compute CGM marginal effects."""
    cgm_scenarios = {
        "cassava-only-cgm":  (0, 0, 0, 0),  # Am, CGM, P, Ta
        "cgm-only":          (0, 1, 0, 0),
        "cgm-ta":            (0, 1, 0, 1),
        "cgm-am":            (1, 1, 0, 0),
        "cgm-ta-am":         (1, 1, 0, 1),
        "cgm-only-fungi":    (0, 1, 1, 0),
        "cgm-ta-fungi":      (0, 1, 1, 1),
        "cgm-am-fungi":      (1, 1, 1, 0),
        "cgm-ta-am-fungi":   (1, 1, 1, 1),
    }
    
    Y_list = []
    X_list = []
    
    for name, dummies in cgm_scenarios.items():
        if name not in scenario_means:
            continue
        vals = scenario_means[name]
        for v in vals:
            if not np.isnan(v):
                Y_list.append(v)
                am, cgm, p, ta = dummies
                row = [am, cgm, p, ta,
                       am*cgm, am*p, am*ta, cgm*p, cgm*ta, p*ta]
                X_list.append(row)
    
    Y = np.array(Y_list)
    X = np.array(X_list)
    
    beta = fit_regression(Y, X, X.shape[1])
    if beta is None:
        return None
    
    d = 4.0 / 9.0
    # beta: [intercept, Am, CGM, P, Ta, Am*CGM, Am*P, Am*Ta, CGM*P, CGM*Ta, P*Ta]
    #         0          1   2   3  4   5       6     7      8      9       10
    effects = {
        "CGM+": beta[2] + beta[5]*d + beta[8]*d + beta[9]*d,
        "Ta+":  beta[4] + beta[7]*d + beta[9]*d + beta[10]*d,
        "Am+":  beta[1] + beta[5]*d + beta[6]*d + beta[7]*d,
        "P+":   beta[3] + beta[6]*d + beta[8]*d + beta[10]*d,
    }
    
    r2 = 1.0 - np.sum((Y - np.hstack([np.ones((len(Y),1)), X]) @ beta)**2) / np.sum((Y - Y.mean())**2)
    effects["R2"] = r2
    
    return effects


def main():
    parser = argparse.ArgumentParser(description="Stochastic variation test")
    parser.add_argument("--n-cells", type=int, default=300,
                        help="Number of cassava-belt cells to sample")
    parser.add_argument("--n-replicates", type=int, default=10,
                        help="Number of replicate runs per cell")
    parser.add_argument("--workers", "-j", type=int, default=8)
    parser.add_argument("--cassava-bin", type=str,
                        default=str(pathlib.Path(__file__).parent.parent.parent / "cassava" / "cassava"))
    parser.add_argument("--wx-dir", type=str,
                        default=str(pathlib.Path.home() / "Projects" / "pbdm" / "data" / "agmerra-pascal-weather-africa-1980-2010"))
    parser.add_argument("--manifest", type=str, default=None,
                        help="Path to manifest TSV (default: wx-dir/_manifest.tsv)")
    parser.add_argument("--mask", type=str,
                        default=str(pathlib.Path.home() / "Projects" / "pbdm" / "data" / "cropgrids" / "cassava_africa_mask_agmerra.csv"))
    parser.add_argument("--analysis", choices=["cm", "cgm", "both"], default="both")
    parser.add_argument("--seed", type=int, default=42, help="Seed for cell sampling")
    args = parser.parse_args()

    cassava_bin = pathlib.Path(args.cassava_bin)
    wx_dir = pathlib.Path(args.wx_dir)
    
    # Load manifest and select alternating cells
    manifest_path = args.manifest if args.manifest else str(wx_dir / "_manifest.tsv")
    all_cells = load_manifest(manifest_path)
    alt_cells = select_alternating_cells(all_cells)
    print(f"Alternating grid: {len(alt_cells)} cells")
    
    # Load cassava mask for belt filtering
    mask_lons = set()
    if args.mask:
        with open(args.mask) as f:
            reader = csv.DictReader(f)
            for row in reader:
                mask_lons.add((round(float(row["lon"]), 4), round(float(row["lat"]), 4)))
    
    # Filter to cassava belt: yield > 1500 from our existing full run, or just use mask
    # For simplicity, use the mask cells that are in our alternating grid
    belt_cells = []
    for name, lon, lat in alt_cells:
        key = (round(lon, 4), round(lat, 4))
        if key in mask_lons:
            belt_cells.append((name, lon, lat))
    
    print(f"Cassava belt cells: {len(belt_cells)}")
    
    # Sample N cells
    rng = random.Random(args.seed)
    sample = rng.sample(belt_cells, min(args.n_cells, len(belt_cells)))
    print(f"Sampled {len(sample)} cells for stochastic test")
    
    # Determine which scenario groups to run
    run_cm = args.analysis in ("cm", "both")
    run_cgm = args.analysis in ("cgm", "both")
    
    cm_scenario_names = [
        "cassava-only", "cm-only", "cm-al", "cm-ad", "cm-al-ad",
        "cm-fungi", "cm-al-fungi", "cm-ad-fungi", "cm-al-ad-fungi",
    ]
    cgm_scenario_names = [
        "cassava-only-cgm", "cgm-only", "cgm-ta", "cgm-am", "cgm-ta-am",
        "cgm-only-fungi", "cgm-ta-fungi", "cgm-am-fungi", "cgm-ta-am-fungi",
    ]
    
    scenario_names = []
    if run_cm:
        scenario_names.extend(cm_scenario_names)
    if run_cgm:
        scenario_names.extend(cgm_scenario_names)
    
    n_rep = args.n_replicates
    n_cells = len(sample)
    n_scenarios = len(scenario_names)
    total_runs = n_cells * n_scenarios * n_rep
    print(f"Total runs: {n_cells} cells × {n_scenarios} scenarios × {n_rep} replicates = {total_runs}")
    
    # Prepare INI texts and cmd_dates for each scenario
    ini_texts = {}
    cmd_dates_map = {}
    for sname in scenario_names:
        s = SCENARIOS[sname]
        ini_texts[sname] = make_cassava_ini(s)
        start_y = s.get("start_year", s["period"][2])
        end_y = s.get("end_year", s["period"][5])
        cmd_dates_map[sname] = [
            "01", "01", str(start_y), "12", "31", str(end_y),
            str(s.get("gis_interval", 365)),
        ]
    
    # Build task list: (cassava_bin, wx_path, ini_text, cmd_dates, work_dir)
    # Results stored as: results[replicate][scenario][cell_idx] = mean_tuber
    work_base = pathlib.Path(tempfile.mkdtemp(prefix="stoch_test_"))
    print(f"Working directory: {work_base}")
    
    tasks = []
    task_keys = []  # (rep, scenario, cell_idx)
    
    for rep in range(n_rep):
        for si, sname in enumerate(scenario_names):
            for ci, (wx_name, lon, lat) in enumerate(sample):
                wx_path = wx_dir / wx_name
                work_dir = work_base / f"r{rep}" / sname / f"c{ci}"
                tasks.append((
                    str(cassava_bin), str(wx_path), ini_texts[sname],
                    cmd_dates_map[sname], str(work_dir)
                ))
                task_keys.append((rep, sname, ci))
    
    # Run all tasks in parallel
    print(f"\nRunning {len(tasks)} simulations with {args.workers} workers...")
    results = {}  # (rep, scenario, cell_idx) -> mean_tuber
    done = 0
    failed = 0
    
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(_worker, t): k for t, k in zip(tasks, task_keys)}
        for future in as_completed(futures):
            key = futures[future]
            try:
                ok, mean_tuber = future.result()
                results[key] = mean_tuber
                if not ok:
                    failed += 1
            except Exception as e:
                results[key] = np.nan
                failed += 1
            done += 1
            if done % 500 == 0:
                print(f"  [{done}/{len(tasks)}] {done-failed} ok, {failed} failed", flush=True)
    
    print(f"\nCompleted: {done-failed} ok, {failed} failed")
    
    # Organize results by replicate
    print("\n" + "="*70)
    print("STOCHASTIC VARIATION ANALYSIS")
    print("="*70)
    
    if run_cm:
        print("\n--- CM Analysis ---")
        cm_effects_per_rep = []
        for rep in range(n_rep):
            scenario_means = {}
            for sname in cm_scenario_names:
                vals = []
                for ci in range(n_cells):
                    v = results.get((rep, sname, ci), np.nan)
                    if not np.isnan(v):
                        vals.append(v)
                scenario_means[sname] = np.array(vals)
            
            effects = compute_cm_marginal_effects(scenario_means)
            if effects is not None:
                cm_effects_per_rep.append(effects)
                print(f"  Rep {rep}: CM+={effects['CM+']:+.1f}, Al+={effects['Al+']:+.1f}, "
                      f"Ad+={effects['Ad+']:+.1f}, P+={effects['P+']:+.1f}, R²={effects['R2']:.4f}")
        
        if cm_effects_per_rep:
            print(f"\n{'Effect':<8} {'Mean':>10} {'Std':>10} {'95% CI low':>12} {'95% CI high':>12} {'Paper':>10} {'In CI?':>8}")
            print("-" * 75)
            for eff in ["CM+", "Al+", "Ad+", "P+"]:
                vals = [e[eff] for e in cm_effects_per_rep]
                mean = np.mean(vals)
                std = np.std(vals, ddof=1)
                ci_lo = mean - 1.96 * std
                ci_hi = mean + 1.96 * std
                paper = PAPER_CM[eff]
                in_ci = "✓" if ci_lo <= paper <= ci_hi else "✗"
                print(f"{eff:<8} {mean:>+10.1f} {std:>10.1f} {ci_lo:>+12.1f} {ci_hi:>+12.1f} {paper:>+10.1f} {in_ci:>8}")
            
            # Recovery %
            recoveries = []
            for e in cm_effects_per_rep:
                total_recovery = e["Al+"] + e["Ad+"] + e["P+"]
                cm_damage = abs(e["CM+"])
                if cm_damage > 0:
                    recoveries.append(total_recovery / cm_damage * 100)
            if recoveries:
                print(f"\nCM Recovery: {np.mean(recoveries):.1f}% ± {np.std(recoveries, ddof=1):.1f}% "
                      f"(paper: ~95%)")
    
    if run_cgm:
        print("\n--- CGM Analysis ---")
        cgm_effects_per_rep = []
        for rep in range(n_rep):
            scenario_means = {}
            for sname in cgm_scenario_names:
                vals = []
                for ci in range(n_cells):
                    v = results.get((rep, sname, ci), np.nan)
                    if not np.isnan(v):
                        vals.append(v)
                scenario_means[sname] = np.array(vals)
            
            effects = compute_cgm_marginal_effects(scenario_means)
            if effects is not None:
                cgm_effects_per_rep.append(effects)
                print(f"  Rep {rep}: CGM+={effects['CGM+']:+.1f}, Ta+={effects['Ta+']:+.1f}, "
                      f"Am+={effects['Am+']:+.1f}, P+={effects['P+']:+.1f}, R²={effects['R2']:.4f}")
        
        if cgm_effects_per_rep:
            print(f"\n{'Effect':<8} {'Mean':>10} {'Std':>10} {'95% CI low':>12} {'95% CI high':>12}")
            print("-" * 60)
            for eff in ["CGM+", "Ta+", "Am+", "P+"]:
                vals = [e[eff] for e in cgm_effects_per_rep]
                mean = np.mean(vals)
                std = np.std(vals, ddof=1)
                ci_lo = mean - 1.96 * std
                ci_hi = mean + 1.96 * std
                print(f"{eff:<8} {mean:>+10.1f} {std:>10.1f} {ci_lo:>+12.1f} {ci_hi:>+12.1f}")
            
            # Recovery %
            recoveries = []
            for e in cgm_effects_per_rep:
                total_recovery = e["Ta+"] + e["Am+"] + e["P+"]
                cgm_damage = abs(e["CGM+"])
                if cgm_damage > 0:
                    recoveries.append(total_recovery / cgm_damage * 100)
            if recoveries:
                print(f"\nCGM Recovery: {np.mean(recoveries):.1f}% ± {np.std(recoveries, ddof=1):.1f}% "
                      f"(paper: ~95%)")
    
    # Cleanup
    import shutil
    shutil.rmtree(work_base, ignore_errors=True)
    print(f"\nCleaned up {work_base}")


if __name__ == "__main__":
    main()
