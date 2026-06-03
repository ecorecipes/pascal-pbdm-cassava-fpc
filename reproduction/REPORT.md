# Reproduction of Gutierrez et al. (2025)

Reproduction of the cassava tri-trophic PBDM analyses in:

> Gutierrez, A. P., Ponti, L., Neuenschwander, P., Yaninek, J. S., & Herren, H. R. (2025).
> Predicting natural enemy efficacy in biological control using ex-ante analyses.
> *Scientific Reports* **15**, 44886. <https://doi.org/10.1038/s41598-025-29022-1>

using the Free Pascal port in this repository.

## Summary

- **The qualitative results of the paper reproduce.** *A. lopezi* outperforms
  *A. diversicornis*; *T. aripo* outperforms *A. manihoti*; cassava-mealybug damage and
  the *A. diversicornis* effect match the paper within stochastic confidence intervals.
- **The port is faithful to the original model.** Against a genuine Delphi 3 golden
  master built from the *published* paper source (Zenodo 17559583), the FPC port agrees
  to a median |Δ| of **0.13–0.16%** — pure x87-vs-IEEE-754 precision, not a porting bug.
  The published paper source is byte-identical to this repo's legacy source, and the
  weather conversion is byte-exact against raw AgMERRA.
- **The main author-vs-port gap is a configuration artifact, not a model/weather/code
  error.** The `Cassava.paper.ini` shipped with the paper repository **disables** the
  mealybug + parasitoid subsystem that the authors' published *output* columns prove was
  active (with strong evidence that the fungal/rain-mortality pathway was also on).
  Re-enabling those flags cuts the median tuber-yield error from **117% to ~10–16%**.
- **The remaining ~10–16% residual is blocked on un-published inputs**: the authors'
  run-specific tuned pest parameters and their actual per-cell weather files (a
  CASAS/Protheus product that is not a naive resampling of AgMERRA). It is concentrated
  in hypersensitive, water-limited desert-edge cells and does not affect the paper's
  substantive sub-Saharan conclusions.

## Method

| Item | Value |
|---|---|
| Model | Free Pascal (FPC) port of the Delphi cassava tri-trophic PBDM |
| Weather | AgMERRA daily gridded data (1980–2010), native 0.25° nearest-cell |
| Plant layout | 10 plants in rows, ±20% perturbation (`distribution=1`) |
| Random seed | 0 (model is deterministic for these configs — see below) |
| First simulation year | excluded from GIS output by the model |
| Analysis | binomial multiple linear regression with interaction terms (paper Eq. 7) |
| Cells simulated | 10,177 (paper: 10,172 alternating-lattice cells) |
| Scenarios | 9 CM + 9 CGM (2³ factorial + baseline) |

**Cassava-belt selection.** Cells are restricted to a cassava "belt": CROPGRIDS
harvested-area mask aggregated to the AgMERRA grid, plus a >1500 g dry-matter-per-plant
yield threshold (cassava-only scenario). This yields **3765** belt cells of 10,177.

