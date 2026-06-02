# Free Pascal port of the cassava tri-trophic PBDM

This repository is a **[Free Pascal](https://www.freepascal.org/) port** of the CASAS
cassava tri-trophic PBDM, modernized from the legacy Borland Delphi 3 sources so the
model compiles and runs with the open-source `fpc` compiler on macOS, Linux, and
Windows. It aims to preserve the scientific behavior of the original model as used in:

> Gutierrez, A.P., Ponti, L., Neuenschwander, P. et al. Predicting natural enemy efficacy
> in biological control using ex-ante analyses. *Sci Rep* **15**, 44886 (2025).
> <https://doi.org/10.1038/s41598-025-29022-1>

The original Delphi description and run instructions are preserved unchanged
[further down](#pascal-code-for-the-cassava-tri-trophic-pbdm-system).

## What is different in this port

- **Builds with Free Pascal.** Compile the native binary with `./build-fpc.sh`
  (equivalently `cd cassava && fpc -Mdelphi cassava.pas`). Delphi mode (`-Mdelphi`) is
  the baseline compatibility mode. On **Windows**, where bash is not available, use the
  equivalent PowerShell scripts: `.\build-fpc.ps1` (model), `.\tools\build-tools.ps1`
  (NetCDF data tools), `.\build-fpc-x87.ps1` (32-bit x87 diagnostic build), and
  `.\render-notes.ps1` (docs). The `.ps1` scripts also run cross-platform under
  PowerShell 7 (`pwsh`).
- **Delphi-compatible random numbers.** Free Pascal's `Random` uses a Mersenne Twister,
  whereas Delphi 3 uses a linear congruential generator (LCG). Since the model is
  sensitive to stochastic plant placement, `cassava/rng.pas` provides a pluggable RNG
  that shadows `System.Random` and defaults to a Delphi-compatible LCG (multiplier
  `$08088405`, increment 1) so output can be compared bit-for-bit with the legacy build.
- **Reconstructed `spatial.pas`.** The source for the original `spatial.dcu` was lost.
  It has been reconstructed as `cassava/spatial.pas` by disassembling the compiled unit
  and validating against a genuine Delphi 3 golden master; it is verified byte-faithful
  to the original.
- **Data tooling.** `tools/` contains Python and equivalent Free Pascal utilities to
  fetch and prepare the inputs used in the paper: an AgMERRA NetCDF → Pascal weather
  converter, a CROPGRIDS cassava-grid downloader, and a builder for the African cassava
  weather-points mask.
- **Documentation.** `PORTING_NOTES.md` records the full port, the `spatial`
  reconstruction, the Delphi 3 golden-master setup, the floating-point findings, and
  reusable patterns for porting other CASAS Delphi models. Render it to HTML/Word/PDF
  with `./render-notes.sh`.

## Numerical reproducibility across platforms

Output differs slightly by floating-point execution model, **not** by logic:

- The legacy Delphi 3 build and a Free Pascal **i386 (x87)** build use the 80-bit
  extended x87 FPU and agree to within ≤0.031% (first simulated year exact).
- Every **64-bit scalar-double** build — native **arm64 (Apple Silicon)** and
  **x86-64 (SSE2)** — is bit-identical to the others but sits ~0.26% from the x87
  results. This is the well-known x87-80-bit vs IEEE-754-64-bit intermediate-precision
  difference and is irreducible without an 80-bit-extended backend. For the
  modernization target (native arm64/x86-64), the 64-bit build is correct and stable.

## Paper reproduction status

The `reproduction/` framework reproduces the paper's Africa-wide marginal-effect
analyses. **Qualitative results reproduce** (A. lopezi > A. diversicornis;
T. aripo > A. manihoti; cassava mealybug biocontrol recovery ≈95%), and CM marginal
damage matches within ~8%. Remaining quantitative gaps are attributable to the cassava
"belt" cell-selection definition and to legacy-source version drift (a dated 2024
re-fit of the endemic fungal-pathogen mortality cap that post-dates the paper's runs),
**not** to the port itself. See `PORTING_NOTES.md` for details.

## Quick start

Prerequisites: [Free Pascal](https://www.freepascal.org/) (`fpc`). The data tools also
need the NetCDF C library (`brew install netcdf` on macOS, `sudo apt install
libnetcdf-dev` on Debian/Ubuntu, `conda install -c conda-forge netcdf-c` on Windows).
On Windows use the `.ps1` scripts shown in parentheses.

```bash
# 1. Clone
git clone https://github.com/ecorecipes/pascal-pbdm-cassava-fpc
cd pascal-pbdm-cassava-fpc

# 2. Build the model              (Windows: .\build-fpc.ps1)
./build-fpc.sh

# 3. Run immediately with the bundled sample weather (no download needed)
cd cassava
./cassava Cassava.det.ini 01 01 1980 12 31 1985 365 wx.det.txt
```

That produces georeferenced `Cassava_<date>_NNNNN.txt` outputs plus
`CassavaSummaries.txt` in `cassava/`. To run your own scenario, edit
`cassava/Cassava.ini` (species switches and initial conditions; positional format) and
supply a weather file. The argument order is:

```text
cassava <ini> <startMM> <startDD> <startYYYY> <endMM> <endDD> <endYYYY> <gisInterval> <weatherFile>
```

To reproduce the paper's Africa-wide inputs instead of the bundled sample, build the
data tools and download the datasets (large; ~1 GB+):

```bash
# Build the NetCDF data tools     (Windows: .\tools\build-tools.ps1)
./tools/build-tools.sh

# Fetch CROPGRIDS cassava grid + country borders, derive the cell mask
./tools/download_cropgrids --natural-earth
./tools/build_cassava_mask

# Convert AgMERRA NetCDF drivers to Pascal weather text (1980–2010)
./tools/agmerra_to_pascal_weather \
  --points-file data/cropgrids/cassava_africa_mask_agmerra.csv \
  --start-year 1980 --end-year 2010
```

See **[`docs/getting-started.md`](docs/getting-started.md)** for a step-by-step guide
(per-OS prerequisites, exact tool flags, data layout, editing the `.ini`, interpreting
outputs, and the numerical-platform notes).

---

# Pascal code for the cassava tri-trophic PBDM system

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20274693.svg)](https://doi.org/10.5281/zenodo.20274693)

## Description

The meta population cassava GIS model was developed for scientific purposes and should not be used for commercial purposes. Copyright is held by the [Center for the Analysis of Sustainable Agricultural Systems](https://www.casasglobal.org/). The code has developer idiosyncrasies and is best used to develop similar code for other systems. The code is offered free access without warranty.

The repository has the following components to compile and run the model:

1. Delphi Pascal 3  `*.pas` files.
2. `modutils.pas` contains utilities (functions) called by the program (e.g., different version of distributed maturation time dynamics models).
3. The associated `*.DCU` files – note that the source codes for spatial.dcu was lost and the dcu is required for compiling.
4. The bat file to compile (`m.bat`) requires path corrections for your system.
5. The configuration file (cassava.ini) has all of the Boolean variables to run the various combinations of species in the model and the initial conditions (see additional notes in the file).
6. The run (r) file is in `rAfrica1980-2010windowscoarse.bat` with calls to specific locations (i.e., 1 or thousands of locations). An example call to one location is the following: `cassava cassava.ini 01 01 1980 12 31 1985 365 C:\models\wx\AgMERRA_wx_africa_coarse_1980-2010_windows\agmerra_0001_217_DZA_NF.txt`

The sub components of the location call line are:

- i. `cassava` is the simulation program,
- ii. `cassava.ini` is the setup file,
- iii. `01 01 1980 12 31 1985` says the start date is `01 01 1980` and the end date is `12 31 1985`
- iv. the path to weather data is `C:\models\wx\AgMERRA_wx_africa_coarse_1980-2010_windows\agmerra_0001_217_DZA_NF.txt`

If only one location is run (say on 15Aug2025), daily (or more coarse time intervals) output for that location can be specified in the `cassava.ini` file. If multiple locations are run (say 15,000 lattice cells across Africa) for say years 1980-2010, then at the end of every year, summary variables are appended to the text file `Summary.txt`, and yearly georeferenced summary variables are appended to text files `Cassava_15Aug25_00002`, ... , `Cassava_15Aug25_00010`, each of which contains that year’s results for all locations for that year. An example of tab delimited output for BEN_ikpinle.txt is illustrated below with the first line being the header line of variables and the second line are variable values.

Header:

`Model Date Time WxFile Long Lat JdStart JdEnd Month Day Year dd root stem leaf tuber leafnum sdlsr nsdlsr wsd sqdecmplt lai evapsoil fielddem avgev wvgwd gmtot TariNum TManNum mb1 mb2 mb3 mb4 mb5  mb6 ed1 ed2 ed3 el1 el2 el3`

Output line:

`CasGIS 15Aug25 8:07:28-PM C:\models\wx\agmerra_0011_332_BEN_ikpinle.txt 2.6250 7.1250 150 151 12 30 1991 3622 0.000 3.250 0.000 0.000 0.000 1.00  1.00 1.00 0.001 0.000 0.249 0.010 0.249 0.010 0.0682 0.0059 0.0000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.000 0.0000.000`

The `Summary.txt` file is used for statistical analyses and the means, std and coefficient of variation are computed for each location across `Cassava_15Aug25_00002`, ... , `Cassava_15Aug25_00010` and are used for GIS mapping. Once the run for one location is completed, the program re-initializes and goes to the next location in the `rAfrica1980-2010windowscoarse.bat` file for the next location to run. When all runs are completed, the program terminates.

Then the analysis can begin.

Andrew Paul Gutierrez

Luigi Ponti

## License

SPDX-License-Identifier: [GPL-3.0-or-later](https://spdx.org/licenses/GPL-3.0-or-later.html)

## Authors

- Andrew Paul Gutierrez (University of California, Berkeley / CASAS Global - Center for Analysis of Sustainable Agriculture Systems)
- Luigi Ponti (ENEA - Agenzia nazionale per le nuove tecnologie, l'energia e lo sviluppo economico sostenibile / CASAS Global)
