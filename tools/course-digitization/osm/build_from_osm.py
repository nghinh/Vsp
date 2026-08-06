#!/usr/bin/env python3
"""Rebuild course geometry in the VSP database from an OpenStreetMap snapshot.

Step 2 of two (see fetch_osm.py). This script never touches the network: its
only inputs are the committed snapshot and the database. Same snapshot + same
seed data => same rows, on any machine.

What it does, in order:

  1  load the snapshot into `osm_golf_staging` (drop/recreate — pure scratch)
  2  match OSM golf courses to `golf_facilities` by normalised name similarity
     (>= 0.90) AND centroid distance (<= 25 km), then write the real coordinate
     onto the facility (and realign the course row that hangs off it)
  3  match OSM `golf=hole` ways to `holes` by ref + proximity + length, one to
     one, into `osm_hole_match`
  4  write `holes.teeing_ground_location` / `green_location` from the ends of
     the matched line (direction resolved by which end is nearer a golf=green)
  5  import real OSM greens / bunkers / water hazards, each attached to the
     nearest matched hole line
  6  derive a green (buffer around the green point) for every hole that has no
     real one
  7  derive a fairway corridor (buffer around the tee->green line) for every
     hole that has no real one

Note on 3: `golf=hole` in OSM is a LINESTRING tee->green, not a polygon, and
only ~75% of them carry the hole number in `ref`. That is why so few holes
match: the data is not there, not because the matcher is timid.

IDEMPOTENCE
  Every write is guarded so a second run against an unchanged snapshot updates
  and inserts nothing. Derived and imported rows are keyed by (hole_id, source)
  and re-created from scratch each run; nothing else in the schema is touched.

WHAT IS PROTECTED
  A row is protected when verification_status = 'VERIFIED' AND source <> 'SEED'
  — i.e. a human looked at it and signed it off. Protected rows are never
  updated, never deleted, and are reported as skipped.

  Rows with source = 'SEED' are *not* protected even though the seed marks them
  'VERIFIED': those coordinates are synthesised in a loop by
  scripts/dev/seed_courses_vn.sql (tee = facility + hole_number * 0.0008 deg)
  and are wrong by kilometres. Overwriting them with real data is the entire
  point of this pipeline. It is not silent — the run report counts them, and
  --respect-seed-verified turns it off.

USAGE
  python3 build_from_osm.py                      # dry run: does everything, rolls back
  python3 build_from_osm.py --apply              # commits
  python3 build_from_osm.py --snapshot data/osm-vietnam-golf-2026-08-05.json.gz --apply
  python3 build_from_osm.py --print-sql > /tmp/pipeline.sql   # inspect, run nothing

  --psql lets it run anywhere the database is reachable, e.g.
  --psql "psql postgresql://vsp:pw@db.internal:5432/vsp"

ATTRIBUTION
  Everything imported keeps source = 'osm:way/<id>', publisher = 'OpenStreetMap
  contributors', license = 'ODbL-1.0'. Shapes *derived* from OSM geometry stay
  ODbL (they are a derivative); shapes derived from the synthetic seed points
  are marked publisher 'VSP' / license 'internal-derived'. Nothing lands above
  accuracy_class D_UNVERIFIED_COMMUNITY or verification_status PENDING_REVIEW.
"""

import argparse
import difflib
import gzip
import json
import math
import pathlib
import re
import shlex
import subprocess
import sys
import unicodedata

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_PSQL = "docker exec -i vsp_postgres psql -U vsp -d vsp"

# ── matching parameters ──────────────────────────────────────────────────────
NAME_SIMILARITY_MIN = 0.90      # difflib ratio on the normalised names
FACILITY_MAX_DIST_M = 25_000    # seeded coords are wrong by up to ~10 km
HOLE_SEARCH_RADIUS_M = 3_000    # OSM hole line centroid to facility point
HOLE_LENGTH_TOLERANCE = 0.25    # |osm_len - db_len| <= 25% of db_len
GREEN_ASSIGN_RADIUS_M = 45      # OSM green -> nearest matched hole line
BUNKER_ASSIGN_RADIUS_M = 60
WATER_ASSIGN_RADIUS_M = 60
DERIVED_GREEN_RADIUS_M = 14     # ~615 m2, about right for a real green
FAIRWAY_WIDTH_FRACTION = 0.09   # of hole length, clamped:
FAIRWAY_WIDTH_MIN_M = 18
FAIRWAY_WIDTH_MAX_M = 35

# Generic words dropped before comparing names. Keep this list stable — every
# change reshuffles which facilities match.
GENERIC_WORDS = {"golf", "club", "resort", "course", "san", "championship", "links"}

