"""Every mapped US golf course, from Geofabrik extracts instead of Overpass.

The Overpass discoverer found 220 complete courses and was the right tool for
finding them politely. It is the wrong tool for finding two thousand: measured
on this box it settles at roughly 24 courses an hour, because every course is
two rate-limited queries against a shared public server, and the corpus this
project now wants would take two days of asking nicely.

A Geofabrik state extract is the same OpenStreetMap data as a single file.
One download per state, every course in that state in one local pass, no
server to be polite to. The output is byte-compatible with the Overpass
discoverer — same index.json, same courses/*.geojson, same REQUIRED gate —
so `build_naip_dataset.py` cannot tell which road the courses arrived by.

Differences that are improvements, not accidents:

* Multipolygon courses and features arrive assembled (pyosmium's area
  handler), so a course drawn as a relation — most big ones are — keeps its
  shape instead of being skipped.
* Features are matched to a course by geometry against the course's bounding
  box, exactly as the Overpass version's per-box query did, including the
  property that two courses sharing a photograph both keep the shared
  features. The mask must label every green in the frame, whoever owns it.

    python datasets/discover_from_pbf.py --out data/osm-us-large \
        --pbf-dir data/pbf --limit 2000
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.masks.labels import LAYER_TO_INDEX, bounds_of   # noqa: E402
from datasets.discover_osm_courses import (                     # noqa: E402
    GOLF_TAGS, NATURAL_WATER, REQUIRED, STATES, completeness,
    is_complete_enough)

#: ISO code → Geofabrik slug, for the states the Overpass discoverer ranked.
#: Same order, same reasoning: warm-season turf first, because that is what
#: Vietnamese golf looks like.
GEOFABRIK = {
    "US-FL": "florida", "US-SC": "south-carolina", "US-GA": "georgia",
    "US-TX": "texas", "US-AL": "alabama", "US-LA": "louisiana",
    "US-MS": "mississippi", "US-NC": "north-carolina",
    "US-CA": "california", "US-AZ": "arizona", "US-TN": "tennessee",
    "US-VA": "virginia", "US-AR": "arkansas", "US-OK": "oklahoma",
    "US-NV": "nevada", "US-KY": "kentucky", "US-MD": "maryland",
    "US-NJ": "new-jersey", "US-NY": "new-york", "US-PA": "pennsylvania",
    "US-OH": "ohio", "US-MI": "michigan", "US-IL": "illinois",
    "US-WI": "wisconsin", "US-MN": "minnesota", "US-MA": "massachusetts",
    "US-CO": "colorado", "US-WA": "washington",
    # Small states, kept for smoke tests and completeness.
    "US-DE": "delaware", "US-RI": "rhode-island",
}

MIRROR = "https://download.geofabrik.de/north-america/us"


def fetch_pbf(state: str, pbf_dir: Path) -> Path:
    slug = GEOFABRIK[state]
    target = pbf_dir / f"{slug}-latest.osm.pbf"
    if target.exists() and target.stat().st_size > 1_000_000:
        return target
    url = f"{MIRROR}/{slug}-latest.osm.pbf"
    print(f"  fetching {url}")
    partial = target.with_suffix(".part")
    with urllib.request.urlopen(url, timeout=600) as answer:
        partial.write_bytes(answer.read())
    partial.rename(target)
    return target


def layer_of(tags: dict) -> str | None:
    golf = tags.get("golf")
    if golf in GOLF_TAGS:
        return GOLF_TAGS[golf]
    if golf is not None:
        return None
    if tags.get("natural") in NATURAL_WATER:
        return "WATER_HAZARD"
    return None


def collect_state(pbf: Path) -> tuple[list[dict], list[dict]]:
    """One pass over a state: every course boundary, every golf surface.

    pyosmium hands areas — closed ways and assembled multipolygon relations —
    through a single callback, tags intact. Everything golf gets kept as
    GeoJSON; the join to courses happens afterwards, in memory, where there
    is no server to throttle it. osmium is imported here rather than at the
    top so the module stays importable on machines that only run its tests.
    """
    import osmium

    factory = osmium.geom.GeoJSONFactory()
    courses: list[dict] = []
    features: list[dict] = []

    class Collector(osmium.SimpleHandler):
        def area(self, a) -> None:
            tags = {t.k: t.v for t in a.tags}
            layer = layer_of(tags)
            is_course = tags.get("leisure") == "golf_course"
            if layer is None and not is_course:
                return
            try:
                geometry = json.loads(factory.create_multipolygon(a))
            except (RuntimeError, ValueError):
                return   # a broken multipolygon in OSM stays OSM's problem

            entry = {
                "geometry": geometry,
                "tags": tags,
                "osmId": a.orig_id(),
                "osmType": "way" if a.from_way() else "relation",
            }
            if is_course:
                courses.append(entry)
            if layer is not None:
                features.append({**entry, "layer": layer})

    Collector().apply_file(str(pbf), locations=True)
    return courses, features


def geometry_bounds(geometry: dict) -> tuple[float, float, float, float]:
    lngs, lats = [], []
    polygons = (geometry["coordinates"]
                if geometry["type"] == "MultiPolygon"
                else [geometry["coordinates"]])
    for polygon in polygons:
        for lng, lat in polygon[0]:
            lngs.append(lng)
            lats.append(lat)
    return min(lats), min(lngs), max(lats), max(lngs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="data/osm-us-large")
    parser.add_argument("--pbf-dir", default="data/pbf")
    parser.add_argument("--limit", type=int, default=2000)
    parser.add_argument("--per-state", type=int, default=200)
    parser.add_argument("--states", nargs="*", default=None)
    args = parser.parse_args()

    out = Path(args.out)
    (out / "courses").mkdir(parents=True, exist_ok=True)
    pbf_dir = Path(args.pbf_dir)
    pbf_dir.mkdir(parents=True, exist_ok=True)

    index_path = out / "index.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {
        "source": "OpenStreetMap via Geofabrik extracts",
        "license": "ODbL 1.0 — © OpenStreetMap contributors",
        "required": REQUIRED, "courses": [],
    }
    seen = {(c["osmType"], c["osmId"]) for c in index["courses"]}
    kept = len(index["courses"])

    for state in (args.states or list(GEOFABRIK)):
        if kept >= args.limit:
            break
        try:
            pbf = fetch_pbf(state, pbf_dir)
        except Exception as error:      # noqa: BLE001
            print(f"! {state}: {error}")
            continue

        courses, features = collect_state(pbf)
        print(f"{state}: {len(courses)} courses drawn, "
              f"{len(features)} golf surfaces")

        # The join. Feature bounds once, course bounds once, then a plain
        # sweep — thousands by thousands is small enough not to need a tree.
        feature_boxes = [(geometry_bounds(f["geometry"]), f) for f in features]

        in_state = 0
        for course in sorted(
                courses,
                key=lambda c: c["tags"].get("name") or f"~{c['osmId']}"):
            if kept >= args.limit or in_state >= args.per_state:
                break
            key = (course["osmType"], course["osmId"])
            if key in seen:
                continue
            seen.add(key)

            south, west, north, east = geometry_bounds(course["geometry"])
            # A golf course is a few kilometres across at the outside. A
            # boundary bigger than ~6 km on a side is a resort drawn around
            # its whole town, a relation error, or a coastline — and at zoom
            # 19 it would be a frame the builder refuses anyway. Skipped here,
            # where it costs a line, not a fetch.
            if (north - south) > 0.055 or (east - west) > 0.06:
                continue
            # A feature belongs to this course if it overlaps the course's box
            # AND fits inside it, give or take a margin. The overlap test
            # alone is what the Overpass version ran — and there it was safe,
            # because that version only kept small closed ways. Assembled
            # multipolygons include the Intracoastal Waterway, tagged
            # natural=water and 180 km long: it overlaps every coastal course
            # in Florida, and one such feature in the list blows the course's
            # frame up to 235,520 by 664,320 pixels, which the NAIP builder
            # then rightly refuses. A pond that is a course's own is at most
            # course-sized; a feature bigger than the course it decorates is
            # scenery, not a hazard.
            margin_lat = (north - south) * 0.25
            margin_lng = (east - west) * 0.25
            inside = [
                {
                    "type": "Feature",
                    "geometry": f["geometry"],
                    "properties": {
                        "layerType": f["layer"],
                        "osmId": f["osmId"],
                        "osmType": f["osmType"],
                        "name": f["tags"].get("name"),
                    },
                }
                for (fs, fw, fn, fe), f in feature_boxes
                if fs <= north and fn >= south and fw <= east and fe >= west
                and fs >= south - margin_lat and fn <= north + margin_lat
                and fw >= west - margin_lng and fe <= east + margin_lng
            ]
            counts = completeness(inside)
            if not is_complete_enough(counts):
                continue
            box = bounds_of(inside)
            if box is None:
                continue

            cache = out / "courses" / f"{course['osmType']}-{course['osmId']}.geojson"
            cache.write_text(json.dumps(
                {"type": "FeatureCollection", "features": inside}))
            index["courses"].append({
                "osmType": course["osmType"],
                "osmId": course["osmId"],
                "state": state,
                "name": (course["tags"].get("name")
                         or f"{course['osmType']}/{course['osmId']}"),
                "south": box[0], "west": box[1],
                "north": box[2], "east": box[3],
                "features": len(inside),
                "counts": counts,
                "classes": sorted(
                    layer for layer in counts if layer in LAYER_TO_INDEX),
                "file": cache.name,
            })
            kept += 1
            in_state += 1
            print(f"  + {index['courses'][-1]['name'][:38]:38s} "
                  f"green {counts.get('GREEN', 0):3d} bunker "
                  f"{counts.get('BUNKER', 0):3d}  [{kept}]")

        index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False))

    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False))
    print(f"\n{kept} complete courses -> {index_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
