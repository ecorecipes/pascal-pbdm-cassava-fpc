# Free Pascal porting notes

Reference log for porting the CASAS Delphi Pascal cassava PBDM to Free Pascal, and
for reproducing the results of Gutierrez et al. (2025, *Scientific Reports*,
doi:10.1038/s41598-025-29022-1). It records the compatibility changes the port
needed, the reconstruction of the lost-source `spatial` unit, the Delphi 3 golden
master used for validation, the floating-point findings, and the reusable patterns
worth applying to other CASAS Delphi model ports.

Paths are repo-relative. The legacy Delphi tree is the sibling `pascal-pbdm-cassava/`;
this port is its own tree. Large data and the wine prefix are referenced via
repo-relative or `$HOME`-relative paths, never machine-absolute paths.

---

## 1. Layout and build

- **Legacy reference:** `../pascal-pbdm-cassava/cassava/` — original Delphi 3 sources,
  the lost-source `spatial.dcu`, and checked-in golden output artifacts. Kept intact
  for comparison.
- **Port:** this tree. Native build (the modernization target) from `cassava/`:

  ```bash
  ./build-fpc.sh          # = cd cassava && fpc -Mdelphi cassava.pas
  ```

- **Diagnostic builds under wine** (FP-comparison only, see §6–7):
  - `build-fpc-x87.sh` — 32-bit i386-win32 (x87 80-bit extended), matches Delphi 3.
  - `build-fpc-win64.sh` — 64-bit x86_64-win64 (SSE2 scalar double), matches arm64.
- Build artifacts (`cassava/cassava`, `*.ppu`, `*.o`, compiled tool binaries,
  `__pycache__`) are git-ignored via the root `.gitignore` and `tools/.gitignore`;
  only source is tracked.

`-Mdelphi` is the baseline compatibility mode for all CASAS Delphi ports — it matches
the Borland Delphi 3 dialect and avoids churn in legacy syntax/comments. Use it first,
and make source changes only where Delphi mode is insufficient.

---

## 2. Data directory convention

- Large inputs/caches live in the repo-internal `data/` directory and are **git-ignored**
  (`data/.gitignore` tracks only itself and `data/README.md`). Scripts reference data
  through repo-root-relative paths, never machine-specific absolute paths.
- Expected subdirectories (see `data/README.md`):
  `agmerra-pascal-weather-africa-1980-2010/` (Pascal weather text files),
  `agmerra-cache/` (raw AgMERRA `.nc4`), `cropgrids/` (CROPGRIDS cassava mask).
- Reproduction scripts in `reproduction/scripts/` resolve the data root via
  `Path(__file__).resolve().parents[2] / "data"`, so they run from any cwd.

---

## 3. Tools directory convention

Helper tools live in `tools/`, each with equivalent Python and Free Pascal ports:

- `agmerra_to_pascal_weather.{py,pas}` — AgMERRA `.nc4` → Pascal weather text. Uses
  checked-in GIS output files as point lists (`WxFile`, `Long`, `Lat`) to materialize
  only the per-cell weather files needed, not the full 40,000+ cell archive. AgMERRA
  `srad` is `MJ/m2/day`; the converter multiplies by `1e6/86400` to W/m2 (what
  `wxread.pas` expects before its ×2.066 Langley conversion). Python version has a
  built-in downloader. Source: <https://data.giss.nasa.gov/impacts/agmipcf/agmerra/>.
- `download_cropgrids.{py,pas}` — downloads the CROPGRIDS v1.08 cassava grid from
  Figshare (`doi:10.6084/m9.figshare.22491997`). Default mode **range-extracts** only
  the ~6.5 MB cassava member from the 806 MB archive via HTTP partial-ZIP reads
  (probe size → EOCD → central directory → inflate one member); `--full-zip` downloads
  the whole archive. `--natural-earth` also fetches Natural Earth 10m admin-0 borders.
  Both ports emit a byte-identical `.nc`; the Pascal port uses `curl -r` range requests
  and `zstream` raw inflate.
