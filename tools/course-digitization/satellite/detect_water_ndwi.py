#!/usr/bin/env python3
"""Detect golf-course water hazards from free Sentinel-2 imagery.

Sentinel-2 L2A is 10 m/pixel and free. Water absorbs shortwave infrared almost
completely while turf reflects it, so a pond stands out against a fairway in a
green/SWIR ratio. A 30 m pond is 9 pixels — small, but detectable.

  Bunkers are NOT detectable at 10 m/pixel and this script does not try.
  A 12 m bunker is one pixel, mixed with the grass around it; there is no
  threshold that finds them and no amount of processing that recovers them.
  They need sub-metre imagery — see ../README.md for the manual route.

The imagery comes from the AWS Open Data mirror of Sentinel-2 L2A COGs, via the
Element 84 STAC API. No account, no key, no egress cost. Only the few hundred
pixels over each course are fetched (COG range requests), so a full run moves a
few MB.

  scene choice   lowest cloud cover in the window, then checked against the
                 scene classification band *over the course itself* — a scene
                 that is 8% cloudy nationally can still be solid cloud over
                 the one course that matters
  detection      MNDWI > 0.15 on 2 of 3 clear dates, holes filled, 2+ pixels
  filtering      200 m2 - 150000 m2, inside the OSM course outline, within
                 120 m of a real hole line, not already mapped in OSM
  provenance     accuracy_class D_UNVERIFIED_COMMUNITY, PENDING_REVIEW,
                 confidence 0.25, source sentinel2:<scene>

WHAT IT IS WORTH
  Measured against the water hazards OSM has mapped by hand on these courses,
  it finds 40% of them. The misses are not tuning: several mapped hazards show
  no water signal in any index on any date — they are dry, or vegetated, or
  too small to survive a 10 m grid. Read README.md before trusting a number.
  Everything lands PENDING_REVIEW at confidence 0.25 for that reason, and
  --preview exists so a reviewer can look before believing.

SCOPE
  Only courses that have real hole geometry (`osm_hole_match`, produced by
  ../osm/build_from_osm.py). A water hazard has to attach to a hole, and the
  other courses' holes are synthetic offsets from the clubhouse — attaching a
  real pond to an imaginary hole would be worse than having no pond.

USAGE
  python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
  ./venv/bin/python detect_water_ndwi.py --validate           # score against OSM, write nothing
  ./venv/bin/python detect_water_ndwi.py --preview /tmp/pv    # dry run + pictures
  ./venv/bin/python detect_water_ndwi.py --apply              # commit

LICENSING
  Copernicus Sentinel data. Free to use, redistribute and adapt under the
  "Legal notice on the use of Copernicus Sentinel Data and Service
  Information" (Commission Delegated Regulation (EU) No 1159/2013); the
  required attribution for a derived product is "Contains modified Copernicus
  Sentinel data <year>", which is what lands in the license/publisher columns.
"""

import argparse
import datetime as dt
import json
import os
import pathlib
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
             "then run this script with ./venv/bin/python")

DEFAULT_PSQL = "docker exec -i vsp_postgres psql -U vsp -d vsp"
STAC_URL = "https://earth-search.aws.element84.com/v1/search"

MNDWI_THRESHOLD = 0.15      # see the note on index choice below
AOI_MARGIN_M = 200          # around the course's hole lines
MIN_AREA_M2 = 200           # 2 pixels; below this it is noise
MAX_AREA_M2 = 150_000       # a course lake can be 6 ha; beyond this it is a river or reservoir
HOLE_ASSIGN_RADIUS_M = 120  # pond to hole line
MAX_AOI_CLOUD_FRACTION = 0.02
SCENE_CANDIDATES = 12       # scenes to consider per course
SCENES_REQUIRED = 2         # a pixel must be water in this many of them
SCENES_USED = 3             # ... out of this many clear dates

# SCL classes that make a pixel unusable: cloud shadow, cloud medium/high,
# thin cirrus. (SCL 6 is "water" — a hint, but too coarse at 20 m to use.)
SCL_BAD = (3, 8, 9, 10)

PUBLISHER = "Contains modified Copernicus Sentinel data"
LICENSE = "Copernicus Sentinel Data Legal Notice"


# ── database plumbing ────────────────────────────────────────────────────────
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
    return "NULL" if text is None else "'" + str(text).replace("'", "''") + "'"