OSM_PUBLISHER = "OpenStreetMap contributors"
OSM_LICENSE = "ODbL-1.0"
AREA_KINDS = {"green", "tee", "bunker", "water_hazard", "fairway"}


# ── database plumbing ────────────────────────────────────────────────────────
def run_psql(psql_cmd: list[str], sql: str, extra: list[str] | None = None) -> str:
    proc = subprocess.run(
        psql_cmd + ["-v", "ON_ERROR_STOP=1"] + (extra or []) + ["-f", "-"],
        input=sql, text=True, capture_output=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.exit(f"psql failed:\n{proc.stderr.strip()}")
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)
    return proc.stdout


def query(psql_cmd: list[str], sql: str) -> list[list[str]]:
    out = run_psql(psql_cmd, sql, extra=["-t", "-A", "-F", "\t"])
    return [line.split("\t") for line in out.splitlines() if line.strip()]


def q(text: str | None) -> str:
    """Single-quote a value for SQL, or NULL."""
    if text is None:
        return "NULL"
    return "'" + str(text).replace("'", "''") + "'"


# ── name normalisation & matching ────────────────────────────────────────────
def normalise(name: str) -> str:
    """Lowercase, strip diacritics and generic golf words, collapse to letters."""
    folded = unicodedata.normalize("NFD", name)
    folded = "".join(ch for ch in folded if unicodedata.category(ch) != "Mn")
    folded = folded.replace("đ", "d").replace("Đ", "d").lower()
    words = [w for w in re.split(r"[^a-z0-9]+", folded) if w and w not in GENERIC_WORDS]
    return " ".join(words)


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, a, b).ratio()


def contains_all_words(a: str, b: str) -> bool:
    """True when the shorter name's words all appear in the longer one.

    Straight string similarity is not enough on its own. OSM and the seed
    disagree about how much of a name to write down:

        'BRG Kings Island Golf Resort'  vs  'Mountain View - BRG Kings Island'
        'FLC Hạ Long Golf Club'         vs  'FLC Ha Long Bay Golf Club & Luxury Resort'
        'Đại Lải Star Golf & Country Club' vs 'Sân Golf Đại Lải'

    Those are the same places, and they score 0.52-0.70 — well under the 0.90
    similarity bar. Word containment catches them without opening the door to
    'Long Thành' / 'Long Biên', which share a word but not a word *set*. Two
    words minimum, so a lone 'Phoenix' cannot swallow a neighbour.
    """
    wa, wb = set(a.split()), set(b.split())
    if not wa or not wb:
        return False
    short, long = (wa, wb) if len(wa) <= len(wb) else (wb, wa)
    return len(short) >= 2 and short <= long


