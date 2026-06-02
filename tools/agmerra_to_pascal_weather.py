#!/usr/bin/env python3
"""Create CASAS Pascal weather text files from NASA GISS AgMERRA NetCDF4 data.

The Pascal model expects one text file per lattice cell:

    <station id>\t<description>
    <longitude> <latitude>
    month day year tmax tmin solar rain rh wind
    ...

AgMERRA source files are yearly, one variable per file:
https://data.giss.nasa.gov/impacts/agmipcf/agmerra/AgMERRA_<year>_<var>.nc4

This script intentionally downloads only the variables/years requested by a run.
Install dependency in a virtual environment:

    python3 -m venv /tmp/pbdm-netcdf-venv
    /tmp/pbdm-netcdf-venv/bin/pip install netCDF4
    /tmp/pbdm-netcdf-venv/bin/python tools/agmerra_to_pascal_weather.py ...
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from datetime import date, timedelta
from io import StringIO
from pathlib import Path
from urllib.request import urlretrieve

try:
    from netCDF4 import Dataset
    import numpy as np
except ImportError as exc:  # pragma: no cover - environment guidance
    raise SystemExit(
        "Missing Python dependency 'netCDF4'. Create a venv and install it, e.g.\n"
        "  python3 -m venv /tmp/pbdm-netcdf-venv\n"
        "  /tmp/pbdm-netcdf-venv/bin/pip install netCDF4\n"
        "  /tmp/pbdm-netcdf-venv/bin/python tools/agmerra_to_pascal_weather.py ..."
    ) from exc


BASE_URL = "https://data.giss.nasa.gov/impacts/agmipcf/agmerra"
VARS = ("tmax", "tmin", "srad", "prate", "rhstmax", "wndspd")
MJ_M2_DAY_TO_W_M2 = 1_000_000.0 / 86_400.0


@dataclass(frozen=True)
class WeatherPoint:
    output_name: str
    lon: float
    lat: float


def parse_points_file(path: Path) -> list[WeatherPoint]:
    """Read points from a legacy GIS output file or a simple TSV/CSV.

    If the file has a WxFile column, output names are taken from that basename.
    Otherwise expected columns are output_name, lon, lat.
    """
    with path.open(newline="", errors="replace") as f:
        sample = f.read(4096)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters="\t,")
        except csv.Error:
            dialect = csv.excel_tab if "\t" in sample.splitlines()[0] else csv.excel
        reader = csv.DictReader(f, dialect=dialect)
        points: list[WeatherPoint] = []
        for row in reader:
            if "WxFile" in row:
                output_name = Path(row["WxFile"].replace("\\", "/")).name
                lon = float(row["Long"])
                lat = float(row["Lat"])
            else:
                output_name = row["output_name"]
                lon = float(row["lon"])
                lat = float(row["lat"])
            points.append(WeatherPoint(output_name, lon, lat))
    return points


def agmerra_path(cache_dir: Path, year: int, var: str) -> Path:
    return cache_dir / f"AgMERRA_{year}_{var}.nc4"


def ensure_agmerra_file(cache_dir: Path, year: int, var: str, retries: int = 3) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = agmerra_path(cache_dir, year, var)
    if path.exists():
        # Verify the file is a valid NetCDF4 (not a truncated download)
        try:
            ds = Dataset(path)
            ds.close()
            return path
        except Exception:
            print(f"Removing corrupt/incomplete {path.name}", flush=True)
            path.unlink()
    url = f"{BASE_URL}/AgMERRA_{year}_{var}.nc4"
    for attempt in range(1, retries + 1):
        try:
            print(f"Downloading {url}" + (f" (attempt {attempt})" if attempt > 1 else ""), flush=True)
            urlretrieve(url, path)
            return path
        except Exception as exc:
            if path.exists():
                path.unlink()
            if attempt == retries:
                raise
            print(f"  Download failed: {exc}; retrying...", flush=True)
    return path  # unreachable


def nearest_index(values, target: float) -> int:
    # AgMERRA longitudes are 0.125..359.875 degrees_east.
    best_i = 0
    best_delta = float("inf")
    for i, value in enumerate(values):
        delta = abs(float(value) - target)
        if delta < best_delta:
            best_i = i
            best_delta = delta
    return best_i


def open_year(cache_dir: Path, year: int):
    return {var: Dataset(ensure_agmerra_file(cache_dir, year, var)) for var in VARS}


def close_year(datasets) -> None:
    for ds in datasets.values():
        ds.close()


def iter_dates(start_year: int, end_year: int):
    d = date(start_year, 1, 1)
    end = date(end_year, 12, 31)
    while d <= end:
        yield d
        d += timedelta(days=1)


def write_point_weather(point: WeatherPoint, start_year: int, end_year: int, cache_dir: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / point.output_name
    lon_target = point.lon % 360.0

    with out_path.open("w") as out:
        out.write(f"{out_path.stem}\tgenerated from NASA GISS AgMERRA NetCDF4\n")
        out.write(f"{point.lon:.4f} {point.lat:.4f}\n")
        out.write("month day year tmax tmin solar rain rh wind\n")

        for year in range(start_year, end_year + 1):
            datasets = open_year(cache_dir, year)
            try:
                sample_ds = next(iter(datasets.values()))
                lat_i = nearest_index(sample_ds.variables["latitude"][:], point.lat)
                lon_i = nearest_index(sample_ds.variables["longitude"][:], lon_target)

                for d in (day for day in iter_dates(year, year)):
                    ti = d.timetuple().tm_yday - 1
                    values = {var: float(datasets[var].variables[var][ti, lat_i, lon_i]) for var in VARS}
                    # AgMERRA srad is daily total MJ/m2/day. The Pascal reader
                    # expects W/m2 and then converts W/m2 to Langleys internally.
                    values["srad"] *= MJ_M2_DAY_TO_W_M2
                    out.write(
                        f"{d.month} {d.day} {d.year} "
                        f"{values['tmax']:.3f} {values['tmin']:.3f} "
                        f"{values['srad']:.3f} {values['prate']:.3f} "
                        f"{values['rhstmax']:.3f} {values['wndspd']:.3f}\n"
                    )
            finally:
                close_year(datasets)

def dates_for_year(year: int) -> list[date]:
    return list(iter_dates(year, year))


def prepare_output_files(points: list[WeatherPoint], out_dir: Path, overwrite: bool) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    existing = list(out_dir.glob("*.txt"))
    if existing and not overwrite:
        raise SystemExit(f"{out_dir} already contains {len(existing)} .txt files; pass --overwrite to replace them")
    if overwrite:
        for path in existing:
            path.unlink()
    for point in points:
        out_path = out_dir / point.output_name
        with out_path.open("w") as out:
            out.write(f"{out_path.stem}\tgenerated from NASA GISS AgMERRA NetCDF4\n")
            out.write(f"{point.lon:.4f} {point.lat:.4f}\n")
            out.write("month day year tmax tmin solar rain rh wind\n")


def point_indices(points: list[WeatherPoint], sample_ds) -> list[tuple[WeatherPoint, int, int]]:
    lat_values = sample_ds.variables["latitude"][:]
    lon_values = sample_ds.variables["longitude"][:]
    indexed = []
    for point in points:
        indexed.append((
            point,
            nearest_index(lat_values, point.lat),
            nearest_index(lon_values, point.lon % 360.0),
        ))
    return indexed


def write_year_for_points(year: int, indexed_points: list[tuple[WeatherPoint, int, int]], cache_dir: Path, out_dir: Path) -> None:
    datasets = open_year(cache_dir, year)
    try:
        days = dates_for_year(year)
        date_prefixes = [f"{d.month} {d.day} {d.year}" for d in days]
        lat_indices = np.array([lat_i for _point, lat_i, _lon_i in indexed_points], dtype=np.intp)
        lon_indices = np.array([lon_i for _point, _lat_i, lon_i in indexed_points], dtype=np.intp)
        buffers = [StringIO() for _ in indexed_points]

        for ti, prefix in enumerate(date_prefixes):
            day_values = {}
            for var in VARS:
                grid = datasets[var].variables[var][ti, :, :]
                values = grid[lat_indices, lon_indices]
                if var == "srad":
                    values = values * MJ_M2_DAY_TO_W_M2
                day_values[var] = values

            for i, buffer in enumerate(buffers):
                buffer.write(
                    f"{prefix} "
                    f"{float(day_values['tmax'][i]):.3f} "
                    f"{float(day_values['tmin'][i]):.3f} "
                    f"{float(day_values['srad'][i]):.3f} "
                    f"{float(day_values['prate'][i]):.3f} "
                    f"{float(day_values['rhstmax'][i]):.3f} "
                    f"{float(day_values['wndspd'][i]):.3f}\n"
                )

        for (point, _lat_i, _lon_i), buffer in zip(indexed_points, buffers):
            with (out_dir / point.output_name).open("a") as out:
                out.write(buffer.getvalue())
    finally:
        close_year(datasets)


def detect_completed_years(out_dir: Path, points: list[WeatherPoint], start_year: int) -> int:
    """Check multiple sample output files to find how many years are already written.

    Samples up to 10 files spread across the point list and returns the
    minimum last-year-seen + 1, so a partially-written year is detected.
    """
    import random as _rng
    n = min(10, len(points))
    indices = sorted(_rng.sample(range(len(points)), n))
    min_last_year = None
    for idx in indices:
        sample_path = out_dir / points[idx].output_name
        if not sample_path.exists():
            return start_year
        last_year_seen = None
        with sample_path.open() as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        y = int(parts[2])
                        if 1900 < y < 2100:
                            last_year_seen = y
                    except ValueError:
                        pass
        if last_year_seen is None:
            return start_year
        if min_last_year is None or last_year_seen < min_last_year:
            min_last_year = last_year_seen
    if min_last_year is None:
        return start_year
    return min_last_year + 1


def write_all_weather(points: list[WeatherPoint], start_year: int, end_year: int, cache_dir: Path, out_dir: Path, overwrite: bool, resume: bool = False) -> None:
    actual_start = start_year
    if resume and not overwrite:
        actual_start = detect_completed_years(out_dir, points, start_year)
        if actual_start > end_year:
            print(f"All years {start_year}-{end_year} already present, nothing to do.", flush=True)
            return
        if actual_start > start_year:
            print(f"Resuming from {actual_start} (years {start_year}-{actual_start - 1} already written)", flush=True)

    if not resume or actual_start == start_year:
        prepare_output_files(points, out_dir, overwrite=overwrite)

    first_ds_year = actual_start
    first_year = open_year(cache_dir, first_ds_year)
    try:
        indexed = point_indices(points, next(iter(first_year.values())))
    finally:
        close_year(first_year)

    manifest = out_dir / "_manifest.tsv"
    with manifest.open("w") as f:
        f.write("output_name\tlon\tlat\tlat_index_0\tlon_index_0\n")
        for point, lat_i, lon_i in indexed:
            f.write(f"{point.output_name}\t{point.lon:.4f}\t{point.lat:.4f}\t{lat_i}\t{lon_i}\n")

    for year in range(actual_start, end_year + 1):
        print(f"Writing year {year} for {len(points)} points", flush=True)
        write_year_for_points(year, indexed, cache_dir, out_dir)


def download_years(start_year: int, end_year: int, cache_dir: Path) -> None:
    for year in range(start_year, end_year + 1):
        for var in VARS:
            ensure_agmerra_file(cache_dir, year, var)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--points-file", type=Path, required=True, help="Legacy GIS output with WxFile/Long/Lat or TSV with output_name/lon/lat")
    parser.add_argument("--start-year", type=int, required=True)
    parser.add_argument("--end-year", type=int, required=True)
    parser.add_argument("--cache-dir", type=Path, default=Path.home() / ".cache" / "pbdm-agmerra")
    parser.add_argument("--out-dir", type=Path, default=Path("data/agmerra-pascal-weather"))
    parser.add_argument("--limit", type=int, default=0, help="Limit number of points for testing")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing .txt files in --out-dir")
    parser.add_argument("--resume", action="store_true", help="Resume from last completed year in existing output")
    parser.add_argument("--download-only", action="store_true", help="Only download AgMERRA NetCDF4 source files")
    parser.add_argument("--point-at-a-time", action="store_true", help="Use slower point-at-a-time conversion for debugging")
    args = parser.parse_args()

    points = parse_points_file(args.points_file)
    if args.limit:
        points = points[: args.limit]

    if args.download_only:
        download_years(args.start_year, args.end_year, args.cache_dir)
        return 0

    if args.point_at_a_time:
        for point in points:
            print(f"Writing {point.output_name} ({point.lon}, {point.lat})")
            write_point_weather(point, args.start_year, args.end_year, args.cache_dir, args.out_dir)
    else:
        write_all_weather(points, args.start_year, args.end_year, args.cache_dir, args.out_dir, overwrite=args.overwrite, resume=args.resume)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
