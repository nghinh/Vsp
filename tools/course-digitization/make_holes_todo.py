#!/usr/bin/env python3
"""Regenerate holes_todo.geojson — the work list for manual digitisation.

One feature per hole that still has no real geometry: a bounding box around its
tee->green line with 80 m of margin, plus enough identity for the tracer to know
what they are looking at and for import_digitized.py to place the result.

A hole is "outstanding" when `holes.source` is not an `osm:` reference — i.e.
its coordinates are still the synthetic clubhouse offset the seed writes, or the
fallback the OSM pipeline leaves behind when a match disappears.

Run it after every import so finished holes drop off the list:

    python3 make_holes_todo.py                 # -> holes_todo.geojson
    python3 make_holes_todo.py --out /tmp/x.geojson --psql "psql postgresql://…"

This exists because the query that first built the file lived only in a chat
session, and a work list nobody can regenerate stops being a work list the first
time it goes stale.
"""

import argparse
import json
import pathlib
import shlex
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_PSQL = "docker exec -i vsp_postgres psql -U vsp -d vsp"
MARGIN_M = 80

SQL = f"""
SELECT h.id, c.id, c.name, f.name, h.hole_number, h.par,
       COALESCE(h.playing_length_meters, 0), h.source,
       ST_XMin(box), ST_YMin(box), ST_XMax(box), ST_YMax(box),
       ST_Y(ST_Centroid(box)), ST_X(ST_Centroid(box))
FROM holes h
JOIN courses c         ON c.id = h.course_id
JOIN golf_facilities f ON f.id = c.facility_id
CROSS JOIN LATERAL (
    SELECT ST_Envelope(
        ST_Buffer(
            ST_MakeLine(h.teeing_ground_location, h.green_location)::geography,
            {MARGIN_M}
        )::geometry
    ) AS box
) b
WHERE h.source NOT LIKE 'osm:%'
  AND h.teeing_ground_location IS NOT NULL
  AND h.green_location IS NOT NULL
ORDER BY c.name, h.hole_number;
"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "holes_todo.geojson")
    ap.add_argument("--psql", default=DEFAULT_PSQL)
    args = ap.parse_args()

    proc = subprocess.run(
        shlex.split(args.psql) + ["-v", "ON_ERROR_STOP=1", "-t", "-A", "-F", "\t", "-c", SQL],
        text=True, capture_output=True,
    )
    if proc.returncode != 0:
        sys.exit(f"psql failed:\n{proc.stderr.strip()}")

    features = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        (hid, cid, course, facility, hole_no, par, length,
         source, xmin, ymin, xmax, ymax, clat, clon) = line.split("\t")
        xmin, ymin, xmax, ymax = float(xmin), float(ymin), float(xmax), float(ymax)
        features.append({
            "type": "Feature",
            "geometry": {"type": "Polygon", "coordinates": [[
                [xmin, ymin], [xmin, ymax], [xmax, ymax], [xmax, ymin], [xmin, ymin],
            ]]},
            "properties": {
                "db_hole_id": int(hid),
                "course_id": int(cid),
                "course": course,
                "facility": facility,
                "hole_number": int(hole_no),
                "par": int(par),
                "length_m": round(float(length), 1),
                "coords_source": source,
                "todo": "draw: green, fairway, bunker, water, ob",
                "centroid": f"{float(clat)},{float(clon)}",
            },
        })

    args.out.write_text(
        json.dumps({"type": "FeatureCollection", "features": features}, ensure_ascii=False) + "\n"
    )
    print(f"{len(features)} holes still to digitise -> {args.out}")


if __name__ == "__main__":
    main()
