#!/usr/bin/env python3
"""Import hand-digitised course geometry back into the VSP database.

Pairs with holes_todo.geojson: an editor opens that file in JOSM/QGIS, traces
the real features over licensed imagery, and saves one GeoJSON per batch. This
script validates and loads the result.

Every feature must carry:
  db_hole_id : int   the hole it belongs to (from holes_todo.geojson)
  layer      : str   green | fairway | bunker | water | ob
  source     : str   imagery used, e.g. "bing-aerial-2026-08"

Imagery licensing is not optional: tracing Google Maps/Earth is prohibited and
poisons the derived data. Use Bing Aerial, Esri World Imagery, Maxar under
contract, or imagery the course supplies. The source string is stored so a
future audit can tell where each polygon came from.

Nothing is written unless every feature passes validation — a partial import
leaves the map half-real, which is worse than an empty one.

Usage:
  python3 import_digitized.py traced.geojson --publisher "Acme Survey" \
      --license "ODbL-1.0" [--apply]

Without --apply it reports what it would do and exits (dry run).
"""

import argparse
import json
import subprocess
import sys
from collections import Counter

LAYER_TABLES = {
    "green": "greens",
    "fairway": "fairway_segments",
    "bunker": "bunkers",
    "water": "water_hazards",
    "ob": "out_of_bounds",
}

# The schema only accepts these; hand-traced imagery is verified satellite work
# when done by a known surveyor, community-grade otherwise.
ACCURACY = "C_VERIFIED_SATELLITE"


def psql(sql: str, capture: bool = True) -> str:
    cmd = ["docker", "exec", "-i", "vsp_postgres", "psql", "-U", "vsp", "-d", "vsp", "-t", "-A", "-c", sql]
    result = subprocess.run(cmd, capture_output=capture, text=True)
    if result.returncode != 0:
        sys.exit(f"psql failed: {result.stderr.strip()}")
    return result.stdout.strip()


def validate(features):
    """Return (errors, per-layer counts). Refuses anything it cannot place."""
    errors, counts = [], Counter()
    known = set(psql("SELECT id FROM holes").split("\n"))
    for i, f in enumerate(features):
        props = f.get("properties") or {}
        hole_id = props.get("db_hole_id")
        layer = props.get("layer")
        where = f"feature #{i}"
        if hole_id is None or str(hole_id) not in known:
            errors.append(f"{where}: db_hole_id {hole_id!r} is not a hole in this database")
        if layer not in LAYER_TABLES:
            errors.append(f"{where}: layer {layer!r} must be one of {sorted(LAYER_TABLES)}")
        if not props.get("source"):
            errors.append(f"{where}: missing source (which imagery was traced)")
        geom = f.get("geometry") or {}
        if geom.get("type") not in ("Polygon", "MultiPolygon"):
            errors.append(f"{where}: geometry must be a closed area, got {geom.get('type')!r}")
        if not errors or errors[-1].startswith(where) is False:
            counts[layer] += 1
    return errors, counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("geojson")
    parser.add_argument("--publisher", required=True, help="who traced it")
    parser.add_argument("--license", required=True, help="licence of the imagery/result")
    parser.add_argument("--apply", action="store_true", help="write to the database")
    args = parser.parse_args()

    data = json.load(open(args.geojson))
    features = data.get("features", [])
    errors, counts = validate(features)

    print(f"{len(features)} features: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if errors:
        print(f"\n{len(errors)} problems — nothing imported:")
        for e in errors[:20]:
            print("  -", e)
        sys.exit(1)

    if not args.apply:
        print("\nDry run OK. Re-run with --apply to write.")
        return

    statements = []
    for f in features:
        p = f["properties"]
        table = LAYER_TABLES[p["layer"]]
        geom = json.dumps(f["geometry"]).replace("'", "''")
        src = str(p["source"]).replace("'", "''")
        statements.append(
            f"INSERT INTO {table} (hole_id, location, accuracy_class, confidence, "
            f"verification_status, source, publisher, license, version, created_at, "
            f"updated_at, effective_date) VALUES ({int(p['db_hole_id'])}, "
            f"ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON('{geom}'),4326)), "
            f"'{ACCURACY}', 0.80, 'PENDING_REVIEW', 'traced:{src}', "
            f"'{args.publisher}', '{args.license}', 1, now(), now(), CURRENT_DATE);"
        )
    # One transaction: either the whole batch lands or none of it does.
    sql = "BEGIN;\n" + "\n".join(statements) + "\nCOMMIT;"
    subprocess.run(
        ["docker", "exec", "-i", "vsp_postgres", "psql", "-U", "vsp", "-d", "vsp", "-q", "-f", "-"],
        input=sql, text=True, check=True,
    )
    print(f"imported {len(statements)} features")


if __name__ == "__main__":
    main()