# ── imagery ──────────────────────────────────────────────────────────────────
def stac_search(bbox, start, end, max_cloud) -> list[dict]:
    body = {
        "collections": ["sentinel-2-l2a"],
        "bbox": list(bbox),
        "datetime": f"{start}T00:00:00Z/{end}T00:00:00Z",
        "query": {"eo:cloud_cover": {"lt": max_cloud}},
        "limit": 50,
    }
    req = urllib.request.Request(STAC_URL, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        items = json.load(resp)["features"]
    return sorted(items, key=lambda f: f["properties"]["eo:cloud_cover"])


def read_window(href: str, bbox, out_shape=None):
    """Read just the AOI out of a COG. Returns (array, transform, crs)."""
    with rasterio.open(href) as ds:
        proj = transform_bounds("EPSG:4326", ds.crs, *bbox)
        win = from_bounds(*proj, ds.transform)
        kw = {"window": win, "out_dtype": "float32"}
        if out_shape:
            kw["out_shape"] = out_shape
        return ds.read(1, **kw), ds.window_transform(win), ds.crs


def fill_holes(mask: np.ndarray) -> np.ndarray:
    """Flood the background in from the border; whatever it cannot reach is an
    interior hole (an island of bright water pixels inside a pond edge)."""
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


def water_mask(item: dict, bbox, out_shape=None) -> tuple[np.ndarray, np.ndarray, object, object, float]:
    """(water, usable, transform, crs, cloud fraction) for one acquisition.

    Index choice is empirical, not fashion. Measured against the water hazards
    OSM has mapped by hand on these very courses, at the pond that is unambiguously
    a lake:

        NDWI  (green-NIR )/(green+NIR )   0.10   barely over a grass background
        MNDWI (green-SWIR)/(green+SWIR)   0.58   unmistakable

    Vietnamese course ponds are shallow, turbid and often algal, which lifts
    their NIR and collapses NDWI towards the fairway around them. SWIR is
    absorbed by water regardless of what is floating in it, so MNDWI keeps the
    separation. B11 is 20 m and gets resampled onto the 10 m grid — the cost is
    a blurrier outline, not a missed pond.
    """
    green, tr, crs = read_window(item["assets"]["green"]["href"], bbox, out_shape=out_shape)
    swir, _, _ = read_window(item["assets"]["swir16"]["href"], bbox, out_shape=green.shape)
    scl, _, _ = read_window(item["assets"]["scl"]["href"], bbox, out_shape=green.shape)

    bad = np.isin(scl.astype("int16"), SCL_BAD)
    cloud_fraction = float(bad.mean())

    # Processing baseline 04.00+ shifts reflectance by -1000 DN. A band ratio
    # does not cancel that out — it biases the whole scene. The STAC item says
    # whether the mirror already undid it.
    offset = 0.0 if item["properties"].get("earthsearch:boa_offset_applied") else -1000.0
    green = (green + offset) / 10_000.0
    swir = (swir + offset) / 10_000.0

    mndwi = (green - swir) / np.maximum(green + swir, 1e-6)
    return (mndwi > MNDWI_THRESHOLD) & ~bad, ~bad, tr, crs, cloud_fraction


def polygonise(mask: np.ndarray, tr, crs) -> list[dict]:
    mask = fill_holes(mask)
    out = []
    for geom, value in shapes(mask.astype("uint8"), mask=mask, transform=tr):
        if value != 1:
            continue
        ring = geom["coordinates"][0]
        # Shoelace in projected metres — UTM, so this is real area.
        area = abs(sum(ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1]
                       for i in range(len(ring) - 1))) / 2.0
        if not (MIN_AREA_M2 <= area <= MAX_AREA_M2):
            continue
        wgs = transform_geom(crs, "EPSG:4326", geom, precision=7)
        coords = wgs["coordinates"][0]
        wkt = "POLYGON((" + ", ".join(f"{x:.7f} {y:.7f}" for x, y in coords) + "))"
        out.append({"wkt": wkt, "area_m2": area})
    return out


def tile_of(item: dict) -> str:
    return item["id"].split("_")[1]


