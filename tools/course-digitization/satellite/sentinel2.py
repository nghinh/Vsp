#!/usr/bin/env python3
"""Shared Sentinel-2 plumbing for the course-digitisation detectors.

Factored out of detect_water_ndwi.py, which had all of this inlined. Nothing
here is new; what is new is that a second detector can use it without copying
it, and that the awkward details below are written down once instead of being
rediscovered.

The awkward details, since they are the whole value of this file:

  BOA offset      Processing baseline 04.00+ stores reflectance shifted by
                  -1000 DN. A band *ratio* does not cancel that out — it biases
                  the index across the whole scene. The STAC item says whether
                  the mirror already undid it; read it, do not assume.

  cloud per AOI   A scene that is 8% cloudy nationally can be solid cloud over
                  the one course that matters. Scene-level `eo:cloud_cover` is
                  a search filter, not an answer; the SCL band over the AOI is
                  the answer.

  one MGRS tile   Pixel grids only line up between scenes of the same tile.
                  Any multi-date vote has to be within a tile or it is voting
                  on approximately-the-same-place.

  windowed reads  These are COGs on S3. Reading a 2 km window costs a few
                  hundred KB; reading the scene costs 600 MB. Always window.

Licensing: Copernicus Sentinel data, free to use and adapt. Derived products
must carry "Contains modified Copernicus Sentinel data <year>" — PUBLISHER and
LICENSE below are what the database columns get.
"""

from __future__ import annotations

import json
import math
import os
import shlex
import subprocess
import sys
import urllib.request