def haversine_m(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    r = 6_371_008.8
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def match_facilities(db_facilities: list[dict], osm_courses: list[dict]) -> list[dict]:
    """Greedy one-to-one match: best similarity first, distance breaks ties."""
    pairs = []
    for fac in db_facilities:
        if fac["lon"] is None:
            continue
        fac_norm = normalise(fac["name"])
        for osm in osm_courses:
            if not osm["name"]:
                continue
            osm_norm = normalise(osm["name"])
            score = similarity(fac_norm, osm_norm)
            by_words = contains_all_words(fac_norm, osm_norm)
            if score < NAME_SIMILARITY_MIN and not by_words:
                continue
            dist = haversine_m(fac["lon"], fac["lat"], osm["lon"], osm["lat"])
            if dist > FACILITY_MAX_DIST_M:
                continue
            pairs.append({"facility": fac, "osm": osm, "similarity": score,
                          "dist_m": dist, "how": "name" if score >= NAME_SIMILARITY_MIN else "words"})

    # Best first, so a strong pair claims its OSM course before a weak one can.
    # Ways beat relations on a tie: `out geom` gives us a way's ring directly.
    pairs.sort(key=lambda p: (-p["similarity"], p["dist_m"],
                              p["osm"]["ref"].startswith("relation/"),
                              p["facility"]["id"], p["osm"]["ref"]))
    used_fac, used_osm, chosen = set(), set(), []
    for p in pairs:
        if p["facility"]["id"] in used_fac or p["osm"]["ref"] in used_osm:
            continue
        used_fac.add(p["facility"]["id"])
        used_osm.add(p["osm"]["ref"])
        chosen.append(p)
    return chosen


# ── snapshot -> staging rows ─────────────────────────────────────────────────
def load_snapshot(path: pathlib.Path) -> dict:
    raw = path.read_bytes()
    if path.suffix == ".gz":
        raw = gzip.decompress(raw)
    return json.loads(raw)


def osm_courses_from(elements: list[dict]) -> list[dict]:
    out = []
    for el in elements:
        tags = el.get("tags") or {}
        name = tags.get("name") or tags.get("name:en") or tags.get("name:vi")
        centre = el.get("center") or ({"lat": el.get("lat"), "lon": el.get("lon")} if "lat" in el else None)
        if not name or not centre or centre.get("lat") is None:
            continue
        out.append({
            "ref": f"{el['type']}/{el['id']}",
            "name": name,
            "lon": float(centre["lon"]),
            "lat": float(centre["lat"]),
        })
    out.sort(key=lambda o: o["ref"])
    return out


def wkt_for(el: dict, kind: str) -> str | None:
    """WKT for an OSM way. Closed rings of area kinds become polygons."""
    geometry = el.get("geometry")
    if not geometry:
        return None
    pts = [(float(p["lon"]), float(p["lat"])) for p in geometry if p.get("lat") is not None]
    if len(pts) < 2:
        return None
    coords = ", ".join(f"{lon:.7f} {lat:.7f}" for lon, lat in pts)
    closed = len(pts) >= 4 and pts[0] == pts[-1]
    if kind in AREA_KINDS and closed:
        return f"POLYGON(({coords}))"
    return f"LINESTRING({coords})"


def boundary_rows(elements: list[dict]) -> list[tuple]:
    """Course outlines, staged alongside the features as kind='course_boundary'.

    Nothing in this pipeline needs them — the satellite pipeline does. It is the
    difference between "water within 120 m of a hole" and "water on the course",
    which in the Mekong delta is the difference between a hazard and a neighbour's
    fish pond.
    """
    rows = []
    for el in elements:
        if el["type"] != "way" or not el.get("geometry"):
            continue
        wkt = wkt_for(el, "green")  # any area kind: closes the ring if it can
        if wkt is None or not wkt.startswith("POLYGON"):
            continue
        name = (el.get("tags") or {}).get("name")
        rows.append((el["id"], f"way/{el['id']}", "course_boundary", name, wkt))
    rows.sort(key=lambda r: r[0])
    return rows


def staging_rows(elements: list[dict]) -> tuple[list[tuple], int]:
    """(rows, skipped_relations). Relations are multipolygons that `out geom`
    only returns member-wise; they are 1.3% of features and are left out rather
    than reassembled badly."""
    rows, skipped = [], 0
    for el in elements:
        tags = el.get("tags") or {}
        kind = tags.get("golf")
        if kind is None:
            continue
        if el["type"] != "way":
            skipped += 1
            continue
        wkt = wkt_for(el, kind)
        if wkt is None:
            skipped += 1
            continue
        rows.append((el["id"], f"way/{el['id']}", kind, tags.get("ref"), wkt))
    rows.sort(key=lambda r: r[0])
    return rows, skipped


# ── SQL generation ───────────────────────────────────────────────────────────
def sql_staging(rows: list[tuple]) -> str:
    parts = [
        "DROP TABLE IF EXISTS osm_golf_staging;",
        """CREATE TABLE osm_golf_staging (
    osm_id   bigint PRIMARY KEY,
    osm_ref  text   NOT NULL,
    kind     text   NOT NULL,
    ref      text,
    geom     geometry(Geometry,4326) NOT NULL
);""",
    ]
    chunk = 400
    for i in range(0, len(rows), chunk):
        values = ",\n".join(
            f"({osm_id},{q(osm_ref)},{q(kind)},{q(ref)},ST_GeomFromText({q(wkt)},4326))"
            for osm_id, osm_ref, kind, ref, wkt in rows[i:i + chunk]
        )
        parts.append(f"INSERT INTO osm_golf_staging (osm_id,osm_ref,kind,ref,geom) VALUES\n{values};")
    parts.append("CREATE INDEX osm_golf_staging_geom_idx ON osm_golf_staging USING gist (geom);")
    parts.append("ANALYZE osm_golf_staging;")
    return "\n".join(parts)


def sql_facilities(matches: list[dict], respect_seed: bool) -> str:
    protect = "(f.verification_status = 'VERIFIED' AND f.source <> 'SEED')"
    if respect_seed:
        protect = "(f.verification_status = 'VERIFIED')"
    if not matches:
        return "INSERT INTO run_report VALUES ('2 facilities', 'no name matches in snapshot', 0);"
    values = ",\n".join(
        f"({m['facility']['id']},{q(m['osm']['ref'])},{m['osm']['lon']:.7f},"
        f"{m['osm']['lat']:.7f},{m['similarity']:.4f},{m['dist_m']:.1f})"
        for m in matches
    )
    return f"""
CREATE TEMP TABLE fac_match (
    facility_id bigint PRIMARY KEY, osm_ref text, lon double precision,
    lat double precision, similarity double precision, dist_m double precision
) ON COMMIT DROP;
INSERT INTO fac_match VALUES
{values};

INSERT INTO run_report
SELECT '2 facilities', 'skipped: human-VERIFIED, left alone', count(*)
FROM golf_facilities f JOIN fac_match m ON m.facility_id = f.id WHERE {protect};

INSERT INTO run_report
SELECT '2 facilities', 'synthetic SEED coordinate replaced', count(*)
FROM golf_facilities f JOIN fac_match m ON m.facility_id = f.id
WHERE f.source = 'SEED' AND NOT {protect};

WITH upd AS (
    UPDATE golf_facilities f SET
        location            = ST_SetSRID(ST_MakePoint(m.lon, m.lat), 4326),
        source              = 'osm:' || m.osm_ref,
        publisher           = {q(OSM_PUBLISHER)},
        license             = {q(OSM_LICENSE)},
        accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
        verification_status = 'PENDING_REVIEW',
        confidence          = 60.00,
        updated_at          = now(),
        version             = f.version + 1
    FROM fac_match m
    WHERE f.id = m.facility_id
      AND NOT {protect}
      AND (f.location IS DISTINCT FROM ST_SetSRID(ST_MakePoint(m.lon, m.lat), 4326)
           OR f.source IS DISTINCT FROM 'osm:' || m.osm_ref)
    RETURNING 1
) INSERT INTO run_report SELECT '2 facilities', 'location written from OSM', count(*) FROM upd;

-- The course row carries its own copy of the location (search reads the
-- facility, but the course copy is what the portal map draws). Keep them equal
-- rather than leaving the course 22 km away from its own clubhouse.
WITH upd AS (
    UPDATE courses c SET
        location            = f.location,
        source              = f.source,
        publisher           = f.publisher,
        license             = f.license,
        accuracy_class      = f.accuracy_class,
        verification_status = f.verification_status,
        confidence          = f.confidence,
        updated_at          = now(),
        version             = c.version + 1
    FROM golf_facilities f
    WHERE f.id = c.facility_id
      AND f.source LIKE 'osm:%'
      AND NOT (c.verification_status = 'VERIFIED' AND c.source <> 'SEED')
      AND c.location IS DISTINCT FROM f.location
    RETURNING 1
) INSERT INTO run_report SELECT '2 facilities', 'course row realigned to facility', count(*) FROM upd;
"""


SQL_HOLE_MATCH = f"""
DROP TABLE IF EXISTS osm_hole_match;
CREATE TABLE osm_hole_match (
    db_hole_id      bigint PRIMARY KEY,
    course_id       bigint NOT NULL,
    hole_no         integer NOT NULL,
    osm_id          bigint NOT NULL UNIQUE,
    osm_ref         text NOT NULL,
    geom            geometry(LineString,4326) NOT NULL,
    osm_len_m       double precision NOT NULL,
    db_len_m        numeric(7,2),
    len_diff_m      double precision NOT NULL,
    centroid_dist_m double precision NOT NULL,
    flipped         boolean NOT NULL
);
COMMENT ON TABLE osm_hole_match IS
  'Pipeline artefact: OSM golf=hole way chosen for each DB hole. Rebuilt by tools/course-digitization/osm/build_from_osm.py.';

INSERT INTO osm_hole_match
WITH cand AS (
    SELECT h.id  AS db_hole_id,
           c.id  AS course_id,
           h.hole_number,
           s.osm_id,
           s.osm_ref,
           s.geom,
           ST_Length(s.geom::geography)                                    AS osm_len_m,
           h.playing_length_meters                                         AS db_len_m,
           abs(ST_Length(s.geom::geography) - h.playing_length_meters)     AS len_diff_m,
           ST_Distance(f.location::geography, ST_Centroid(s.geom)::geography) AS centroid_dist_m
    FROM holes h
    JOIN courses c          ON c.id = h.course_id
    JOIN golf_facilities f  ON f.id = c.facility_id
    JOIN osm_golf_staging s ON s.kind = 'hole'
                           AND ST_GeometryType(s.geom) = 'ST_LineString'
                           AND s.ref ~ '^[0-9]+$'
                           AND s.ref::int = h.hole_number
                           AND ST_DWithin(f.location::geography, s.geom::geography, {HOLE_SEARCH_RADIUS_M})
    WHERE h.playing_length_meters IS NOT NULL
      AND f.location IS NOT NULL
      AND abs(ST_Length(s.geom::geography) - h.playing_length_meters)
          <= {HOLE_LENGTH_TOLERANCE} * h.playing_length_meters
),
-- One OSM way per DB hole ...
best AS (
    SELECT DISTINCT ON (db_hole_id) * FROM cand
    ORDER BY db_hole_id, len_diff_m, centroid_dist_m, osm_id
),
-- ... and one DB hole per OSM way. 36-hole resorts have two "hole 1"; without
-- this the same line gets written onto both of them.
one2one AS (
    SELECT DISTINCT ON (osm_id) * FROM best
    ORDER BY osm_id, len_diff_m, centroid_dist_m, db_hole_id
)
SELECT o.db_hole_id, o.course_id, o.hole_number, o.osm_id, o.osm_ref, o.geom,
       o.osm_len_m, o.db_len_m, o.len_diff_m, o.centroid_dist_m,
       -- A golf=hole line has no guaranteed direction. Whichever end sits
       -- nearer a golf=green is the green end.
       COALESCE(
           (SELECT min(ST_Distance(ST_StartPoint(o.geom)::geography, g.geom::geography))
              FROM osm_golf_staging g
             WHERE g.kind = 'green'
               AND ST_DWithin(ST_StartPoint(o.geom)::geography, g.geom::geography, 250))
           <
           COALESCE((SELECT min(ST_Distance(ST_EndPoint(o.geom)::geography, g.geom::geography))
              FROM osm_golf_staging g
             WHERE g.kind = 'green'
               AND ST_DWithin(ST_EndPoint(o.geom)::geography, g.geom::geography, 250)), 1e9),
       false) AS flipped
FROM one2one o;

INSERT INTO run_report SELECT '3 hole match', 'OSM hole lines matched to DB holes', count(*) FROM osm_hole_match;
INSERT INTO run_report SELECT '3 hole match', 'courses with at least one matched hole', count(DISTINCT course_id) FROM osm_hole_match;
INSERT INTO run_report SELECT '3 hole match', 'median |osm_len - db_len| in metres',
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY len_diff_m)::numeric) FROM osm_hole_match;
INSERT INTO run_report SELECT '3 hole match', 'lines flipped (green end came first)', count(*) FROM osm_hole_match WHERE flipped;
"""


def sql_hole_points(respect_seed: bool) -> str:
    # Seeded rows are UNVERIFIED, so the status test alone already lets this
    # pipeline overwrite them; the source test is kept for databases seeded
    # before the labels were corrected, which still carry source='SEED'.
    protect = "(h.verification_status = 'VERIFIED' AND h.source <> 'SEED')"
    if respect_seed:
        protect = "(h.verification_status = 'VERIFIED')"
    return f"""
INSERT INTO run_report
SELECT '4 hole points', 'skipped: human-VERIFIED, left alone', count(*)
FROM holes h JOIN osm_hole_match m ON m.db_hole_id = h.id WHERE {protect};

WITH upd AS (
    UPDATE holes h SET
        teeing_ground_location = CASE WHEN m.flipped THEN ST_EndPoint(m.geom) ELSE ST_StartPoint(m.geom) END,
        green_location         = CASE WHEN m.flipped THEN ST_StartPoint(m.geom) ELSE ST_EndPoint(m.geom) END,
        -- The card comes from the same line as the points. It used to be left
        -- at whatever the seed invented, so a hole could state 488 m while its
        -- real coordinates sat 377 m apart (Long Thanh 2) — two numbers for
        -- one hole, and the one a golfer read was the fabricated one. Measured
        -- along the way, not across it: a dogleg genuinely plays longer than
        -- tee-to-green.
        playing_length_meters  = round(m.osm_len_m::numeric, 2),
        source                 = 'osm:' || m.osm_ref,
        publisher              = {q(OSM_PUBLISHER)},
        license                = {q(OSM_LICENSE)},
        accuracy_class         = 'D_UNVERIFIED_COMMUNITY',
        verification_status    = 'PENDING_REVIEW',
        confidence             = 60.00,
        updated_at             = now(),
        version                = h.version + 1
    FROM osm_hole_match m
    WHERE h.id = m.db_hole_id
      AND NOT {protect}
      AND (h.teeing_ground_location IS DISTINCT FROM
             (CASE WHEN m.flipped THEN ST_EndPoint(m.geom) ELSE ST_StartPoint(m.geom) END)
           OR h.green_location IS DISTINCT FROM
             (CASE WHEN m.flipped THEN ST_StartPoint(m.geom) ELSE ST_EndPoint(m.geom) END)
           -- provenance counts too: right point, wrong source is still wrong
           OR h.source IS DISTINCT FROM 'osm:' || m.osm_ref
           OR h.playing_length_meters IS DISTINCT FROM round(m.osm_len_m::numeric, 2))
    RETURNING 1
) INSERT INTO run_report SELECT '4 hole points', 'tee/green points written from OSM', count(*) FROM upd;

-- Convergence. A hole may carry an 'osm:' source that this snapshot no longer
-- produces: the way was deleted upstream, its ref changed, or — the case that
-- actually occurred here — an earlier hand-run assigned one OSM way to two
-- different holes. Leaving those rows behind means the database keeps geometry
-- no input can explain, which is exactly the state this pipeline exists to end.
-- They go back to the synthetic clubhouse offset the seed uses, relabelled so
-- nobody mistakes them for a survey.
WITH upd AS (
    UPDATE holes h SET
        teeing_ground_location = ST_SetSRID(ST_MakePoint(
            ST_X(f.location) + h.hole_number * 0.0008,
            ST_Y(f.location) + h.hole_number * 0.0006), 4326),
        green_location = ST_SetSRID(ST_MakePoint(
            ST_X(f.location) + h.hole_number * 0.0008,
            ST_Y(f.location) + h.hole_number * 0.0006
                + COALESCE(h.playing_length_meters::double precision, 0) / 111000.0), 4326),
        source              = 'derived:facility-offset',
        publisher           = 'VSP',
        license             = 'internal-derived',
        accuracy_class      = 'D_UNVERIFIED_COMMUNITY',
        verification_status = 'UNVERIFIED',
        confidence          = 20.00,
        updated_at          = now(),
        version             = h.version + 1
    FROM courses c
    JOIN golf_facilities f ON f.id = c.facility_id
    WHERE c.id = h.course_id
      AND h.source LIKE 'osm:%'
      AND f.location IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM osm_hole_match m WHERE m.db_hole_id = h.id)
      AND NOT {protect}
    RETURNING 1
) INSERT INTO run_report
  SELECT '4 hole points', 'stale OSM holes reset (snapshot no longer matches them)', count(*) FROM upd;
"""


def sql_features() -> str:
    """Clear pipeline-owned rows, import the real OSM ones, derive the rest."""
    owned = "(source LIKE 'osm:%' OR source LIKE 'derived:%')"
    keep = "coalesce(verification_status,'') <> 'VERIFIED'"
    blocks = []

    for table in ("greens", "bunkers", "water_hazards", "fairway_segments"):
        blocks.append(f"""
INSERT INTO run_report SELECT '5 features', 'kept: human-VERIFIED {table}', count(*)
FROM {table} WHERE {owned} AND NOT ({keep});
DELETE FROM {table} WHERE {owned} AND {keep};""")

    cols = ("hole_id, location, accuracy_class, verification_status, confidence, "
            "source, publisher, license, effective_date, version, created_at, updated_at")

    def osm_import(table: str, kind: str, radius: int, extra_cols: str = "", extra_vals: str = "") -> str:
        return f"""
WITH assign AS (
    SELECT DISTINCT ON (s.osm_id) s.osm_id, s.osm_ref, s.geom, m.db_hole_id
    FROM osm_golf_staging s
    JOIN osm_hole_match m ON ST_DWithin(s.geom::geography, m.geom::geography, {radius})
    WHERE s.kind = {q(kind)} AND ST_GeometryType(s.geom) = 'ST_Polygon'
    ORDER BY s.osm_id, ST_Distance(s.geom::geography, m.geom::geography)
), ins AS (
    INSERT INTO {table} ({cols}{extra_cols})
    SELECT a.db_hole_id, a.geom, 'D_UNVERIFIED_COMMUNITY', 'PENDING_REVIEW', 55.00,
           'osm:' || a.osm_ref, {q(OSM_PUBLISHER)}, {q(OSM_LICENSE)},
           CURRENT_DATE, 1, now(), now(){extra_vals}
    FROM assign a
    WHERE NOT EXISTS (SELECT 1 FROM {table} t
                       WHERE t.hole_id = a.db_hole_id AND t.source = 'osm:' || a.osm_ref)
    RETURNING 1
) INSERT INTO run_report SELECT '5 features', 'OSM {kind} imported', count(*) FROM ins;"""

    blocks.append(osm_import("greens", "green", GREEN_ASSIGN_RADIUS_M))
    blocks.append(osm_import("bunkers", "bunker", BUNKER_ASSIGN_RADIUS_M))
    blocks.append(osm_import("water_hazards", "water_hazard", WATER_ASSIGN_RADIUS_M,
                             ", hazard_type", ", 'WATER'"))

    # Derived green: only where no real one landed. Provenance depends on where
    # the underlying point came from — an OSM-derived shape stays ODbL, a shape
    # built on a synthesised seed point is internal and stays UNVERIFIED (there
    # is nothing there for a reviewer to confirm).
    blocks.append(f"""
WITH ins AS (
    INSERT INTO greens ({cols})
    SELECT h.id,
           ST_Buffer(h.green_location::geography, {DERIVED_GREEN_RADIUS_M})::geometry,
           'D_UNVERIFIED_COMMUNITY',
           CASE WHEN m.db_hole_id IS NOT NULL THEN 'PENDING_REVIEW' ELSE 'UNVERIFIED' END,
           CASE WHEN m.db_hole_id IS NOT NULL THEN 40.00 ELSE 30.00 END,
           'derived:green-point-extent', 'VSP',
           CASE WHEN m.db_hole_id IS NOT NULL THEN {q(OSM_LICENSE)} ELSE 'internal-derived' END,
           CURRENT_DATE, 1, now(), now()
    FROM holes h
    LEFT JOIN osm_hole_match m ON m.db_hole_id = h.id
    WHERE h.green_location IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM greens g WHERE g.hole_id = h.id)
    RETURNING 1
) INSERT INTO run_report SELECT '6 derived', 'greens derived from the green point', count(*) FROM ins;

WITH ins AS (
    INSERT INTO fairway_segments ({cols})
    SELECT h.id,
           ST_Buffer(
               ST_MakeLine(h.teeing_ground_location, h.green_location)::geography,
               LEAST({FAIRWAY_WIDTH_MAX_M}, GREATEST({FAIRWAY_WIDTH_MIN_M},
                   COALESCE(h.playing_length_meters::double precision,
                            ST_Distance(h.teeing_ground_location::geography,
                                        h.green_location::geography)) * {FAIRWAY_WIDTH_FRACTION}))
           )::geometry,
           'D_UNVERIFIED_COMMUNITY',
           CASE WHEN m.db_hole_id IS NOT NULL THEN 'PENDING_REVIEW' ELSE 'UNVERIFIED' END,
           CASE WHEN m.db_hole_id IS NOT NULL THEN 45.00 ELSE 35.00 END,
           CASE WHEN m.db_hole_id IS NOT NULL THEN 'derived:osm-tee-green-corridor'
                ELSE 'derived:tee-green-corridor' END,
           'VSP',
           CASE WHEN m.db_hole_id IS NOT NULL THEN {q(OSM_LICENSE)} ELSE 'internal-derived' END,
           CURRENT_DATE, 1, now(), now()
    FROM holes h
    LEFT JOIN osm_hole_match m ON m.db_hole_id = h.id
    WHERE h.teeing_ground_location IS NOT NULL
      AND h.green_location IS NOT NULL
      AND NOT ST_Equals(h.teeing_ground_location, h.green_location)
      AND NOT EXISTS (SELECT 1 FROM fairway_segments fs WHERE fs.hole_id = h.id)
    RETURNING 1
) INSERT INTO run_report SELECT '6 derived', 'fairway corridors derived from tee->green', count(*) FROM ins;""")

    return "\n".join(blocks)


SQL_REPORT = """
\\echo ''
\\echo '── what this run changed ─────────────────────────────────────────────'
SELECT step, detail, n FROM run_report ORDER BY step, detail;

\\echo ''
\\echo '── resulting state ───────────────────────────────────────────────────'
SELECT 'golf_facilities with real OSM coords' AS metric, count(*) AS n FROM golf_facilities WHERE source LIKE 'osm:%'
UNION ALL SELECT 'holes with OSM tee/green points',   count(*) FROM holes WHERE source LIKE 'osm:%'
UNION ALL SELECT 'holes total',                       count(*) FROM holes
UNION ALL SELECT 'greens from OSM',                   count(*) FROM greens WHERE source LIKE 'osm:%'
UNION ALL SELECT 'greens derived',                    count(*) FROM greens WHERE source LIKE 'derived:%'
UNION ALL SELECT 'holes with no green at all',        count(*) FROM holes h WHERE NOT EXISTS (SELECT 1 FROM greens g WHERE g.hole_id = h.id)
UNION ALL SELECT 'bunkers from OSM',                  count(*) FROM bunkers WHERE source LIKE 'osm:%'
UNION ALL SELECT 'water hazards from OSM',            count(*) FROM water_hazards WHERE source LIKE 'osm:%'
UNION ALL SELECT 'fairway corridors derived',         count(*) FROM fairway_segments WHERE source LIKE 'derived:%'
UNION ALL SELECT 'rows claiming better than D_UNVERIFIED_COMMUNITY from this pipeline',
       (SELECT count(*) FROM greens WHERE (source LIKE 'osm:%' OR source LIKE 'derived:%') AND accuracy_class <> 'D_UNVERIFIED_COMMUNITY')
     + (SELECT count(*) FROM bunkers WHERE (source LIKE 'osm:%' OR source LIKE 'derived:%') AND accuracy_class <> 'D_UNVERIFIED_COMMUNITY')
     + (SELECT count(*) FROM water_hazards WHERE (source LIKE 'osm:%' OR source LIKE 'derived:%') AND accuracy_class <> 'D_UNVERIFIED_COMMUNITY')
     + (SELECT count(*) FROM fairway_segments WHERE (source LIKE 'osm:%' OR source LIKE 'derived:%') AND accuracy_class <> 'D_UNVERIFIED_COMMUNITY');
"""


def build_sql(snapshot_path: pathlib.Path, matches: list[dict], rows: list[tuple],
              respect_seed: bool, apply: bool) -> str:
    return "\n".join([
        f"-- Generated by tools/course-digitization/osm/build_from_osm.py",
        f"-- Snapshot: {snapshot_path.name}",
        "-- Do not hand-edit a copy of this file into the database; re-run the script.",
        "BEGIN;",
        "CREATE TEMP TABLE run_report (step text, detail text, n bigint) ON COMMIT DROP;",
        sql_staging(rows),
        f"INSERT INTO run_report VALUES ('1 staging', 'OSM features loaded', {len(rows)});",
        sql_facilities(matches, respect_seed),
        SQL_HOLE_MATCH,
        sql_hole_points(respect_seed),
        sql_features(),
        SQL_REPORT,
        "COMMIT;" if apply else "ROLLBACK;  -- dry run: re-run with --apply to keep this",
    ])


# ── entry point ──────────────────────────────────────────────────────────────
def newest_snapshot() -> pathlib.Path:
    candidates = sorted((HERE / "data").glob("osm-vietnam-golf-*.json*"))
    if not candidates:
        sys.exit("No snapshot in data/. Run fetch_osm.py first.")
    return candidates[-1]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--snapshot", type=pathlib.Path, help="default: newest in data/")
    ap.add_argument("--apply", action="store_true", help="commit (default is a dry run that rolls back)")
    ap.add_argument("--print-sql", action="store_true", help="write the SQL to stdout and stop")
    ap.add_argument("--psql", default=DEFAULT_PSQL, help=f"psql invocation (default: {DEFAULT_PSQL!r})")
    ap.add_argument("--respect-seed-verified", action="store_true",
                    help="treat the synthetic SEED rows as human-verified and leave them alone "
                         "(the pipeline then has almost nothing to do)")
    args = ap.parse_args()

    psql_cmd = shlex.split(args.psql)
    snapshot_path = args.snapshot or newest_snapshot()
    snap = load_snapshot(snapshot_path)

    print(f"snapshot     {snapshot_path.name}  (fetched {snap.get('fetched_at', 'unknown')})")

    rows, skipped = staging_rows(snap["features"])
    bounds = boundary_rows(snap["facilities"])
    rows = rows + bounds
    print(f"features     {len(rows) - len(bounds)} ways loaded, "
          f"{skipped} relations/degenerate ways skipped")
    print(f"boundaries   {len(bounds)} course outlines staged")

    osm_courses = osm_courses_from(snap["facilities"])
    db_facilities = [
        {"id": int(r[0]), "name": r[1],
         "lon": float(r[2]) if r[2] else None, "lat": float(r[3]) if r[3] else None}
        for r in query(psql_cmd,
                       "SELECT id, name, ST_X(location), ST_Y(location) FROM golf_facilities ORDER BY id;")
    ]
    print(f"facilities   {len(db_facilities)} in DB, {len(osm_courses)} named golf courses in snapshot")

    matches = match_facilities(db_facilities, osm_courses)
    print(f"name match   {len(matches)} facilities matched "
          f"(similarity >= {NAME_SIMILARITY_MIN} or word containment, "
          f"distance <= {FACILITY_MAX_DIST_M / 1000:g} km)")
    for m in sorted(matches, key=lambda m: m["facility"]["name"]):
        print(f"               {m['facility']['name'][:44]:<44} -> {m['osm']['ref']:<18} "
              f"sim {m['similarity']:.2f} via {m['how']:<5} {m['dist_m'] / 1000:.1f} km")

    sql = build_sql(snapshot_path, matches, rows, args.respect_seed_verified, args.apply)

    if args.print_sql:
        sys.stdout.write(sql)
        return

    print(f"\nrunning ({'APPLY — will commit' if args.apply else 'dry run — will roll back'})…\n")
    sys.stdout.write(run_psql(psql_cmd, sql))
    if not args.apply:
        print("\nDry run: everything above was rolled back. Re-run with --apply to keep it.")


if __name__ == "__main__":
    main()