- `build_cassava_mask.{py,pas}` — reconstructs the cell-selection/weather-points mask
  `data/cropgrids/cassava_africa_mask_agmerra.csv` from CROPGRIDS. Aggregates 0.05°
  harvested area to the AgMERRA 0.25° grid (exact 5×5 block sum, Ocean→0), keeps African
  cassava cells with valid AgMERRA weather, assigns ISO3 country + UN-M49 subregion, and
  emits `agmerra_<lonidx>_<latidx>_<ISO3>_<sub>.txt` names. `--validate` diffs against an
  existing mask. Reproduction fidelity vs the shipped CSV: **100%** of reference cells
  recovered, harvarea exact to ±0.01 ha, **99.59%** country labels (residual is genuine
  border cells under an unknown borders source). The Pascal port reads CROPGRIDS via
  libnetcdf and parses the GeoJSON with `fpjson` + ray-cast point-in-polygon; it matches
  the Python tool's aggregate metrics exactly.
- `DCU32INT/` — the Delphi DCU disassembler (vendored from `github.com/sarog/DCU32INT`)
  with local FPC-port patches; used to reconstruct `spatial.pas` (see §5). Build:
  `fpc -Mdelphi -dXMLx86 -dI64 -Fu80x86 DasmUtil.pas` then `... DCU32INT.dpr`.

**FPC tool build flags (libnetcdf).** The NetCDF-linked Pascal tools
(`agmerra_to_pascal_weather`, `download_cropgrids`, `build_cassava_mask`) must be built
with C linker flags in addition to the FPC search paths — `external 'libnetcdf.dylib'`
alone does **not** make FPC pass the library to `ld`:

```bash
fpc -Mdelphi -Fi/opt/homebrew/include -Fl/opt/homebrew/lib \
    -k-L/opt/homebrew/lib -k-lnetcdf  <tool>.pas
```

Without `-k-L.../-k-lnetcdf` the link fails with `Undefined symbols ... _nc_open`.
Install with `brew install netcdf` (macOS) / `apt install libnetcdf-dev` (Debian); on
Linux adjust `-k-L<libdir>`. The Python tools need `netCDF4`, `numpy`, and (for the mask
builder) `shapely` in a venv.

---

## 4. Free Pascal compatibility changes

Source-level changes the port needed to compile and run faithfully under `fpc -Mdelphi`:

- **Comment normalization** in `globals.pas`: a stray `{{...}` double-open brace
  confused FPC comment parsing; normalized to a single brace. Clean clear typographic
  comment issues that block parsing; avoid broad comment rewrites.
- **Duplicate `i100` type removed** from `modutils.pas`. Both `globals.pas` and
  `modutils.pas` defined `i100 = array[1..100] of integer`; in FPC strict mode these are
  distinct nominal types, breaking `shufl(var deck:i100;...)`. Keep the single
  `globals.i100` definition.
- **`Cassava.ini` `milsecdelay` parse fix.** The ini's `milsecdelay` line (a Delphi GUI
  graphics delay) was never consumed by `init.pas`, shifting every later `readln` by one
  line so `immigmethod` and `randseed` read the wrong values. *This bug existed in the
  legacy Delphi build too* — the original binary effectively ran with `immigmethod=1`,
  `randseed=2`. Fixed by adding `readln(setfile, milsecdelay)` in `init.pas` and declaring
  `milsecdelay: integer` in `globals.pas` (read but unused).
- **`means.pas` deck indexing for scattered mode.** `means.pas` indexed per-plant
  pointer arrays directly (`casPtrs[i]^`), which is only valid when `deck[i]=i`
  (`distribution=1`, rows). Under `distribution=2` (scattered) the deck is shuffled, so
  slots 1..ncas may be unallocated → access violation. Changed all per-plant accesses to
  `...[deck[i]]^`. No-op in row mode. (The real Cassava.ini uses rows; this is for other
  ports / scattered runs.) **Pattern:** always access per-plant pointer arrays via
  `deck[]` indirection in any code that may run scattered.

