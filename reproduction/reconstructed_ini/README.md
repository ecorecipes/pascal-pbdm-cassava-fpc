# Reconstructed `Cassava.ini` configurations (paper-derived)

These ini files reconstruct the run configurations used in Gutierrez, Ponti,
Neuenschwander, Yaninek & Herren (2025), *Predicting natural enemy efficacy in
biological control using ex-ante analyses*, **Scientific Reports**,
https://doi.org/10.1038/s41598-025-29022-1.

They were derived by mining the paper + supplement for the simulation design and
validating against the authors' shipped Zenodo output
(`../paper_zenodo/Cassava_06Nov25_0000{2..7}.txt`, Zenodo 17559583 v1.0.1).

> **Why these are needed:** the ini shipped in the Zenodo archive
> (`../paper_zenodo/Cassava.paper.ini`) is **byte-identical to the repo source
> default** (`pascal-pbdm-cassava/cassava/Cassava.ini`). It disables the
> mealybug/parasitoid subsystem and the rain-mortality fungus, so it does **not**
> capture the authors' run-specific configuration. The authors' own output files
> have the `mb*`, `ed*`, `el*` columns populated and 41 GIS columns
> (`gmtot/TariNum/TManNum` present) — proving the full tri-trophic system + fungus
> were ON. These reconstructed inis restore that configuration.

## Files

| File | Purpose | Subsystems ON | Presence/absence | Run period (CLI) |
|------|---------|---------------|------------------|------------------|
| `Cassava.full.ini` | **Validated** demo config matching the Zenodo `Cassava_06Nov25` output (41-col full tri-trophic) | CMB, *A. lopezi*, *A. diversicornis*, green mite, *T. aripo*, *A. manihoti*, fungus | OFF (deterministic) | `01 01 1980 12 31 1985` |
| `Cassava.cm.ini` | CM-system **marginal analysis** (cassava mealybug control) | CMB, *A. lopezi*, *A. diversicornis*, fungus (green-mite subsystem OFF) | ON | `01 01 1980 12 31 1990` |
| `Cassava.cgm.ini` | CGM-system **marginal analysis** (green-mite control) | green mite, *T. aripo*, *A. manihoti*, fungus (mealybug subsystem OFF) | ON | `06 01 1990 06 30 2000` |

All three keep `Hyperaspis jucunda` (line 88) **OFF** and `randseed = 0`
(line 97). Line endings are **CRLF** (required by the Delphi/wine parser).

## Flag deltas vs the repo-default ini

Each reconstructed ini = repo-default `Cassava.ini` with these boolean lines flipped:

| Line | Flag | default | full | cm | cgm |
|------|------|---------|------|----|-----|
| 24 | use presence/absence logic each year | F | F | **T** | **T** |
| 58 | include CMB (mealybug) | F | **T** | **T** | F |
| 66 | include *A. lopezi* | F | **T** | **T** | F |
| 71 | include *A. diversicornis* | F | **T** | **T** | F |
| 76 | include green mite | T | T | **F** | T |
| 81 | include pred1 *T. aripo* | T | T | **F** | T |
| 84 | include pred2 *A. manihoti* | T | T | **F** | T |
| 88 | include *Hyperaspis* | F | F | F | F |
| 94 | include fungus (rain mortality) | F | **T** | **T** | **T** |

## Paper-derived simulation design

- **CM (cassava mealybug) system:** simulated 1/1/1980–1990; first year (1980)
  excluded from prospective averages (1981–1990). Marginal regression independent
  variables: *A. lopezi* (Al+), *A. diversicornis* (Ad+), endemic fungal pathogen
  (P+). "Al+ was absent in about half of the simulations" — the presence/absence
  flag (line 24) randomly toggles each enemy present/absent per cell-year.
- **CGM (cassava green mite) system:** simulated 6/1/1990–6/30/2000; prospective
  1991–2000. Marginal variables: green mite (CGM+), *T. aripo* (Ta+),
  *A. manihoti* (Am+), fungal pathogen (P+).
- **"The endemic fungal pathogen on CM is included in all sub-figures"** → fungus
  (line 94) ON in every configuration.

## Validation status (`Cassava.full.ini`)

Golden-master Delphi x87 binary (`~/.wine-delphi3/drive_c/casgm/cassava.exe`,
proven byte-identical to the paper code) vs the authors' Zenodo output, 17 cells
(`agmerra_0001_{217..249 odd}_DZA_NF`), period 1980→1985:

- **Deterministic** (randseed=0 gives identical output across runs; `immigmethod=2`
  uses a mean-based migrant pool, not random draws).
- **Median tuber error 1981–1984: 9.5%**; *A. lopezi* (el1) converges to **~5%**.
  Cell 217 matches the authors to ~1–5% across **all** species columns (leaf,
  tuber, gmtot, mealybug, lopezi) for 1981–1984.
- **Residual:** tuber error compounds year-over-year (7→9→13→23→37%) while the
  pest columns converge — i.e. the gap is in the **perennial cassava biomass
  carryover**, consistent with un-shipped tuned plant parameters, **not** weather
  (proven byte-faithful, Finding 8) or code/precision (proven identical to the
  paper binary). 1985 shows a plant-level discontinuity (pests still match) right
  after the 1984 leap year.
- The authors' Zenodo "1986" GIS row is all-zeros = a terminal write, so their
  demo run ended at **end of 1985** (year-ends 1981–1985).

## Reproduction

```bash
# from pascal-pbdm-cassava-fpc/reproduction
/tmp/ncenv/bin/python scripts/p1k_full_system_validate.py   # 17-cell per-year error
/tmp/ncenv/bin/python scripts/p1l_determinism_check.py      # randseed=0 determinism proof
```
