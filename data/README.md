# `data/` — local data root (not version-controlled)

This directory holds the large input/cache data used by the cassava reproduction
and weather-conversion workflows. Its contents are **git-ignored** (see
`.gitignore`); only this README and the ignore rule are tracked. Scripts reference
data through repo-relative paths (`<repo>/data/...`), so the repository is portable
across machines once these directories are populated.

## Expected contents

| Subdirectory | Description | Produced by / source |
|---|---|---|
| `agmerra-pascal-weather-africa-1980-2010/` | Per-cell Pascal-format weather text files (`agmerra_XXXX_YYY_ISO_name.txt`), space-delimited, used as the model's `WxFile` inputs. | `tools/agmerra_to_pascal_weather.py` |
| `agmerra-cache/` | Raw AgMERRA yearly NetCDF4 drivers (`AgMERRA_<year>_<var>.nc4` for tmax, tmin, srad, prate, rhstmax, wndspd). | <https://data.giss.nasa.gov/impacts/agmipcf/agmerra/> |
| `cropgrids/` | CROPGRIDS cassava harvested-area grid (`CROPGRIDSv1.08_cassava.nc`), Natural Earth country borders (`ne_10m_admin_0_countries.geojson`), and the derived cell-selection mask / weather points-file (`cassava_africa_mask_agmerra.csv`). | `tools/download_cropgrids.py` + `tools/build_cassava_mask.py` |

## Populating

These directories are intentionally not committed (size: ~1 GB+). To recreate them:

- **AgMERRA cache:** download the yearly `.nc4` files into `data/agmerra-cache/`,
  e.g. `python3 tools/agmerra_to_pascal_weather.py --download-only --points-file
  data/cropgrids/cassava_africa_mask_agmerra.csv --start-year 1980 --end-year 2010
  --cache-dir data/agmerra-cache`.
- **CROPGRIDS + country borders:** `python3 tools/download_cropgrids.py --natural-earth`
  (or the FPC port `tools/download_cropgrids`) range-extracts the ~6.5 MB cassava grid
  from the 806 MB Figshare archive and downloads the Natural Earth admin-0 borders into
  `data/cropgrids/`.
- **Cell-selection mask / points-file:** `python3 tools/build_cassava_mask.py` (or the
  FPC port `tools/build_cassava_mask`) aggregates CROPGRIDS to the AgMERRA 0.25° grid,
  filters to African cassava cells with valid AgMERRA weather, and writes
  `cassava_africa_mask_agmerra.csv`. Add `--validate` to diff against an existing mask.
- **Weather files:** convert AgMERRA NetCDF4 to Pascal weather text with
  `tools/agmerra_to_pascal_weather.py --points-file
  data/cropgrids/cassava_africa_mask_agmerra.csv` (see `PORTING_NOTES.md`), writing
  into `data/agmerra-pascal-weather-africa-1980-2010/`.

Reproduction scripts in `reproduction/scripts/` resolve these paths relative to the
repository root, so no machine-specific absolute paths are required.