### Pluggable RNG unit (`rng.pas`)

FPC's `Random` is a Mersenne Twister; Delphi's is an LCG (multiplier `$08088405` =
134775813, increment 1). The same `RandSeed` yields completely different sequences, and
the model is sensitive to stochastic plant placement, so RNG choice affects output.

`rng.pas` declares `Random`/`Randomize` overloads that **shadow** the `System` versions
(last unit in `uses` wins) and a `TRNGKind` enum (`rkDelphi`, `rkFPC`). The Delphi LCG
follows <https://wiki.freepascal.org/Delphi_compatible_LCG_Random> and uses
`System.RandSeed` directly as state, so the existing `readln(setfile, randseed)` works
unchanged. Default `rkDelphi` for legacy comparison; `rkFPC` for the native MT once
validated. Add `rng` as the **last** unit in `uses` for every file that calls `Random`:
`cassava.pas` (and its `$I PRESENCE.PAS`), `gmite.pas`, `hj97.pas`, `Hyperaspis.pas`,
`init.pas`, `mb.pas`, `models.pas`, `modutils.pas`, `para.pas`, `preds.pas`,
`SETUPCAS.PAS`, `water.pas`.

**Pattern:** for any Delphi model using `Random`, shadow it with a same-named unit listed
last in `uses` — non-invasive, no source renames. (The `{$MACRO ON}`/`{$DEFINE
random:=LCGRandom}` approach also works but is more fragile around comments/strings.)

---

## 5. Reconstructing `spatial.pas` (the lost DCU)

`spatial.dcu` ships with the legacy model but its source was lost, and FPC cannot consume
Delphi 3 `.dcu` files. `spatial` is `uses`d by `cassava.pas`, `nitr.pas`, and `water.pas`.
It was reconstructed as `cassava/spatial.pas` and is now **verified byte-faithful** to the
original (see "Verification" below).

**Workflow (reusable for any lost-source `.dcu`):**

1. Infer the API from call sites, then dump the real DCU with the vendored DCU32INT —
   `-I` for the interface first, `-S` for the full disassembly:

   ```bash
   ../tools/DCU32INT/DCU32INT spatial.dcu -I -U. ../reconstruction/spatial.interface.int
   ../tools/DCU32INT/DCU32INT spatial.dcu -S -U. ../reconstruction/spatial.full.int
   ```

2. Recovered public API:

   ```pascal
   function  cellarea(i, j: Integer; l, t, r, b: Single): Single;  { rect / grid-cell overlap }
   function  inwind(xl, xr, ya, yb, left, right, top, bottom: Integer): Boolean;
   procedure setsides;   { plant canopy extent -> sqdmpl, for light interception }
   ```

   `spatial` is purely canopy/light geometry + soil-water cell overlap — **not** insect
   dispersal (that is the metapopulation immigration mechanism in `mb.pas`/`para.pas`/
   `gmite.pas`/`preds.pas`/`Hyperaspis.pas`, which are faithful non-reconstructed ports).
   `inwind` is present in the interface but never called by the model.

3. Decode each procedure from the `.int` disassembly. Plant-record field offsets recovered
   from it: `1008`=tdda, `1052`=totall, `1132`=glf, `1996`=x, `2000`=y, `2020`=jl,
   `2024`=ja, `2028`=jr, `2032`=jb, `2036`=sidel, `2040`=sidea, `2044`=sider, `2048`=sideb,
   `2052`=sqdmpl.

**Key reconstructed details (all verified against the DCU):**

- `cellarea` uses literal three-case width/height branches (not `min`/`max`) with cell
  constants `nl = i*0.5 - 1.0`, `nr = i*0.5 - 0.5`. The three selections are independent
  `if` statements (not an `else if` chain) — matching this closed the last codegen gap.
