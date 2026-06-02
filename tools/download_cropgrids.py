#!/usr/bin/env python3
"""Download the CROPGRIDS v1.08 cassava harvested-area grid.

CROPGRIDS (Tang et al. 2024, Scientific Data, CC BY 4.0) is published on Figshare:

    https://doi.org/10.6084/m9.figshare.22491997

The per-crop NetCDF maps are only distributed inside a single 806 MB archive
(``CROPGRIDSv1.08_NC_maps.zip``).  Downloading the whole archive just to obtain
the ~6.5 MB cassava grid is wasteful, so by default this tool performs a
*partial* extraction: it uses HTTP range requests to read only the ZIP central
directory and then only the bytes of the cassava member, and inflates them
locally.  Pass ``--full-zip`` to download and extract the entire archive instead
(useful if the server stops honouring range requests).

The single output file is written to ``data/cropgrids/CROPGRIDSv1.08_cassava.nc``
and is the input to ``tools/build_cassava_mask.py``.

Example:

    python3 tools/download_cropgrids.py
    python3 tools/download_cropgrids.py --out-dir data/cropgrids
"""

from __future__ import annotations

import argparse
import struct
import sys
import zipfile
import zlib
from pathlib import Path
from urllib.request import Request, urlopen

# Figshare "download" endpoint for CROPGRIDSv1.08_NC_maps.zip (article 22491997).
# Hitting this URL 302-redirects to a short-lived signed S3 URL; the redirect
# preserves the Range header, so each ranged request gets a fresh signed URL.
ZIP_URL = "https://ndownloader.figshare.com/files/44950942"
MEMBER_NAME = "CROPGRIDSv1.08_NC_maps/CROPGRIDSv1.08_cassava.nc"
OUTPUT_NAME = "CROPGRIDSv1.08_cassava.nc"

# Natural Earth 10m admin-0 country borders, used by tools/build_cassava_mask.py
# to label each cassava cell with its ISO3 country / UN sub-region.
NE_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/"
    "geojson/ne_10m_admin_0_countries.geojson"
)
NE_OUTPUT_NAME = "ne_10m_admin_0_countries.geojson"

EOCD_SIG = b"PK\x05\x06"
CDIR_SIG = b"PK\x01\x02"
LFH_SIG = b"PK\x03\x04"


def _ranged_read(url: str, start: int, end: int, retries: int = 3) -> tuple[bytes, int]:
    """Return ``url`` bytes ``[start, end]`` (inclusive) and the total size."""
    last_exc: Exception | None = None
    for attempt in range(1, retries + 1):
        try:
            req = Request(url, headers={"Range": f"bytes={start}-{end}"})
            with urlopen(req) as resp:
                if resp.status not in (200, 206):
                    raise OSError(f"unexpected HTTP status {resp.status}")
                total = int(resp.headers["Content-Range"].split("/")[1])
                return resp.read(), total
        except Exception as exc:  # pragma: no cover - network dependent
            last_exc = exc
            if attempt == retries:
                raise
            print(f"  range request failed: {exc}; retrying...", flush=True)
    raise last_exc  # pragma: no cover - unreachable


def _find_member(url: str) -> tuple[int, int, int, int]:
    """Locate the cassava member via the ZIP central directory.

    Returns ``(local_header_offset, compress_method, compressed_size,
    uncompressed_size)``.
    """
    # A tiny probe yields the archive's total size from the Content-Range header.
    _probe, total = _ranged_read(url, 0, 1)
    # Read the tail of the archive to find the End Of Central Directory record.
    tail, total = _ranged_read(url, max(0, total - 66000), total - 1)
    idx = tail.rfind(EOCD_SIG)
    if idx < 0:
        raise SystemExit("Could not find ZIP end-of-central-directory record")
    (_sig, _disk, _cdisk, _nthis, _ntot, cd_size, cd_off, _clen) = struct.unpack(
        "<IHHHHIIH", tail[idx : idx + 22]
    )
    cdir, _ = _ranged_read(url, cd_off, cd_off + cd_size - 1)
    pos = 0
    while pos + 46 <= len(cdir) and cdir[pos : pos + 4] == CDIR_SIG:
        fields = struct.unpack("<IHHHHHHIIIHHHHHII", cdir[pos : pos + 46])
        method = fields[4]
        comp_size = fields[8]
        uncomp_size = fields[9]
        nlen, elen, clen = fields[10], fields[11], fields[12]
        lho = fields[16]
        name = cdir[pos + 46 : pos + 46 + nlen].decode("utf-8", "replace")
        if name == MEMBER_NAME or name.endswith("/" + OUTPUT_NAME) or name == OUTPUT_NAME:
            return lho, method, comp_size, uncomp_size
        pos += 46 + nlen + elen + clen
    raise SystemExit(f"Member {MEMBER_NAME!r} not found in archive central directory")


