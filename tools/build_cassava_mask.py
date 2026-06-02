#!/usr/bin/env python3
"""Derive the cassava harvested-area mask / weather points-file from CROPGRIDS.

This reproduces ``data/cropgrids/cassava_africa_mask_agmerra.csv``: the list of
AgMERRA 0.25-degree lattice cells over Africa where cassava is grown, which
drives per-cell weather generation (``tools/agmerra_to_pascal_weather.py``).

Pipeline (each step verified penny-exact against the shipped CSV):

1. Read CROPGRIDS v1.08 cassava ``harvarea`` (0.05 deg, 7200x3600, ascending
   lon/lat, Ocean = -1).
2. Aggregate to the AgMERRA 0.25 deg grid.  CROPGRIDS is exactly 5x the AgMERRA
   resolution and grid-aligned, so every AgMERRA cell is exactly 5x5 CROPGRIDS
   cells; Ocean(-1) is treated as 0 and the block is summed (hectares).
3. Keep cells with ``harvarea > 0`` whose centre falls inside an African country
   (Natural Earth 10m admin-0 point-in-polygon).
4. Emit ``agmerra_<lonidx4>_<latidx3>_<ISO3>_<subregion2>.txt`` weather-file
   names with 1-based AgMERRA indices (lon in 0-360 convention, lat from north),
   plus the aggregated harvested area.

The country borders come from Natural Earth (``--countries-file``); download it
once with ``tools/download_cropgrids.py --natural-earth`` or pass your own copy.
Run ``--validate`` to diff the generated mask against the shipped CSV.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

try:
    from netCDF4 import Dataset
    import numpy as np
except ImportError as exc:  # pragma: no cover - environment guidance
    raise SystemExit(
        "Missing Python dependency 'netCDF4'/'numpy'. Create a venv and install them:\n"
        "  python3 -m venv /tmp/pbdm-venv\n"
        "  /tmp/pbdm-venv/bin/pip install netCDF4 numpy shapely\n"
    ) from exc

# AgMERRA grid geometry (0.25 deg).  Longitudes use the 0..360 convention with
# cell centres at 0.125, 0.375, ...; latitudes run north-to-south from 89.875.
AGMERRA_RES = 0.25
CROPGRIDS_FACTOR = 5  # 0.25 / 0.05

# UN M49 sub-region code (as used in the weather-file names) for every African
# country that appears in the shipped cassava mask.  Two-letter codes:
#   EA Eastern Africa, MA Middle (Central) Africa, WA Western Africa,
#   SA Southern Africa, NF Northern Africa.
COUNTRY_SUBREGION = {
    "AGO": "MA", "BDI": "EA", "BEN": "WA", "BFA": "WA", "BWA": "SA",
    "CAF": "MA", "CIV": "WA", "CMR": "MA", "COD": "MA", "COG": "MA",
    "ERI": "EA", "ETH": "EA", "GAB": "MA", "GHA": "WA", "GIN": "WA",
    "GMB": "WA", "GNB": "WA", "GNQ": "MA", "KEN": "EA", "LBR": "WA",
    "MDG": "EA", "MLI": "WA", "MOZ": "EA", "MRT": "WA", "MWI": "EA",
    "NAM": "SA", "NER": "WA", "NGA": "WA", "RWA": "EA", "SDN": "NF",
    "SEN": "WA", "SLE": "WA", "SOL": "EA", "SOM": "EA", "SSD": "EA",
    "STP": "MA", "TCD": "MA", "TGO": "WA", "TZA": "EA", "UGA": "EA",
    "ZAF": "SA", "ZMB": "EA", "ZWE": "EA",
}

# Natural Earth uses a few admin-0 codes that differ from the mask's ISO3.
ISO_REMAP = {"SDS": "SSD"}


def aggregate_harvarea(nc_path: Path):
    """Return (agg_ha, lon_centres, lat_centres) on the AgMERRA 0.25 deg grid."""
    ds = Dataset(nc_path)
    ha = np.asarray(ds.variables["harvarea"][:], dtype="float64")
    cg_lon = np.asarray(ds.variables["lon"][:], dtype="float64")
    cg_lat = np.asarray(ds.variables["lat"][:], dtype="float64")
    ds.close()

    nlat, nlon = ha.shape
    if nlat % CROPGRIDS_FACTOR or nlon % CROPGRIDS_FACTOR:
        raise SystemExit("CROPGRIDS grid is not an exact 5x multiple of AgMERRA")
    ha = np.where(ha < 0, 0.0, ha)  # Ocean (-1) -> 0
    blocks = ha.reshape(nlat // CROPGRIDS_FACTOR, CROPGRIDS_FACTOR,
                        nlon // CROPGRIDS_FACTOR, CROPGRIDS_FACTOR)
    agg = blocks.sum(axis=(1, 3))

    lon_c = cg_lon.reshape(-1, CROPGRIDS_FACTOR).mean(axis=1)
    lat_c = cg_lat.reshape(-1, CROPGRIDS_FACTOR).mean(axis=1)
    return agg, lon_c, lat_c


def load_country_index(countries_file: Path):
    try:
        from shapely.geometry import shape, Point
        from shapely.strtree import STRtree
    except ImportError as exc:  # pragma: no cover
        raise SystemExit(
            "Missing dependency 'shapely' for country assignment. Install with\n"
            "  pip install shapely"
        ) from exc

    feats = json.load(countries_file.open())["features"]
    geoms, isos = [], []
    for f in feats:
        p = f["properties"]
        iso = p.get("ADM0_A3") or p.get("ISO_A3") or p.get("SOV_A3")
        iso = ISO_REMAP.get(iso, iso)
        geoms.append(shape(f["geometry"]))
        isos.append(iso)
    tree = STRtree(geoms)
    return tree, geoms, isos, Point


def assign_country(lon, lat, tree, geoms, isos, Point):
    pt = Point(lon, lat)
    for idx in tree.query(pt):
        if geoms[idx].contains(pt):
            return isos[idx]
    idx = tree.nearest(pt)  # fall back to nearest polygon for coastal cells
    return isos[idx]


def lon_index(lon_e: float) -> int:
    """1-based AgMERRA longitude index (0..360 convention)."""
    return int(round((lon_e % 360.0 - 0.125) / AGMERRA_RES)) + 1


def lat_index(lat: float) -> int:
    """1-based AgMERRA latitude index counted from the north (89.875)."""
    return int(round((89.875 - lat) / AGMERRA_RES)) + 1


def load_agmerra_valid_mask(cache_dir: Path, year: int):
    """Return a (720, 1440) bool mask of AgMERRA cells with valid data in all
    six driver variables for ``year``, or ``None`` if the cache is unavailable.

    Cells lacking weather data (ocean) cannot be simulated, so the original mask
    is restricted to land cells where AgMERRA actually has values.
    """
    nc_vars = ("tmax", "tmin", "srad", "prate", "rhstmax", "wndspd")
    valid = None
    for var in nc_vars:
        path = cache_dir / f"AgMERRA_{year}_{var}.nc4"
        if not path.exists():
            return None
        ds = Dataset(path)
        arr = ds.variables[var][0, :, :]
        m = ~np.ma.getmaskarray(np.ma.asarray(arr))
        ds.close()
        valid = m if valid is None else (valid & m)
    return valid


def agmerra_cell_valid(valid_mask, lon_e: float, lat: float) -> bool:
    if valid_mask is None:
        return True
    j = int(round((lon_e % 360.0 - 0.125) / AGMERRA_RES))
    i = int(round((89.875 - lat) / AGMERRA_RES))
    if 0 <= i < valid_mask.shape[0] and 0 <= j < valid_mask.shape[1]:
        return bool(valid_mask[i, j])
    return False


def build_rows(nc_path: Path, countries_file: Path, bbox, valid_mask=None):
    agg, lon_c, lat_c = aggregate_harvarea(nc_path)
    tree, geoms, isos, Point = load_country_index(countries_file)
    lon_min, lon_max, lat_min, lat_max = bbox

    rows = []
    lat_idx = np.where((lat_c >= lat_min) & (lat_c <= lat_max))[0]
    lon_idx = np.where((lon_c >= lon_min) & (lon_c <= lon_max))[0]
    for i in lat_idx:
        lat = float(lat_c[i])
        for j in lon_idx:
            ha = float(agg[i, j])
            if ha <= 0:
                continue
            lon = float(lon_c[j])
            lon_e = lon % 360.0
            if not agmerra_cell_valid(valid_mask, lon_e, lat):
                continue  # no AgMERRA weather here -> cannot be simulated
            iso = assign_country(lon, lat, tree, geoms, isos, Point)
            sub = COUNTRY_SUBREGION.get(iso)
            if sub is None:
                continue  # not an African cassava country -> outside the mask
            name = f"agmerra_{lon_index(lon_e):04d}_{lat_index(lat):03d}_{iso}_{sub}.txt"
            rows.append((lon, lat, name, ha))
    rows.sort(key=lambda r: (r[2]))
    return rows


def write_csv(rows, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["lon", "lat", "wxfile", "harvarea_ha"])
        for lon, lat, name, ha in rows:
            w.writerow([f"{lon:.4f}", f"{lat:.4f}", name, f"{ha:.2f}"])


def validate(rows, reference: Path):
    ref = {}
    with reference.open(newline="") as f:
        for r in csv.DictReader(f):
            ref[(round(float(r["lon"]), 3), round(float(r["lat"]), 3))] = r
    gen = {(round(r[0], 3), round(r[1], 3)): r for r in rows}

    ref_keys, gen_keys = set(ref), set(gen)
    both = ref_keys & gen_keys
    only_ref = ref_keys - gen_keys
    only_gen = gen_keys - ref_keys

    name_match = ha_match = 0
    name_mismatch = []
    for k in both:
        rr = ref[k]
        gr = gen[k]
        if rr["wxfile"] == gr[2]:
            name_match += 1
        elif len(name_mismatch) < 10:
            name_mismatch.append((rr["wxfile"], gr[2]))
        if abs(float(rr["harvarea_ha"]) - gr[3]) < 0.01:
            ha_match += 1

    print(f"reference cells : {len(ref_keys)}")
    print(f"generated cells : {len(gen_keys)}")
    print(f"shared cells    : {len(both)}")
    print(f"only in ref     : {len(only_ref)}")
    print(f"only in gen     : {len(only_gen)}")
    if both:
        print(f"wxfile match    : {name_match}/{len(both)} = {name_match/len(both):.2%}")
        print(f"harvarea match  : {ha_match}/{len(both)} = {ha_match/len(both):.2%}")
    for a, b in name_mismatch:
        print(f"  name diff: ref={a} gen={b}")
    ok = not only_ref and not only_gen and name_match == len(both) == ha_match
    return 0 if ok else 1


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--cropgrids-nc", type=Path,
        default=Path("data/cropgrids/CROPGRIDSv1.08_cassava.nc"),
        help="CROPGRIDS cassava NetCDF (default: data/cropgrids/CROPGRIDSv1.08_cassava.nc)",
    )
    parser.add_argument(
        "--countries-file", type=Path,
        default=Path("data/cropgrids/ne_10m_admin_0_countries.geojson"),
        help="Natural Earth 10m admin-0 GeoJSON for country borders",
    )
    parser.add_argument(
        "--out", type=Path,
        default=Path("data/cropgrids/cassava_africa_mask_agmerra.csv"),
        help="Output mask CSV path",
    )
    parser.add_argument(
        "--bbox", nargs=4, type=float, metavar=("LONMIN", "LONMAX", "LATMIN", "LATMAX"),
        default=[-20.0, 52.0, -36.0, 38.0],
        help="Africa bounding box (lon/lon/lat/lat) to scan",
    )
    parser.add_argument(
        "--agmerra-cache", type=Path, default=Path("data/agmerra-cache"),
        help="AgMERRA NetCDF cache; restricts the mask to cells with valid "
             "weather data (default: data/agmerra-cache, skipped if absent)",
    )
    parser.add_argument(
        "--agmerra-year", type=int, default=1980,
        help="AgMERRA year used for the land/validity mask (default: 1980)",
    )
    parser.add_argument(
        "--validate", type=Path, nargs="?", const=True, default=None,
        help="Validate against an existing mask CSV (default: the --out path) "
             "instead of overwriting it",
    )
    args = parser.parse_args(argv)

    if not args.cropgrids_nc.exists():
        raise SystemExit(
            f"{args.cropgrids_nc} not found. Run tools/download_cropgrids.py first."
        )
    if not args.countries_file.exists():
        raise SystemExit(
            f"{args.countries_file} not found. Download Natural Earth 10m admin-0 with\n"
            "  python3 tools/download_cropgrids.py --natural-earth"
        )

    valid_mask = load_agmerra_valid_mask(args.agmerra_cache, args.agmerra_year)
    if valid_mask is None:
        print(
            f"Note: AgMERRA cache {args.agmerra_cache} not found; emitting all "
            "cassava cells without a weather-availability filter.",
            flush=True,
        )
    rows = build_rows(args.cropgrids_nc, args.countries_file, args.bbox, valid_mask)

    if args.validate is not None:
        reference = args.out if args.validate is True else args.validate
        print(f"Validating generated mask against {reference}")
        return validate(rows, reference)

    write_csv(rows, args.out)
    print(f"Wrote {args.out} ({len(rows)} cells)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