- `setsides`'s `newb := y + (limitb - y) * (neww / w)` uses the **x-ratio `neww/w`**, not
  the expected `newh/h`. This is an original-source quirk, preserved for fidelity (`newa`
  correctly uses `newh/h`). There is no `w<=0/h<=0` guard — the 0.001 epsilon clamps on the
  limits guarantee positive `w`/`h`.
- **The decisive `setsides` bug (the stochasticity root cause).** The senescence/shrink
  branch must be `if demarea<0.0 then newarea := leafarea` (shrink the footprint to the
  demanded leaf area). The first reconstruction wrongly kept `newarea := currentarea`
  (oversized footprint → `sqdmpl` too high → lower LAI → ~7% lower tuber yield). The wrong
  version made the daily tessellation depend on shuffled processing order, which is why the
  port was stochastic while the original is deterministic. After the fix the port is
  **seed-insensitive** and the lattice converges order-independently, matching the golden
  master. Found at `reconstruction/spatial.full.int` `setsides` source-line #384.
- **Scattered-mode `limoverlap`/`findscatlims`** (reachable only when `scattered=true`,
  `distribution=2`; dead code for the real row-mode run). Decoded fully from the DCU:
  block order is **limitl → limita → limitr → limitb** (each block's inner clamp reads
  sibling limits earlier blocks may have modified); constants are **0.2** (far-side inset)
  and **0.1** (centre half-gap), recovered as 80-bit extendeds at DCU file offsets 2597 and
  2609. `findscatlims` uses `maxwidth*0.5`.

### Verification: byte-faithful to the original `spatial.dcu`

The reconstruction was compiled under the genuine Delphi 3 `dcc32` (wine, §6) and the
resulting `.dcu` decompiled and compared procedure-by-procedure against the original
(`reconstruction/spatial.full.int`):

| procedure | original Sz | reconstructed Sz | status |
|---|---|---|---|
| `cellarea` | `140` | `140` | byte-exact |
| `inwind` | `63` | `63` | byte-exact |
| `limoverlap` | `428` | `428` | byte-exact |
| `findscatlims` | `88` | `88` | byte-exact |
| `setsides` | `6FC` | `6E8` | FP-arithmetic byte-exact; 20-byte residual is integer/loop-register codegen only |

All 223 FP mnemonics / 107 arithmetic ops in `setsides` are identical in order and operand
kind; the residual bytes are loop-counter/`deck[]`-index register allocation that touches no
single-precision value. Three association/code-shape discrepancies found by diffing the
normalized FP-op streams were fixed for fidelity (Expo-argument association
`suparea/demarea*alpha`; inline `(limitr-limitl)`/`(limitb-limita)` recomputation; the
separate-`if` `cellarea` shape). All are numerically inert. `spatial.pas` is therefore
**exonerated** as a source of any residual model divergence.

**Reusable technique:** to prove a reconstructed unit faithful to a lost `.dcu`, compile it
under the original `dcc32`, decompile both with `DCU32INT -S`, compare per-procedure `Sz:`
first, then diff the **FP-op stream only** (normalizing stack offsets, const-pool labels,
register names). A reversed `FDIV;FMUL` / `FSUB`-operand-order reveals an
operator-association bug. Trust the disassembly over plausible-looking reconstructions, and
make sure differential probes exercise *every* branch (the `setsides` shrink bug hid in
`demarea<0`, which an early growth-only probe never covered).

---

## 6. Golden master: Delphi 3 `dcc32` under wine

A genuine Delphi 3 toolchain (from a legal ISO) is installed in the wine prefix
`$HOME/.wine-delphi3` (Delphi tree at `C:\Delphi30`). It can both compile and run the
original cassava, linking the lost-source `spatial.dcu`, giving a true golden master for
Delphi-vs-FPC comparison. The canonical golden-master build/run dir is
`$HOME/.wine-delphi3/drive_c/gm/` (legacy `.pas` sources, original `spatial.dcu`, prebuilt
`cassava.exe`, `dcc32.cfg`, a CRLF weather file).