os.environ.setdefault("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
os.environ.setdefault("AWS_NO_SIGN_REQUEST", "YES")
os.environ.setdefault("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif")
os.environ.setdefault("GDAL_HTTP_MAX_RETRY", "3")
os.environ.setdefault("GDAL_HTTP_RETRY_DELAY", "2")

try:
    import numpy as np
    import rasterio
    from rasterio.features import shapes
    from rasterio.warp import transform_bounds, transform_geom
    from rasterio.windows import from_bounds
except ImportError:  # pragma: no cover - the message is the point
    sys.exit("Needs numpy + rasterio:\n"
             "  python3 -m venv venv && ./venv/bin/pip install -r requirements.txt\n"
             "then run scripts with ./venv/bin/python")

DEFAULT_PSQL = "docker exec -i vsp_postgres psql -U vsp -d vsp"
STAC_URL = "https://earth-search.aws.element84.com/v1/search"

# SCL classes that make a pixel unusable: cloud shadow, cloud medium/high,
# thin cirrus. (SCL 6 is "water" — a hint, but too coarse at 20 m to rely on.)
SCL_BAD = (3, 8, 9, 10)

PUBLISHER = "Contains modified Copernicus Sentinel data"
LICENSE = "Copernicus Sentinel Data Legal Notice"


# ── database plumbing ────────────────────────────────────────────────────────

def psql_argv(spec: str | None) -> list[str]:
    return shlex.split(spec or DEFAULT_PSQL)


def run_psql(psql_cmd: list[str], sql: str, extra: list[str] | None = None) -> str:
    proc = subprocess.run(
        psql_cmd + ["-v", "ON_ERROR_STOP=1"] + (extra or []) + ["-f", "-"],
        input=sql, text=True, capture_output=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.exit(f"psql failed:\n{proc.stderr.strip()}")
    return proc.stdout


def query(psql_cmd: list[str], sql: str) -> list[list[str]]:
    out = run_psql(psql_cmd, sql, extra=["-t", "-A", "-F", "\t"])
    return [line.split("\t") for line in out.splitlines() if line.strip()]


def q(text) -> str:
    """SQL literal. NULL for None; everything else quoted and escaped."""
    return "NULL" if text is None else "'" + str(text).replace("'", "''") + "'"


# ── geometry helpers ─────────────────────────────────────────────────────────

def bbox_around(lat: float, lon: float, radius_m: float) -> tuple[float, float, float, float]:
    """A square degree box of the given radius. Good enough for a STAC search
    and for a COG window; nobody measures anything with it."""
    dlat = radius_m / 110_540.0
    dlon = radius_m / (111_320.0 * max(math.cos(math.radians(lat)), 1e-6))
    return (lon - dlon, lat - dlat, lon + dlon, lat + dlat)


# ── imagery ──────────────────────────────────────────────────────────────────

def stac_search(bbox, start: str, end: str, max_cloud: float, limit: int = 200) -> list[dict]:
    """Sentinel-2 L2A items over the bbox, cheapest cloud first.

    `eo:cloud_cover` here is the *scene* figure and is only a filter — see
    aoi_cloud_fraction for the number that decides anything.
    """
    body = {
        "collections": ["sentinel-2-l2a"],
        "bbox": list(bbox),
        "datetime": f"{start}T00:00:00Z/{end}T00:00:00Z",
        "query": {"eo:cloud_cover": {"lt": max_cloud}},
        "limit": limit,
    }
    req = urllib.request.Request(STAC_URL, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        items = json.load(resp)["features"]
    return sorted(items, key=lambda f: f["properties"]["eo:cloud_cover"])


def tile_of(item: dict) -> str:
    """MGRS tile id. Scenes only share a pixel grid within one tile."""
    return item["id"].split("_")[1]


def read_window(href: str, bbox, out_shape=None):
    """Read just the AOI out of a COG. Returns (array, transform, crs)."""
    with rasterio.open(href) as ds:
        proj = transform_bounds("EPSG:4326", ds.crs, *bbox)
        win = from_bounds(*proj, ds.transform)
        kw = {"window": win, "out_dtype": "float32"}
        if out_shape:
            kw["out_shape"] = out_shape
        return ds.read(1, **kw), ds.window_transform(win), ds.crs


def boa_offset(item: dict) -> float:
    """-1000 DN, unless the mirror already applied it. See the module header."""
    return 0.0 if item["properties"].get("earthsearch:boa_offset_applied") else -1000.0


def reflectance(item: dict, asset: str, bbox, out_shape=None):
    """One band as surface reflectance in 0..1, offset corrected."""
    raw, tr, crs = read_window(item["assets"][asset]["href"], bbox, out_shape=out_shape)
    return (raw + boa_offset(item)) / 10_000.0, tr, crs


def usable_mask(item: dict, bbox, out_shape) -> tuple[np.ndarray, float]:
    """(pixels worth trusting, cloud fraction over the AOI)."""
    scl, _, _ = read_window(item["assets"]["scl"]["href"], bbox, out_shape=out_shape)
    bad = np.isin(scl.astype("int16"), SCL_BAD)
    return ~bad, float(bad.mean())


def ratio(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """(a-b)/(a+b), guarded. NDVI, NDWI, MNDWI are all this."""
    return (a - b) / np.maximum(a + b, 1e-6)


# ── raster to vector ─────────────────────────────────────────────────────────

def fill_holes(mask: np.ndarray) -> np.ndarray:
    """Flood the background in from the border; whatever it cannot reach is an
    interior hole."""
    h, w = mask.shape
    outside = np.zeros_like(mask, dtype=bool)
    stack = [(r, c) for r in range(h) for c in (0, w - 1) if not mask[r, c]]
    stack += [(r, c) for c in range(w) for r in (0, h - 1) if not mask[r, c]]
    for r, c in stack:
        outside[r, c] = True
    while stack:
        r, c = stack.pop()
        for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if 0 <= nr < h and 0 <= nc < w and not mask[nr, nc] and not outside[nr, nc]:
                outside[nr, nc] = True
                stack.append((nr, nc))
    return mask | ~outside


def binary_close(mask: np.ndarray, iterations: int = 1) -> np.ndarray:
    """Dilate then erode, 4-connected. Bridges the cart paths and bunkers that
    cut a course's turf into pieces, without pulling in the next field."""
    def shift_or(m):
        out = m.copy()
        out[1:, :] |= m[:-1, :]
        out[:-1, :] |= m[1:, :]
        out[:, 1:] |= m[:, :-1]
        out[:, :-1] |= m[:, 1:]
        return out

    def shift_and(m):
        out = m.copy()
        out[1:, :] &= m[:-1, :]
        out[:-1, :] &= m[1:, :]
        out[:, 1:] &= m[:, :-1]
        out[:, :-1] &= m[:, 1:]
        return out

    for _ in range(iterations):
        mask = shift_or(mask)
    for _ in range(iterations):
        mask = shift_and(mask)
    return mask


def connected_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """4-connected labelling. Iterative, because a golf course is bigger than
    Python's recursion limit."""
    labels = np.zeros(mask.shape, dtype="int32")
    current = 0
    h, w = mask.shape
    for r0 in range(h):
        for c0 in range(w):
            if not mask[r0, c0] or labels[r0, c0]:
                continue
            current += 1
            stack = [(r0, c0)]
            labels[r0, c0] = current
            while stack:
                r, c = stack.pop()
                for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                    if 0 <= nr < h and 0 <= nc < w and mask[nr, nc] and not labels[nr, nc]:
                        labels[nr, nc] = current
                        stack.append((nr, nc))
    return labels, current


def ring_area_m2(ring) -> float:
    """Shoelace, in whatever units the ring is in. Callers pass projected
    metres — UTM — so this is real area."""
    return abs(sum(ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1]
                   for i in range(len(ring) - 1))) / 2.0


def polygonise(mask: np.ndarray, tr, crs, min_area_m2: float, max_area_m2: float,
               fill: bool = True) -> list[dict]:
    """Mask to WGS84 polygon WKT, filtered by area in projected metres."""
    if fill:
        mask = fill_holes(mask)
    out = []
    for geom, value in shapes(mask.astype("uint8"), mask=mask, transform=tr):
        if value != 1:
            continue
        area = ring_area_m2(geom["coordinates"][0])
        if not (min_area_m2 <= area <= max_area_m2):
            continue
        wgs = transform_geom(crs, "EPSG:4326", geom, precision=7)
        coords = wgs["coordinates"][0]
        wkt = "POLYGON((" + ", ".join(f"{x:.7f} {y:.7f}" for x, y in coords) + "))"
        out.append({"wkt": wkt, "area_m2": area})
    return out