def pick_scenes_and_detect(course: dict, args) -> tuple[list[dict], list[dict], str]:
    """Water that is there on one date can be a flooded field, a shadow, or a
    puddle after a storm. Water that is there on several dates is a pond.
    Scenes are restricted to one MGRS tile so the pixel grids line up exactly
    and the vote is per-pixel rather than per-approximate-location."""
    items = stac_search(course["bbox"], args.start, args.end, args.max_cloud)
    if not items:
        return [], [], "no scene under the cloud limit"

    best = None
    for item in items[:SCENE_CANDIDATES]:
        mask, _, tr, crs, cloud = water_mask(item, course["bbox"])
        if cloud > MAX_AOI_CLOUD_FRACTION:
            continue
        best = (item, mask, tr, crs)
        break
    if best is None:
        return [], [], f"all {min(len(items), SCENE_CANDIDATES)} candidate scenes cloudy over the course"

    item, mask, tr, crs = best
    used, votes = [item], mask.astype("uint8")
    for other in items[:SCENE_CANDIDATES]:
        if len(used) >= SCENES_USED:
            break
        if other["id"] == item["id"] or tile_of(other) != tile_of(item):
            continue
        m, _, _, _, cloud = water_mask(other, course["bbox"], out_shape=mask.shape)
        if cloud > MAX_AOI_CLOUD_FRACTION:
            continue
        used.append(other)
        votes += m.astype("uint8")

    if len(used) < SCENES_REQUIRED:
        return used, [], f"only {len(used)} clear date — not enough to confirm"
    polys = polygonise(votes >= SCENES_REQUIRED, tr, crs)
    return used, polys, f"{len(used)} clear dates"


# ── validation against OSM ───────────────────────────────────────────────────
def validate(psql_cmd, courses, results) -> None:
    """Score the detector where the answer is already known: OSM has water
    hazards mapped by hand on some of these courses. Anything claimed here has
    to survive that comparison first."""
    print("\n── validation against hand-mapped OSM water hazards ──────────────────")
    rows = query(psql_cmd, """
        SELECT m.course_id, count(DISTINCT s.osm_id)
        FROM osm_golf_staging s
        JOIN osm_hole_match m ON ST_DWithin(s.geom::geography, m.geom::geography, 150)
        WHERE s.kind = 'water_hazard'
        GROUP BY 1;""")
    osm_by_course = {int(r[0]): int(r[1]) for r in rows}
    if not osm_by_course:
        print("  no OSM water hazards near matched holes — nothing to score against")
        return

    total_osm = total_hit = total_det = 0
    for course in courses:
        polys = results.get(course["id"], [])
        n_osm = osm_by_course.get(course["id"], 0)
        if not n_osm:
            continue
        values = ",".join(f"(ST_GeomFromText({q(p['wkt'])},4326))" for p in polys) or "(NULL::geometry)"
        hit = query(psql_cmd, f"""
            WITH det(geom) AS (VALUES {values}),
            osm AS (SELECT DISTINCT s.osm_id, s.geom FROM osm_golf_staging s
                    JOIN osm_hole_match m ON ST_DWithin(s.geom::geography, m.geom::geography, 150)
                    WHERE s.kind = 'water_hazard' AND m.course_id = {course['id']})
            SELECT count(*) FROM osm o WHERE EXISTS (
                SELECT 1 FROM det d WHERE d.geom IS NOT NULL AND ST_Intersects(d.geom, o.geom));""")
        n_hit = int(hit[0][0])
        total_osm += n_osm
        total_hit += n_hit
        total_det += len(polys)
        print(f"  {course['name'][:44]:<44} OSM {n_osm:>3}  found {n_hit:>3}  detections {len(polys):>3}")
    if total_osm:
        print(f"  {'TOTAL':<44} OSM {total_osm:>3}  found {total_hit:>3} "
              f"({total_hit * 100 // total_osm}%)  detections {total_det:>3}")
    print("  A detection with no OSM counterpart is not automatically wrong — OSM's\n"
          "  water coverage is patchy. It is why everything lands PENDING_REVIEW.")