**Two env gotchas — set both inline on every call** (each bash invocation is a fresh shell;
env does not persist):

- `export WINEPREFIX="$HOME/.wine-delphi3"` — without it wine uses `~/.wine`, where
  `C:\Delphi30` is absent and `dcc32` dies with `Fatal: File not found: 'System.pas'`.
- `export WINEPATH='C:\Delphi30\BIN'` — seeds the DOS `PATH` so `dcc32` and its sibling
  DLLs (`DCC.DLL`, `RLINK32.DLL`) resolve from `BIN`. Without it: `ShellExecuteEx failed:
  File not found`, or `c0000135` if you launch by absolute path. **Launch `dcc32` by bare
  name** with cwd = the source dir; never by absolute path.

Canonical preamble:

```bash
export WINEPREFIX="$HOME/.wine-delphi3"
export WINEPATH='C:\Delphi30\BIN'
export WINEDEBUG=-all MVK_CONFIG_LOG_LEVEL=0
cd "$HOME/.wine-delphi3/drive_c/gm"
wine dcc32 -cc cassava.pas /M /GD /V /$D+        # rebuild (optional); -cc console, /M make
wine cassava.exe Cassava.ini 01 01 1980 12 31 1985 365 wxcrlf.txt
```

`dcc32.cfg` in the build cwd points unit/lib/include/object/resource paths at
`C:\Delphi30\LIB` (`-UC:\Delphi30\LIB -IC:\Delphi30\LIB -OC:\Delphi30\LIB
-RC:\Delphi30\LIB`). The `m.bat` `/Uc:/Models/SharedCode` path is not needed
(`glob50`/`util50` are referenced only by the un-`$I`-included orphan `getmeans.pas`).

**CRLF vs LF asymmetry (critical for running, not just building).** Delphi under wine strips
a trailing CR on text reads, so it **requires CRLF** for both `.pas` sources and the
`Cassava.ini`/weather files; an LF-only ini makes `readaster`/`wxread` misparse (empty
`GisFilesList.txt`, `errorlog` with `Expected to read asterisk` or `Invalid Month in Julian
Function: 0`). The FPC port on Unix does **not** strip CR and **requires LF**. Comparison
protocol: legacy gets CRLF, FPC gets the LF twin
(`awk '{printf "%s\r\n",$0}' lf.txt > crlf.txt`). The benign wine-loader
`RPC_S_SERVER_UNAVAILABLE (0x6ba)` SEH trace is a red herring.

**Determinism notes.** The genuine golden master is **seed-independent** (identical output
for any seed) and deterministic; with all `Cassava.ini` seasonal-variation flags `f` it
never lets `random()` affect output. `CassavaSummaries.txt` is **appended** across runs —
delete it between runs. `daily=T` emits per-day `CassavaDaily.txt` for day-by-day divergence
tracing. To instrument intermediate values, edit the `gm/` `.pas` sources (keep CRLF),
rebuild with `dcc32`, and re-run — the same instrumentation can be applied to both sides.

---

## 7. Arithmetic matching: x87 vs IEEE-754 double

After the `spatial.pas` `setsides` fix made the port deterministic, a small steady residual
remained between the native arm64 FPC build and the Delphi 3 golden master (1981 tuber:
arm64 164.128 vs Delphi 164.548, ~0.26%). This is **not a logic bug** — it is a
floating-point execution-model difference, and it is irreducible.

- Delphi 3 (i386) computes on the **x87 FPU** with 80-bit `extended` intermediates.
- Native FPC on **arm64** has no x87 / no 80-bit type (`Extended = Double`) and uses scalar
  IEEE-754 64-bit doubles.

**Building an i386-win32 (x87) FPC binary under wine** (`build-fpc-x87.sh`) reproduces
Delphi's precision model and cuts the gap to **≤0.031% (1981 exact)**.

