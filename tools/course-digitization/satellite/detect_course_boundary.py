#!/usr/bin/env python3
"""Find each course's turf extent from a year of free Sentinel-2 imagery.

Phase 1 of docs/course-geometry-autogen-architecture.md.

  MEASURED RESULT: this does not work well enough to use, and the numbers are
  below. It is kept because it is the evidence for that conclusion, because the
  plumbing is sound and reusable the day better imagery arrives, and because
  two of the things it rules out would otherwise be tried again.

THE IDEA
  A golf course is 100 hectares — ten thousand pixels at 10 m — so while
  nothing *inside* it is resolvable (10 m delineates 0% of the 1,127 greens,
  bunkers and tee boxes already traced by hand in this database), the outline
  ought to be easy.

  On one date it is not: a course is "a big patch of healthy vegetation" and so
  is every rice paddy around it. The proposed discriminator was time. Rice is a
  crop cycle — flooded, green, harvested, bare, two or three times a year —
  while mown irrigated turf sits at high NDVI every week. So: not how green a
  pixel is, but how unchangingly green.

WHAT THE MEASUREMENT SAYS
  Scored against the OSM outlines of three deliberately different courses, at
  the loosest threshold that keeps any recall at all:

      Long Thành (Đồng Nai, southern, rubber country)   recall 0.56  precision 0.36
      Sea Links  (Mũi Né, coastal links on dunes)       recall 0.73  precision 0.25
      Sky Lake   (Chương Mỹ, Hà Nội, northern)          recall 0.09  precision 0.13

  There is no threshold that works nationally. Tightening for precision
  collapses recall to zero on Sky Lake; loosening for recall flags 1,000 ha
  around a 160 ha course. The gate for this phase was IoU >= 0.90; the best
  achievable is around 0.25.

  Two reasons, both real and neither fixable by tuning:

    rubber      Southern plantations are stably green year-round and merge with
                the course into one blob. Đồng Nai is rubber country.
    winter      Northern turf goes dormant. Sky Lake is neither reliably green
                nor reliably stable, so the premise fails outright — the
                discriminator assumes a climate that half the country does not
                have.

WHAT WAS RULED OUT ALONG THE WAY
  3x3 spatial texture of NDVI, proposed to separate mown turf from tree canopy,
  separates nothing at this resolution: inside the Long Thành boundary the
  median is 0.054, outside it is 0.052. Measured before it was adopted, which
  is why it is not in the code.

TWO BUGS WORTH REMEMBERING
  Both produced plausible output while being wrong, which is the dangerous kind.

    tile choice   Picking the MGRS tile with the most scenes is not the same as
                  picking one that covers the course. Long Thành sits on the
                  edge of the busiest tile, and rasterio clipped the read window
                  to 730 m instead of 4 km without raising anything. See
                  covers().
    dry season    The twelve clearest scenes of a Vietnamese year all land
                  between April and June. "Stable across dates" measured inside
                  one growing season is not a discriminator at all — rice is
                  perfectly stable there too. See spread_over_months().

WHAT TO DO INSTEAD
  Buy resolution. At 1.5 m — SPOT-6/7 from the national archive — greens are
  directly delineable at 96%, which makes the boundary a by-product rather than
  a problem. This script's scene handling, masking and vectorising all carry
  over; only the thresholds change.

OUTPUT
  A staging table only. Nothing here reaches golf_facilities, courses or any
  geometry table — and on these numbers nothing should.

USAGE
  ./venv/bin/python detect_course_boundary.py --validate      # score vs OSM, write nothing
  ./venv/bin/python detect_course_boundary.py --course 8      # one course, by facility id
  ./venv/bin/python detect_course_boundary.py --apply         # write the staging table

LICENSING
  Copernicus Sentinel data. Derived products carry "Contains modified
  Copernicus Sentinel data <year>".
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import json
import math
import pathlib
import sys

import numpy as np

import sentinel2 as s2

# ── the thresholds, and where they come from ─────────────────────────────────
# Chosen from what the indices mean, not fitted to the validation set. NDVI
# 0.35 is the usual floor for "closed vegetation canopy"; the stability bound
# is set so a rice pixel, which swings from bare soil (~0.15) to full canopy
# (~0.8) within one season, cannot pass it.
NDVI_FLOOR = 0.35
NDVI_STD_CEILING = 0.12
MIN_CLEAR_DATES = 4          # fewer than this and the stability figure is noise
SEARCH_RADIUS_M = 2000       # a big course is ~1.5 km across
MAX_AOI_CLOUD = 0.30         # per scene, over the AOI only
SCENE_CANDIDATES = 120       # STAC hits to consider; a year is ~73 revisits per tile
SCENES_USED = 12             # clear dates to actually download, one per month
MIN_COURSE_HA = 20
MAX_COURSE_HA = 500
CLOSE_ITERATIONS = 2         # bridges cart paths and bunker clusters

SNAPSHOT = pathlib.Path(__file__).resolve().parents[1] / "osm" / "data"


# ── OSM boundaries, for validation only ──────────────────────────────────────

def osm_boundaries() -> list[dict]:
    """Course outlines OSM has drawn, from the newest committed snapshot.

    Validation ground truth, and never an input to detection — the point of
    this script is the courses OSM has not mapped.
    """
    snaps = sorted(SNAPSHOT.glob("osm-vietnam-golf-*.json.gz"))
    if not snaps:
        return []
    facilities = json.load(gzip.open(snaps[-1], "rt"))["facilities"]
    out = []
    for element in facilities:
        ring = element.get("geometry")
        if not ring:
            for member in element.get("members", []):
                if member.get("role") == "outer" and member.get("geometry"):
                    ring = member["geometry"]
                    break
        if not ring or len(ring) < 4:
            continue
        centre = element.get("center")
        if not centre:
            continue
        out.append({
            "ref": f"{element['type']}/{element['id']}",
            "lat": centre["lat"],
            "lon": centre["lon"],
            "wkt": "POLYGON((" + ", ".join(f"{p['lon']:.7f} {p['lat']:.7f}" for p in ring)
                   + (f", {ring[0]['lon']:.7f} {ring[0]['lat']:.7f}"
                      if (ring[0]["lon"], ring[0]["lat"]) != (ring[-1]["lon"], ring[-1]["lat"])
                      else "") + "))",
        })
    return out


# ── detection ────────────────────────────────────────────────────────────────

def covers(item: dict, bbox) -> bool:
    """Whether the scene's footprint contains the whole AOI.

    A partly-covering scene still reads without error — rasterio just clips the
    window at the dataset edge and hands back a smaller array. Silently.
    """
    west, south, east, north = bbox
    ib = item.get("bbox")
    if not ib or len(ib) < 4:
        return False
    return ib[0] <= west and ib[1] <= south and ib[2] >= east and ib[3] >= north


def spread_over_months(items: list[dict]) -> list[dict]:
    """Candidates ordered so the year is sampled before any month is sampled twice.

    Two things have to be true at once. The year must be covered — the clearest
    scenes of a Vietnamese year all land in the dry season, and "stable across
    dates" means nothing inside one growing season, because a rice paddy is
    perfectly stable there too. And the wet-season months are genuinely cloudy,
    so a month's best scene often fails the AOI cloud check and taking only one
    per month throws the month away with it.

    So: round-robin. Every month's best scene first, then every month's second
    best, and so on. The caller stops when it has enough clear dates, which
    gives it the widest spread available before it starts doubling up.
    """
    by_month: dict[str, list[dict]] = {}
    for item in items:
        by_month.setdefault(item["properties"]["datetime"][:7], []).append(item)
    for month in by_month:
        by_month[month].sort(key=lambda i: i["properties"].get("eo:cloud_cover", 100))

    ordered: list[dict] = []
    for rank in range(max(len(v) for v in by_month.values()) if by_month else 0):
        for month in sorted(by_month):
            if rank < len(by_month[month]):
                ordered.append(by_month[month][rank])
    return ordered


def stable_turf_mask(items: list[dict], bbox) -> tuple[np.ndarray, list[str], object, object]:
    """Pixels that are vegetated on every clear date and barely change.

    Returns (mask, dates used, transform, crs).
    """
    ndvi_stack: list[np.ndarray] = []
    valid_stack: list[np.ndarray] = []
    dates: list[str] = []
    tr = crs = None
    shape = None

    for item in items:
        if len(dates) >= SCENES_USED:
            break
        try:
            red, tr_i, crs_i = s2.reflectance(item, "red", bbox, out_shape=shape)
            shape = shape or red.shape
            nir, _, _ = s2.reflectance(item, "nir", bbox, out_shape=shape)
            usable, cloud = s2.usable_mask(item, bbox, shape)
        except Exception as exc:  # a missing asset or a bad COG is not fatal
            print(f"      ! {item['id']}: {exc}", file=sys.stderr)
            continue
        if cloud > MAX_AOI_CLOUD:
            continue
        date = item["properties"]["datetime"][:10]
        if date in dates:
            continue
        tr, crs = tr_i, crs_i
        ndvi = s2.ratio(nir, red)
        ndvi_stack.append(np.where(usable, ndvi, np.nan))
        valid_stack.append(usable)
        dates.append(date)

    if len(dates) < MIN_CLEAR_DATES:
        return np.zeros((1, 1), dtype=bool), dates, tr, crs

    stack = np.stack(ndvi_stack)
    clear = np.stack(valid_stack).sum(axis=0)

    with np.errstate(invalid="ignore"):
        median = np.nanmedian(stack, axis=0)
        spread = np.nanstd(stack, axis=0)

    mask = (
        (clear >= MIN_CLEAR_DATES)
        & (median >= NDVI_FLOOR)
        & (spread <= NDVI_STD_CEILING)
    )
    return s2.binary_close(np.nan_to_num(mask, nan=False), CLOSE_ITERATIONS), dates, tr, crs


def component_at(mask: np.ndarray, tr, lat: float, lon: float, crs) -> np.ndarray | None:
    """The blob the clubhouse sits in, or the biggest one within 600 m of it.

    Starting from the known point is what keeps this from returning the golf
    course's neighbouring plantation, which is also stably green.
    """
    from rasterio.warp import transform as warp_transform

    xs, ys = warp_transform("EPSG:4326", crs, [lon], [lat])
    col = int((xs[0] - tr.c) / tr.a)
    row = int((ys[0] - tr.f) / tr.e)

    labels, count = s2.connected_components(mask)
    if count == 0:
        return None

    h, w = mask.shape
    if 0 <= row < h and 0 <= col < w and labels[row, col]:
        return labels == labels[row, col]

    # The clubhouse is a building, so it is often *not* turf. Take the largest
    # component whose pixels come within 600 m of it instead.
    radius_px = int(600 / abs(tr.a))
    r0, r1 = max(0, row - radius_px), min(h, row + radius_px + 1)
    c0, c1 = max(0, col - radius_px), min(w, col + radius_px + 1)
    near = set(np.unique(labels[r0:r1, c0:c1])) - {0}
    if not near:
        return None
    best = max(near, key=lambda lab: int((labels == lab).sum()))
    return labels == best


def detect(course: dict, args) -> dict:
    bbox = s2.bbox_around(course["lat"], course["lon"], SEARCH_RADIUS_M)
    items = s2.stac_search(bbox, args.start, args.end, args.max_cloud, limit=SCENE_CANDIDATES)
    if not items:
        return {"skip": "no scene under the cloud limit"}

    # One MGRS tile, so the per-pixel stability figure is per-pixel and not
    # per-approximately-the-same-place — and it has to be a tile that actually
    # *covers* the course. Picking the tile with the most scenes is not the
    # same thing: Long Thành sits on the edge of the tile with the most scenes,
    # and the read window came back 730 m tall instead of 4 km, clipped at the
    # tile boundary, with no complaint from anyone.
    by_tile: dict[str, list[dict]] = {}
    for item in items:
        if not covers(item, bbox):
            continue
        by_tile.setdefault(s2.tile_of(item), []).append(item)
    if not by_tile:
        return {"skip": "no tile fully covers the course"}
    tile = max(by_tile, key=lambda t: len(by_tile[t]))

    mask, dates, tr, crs = stable_turf_mask(spread_over_months(by_tile[tile]), bbox)
    if len(dates) < MIN_CLEAR_DATES:
        return {"skip": f"only {len(dates)} clear dates"}
    if not mask.any():
        return {"skip": "no stable turf", "dates": dates}

    blob = component_at(mask, tr, course["lat"], course["lon"], crs)
    if blob is None:
        return {"skip": "no turf near the clubhouse", "dates": dates}

    polys = s2.polygonise(blob, tr, crs,
                          MIN_COURSE_HA * 10_000, MAX_COURSE_HA * 10_000)
    if not polys:
        area_ha = float(blob.sum()) * abs(tr.a * tr.e) / 10_000
        return {"skip": f"blob {area_ha:.0f} ha outside {MIN_COURSE_HA}-{MAX_COURSE_HA} ha",
                "dates": dates}

    best = max(polys, key=lambda p: p["area_m2"])
    return {"wkt": best["wkt"], "area_m2": best["area_m2"], "dates": dates, "tile": tile}


# ── validation ───────────────────────────────────────────────────────────────

def validate(psql_cmd, results: dict, courses: dict) -> None:
    """IoU against the OSM outline, for the courses OSM has drawn.

    Read the caveat in the printed note before treating the number as a grade:
    the two polygons are not measuring the same thing.
    """
    truth = osm_boundaries()
    if not truth:
        print("no OSM snapshot to validate against")
        return

    rows = []
    for fid, res in results.items():
        if "wkt" not in res:
            continue
        course = courses[fid]
        near = [t for t in truth
                if abs(t["lat"] - course["lat"]) < 0.03 and abs(t["lon"] - course["lon"]) < 0.03]
        if not near:
            continue
        best = min(near, key=lambda t: (t["lat"] - course["lat"]) ** 2
                                       + (t["lon"] - course["lon"]) ** 2)
        rows.append((fid, course["name"], res["wkt"], best["wkt"], best["ref"]))

    if not rows:
        print("no course has both a detection and an OSM outline")
        return

    values = ",\n".join(
        f"({fid}, {s2.q(name)}, {s2.q(ref)}, "
        f"ST_MakeValid(ST_GeomFromText({s2.q(det)},4326)), "
        f"ST_MakeValid(ST_GeomFromText({s2.q(osm)},4326)))"
        for fid, name, det, osm, ref in rows
    )
    sql = f"""