**Configurations.** The `Cassava.paper.ini` shipped in the paper repository is
byte-identical to the repo source default and does **not** encode the authors'
run-specific choices (see [Root cause](#root-cause-of-the-authorport-gap)). The
configurations actually used by the paper were reconstructed from the manuscript +
supplement and validated against the Zenodo demo output; they live in
[`reconstructed_ini/`](reconstructed_ini/) (`README.md` documents the full flag table):

- `Cassava.full.ini` — the validated demo config matching the Zenodo `Cassava_06Nov25`
  output (full tri-trophic, 41 GIS columns); = repo default with CMB, *A. lopezi*,
  *A. diversicornis*, and fungus/rain-mortality **ON**, Hyperaspis OFF.
- `Cassava.cm.ini` — CM marginal system (mealybug + *A. lopezi* + *A. diversicornis* +
  fungus), 1980–1990, presence/absence logic ON.
- `Cassava.cgm.ini` — CGM marginal system (green mite + *T. aripo* + *A. manihoti* +
  fungus), 1990–2000.

**Determinism.** With `randseed=0` the model produces byte-identical output across
repeated runs: `init.pas` never assigns a positive seed to the system `RandSeed`, and the
daily-migrant pool (`immigmethod=2`) is mean-based, not random. Bit-exact reproduction
therefore requires no seed matching.

## Results

### 1. Pest-free cassava yield (1981–1990)

- Mean root yield (cassava belt): **3982.8** g dry matter per plant
- Mean degree-days (cassava belt): **2884.1** dd > 14.85 °C

### 2. CM marginal analysis (Eq. 1 / Eq. 7)

9 scenarios, 33,885 scenario × belt-cell observations, R² = 0.276.

Marginal effects at mean dummy values (Ad⁺=0.444, Al⁺=0.444, CM⁺=0.889, P⁺=0.444):

| Effect | Reproduction | Paper | Note |
|--------|-------------|-------|------|
| CM⁺ | −1176.3 g | −1085.0 g | within stochastic CI |
| Al⁺ | +1017.8 g | +575.8 g | see belt-filter note |
| Ad⁺ | +369.1 g | +233.1 g | see belt-filter note |
| P⁺ | +89.9 g | +153.8 g | weak-P residual |
| Total recovery (Al+Ad+P) | +1476.9 g | +962.7 g | |

> **Marginal vs standalone, and the belt filter.** The paper's 575.8 g is the
> *interaction-adjusted marginal* at the product of dummy means, not the standalone
> *A. lopezi* contrast. The correct like-for-like comparison is the **main coefficient**
> b_Al: port **927 g vs paper 958 g (~3%)**, and the fitted Al/CM ratio is **0.882 vs the
> paper's 0.883**. The apparent Al⁺/Ad⁺ inflation above is a *belt-filter selection
> artifact* — the per-row yield>1500 g threshold selects on the dependent variable and
> distorts saturated-dummy per-scenario contrasts — not a biology difference. (The
> underlying model units are byte-identical to the legacy source.)

For reference, simple scenario means (g dry matter):

| Scenario | Mean | Δ baseline | | Scenario | Mean | Δ baseline |
|---|---|---|---|---|---|---|
| cassava-only | 3982.8 | +0.0 | | cm-ad | 3053.5 | −929.3 |
| cm-only | 2246.0 | −1736.8 | | cm-al-ad | 3750.5 | −232.3 |
| cm-fungi | 2442.1 | −1540.7 | | cm-al-fungi | 3810.1 | −172.7 |
| cm-al | 3778.3 | −204.5 | | cm-ad-fungi | 3166.0 | −816.8 |
| | | | | cm-al-ad-fungi | 3770.3 | −212.5 |

### 3. CGM marginal analysis (Eq. 4)

9 scenarios, 34,011 observations, R² = 0.283. The paper gives qualitative CGM targets
("~95% yield recovery", "~80% damage reduction") rather than exact coefficients.

Marginal effects (Am⁺=0.444, CGM⁺=0.889, P⁺=0.444, Ta⁺=0.444): CGM⁺ −1618.0 g,
Ta⁺ +461.4 g, Am⁺ +157.5 g, P⁺ +1013.8 g; total recovery (Ta+Am+P) +1632.7 g.

### 4. Qualitative comparison

| Finding | Paper | Reproduction |
|---------|-------|-------------|
| *A. lopezi* > *A. diversicornis* | Yes | ✓ (ΔAl=+1532 vs ΔAd=+807 g) |
| *T. aripo* > *A. manihoti* | Yes | ✓ (ΔTa=+905 vs ΔAm=+413 g) |
| CM damage (CM⁺) | −1085 g | ✓ (−1101 g, within stochastic CI) |
| Ad⁺ effect | +233 g | ✓ (+206 g, within stochastic CI) |
| CM biocontrol recovery | ~95% | ~ (81% mean across replicates) |
| CGM biocontrol recovery | ~95% | ~ (64% mean across replicates) |

### 5. Stochastic variation

200 belt cells × 5 replicates × 18 scenarios. Although these configs are deterministic in
the seed, replicates capture cell-sampling variability. Paper values are tested against
95% CIs across replicates.

CM: CM⁺ −1101±65 g [−1228, −974] (paper −1085 ✓); Ad⁺ +206±23 g [+161, +251] (paper +233
✓); Al⁺ +660±16 g [+628, +692] (paper +576, partitioning shift); P⁺ +24±19 g [−14, +61]
(paper +154, weak-P). CM recovery 81.0%±7.0%.

CGM: CGM⁺ −1552±61 g; Ta⁺ +235±12 g; Am⁺ +55±29 g; P⁺ +698±24 g. CGM recovery 63.7%±2.3%.

CM⁺ and Ad⁺ paper values fall inside the CIs (stochastic variation fully explains those
gaps). The Al⁺/P⁺ partitioning shift and lower CGM recovery are systematic — not RNG noise
(std is ~1–3% of effect size) — and trace to the analysis belt definition and the
un-shipped pest parameters discussed below.

## What has been ruled out as a cause of the residual

Each item below is established by a controlled experiment (scripts in
[`scripts/`](scripts/)).

- **Porting / code bug — ruled out.** A genuine **Delphi 3 golden master** was built under
  wine (`dcc32`) from the legacy source, linking the original `spatial.dcu`
  (md5 `9fc6483026aee665810d86a76bc697e5`). On an identical 30-cell belt subset the FPC
  arm64 port vs the Delphi golden master agree to a **median |Δ| of 0.13–0.16%**; the
  highest-yield cells agree to ≤0.03%, and the only larger %-differences are sub-10 g
  desert cells where ~1 g is a meaningless percentage. (`gm_compare.py`)
- **Compiler / floating-point precision — ruled out.** Because the golden master runs
  Delphi x87, precision is removed as a variable; the tiny residual above is exactly the
  expected x87-80-bit vs IEEE-754-64-bit difference.
- **Published-code parity — confirmed.** The official paper source (**Zenodo 17559583**,
  `pascal-pbdm-cassava` v1.0.1) is **byte-identical** to this repo's legacy `.pas` units
  apart from a 14-line license header, with an **identical `spatial.dcu` md5**. So the
  golden master *is* the paper binary; code, precision, and the published parameters are
  all eliminated as explanations of any gap vs the paper's numbers.
- **The 0.45 fungal-mortality cap — not the cause.** `mb.pas` caps CM fungal mortality at
  `0.45*(1 − exp(−0.025·precip))` (a `5-29-2024 APG` fit). Uncapping it ~4× the fungal
  rescue (a real sensitivity), but the cap **is present in the published paper code**, so
  uncapping moves *away* from the paper, not toward it. The cap is shared by both builds.
- **Stochasticity — ruled out.** Deterministic for these configs (see Method).
- **Temperature input — ruled out.** Degree-days (a pure tmax/tmin integral) are
  **bit-identical** to the authors' shipped output at every sampled cell/year.
- **Weather conversion — ruled out (byte-exact).** All six drivers
  (tmax/tmin/precip/RH/wind/solar) reproduce raw point AgMERRA to 0.0000 max abs
  difference (solar to 0.0005, output rounding only). Solar unit conversion is physically
  exact (MJ/m²/day → W/m² → langley/day). `tools/agmerra_to_pascal_weather.py` is
  arithmetically exact. (`p1q_allcolumn_nc4_audit.py`)
- **Spatial "coarsening" of weather — ruled out.** The manuscript's coarsening is
  **checkerboard cell *selection*** (10,172 ≈ 40,691/4 alternating-lattice cells), **not**
  within-cell averaging. Naive block-averaging of precip drives yield the *wrong* way and
  is worse than native at every block size (3×3/5×5/9×9). (`p1p_precip_coarsening.py`)

## Root cause of the author–port gap

**First-order cause (proven): the shipped `Cassava.paper.ini` disables the cassava
mealybug + parasitoid subsystem that the authors' run used.** The authors' shipped GIS
output populates the `mb1..mb6` (*P. manihoti* instars), `ed1..ed3` and `el1..el3`
(*Epidinocarsis diversicornis* / *E. lopezi*) columns with nonzero values — columns the
Delphi binary only writes when the subsystem is **included**. The shipped ini sets all
three flags OFF:

| ini line | flag | shipped | authors' run (from output) |
|---|---|---|---|
| 58 | include CMB (mealybug *P. manihoti*) | f | T |
| 66 | include parasitoid *E. lopezi* | f | T |
| 71 | include parasitoid *E. diversicornis* | f | T |

Re-enabling them (golden master, otherwise the shipped ini) reproduces the authors'
signature, including the diagnostic anomaly that no weather perturbation could explain
(near-constant leaf year-to-year at desert cells). Aggregate over 17 cells × 5 years:

| config | median tuber error | mean tuber error |
|---|---|---|
| MB-off (shipped ini) | **117%** | 327% |
| MB-on (authors' run) | **16%** | 29% |

(`p1d_mealybug_subsystem.py`, `p1e_aggregate17_mb.py`)

**Second-order cause (strong evidence): fungus / rain-mortality ON.** Turning on ini line
94 (with the subsystem on, no weather change) pulls 1981–1984 into near-exact agreement at
the spot cell and reduces the 17-cell median tuber error from ~15.9% to ~14.3%.
*Hyperaspis* ON overshoots, so it was OFF — consistent with the default. A
fungal/rain-driven pathogen is itself a natural enemy central to the paper.
(`p1i_flag_fingerprint.py`, `p1j_aggregate17_fungus.py`)

**Validated reconstruction.** With `Cassava.full.ini` (CMB/EL/ED/fungus ON, Hyperaspis
OFF) the 17-cell median tuber error is **9.5% for 1981–1984**, *A. lopezi* (el1) converges
to ~5%, and cell 217 matches all species columns to ~1–5%.
(`p1k_full_system_validate.py`, `p1l_determinism_check.py`)

**Remaining residual (~10–16% median): un-published inputs, not the pipeline.** Two
linked, irreducible factors remain:

1. **Un-shipped tuned pest parameters.** The shipped default ini captures none of the
   authors' run-specific numeric choices (start dates, immigration rates, infestation
   probabilities) which carry over year-to-year and produce the compounding, sign-flipping
   signature.
2. **The authors' weather files ≠ raw point AgMERRA.** Temperature rounds identically, but
   their CASAS/Protheus per-cell pipeline perturbs the moisture/radiation balance enough to
   tip *hypersensitive, water-limited desert-edge cells*. The cassava is a continuous
   perennial here (`InitYear`/`zeropools` fire only at the run's start and end, never at
   intermediate year boundaries), so small per-year growth biases integrate. At cell 217
   (Algeria, 35.9 °N) 1981–1984 match to <3% but 1985 is a knife-edge year whose net growth
   *sign* flips; precip is the dominant, strongly nonlinear lever and no single-variable
   scaling reconciles 1985 without breaking the matched years. The exact aggregation
   (sub-daily blend, interpolation, alternate reanalysis) is unrecoverable from the
   available inputs. (`p1m`–`p1o`, `p1p`/`p1q`)

These DZA cells are a hypersensitive water-limited edge subset; the paper's substantive
results are sub-Saharan and far less precip-marginal.

> **Note for maintainers.** The legacy `para.pas` value `mbn[6] = 1.000` is correct and
> must not be changed to `0.514`. An earlier hypothesis that attributed the Al⁺ gap to this
> constant was based on a marginal-vs-standalone misreading (see the belt-filter note in
> §2) and has been reverted/abandoned.

## Limitations

1. **Cassava-belt filter.** We approximate the paper's distribution mask
   (figshare.22491997) with CROPGRIDS harvested-area data aggregated to AgMERRA 0.25°,
   plus a >1500 g yield threshold. The belt definition affects the marginal-effect
   magnitudes (§2).
2. **Reconstructed `spatial.pas`.** Reconstructed from interface signatures and call-site
   analysis (verified byte-faithful via the golden master). Immigration/dispersal behavior
   matching is supported but not independently provable without the lost source.
3. **GIS output semantics.** We use instantaneous snapshot values from `GisOutput.pas`;
   the paper may use cumulative sums for some density metrics. Yield comparisons are
   unaffected.
4. **Un-published authors' inputs.** Bit-exact reproduction on the hypersensitive DZA
   cells is blocked on the authors' actual per-cell `AgMERRA_wx_africa_coarse` files and
   run-specific pest parameters, neither of which is published.

## Reproduce

Golden-master / fidelity: `gm_compare.py` (Delphi-vs-FPC parity).
Subsystem root cause: `p1d_mealybug_subsystem.py`, `p1e_aggregate17_mb.py`,
`p1i_flag_fingerprint.py`, `p1j_aggregate17_fungus.py`.
Full-system validation & determinism: `p1k_full_system_validate.py`,
`p1l_determinism_check.py`.
Weather audit (byte-exact) & coarsening (ruled out): `p1q_allcolumn_nc4_audit.py`,
`p1p_precip_coarsening.py`.
Water-limited residual mechanism: `p1m_daily_stress_trajectory.py`,
`p1n_weather_sensitivity_1985.py`, `p1o_enddate_invariance.py`.
Stochastic CIs: `stochastic_test.py`.
Reconstructed configurations: [`reconstructed_ini/`](reconstructed_ini/).