**The decisive test — x86_64-win64 FPC (SSE2) is bit-identical to arm64 (NEON).** A third
target (`build-fpc-win64.sh`, `ppcrossx64.exe -Twin64`) runs on the *same* arm64 Mac under
wine but uses the SSE2 scalar-double backend. Deterministic 1980-start run, tuber by year:

| Year | Delphi x87 (genuine) | FPC i386 x87 (wine) | FPC x86_64-win64 (wine) | FPC arm64 (native) |
|---|---:|---:|---:|---:|
| 1981 | 164.548 | 164.548 | **164.128** | **164.128** |
| 1982 | 87.569 | 87.565 | **87.366** | **87.366** |
| 1983 | 129.424 | 129.428 | **129.467** | **129.467** |
| 1984 | 96.537 | 96.507 | **96.443** | **96.443** |
| 1985 | 69.118 | 69.113 | **69.167** | **69.167** |

Results cluster **strictly by FP-execution model, not by CPU**: the two x87 backends agree
to ≤0.031%; the two 64-bit-double backends (SSE2 *and* NEON) are **bit-identical to each
other**. Because x86_64-win64 runs on the same machine as arm64 yet matches arm64, the
divergence is conclusively **not arm-specific, not NEON-specific, and not a porting bug** —
it is the x87-80-bit-extended vs IEEE-754-64-bit-double intermediate-precision difference.

Supporting findings:

- **Transcendentals.** `ln`/`sqrt`/`arctan` (`FYL2X`/`FSQRT`/`FPATAN`) are bit-identical
  between Delphi 3 and FPC i386. FPC's i386 `exp` differs by ≤1 ULP, so `modutils.Expo` is
  routed through a hand-written x87 `DelphiExp` (guarded `{$IFDEF CPUI386}`; inert on arm64)
  that reproduces Delphi's `FLDL2E/F2XM1/FSCALE` sequence bit-for-bit. Because results are
  stored in `single`, this ≤1-ULP extended difference does **not** propagate — model output
  is identical with or without `DelphiExp`.
- **Precision-control width is not the variable.** Forcing the x87 PC field to 53-bit
  (`Set8087CW($1272)`) gives output bit-identical to PC=64, and *not* the arm64 value. So
  the gap is not "x87 keeps 80 bits, SSE keeps 64"; it is operation-sequencing / library /
  FMA-contraction codegen, accumulated across years.
- **The residual is cross-year accumulation.** The first year of any fresh-start run matches
  Delphi exactly; the same calendar year reached after several accumulated years drifts by
  ≤0.031%. A single well-conditioned season is too short to surface it.

**Conclusion:** for the modernization target (native arm64) the SSE build is correct and
stable. ≤0.031% (1981 exact) against Delphi 3 is the practical floor and is irreducible
without an 80-bit-extended backend.

**Reusable diagnostic:** when an arm64 FPC port diverges from an x87/Delphi reference, build
a third `x86_64-win64` target under wine. If it matches arm64 (not x87), the divergence is
the FP model — stop hunting for arm-specific or porting bugs.

---

## 8. Paper reproduction (Gutierrez et al. 2025)

`reproduction/` holds the scenario driver, results collector, and analysis scripts that
reproduce the Africa-wide marginal-effect tables from the paper across the alternating
lattice cells with the CROPGRIDS cassava mask applied. The qualitative findings reproduce
well — A. lopezi > A. diversicornis, T. aripo > A. manihoti, CM biocontrol recovery ~95% —
and CM marginal damage matches within ~8% (−1176 g vs paper −1085 g). Getting there required
five preprocessing/configuration corrections, all of which are reusable cautions for other
CASAS reproductions.

1. **`distribution=1` (rows), not `2` (scattered).** The reproduction scripts initially
   defaulted to scattered placement; the original `Cassava.ini` uses rows with ±20% spacing
   perturbation. The paper's "randomly spaced plants" refers to that perturbation, not
   scattered placement. This was the single biggest quantitative fix (CM overshoot 36% → 8%).
   **Always verify INI parameters byte-for-byte against the original, not against paper prose.**