# ── preview ──────────────────────────────────────────────────────────────────
def kept_indices(psql_cmd, course_id: int, polys: list[dict]) -> set[int]:
    """Which detections would survive the write filters — asked of PostGIS so
    the picture cannot drift away from what the database actually does."""
    if not polys:
        return set()
    values = ",".join(f"({i}, ST_GeomFromText({q(p['wkt'])},4326))" for i, p in enumerate(polys))
    rows = query(psql_cmd, f"""
        WITH det(idx, geom) AS (VALUES {values}),
        outline AS (SELECT s.geom FROM courses c
                    JOIN golf_facilities f  ON f.id = c.facility_id
                    JOIN osm_golf_staging s ON s.kind = 'course_boundary'
                                           AND 'osm:' || s.osm_ref = f.source
                    WHERE c.id = {course_id})
        SELECT d.idx FROM det d
        WHERE EXISTS (SELECT 1 FROM osm_hole_match m
                       WHERE m.course_id = {course_id}
                         AND ST_DWithin(d.geom::geography, m.geom::geography, {HOLE_ASSIGN_RADIUS_M}))
          AND (NOT EXISTS (SELECT 1 FROM outline)
               OR EXISTS (SELECT 1 FROM outline o WHERE ST_Intersects(o.geom, ST_Centroid(d.geom))))
          AND NOT EXISTS (SELECT 1 FROM water_hazards w
                           WHERE w.source LIKE 'osm:%' AND ST_Intersects(w.location, d.geom));""")
    return {int(r[0]) for r in rows}


def write_preview(psql_cmd, course: dict, item: dict, polys: list[dict], out_dir) -> str:
    """True-colour crop with the course outline, the real hole lines, and every
    detection — red for the ones that get written, grey for the ones the filters
    throw away. A reviewer approving PENDING_REVIEW rows should look at this
    before believing any of it."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        sys.exit("--preview needs pillow:  ./venv/bin/pip install pillow")

    zoom = 6
    with rasterio.open(item["assets"]["visual"]["href"]) as ds:
        proj = transform_bounds("EPSG:4326", ds.crs, *course["bbox"])
        win = from_bounds(*proj, ds.transform)
        rgb = ds.read(window=win)
        tr, crs = ds.window_transform(win), ds.crs

    img = np.transpose(rgb, (1, 2, 0)).astype("uint8")
    im = Image.fromarray(img).resize((img.shape[1] * zoom, img.shape[0] * zoom), Image.LANCZOS)
    draw = ImageDraw.Draw(im)
    inv = ~tr

    def to_px(lon, lat):
        xs, ys = rasterio.warp.transform("EPSG:4326", crs, [lon], [lat])
        col, row = inv * (xs[0], ys[0])
        return col * zoom, row * zoom

    def ring(wkt: str) -> list[tuple[float, float]]:
        body = wkt[wkt.index("((") + 2:wkt.rindex("))")] if "((" in wkt \
            else wkt[wkt.index("(") + 1:wkt.rindex(")")]
        return [to_px(*map(float, pt.split())) for pt in body.split(",")]

    for (wkt,) in query(psql_cmd, f"""
            SELECT ST_AsText(s.geom) FROM courses c
            JOIN golf_facilities f  ON f.id = c.facility_id
            JOIN osm_golf_staging s ON s.kind = 'course_boundary'
                                   AND 'osm:' || s.osm_ref = f.source
            WHERE c.id = {course['id']};"""):
        pts = ring(wkt)
        draw.line(pts + [pts[0]], fill=(255, 255, 0), width=2)
    for (wkt,) in query(psql_cmd, f"SELECT ST_AsText(geom) FROM osm_hole_match WHERE course_id = {course['id']};"):
        draw.line(ring(wkt), fill=(80, 180, 255), width=2)

    keep = kept_indices(psql_cmd, course["id"], polys)
    for i, p in enumerate(polys):
        pts = ring(p["wkt"])
        colour = (255, 40, 40) if i in keep else (150, 150, 150)
        draw.line(pts + [pts[0]], fill=colour, width=3 if i in keep else 1)

    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{course['id']}-{course['name'].split(' — ')[0].replace('/', '-')}.png"
    im.save(path)
    return f"{len(keep)}/{len(polys)} kept -> {path.name}"


# ── writing ──────────────────────────────────────────────────────────────────
def build_sql(results: dict, scenes: dict, apply: bool) -> str:
    rows = []
    for course_id, polys in results.items():
        scene = scenes[course_id]
        for p in polys:
            rows.append(
                f"({course_id},{q(scene['id'])},{q(scene['date'])},{q(scene['dates'])},{scene['cloud']:.2f},"
                f"{p['area_m2']:.1f},ST_GeomFromText({q(p['wkt'])},4326))")
    values = ",\n".join(rows) if rows else None

    parts = [
        "BEGIN;",
        "CREATE TEMP TABLE run_report (detail text, n bigint) ON COMMIT DROP;",
        "DROP TABLE IF EXISTS sat_water_staging;",
        """CREATE TABLE sat_water_staging (
    id        bigserial PRIMARY KEY,
    course_id bigint NOT NULL,
    scene     text   NOT NULL,
    acquired  date   NOT NULL,
    dates     text   NOT NULL,   -- every acquisition that voted for this polygon
    cloud_pct double precision,
    area_m2   double precision,
    geom      geometry(Polygon,4326) NOT NULL
);
COMMENT ON TABLE sat_water_staging IS
  'Pipeline artefact: Sentinel-2 MNDWI water detections. Rebuilt by tools/course-digitization/satellite/detect_water_ndwi.py.';""",
    ]
    if values:
        parts.append("INSERT INTO sat_water_staging (course_id,scene,acquired,dates,cloud_pct,area_m2,geom) VALUES\n"
                     + values + ";")
    parts.append("""