WITH v(fid, name, ref, det, osm) AS (VALUES
{values}
), m AS (
  SELECT name, ref,
         ST_Area(ST_Transform(det,32648))/10000 AS det_ha,
         ST_Area(ST_Transform(osm,32648))/10000 AS osm_ha,
         ST_Area(ST_Intersection(ST_Transform(det,32648), ST_Transform(osm,32648)))/10000 AS inter_ha,
         ST_Area(ST_Union(ST_Transform(det,32648), ST_Transform(osm,32648)))/10000 AS union_ha
  FROM v
)
SELECT name, ref,
       round(det_ha::numeric,0) AS det_ha,
       round(osm_ha::numeric,0) AS osm_ha,
       round((inter_ha/NULLIF(union_ha,0))::numeric,2) AS iou,
       round((inter_ha/NULLIF(osm_ha,0))::numeric,2) AS covered
FROM m ORDER BY iou DESC;

SELECT count(*) AS scored,
       round(avg(inter_ha/NULLIF(union_ha,0))::numeric,3) AS mean_iou,
       round(avg(inter_ha/NULLIF(osm_ha,0))::numeric,3) AS mean_coverage_of_osm
FROM m;
"""
    print(s2.run_psql(psql_cmd, sql))
    print("NOTE  IoU here compares a turf mask with a property line. OSM outlines")
    print("      include clubhouses, car parks and scrub; this detects mown grass.")
    print("      `covered` — how much of the OSM outline the detection contains —")
    print("      is the number that matters for using this as a search bound.")


# ── writing ──────────────────────────────────────────────────────────────────

def build_sql(results: dict, courses: dict, apply: bool) -> str:
    year = dt.date.today().year
    parts = ["""