def _extract_member(url: str, dest: Path) -> None:
    lho, method, comp_size, uncomp_size = _find_member(url)
    # The local file header repeats the name/extra fields (lengths can differ
    # from the central directory), so read it to compute the real data offset.
    header, _ = _ranged_read(url, lho, lho + 30 - 1)
    if header[:4] != LFH_SIG:
        raise SystemExit("Local file header signature mismatch")
    nlen, elen = struct.unpack("<HH", header[26:30])
    data_start = lho + 30 + nlen + elen
    print(
        f"Extracting {OUTPUT_NAME} ({comp_size/1e6:.1f} MB compressed,"
        f" {uncomp_size/1e6:.1f} MB) via range requests",
        flush=True,
    )
    raw, _ = _ranged_read(url, data_start, data_start + comp_size - 1)
    if method == zipfile.ZIP_STORED:
        data = raw
    elif method == zipfile.ZIP_DEFLATED:
        data = zlib.decompress(raw, -zlib.MAX_WBITS)
    else:
        raise SystemExit(f"Unsupported ZIP compression method {method}")
    if len(data) != uncomp_size:
        raise SystemExit(
            f"Inflated size {len(data)} != expected {uncomp_size}; download corrupt"
        )
    dest.write_bytes(data)


def _extract_full_zip(url: str, dest: Path) -> None:
    zip_path = dest.parent / "CROPGRIDSv1.08_NC_maps.zip"
    print(f"Downloading full archive to {zip_path} (~806 MB)...", flush=True)
    from urllib.request import urlretrieve

    urlretrieve(url, zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        member = next(
            (n for n in zf.namelist() if n.endswith(OUTPUT_NAME)), None
        )
        if member is None:
            raise SystemExit(f"{OUTPUT_NAME} not found in {zip_path}")
        with zf.open(member) as src:
            dest.write_bytes(src.read())
    print(f"Extracted {member} -> {dest}", flush=True)


def _validate_netcdf(path: Path) -> None:
    try:
        from netCDF4 import Dataset
    except ImportError:
        # netCDF4 is optional for downloading; just check the magic bytes.
        magic = path.read_bytes()[:4]
        if magic[:3] not in (b"CDF", b"\x89HD"):
            raise SystemExit(f"{path} does not look like a NetCDF/HDF5 file")
        return
    ds = Dataset(path)
    has = "harvarea" in ds.variables
    ds.close()
    if not has:
        raise SystemExit(f"{path} is missing the expected 'harvarea' variable")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("data/cropgrids"),
        help="Directory for the cassava NetCDF file (default: data/cropgrids)",
    )
    parser.add_argument(
        "--full-zip",
        action="store_true",
        help="Download the entire 806 MB archive instead of range-extracting",
    )
    parser.add_argument(
        "--natural-earth",
        action="store_true",
        help="Also download the Natural Earth 10m admin-0 country borders "
             "(needed by tools/build_cassava_mask.py)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Re-download even if the output file already exists",
    )
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    if args.natural_earth:
        from urllib.request import urlretrieve

        ne_dest = args.out_dir / NE_OUTPUT_NAME
        if ne_dest.exists() and not args.overwrite:
            print(f"{ne_dest} already present; use --overwrite to replace.")
        else:
            print(f"Downloading Natural Earth borders -> {ne_dest}", flush=True)
            urlretrieve(NE_URL, ne_dest)
            print(f"Wrote {ne_dest} ({ne_dest.stat().st_size/1e6:.1f} MB)")

    dest = args.out_dir / OUTPUT_NAME
    if dest.exists() and not args.overwrite:
        try:
            _validate_netcdf(dest)
            print(f"{dest} already present and valid; use --overwrite to replace.")
            return 0
        except SystemExit:
            print(f"{dest} present but invalid; re-downloading.", flush=True)

    if args.full_zip:
        _extract_full_zip(ZIP_URL, dest)
    else:
        _extract_member(ZIP_URL, dest)
    _validate_netcdf(dest)
    print(f"Wrote {dest} ({dest.stat().st_size/1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