INSERT INTO run_report SELECT 'kept: human-VERIFIED sentinel2 rows', count(*)
FROM water_hazards WHERE source LIKE 'sentinel2:%' AND verification_status = 'VERIFIED';

DELETE FROM water_hazards
WHERE source LIKE 'sentinel2:%' AND coalesce(verification_status,'') <> 'VERIFIED';

-- The course outline, where OSM has one. "Within 120 m of a hole" is not the
-- same as "on the course": in the delta a fairway can run along a fish farm,
-- and NDWI cannot tell a water hazard from someone's shrimp pond. The outline
-- can, so use it wherever it exists.
CREATE TEMP VIEW course_outline AS
SELECT c.id AS course_id, s.geom
FROM courses c
JOIN golf_facilities f  ON f.id = c.facility_id
JOIN osm_golf_staging s ON s.kind = 'course_boundary'
                       AND 'osm:' || s.osm_ref = f.source;

INSERT INTO run_report SELECT 'detections dropped: outside the course outline', count(*)
FROM sat_water_staging s
JOIN course_outline b ON b.course_id = s.course_id
WHERE NOT ST_Intersects(b.geom, ST_Centroid(s.geom));

WITH assign AS (
    SELECT DISTINCT ON (s.id)
           s.id, s.geom, s.scene, s.area_m2, m.db_hole_id,
           ST_Distance(s.geom::geography, m.geom::geography) AS dist_m
    FROM sat_water_staging s
    JOIN osm_hole_match m ON m.course_id = s.course_id
                         AND ST_DWithin(s.geom::geography, m.geom::geography, """
                 + str(HOLE_ASSIGN_RADIUS_M) + """)
    LEFT JOIN course_outline b ON b.course_id = s.course_id
    WHERE b.geom IS NULL OR ST_Intersects(b.geom, ST_Centroid(s.geom))
    ORDER BY s.id, ST_Distance(s.geom::geography, m.geom::geography)
), ins AS (
    INSERT INTO water_hazards (hole_id, hazard_type, location, accuracy_class,
        verification_status, confidence, source, publisher, license,
        effective_date, version, created_at, updated_at)
    SELECT a.db_hole_id, 'WATER',
           ST_SimplifyPreserveTopology(a.geom, 0.00002),
           'D_UNVERIFIED_COMMUNITY', 'PENDING_REVIEW', 0.25,
           'sentinel2:' || a.scene, """ + q(PUBLISHER) + ", " + q(LICENSE) + """,
           CURRENT_DATE, 1, now(), now()
    FROM assign a
    -- Do not shadow a hand-mapped hazard with a 10 m-pixel guess at the same pond.
    WHERE NOT EXISTS (
        SELECT 1 FROM water_hazards w
        WHERE w.hole_id = a.db_hole_id AND ST_Intersects(w.location, a.geom))
    RETURNING 1
) INSERT INTO run_report SELECT 'water hazards written', count(*) FROM ins;