CREATE TABLE IF NOT EXISTS sat_boundary_staging (
    id         BIGSERIAL PRIMARY KEY,
    facility_id BIGINT NOT NULL,
    course_id   BIGINT,
    scenes      TEXT NOT NULL,
    dates       TEXT NOT NULL,
    tile        TEXT,
    area_m2     DOUBLE PRECISION,
    publisher   TEXT NOT NULL,
    license     TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    geom        geometry(Polygon,4326) NOT NULL
);
"""]
    # Re-runnable: this run's rows replace the previous run's for the same
    # facilities, and nothing else is touched.
    ids = ",".join(str(fid) for fid, r in results.items() if "wkt" in r)
    if ids:
        parts.append(f"DELETE FROM sat_boundary_staging WHERE facility_id IN ({ids});")

    for fid, res in results.items():
        if "wkt" not in res:
            continue
        course = courses[fid]
        parts.append(
            "INSERT INTO sat_boundary_staging "
            "(facility_id, course_id, scenes, dates, tile, area_m2, publisher, license, geom) VALUES ("
            f"{fid}, {course['course_id'] or 'NULL'}, "
            f"{s2.q('sentinel2:' + res['tile'])}, {s2.q(','.join(res['dates']))}, "
            f"{s2.q(res['tile'])}, {res['area_m2']:.1f}, "
            f"{s2.q(s2.PUBLISHER + ' ' + str(year))}, {s2.q(s2.LICENSE)}, "
            f"ST_MakeValid(ST_GeomFromText({s2.q(res['wkt'])}, 4326)));"
        )

    parts.append("SELECT count(*) AS boundaries_in_staging FROM sat_boundary_staging;")
    return "\n".join(parts) if apply else ""


# ── entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    today = dt.date.today()
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--psql", help=f"default: {s2.DEFAULT_PSQL}")
    ap.add_argument("--start", default=str(today - dt.timedelta(days=365)))
    ap.add_argument("--end", default=str(today))
    ap.add_argument("--max-cloud", type=float, default=85.0,
                    help="scene-level filter for the STAC search; the AOI check is what decides")
    ap.add_argument("--course", type=int, action="append",
                    help="facility id, repeatable; default is every locatable course")
    ap.add_argument("--limit", type=int, help="stop after N courses (for a quick look)")
    ap.add_argument("--validate", action="store_true", help="score against OSM, write nothing")
    ap.add_argument("--apply", action="store_true", help="write the staging table")
    args = ap.parse_args()

    psql_cmd = s2.psql_argv(args.psql)

    where = "f.location IS NOT NULL AND f.source LIKE 'osm:%'"
    if args.course:
        where = "f.id IN (" + ",".join(str(c) for c in args.course) + ")"
    rows = s2.query(psql_cmd, f"""
        SELECT f.id, f.name, ST_Y(f.location::geometry), ST_X(f.location::geometry),
               (SELECT c.id FROM courses c WHERE c.facility_id = f.id ORDER BY c.id LIMIT 1)
        FROM golf_facilities f
        WHERE {where}
        ORDER BY f.id;
    """)
    courses = {
        int(r[0]): {"name": r[1], "lat": float(r[2]), "lon": float(r[3]),
                    "course_id": int(r[4]) if r[4] else None}
        for r in rows
    }
    if args.limit:
        courses = dict(list(courses.items())[: args.limit])

    print(f"{len(courses)} courses with a real coordinate\n")

    results: dict[int, dict] = {}
    for n, (fid, course) in enumerate(courses.items(), 1):
        print(f"[{n}/{len(courses)}] {course['name']}")
        try:
            res = detect(course, args)
        except Exception as exc:
            res = {"skip": f"{type(exc).__name__}: {exc}"}
        results[fid] = res
        if "wkt" in res:
            print(f"      {res['area_m2']/10000:.0f} ha from {len(res['dates'])} dates")
        else:
            print(f"      skipped: {res['skip']}")

    found = sum(1 for r in results.values() if "wkt" in r)
    print(f"\n{found}/{len(courses)} boundaries detected")

    if args.validate:
        validate(psql_cmd, results, courses)

    if args.apply:
        s2.run_psql(psql_cmd, build_sql(results, courses, apply=True))
        print("written to sat_boundary_staging")
    elif not args.validate:
        print("\nDry run. --apply writes the staging table, --validate scores it.")


if __name__ == "__main__":
    main()
