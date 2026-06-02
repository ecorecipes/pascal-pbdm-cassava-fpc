# Getting started

A step-by-step guide to building and running the Free Pascal port of the CASAS cassava
tri-trophic PBDM. For the short version, see the **Quick start** in the
[README](../README.md). For deep technical detail on the port itself (the `spatial`
reconstruction, the Delphi golden master, floating-point findings, and reusable porting
patterns), see [`PORTING_NOTES.md`](../PORTING_NOTES.md).

Throughout, shell (`.sh`) commands are for macOS/Linux; the PowerShell (`.ps1`)
equivalents in parentheses are for Windows and also work cross-platform under
PowerShell 7 (`pwsh`).

## 1. Prerequisites

### Free Pascal compiler (required for everything)

The model and the Pascal data tools build with [Free Pascal](https://www.freepascal.org/)
(`fpc`), version 3.2.2 or newer.

| OS | Install |
|---|---|
| macOS | `brew install fpc` |
| Debian/Ubuntu | `sudo apt install fpc` |
| Windows | Installer from <https://www.freepascal.org/download.html> (add `fpc` to `PATH`) |

Verify with `fpc -version` (or `fpc -h`).

### NetCDF C library (only for the data-download tools)

The three data tools link against the NetCDF C library. You do **not** need it to build
or run the model itself with the bundled sample weather.

| OS | Install |
|---|---|
| macOS | `brew install netcdf` |
| Debian/Ubuntu | `sudo apt install libnetcdf-dev` |
| Windows | `conda install -c conda-forge netcdf-c` (or vcpkg: `vcpkg install netcdf-c`) |

The build script discovers the headers/libraries with `nc-config` when present;
otherwise pass the locations explicitly (see step 4).

### Optional

- **pandoc + xelatex** — only to re-render `PORTING_NOTES.md` to HTML/Word/PDF
  (`render-notes.sh` / `.\render-notes.ps1`).
- **Python 3** — only if you prefer the Python tools (`tools/*.py`) over the Free Pascal
  ports.

## 2. Clone the repository

```bash
git clone https://github.com/ecorecipes/pascal-pbdm-cassava-fpc
cd pascal-pbdm-cassava-fpc
```

## 3. Build the model

```bash
./build-fpc.sh          # Windows: .\build-fpc.ps1
```

This is equivalent to `cd cassava && fpc -Mdelphi cassava.pas`. Delphi mode
(`-Mdelphi`) is the baseline compatibility mode. The executable is written next to the
sources as `cassava/cassava` (`cassava\cassava.exe` on Windows). Build artifacts
(`*.o`, `*.ppu`, the binary) are git-ignored.

### Run immediately with the bundled sample weather

A small committed weather fixture lets you run without downloading any data:

```bash
cd cassava
./cassava Cassava.det.ini 01 01 1980 12 31 1985 365 wx.det.txt
```

The command-line arguments are **positional**:

```text
cassava <ini> <startMM> <startDD> <startYYYY> <endMM> <endDD> <endYYYY> <gisInterval> <weatherFile>
```

- `<ini>` — setup file (`Cassava.ini` for the full config, `Cassava.det.ini` for the
  deterministic sample run).
- start/end date — month, day, year for each.
- `<gisInterval>` — GIS output interval in days (e.g. `365` = annual summaries).
- `<weatherFile>` — path to a Pascal-format weather text file.

Outputs (written in `cassava/`):

| File | Contents |
|---|---|
| `Cassava_<date>_NNNNN.txt` | Per-cell georeferenced annual summaries (one file per year index); tab-delimited, header in the first row. The columns are documented in the [README](../README.md#description). |
| `CassavaSummaries.txt` | Across-year per-location means/std/CV used for GIS mapping. **Appended** across runs — delete it between runs to avoid mixing. |
| `GisFilesList.txt` | List of the GIS output files produced. |
| `CassavaDaily.txt` | Per-day trajectory for a single location, emitted when `daily=T` in the `.ini`. |

> **Line endings:** the native Free Pascal build is robust to both LF and CRLF input
> files — the `.ini` and weather files may use either, and produce identical numerical
> results. (The legacy Delphi build under wine instead requires CRLF; see
> `PORTING_NOTES.md`.)

## 4. (Optional) Build the data tools and download the paper datasets

Only needed to reproduce the paper's Africa-wide inputs. The datasets are large
(~1 GB+). Skip this if the bundled sample is enough.

```bash
./tools/build-tools.sh          # Windows: .\tools\build-tools.ps1
```

On Windows, if `nc-config` is not available, point the script at your NetCDF install:

```powershell
.\tools\build-tools.ps1 -IncludeDir C:\path\to\netcdf\include -LibDir C:\path\to\netcdf\lib
# or set $env:NETCDF_DIR so that <dir>\include and <dir>\lib exist
```

The tools (each supports `--help`):

| Tool | Purpose | Key flags |
|---|---|---|
| `download_cropgrids` | Range-extracts the ~6.5 MB cassava grid from the CROPGRIDS Figshare archive and downloads Natural Earth country borders into `data/cropgrids/`. | `--natural-earth`, `--full-zip`, `--out-dir`, `--overwrite` |
| `build_cassava_mask` | Aggregates CROPGRIDS to the AgMERRA 0.25° grid, filters to African cassava cells with valid weather, writes `cassava_africa_mask_agmerra.csv`. | `--cropgrids-nc`, `--countries-file`, `--agmerra-cache`, `--agmerra-year`, `--out`, `--validate` |
| `agmerra_to_pascal_weather` | Converts AgMERRA NetCDF4 drivers to Pascal weather text files. | `--points-file`, `--start-year`, `--end-year`, `--cache-dir`, `--out-dir`, `--download-only`, `--resume`, `--limit`, `--overwrite` |

Typical sequence:

```bash
./tools/download_cropgrids --natural-earth
./tools/build_cassava_mask
./tools/agmerra_to_pascal_weather \
  --points-file data/cropgrids/cassava_africa_mask_agmerra.csv \
  --start-year 1980 --end-year 2010
```

Equivalent Python tools (`tools/download_cropgrids.py`, etc.) accept the same flags if
you prefer not to build the Pascal ports.

Data lands under `data/` (all git-ignored). The expected layout and contents are
documented in [`data/README.md`](../data/README.md).

## 5. Edit the configuration and run your own scenario

`Cassava.ini` is **positional**, not key/value: `ReadInputs` expects lines in an exact
order, with `***` separator lines. Boolean switches are read as a single character and
are true only when that character is `T`/`t`. The file's inline comments document each
field; species combinations (cassava mealybug, parasitoids, green mite, mite predators,
Hyperaspis) are toggled here, along with initial conditions and the final `randseed`
(`0` = randomize; a positive value = repeatable sequence).

Then run against a weather file you produced in step 4, e.g.:

```bash
cd cassava
./cassava Cassava.ini 01 01 1980 12 31 1985 365 \
  ../data/agmerra-pascal-weather-africa-1980-2010/agmerra_0001_217_DZA_NF.txt
```

For a multi-location run, the model re-initializes per location and appends yearly
summaries; delete stale `CassavaSummaries.txt` and `Cassava_*.txt` before a fresh batch.

## 6. Numerical results across platforms

Output differs slightly by floating-point execution model, **not** by logic. The native
arm64/x86-64 (64-bit IEEE-754 double) build is the modernization target and is stable
and bit-identical across those CPUs; it sits ~0.26% from the legacy Delphi 3 / 32-bit
x87 (80-bit extended) results. This is the well-known x87-vs-64-bit intermediate
precision difference. See the [README](../README.md#numerical-reproducibility-across-platforms)
and `PORTING_NOTES.md` for the full analysis and the diagnostic builds
(`build-fpc-x87`, `build-fpc-win64`) used to establish it.

## Troubleshooting

- **`fpc: command not found`** — install Free Pascal and ensure `fpc` is on `PATH`.
- **`tools/build-tools.sh` can't find NetCDF** — install the NetCDF C library, or pass
  `-IncludeDir`/`-LibDir` (PowerShell) / set `NETCDF_DIR`.
- **Results mixed across runs** — `CassavaSummaries.txt` is appended; delete it (and any
  `Cassava_*.txt`) between runs.
- **Building the x87 diagnostic binary** — `build-fpc-x87.sh` uses wine + a Windows FPC;
  on Windows `build-fpc-x87.ps1` builds it natively but needs the i386-win32 compiler
  (`ppc386.exe`). Neither is required for normal use.