2. **`FMin` (fungus) gates rainfall/pathogen mortality for *both* CM and CGM**
   (`mb.pas`, `gmite.pas`). Scenarios with `fungi=F` disable it, inflating pest damage. A
   full factorial needs fungi-on and fungi-off variants. Check which mortality pathways a
   cross-cutting switch gates before designing a scenario matrix.
3. **Marginal effects come from a regression with interaction terms, not scenario
   subtraction.** The paper fits `Y = β0 + Σβ·x + Σβ·x·x` over presence/absence dummies and
   reports interaction-adjusted partial derivatives at the product of dummy means. Simple
   scenario subtraction conflates the main effect with absent interactions and evaluates at
   the wrong point. Match the paper's **exact model specification and effect definition**
   before comparing or tuning constants; verify equations from ≥2 renderings (HTML MathML +
   PDF) and reconstruct the reported marginals from the coefficients as a self-check.
4. **Snapshot vs cumulative GIS output.** The compiled `GisOutput.pas` writes
   *instantaneous* per-plant means; the alternative `gisout.pas` writes *cumulative daily
   sums*. Density metrics (e.g. "annual cumulative CGM eggs+immatures") need the cumulative
   form; yield/state totals are unaffected.
5. **Exclude the empty final/equilibration year and apply the external cassava-distribution
   mask.** The last GIS file per cell is a zero-value initialization record (filter on
   `dd==0`, not file index). The paper masks results to the CROPGRIDS cassava distribution
   (ref 35) *before* the `tuber>1500 g` belt threshold — the two filters together change cell
   inclusion, mean values, and regression coefficients. Belt definition is the dominant
   source of remaining quantitative spread. The legacy `casas-gis/` R/Perl preprocessing
   (`StatSum.R` first-year exclusion, `SubtractOutput.pl`, `lineSelect.pl`) is the
   authoritative reference for hidden filtering not documented in the paper.

**Residual fungal-pathway difference — legacy/paper version drift, not a port bug.** After
the above, one robust biology-side residual remains: the endemic fungal-pathogen (P) effect
is ~0.45× the paper's. It is the `0.45` cap in `mb.pas:602`:

```pascal
Cmbrmort := 0.45*(1.0 - EXP(-0.025*precip));  {-0.025 new fit 5-29-2024 APG}
```

The green-mite form (`gmite.pas:224`, `exp(-0.025*rain)`) lacks the cap. A paired diagnostic
(cap `0.45`→`1.00`, identical cells, fungus-off baseline as anchor) ~4×'d the fungal rescue,
confirming the cap as the dominant cause. The discrepancy is **legacy-source drift** — the
dated `5-29-2024 APG` re-fit post-dates or was absent from the paper's runs. **Pattern:** a
faithful port can still diverge from a paper because the legacy source drifted past the
paper's run version; look for dated `{... APG}` "new fit" comments as candidate drift points,
and confirm with a paired diagnostic binary that toggles one constant on identical cells.

> Cleanup note: an earlier hypothesis attributing the A. lopezi over-effectiveness to a
> `para.pas` `mbn[6]` `1.000`→`0.514` parameter change was a dead end and was reverted. It
> confused the paper's *interaction-adjusted marginal* (575.8 g) with the *main coefficient*
> (b_Al = 958.0); fitting the paper's exact regression to the unmodified `1.000` binary gives
> Al/CM = 0.882 vs the paper's 958.0/1085 = 0.883 — i.e. the parasitoid constant is correct.
> Lesson: don't tune constants against the wrong effect definition (see point 3).

---

## 9. Open items

- Numeric reproduction tuning is limited by belt/cell-inclusion definition (point 5) and the
  fungal-cap version drift; the qualitative and within-~8% quantitative match is the current
  state.
- Scattered-planting (`distribution=2`) is fully decoded but exercised only by dead code in
  the real run; keep it in sync if a scattered-layout CASAS model is ported.