INSERT INTO run_report SELECT 'detections dropped: no hole within """
                 + str(HOLE_ASSIGN_RADIUS_M) + """ m', count(*)
FROM sat_water_staging s WHERE NOT EXISTS (
    SELECT 1 FROM osm_hole_match m WHERE m.course_id = s.course_id
      AND ST_DWithin(s.geom::geography, m.geom::geography, """ + str(HOLE_ASSIGN_RADIUS_M) + """));

INSERT INTO run_report SELECT 'detections dropped: already mapped in OSM', count(*)
FROM sat_water_staging s WHERE EXISTS (
    SELECT 1 FROM water_hazards w
     WHERE w.source LIKE 'osm:%' AND ST_Intersects(w.location, s.geom));

\\echo ''
SELECT detail, n FROM run_report ORDER BY detail;
SELECT 'water_hazards total' AS metric, count(*) AS n FROM water_hazards
UNION ALL SELECT '  from OSM', count(*) FROM water_hazards WHERE source LIKE 'osm:%'
UNION ALL SELECT '  from Sentinel-2', count(*) FROM water_hazards WHERE source LIKE 'sentinel2:%'
UNION ALL SELECT '  holes covered', count(DISTINCT hole_id) FROM water_hazards;
""")
    parts.append("COMMIT;" if apply else "ROLLBACK;  -- dry run")
    return "\n".join(parts)


# ── entry point ──────────────────────────────────────────────────────────────
def main() -> None:
    today = dt.date.today()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="commit (default: dry run)")
    ap.add_argument("--validate", action="store_true", help="score against OSM and write nothing")
    ap.add_argument("--psql", default=DEFAULT_PSQL)
    ap.add_argument("--start", default=str(today - dt.timedelta(days=180)),
                    help="earliest acquisition date (YYYY-MM-DD)")
    ap.add_argument("--end", default=str(today), help="latest acquisition date")
    ap.add_argument("--max-cloud", type=float, default=15.0, help="scene-level cloud cover limit %%")
    ap.add_argument("--course", type=int, action="append", dest="courses", help="restrict to course id (repeatable)")
    ap.add_argument("--preview", type=pathlib.Path, metavar="DIR",
                    help="write a true-colour PNG per course with the detections drawn on it")
    args = ap.parse_args()
    psql_cmd = shlex.split(args.psql)

    only = f"AND m.course_id IN ({','.join(str(c) for c in args.courses)})" if args.courses else ""
    rows = query(psql_cmd, f"""
        SELECT m.course_id, c.name, count(*),
               ST_XMin(ST_Extent(m.geom)), ST_YMin(ST_Extent(m.geom)),
               ST_XMax(ST_Extent(m.geom)), ST_YMax(ST_Extent(m.geom))
        FROM osm_hole_match m
        JOIN courses c ON c.id = m.course_id
        WHERE true {only}
        GROUP BY 1, 2 ORDER BY 2;""")
    if not rows:
        sys.exit("No courses with real hole geometry. Run ../osm/build_from_osm.py --apply first.")

    margin = AOI_MARGIN_M / 111_000.0
    courses = [{
        "id": int(r[0]), "name": r[1], "holes": int(r[2]),
        "bbox": (float(r[3]) - margin, float(r[4]) - margin,
                 float(r[5]) + margin, float(r[6]) + margin),
    } for r in rows]

    print(f"{len(courses)} courses with real hole geometry; "
          f"scenes {args.start} .. {args.end}, scene cloud < {args.max_cloud}%\n")

    results, scenes = {}, {}
    for course in courses:
        used, polys, note = pick_scenes_and_detect(course, args)
        if not polys and len(used) < SCENES_REQUIRED:
            print(f"  {course['name'][:44]:<44} SKIPPED — {note}")
            continue
        item = used[0]
        scenes[course["id"]] = {
            "id": item["id"],
            "date": item["properties"]["datetime"][:10],
            "cloud": item["properties"]["eo:cloud_cover"],
            "dates": ",".join(u["properties"]["datetime"][:10] for u in used),
        }
        results[course["id"]] = polys
        extra = ""
        if args.preview:
            extra = "  " + write_preview(psql_cmd, course, item, polys, args.preview)
        print(f"  {course['name'][:44]:<44} {item['id']:<26} {note:<16} "
              f"{len(polys):>3} water polygons{extra}")

    total = sum(len(p) for p in results.values())
    print(f"\n{total} candidate water polygons across {len(results)} courses")

    if args.validate:
        validate(psql_cmd, courses, results)
        return

    sql = build_sql(results, scenes, args.apply)
    print(f"\nwriting ({'APPLY' if args.apply else 'dry run — will roll back'})…")
    sys.stdout.write(run_psql(psql_cmd, sql))
    if not args.apply:
        print("\nDry run: rolled back. Re-run with --apply to keep it.")


if __name__ == "__main__":
    main()
