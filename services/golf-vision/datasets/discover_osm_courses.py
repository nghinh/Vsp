"""Finding the courses somebody already drew, in the country NAIP flies.

OpenStreetMap holds 333 406 greens, 712 541 bunkers, 314 677 fairways and
679 144 tees worldwide — counted from taginfo, not estimated. This project's
training corpus is 36 Vietnamese courses. The gap is the whole argument.

What this does is pick the courses worth asking NAIP for. Two filters, and the
second is the one that matters:

* **In the United States**, because that is where public-domain 0.6 m imagery
  exists. Not a judgement about where golf is; a judgement about where a
  photograph can legally be fed to a model whose weights are going to ship.

* **Mapped completely enough to teach something.** A course with six greens
  drawn and no bunkers is worse than no course at all: the loss would see sand
  labelled background eighteen times per hole. The mask builder handles this
  by marking unmapped classes `ignore`, but a course that is mostly `ignore` is
  mostly wasted bandwidth, so it is cheaper to not fetch it.

The state list is not alphabetical and not a sample of American golf. It is
ordered by how much a course there looks like a course in Vietnam. Florida,
the Carolinas, Georgia, Texas and the Gulf states are warm-season turf —
bermuda, zoysia, paspalum — flat, wet, with sand that is the colour Vietnamese
sand is. Michigan and Oregon are bentgrass under conifers on glacial hills.
Both are golf; only one of them is the domain this model has to work in. The
northern states are in the list, low down, because a model that has only ever
seen one climate finds a way to depend on it.

    python datasets/discover_osm_courses.py --out data/osm-us --limit 400
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.masks.labels import LAYER_TO_INDEX, bounds_of   # noqa: E402

#: Mirrors, tried in order. The main instance at overpass-api.de is the one
#: everybody points at and it answers a discovery run of this shape mostly with
#: 429s; kumi.systems is a volunteer mirror with far more headroom. Both serve
#: the same planet, so which one answers is a question of politeness and
#: throughput rather than of data.
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

#: States, warmest and most Vietnam-like first. See the module docstring.
STATES = [
    "US-FL", "US-SC", "US-GA", "US-TX", "US-AL", "US-LA", "US-MS",
    "US-NC", "US-CA", "US-AZ", "US-TN", "US-VA", "US-AR", "US-OK",
    "US-NV", "US-KY", "US-MD", "US-NJ", "US-NY", "US-PA", "US-OH",
    "US-MI", "US-IL", "US-WI", "US-MN", "US-MA", "US-CO", "US-WA",
]

#: What a course must have drawn before it is worth an image. A green and a
#: bunker are the two classes this model is judged on; a fairway and a tee are
#: what put them in context.
REQUIRED = {"GREEN": 6, "BUNKER": 4, "FAIRWAY": 3, "TEE": 3}

#: OSM tag → the app's layer vocabulary, so a US course and a Vietnamese one
#: rasterise through exactly the same code path.
GOLF_TAGS = {
    "green": "GREEN",
    "bunker": "BUNKER",
    "fairway": "FAIRWAY",
    "tee": "TEE",
    "rough": "ROUGH",
    "water_hazard": "WATER_HAZARD",
    "lateral_water_hazard": "WATER_HAZARD",
    "cartpath": "CART_PATH",
    "path": "CART_PATH",
    "cart_path": "CART_PATH",
}

#: A pond on a course is tagged natural=water far more often than it is tagged
#: with the golf schema — 65 of Long Biên's 68 are. Ignoring that would teach
#: the model that water is rare on a golf course, which is the opposite of true.
NATURAL_WATER = {"water", "pond"}


class Overpass:
    """A polite client. Overpass is free, shared, and easy to get banned from."""

    def __init__(self, pause: float = 1.5, retries: int = 4,
                 endpoints: list[str] | None = None):
        self.pause = pause
        self.retries = retries
        self.endpoints = endpoints or ENDPOINTS
        self._last = 0.0

    def __call__(self, query: str) -> dict:
        for attempt in range(self.retries):
            self._wait()
            endpoint = self.endpoints[attempt % len(self.endpoints)]
            try:
                request = urllib.request.Request(
                    endpoint,
                    data=urllib.parse.urlencode({"data": query}).encode(),
                    headers={"User-Agent": "VSP-golfseg-discovery/1.0 "
                                           "(vsp golf mapping; ODbL)"})
                with urllib.request.urlopen(request, timeout=240) as body:
                    return json.load(body)
            except urllib.error.HTTPError as error:
                if error.code in (429, 504) and attempt < self.retries - 1:
                    # Overpass says slow down by refusing. Believe it.
                    backoff = self.pause * (2 ** (attempt + 1))
                    print(f"  overpass {error.code}, waiting {backoff:.0f}s")
                    time.sleep(backoff)
                    continue
                raise
            except (urllib.error.URLError, TimeoutError) as error:
                if attempt < self.retries - 1:
                    time.sleep(self.pause * (2 ** (attempt + 1)))
                    continue
                raise RuntimeError(f"overpass unreachable: {error}") from error
        raise RuntimeError("overpass: out of retries")

    def _wait(self) -> None:
        elapsed = time.monotonic() - self._last
        if elapsed < self.pause:
            time.sleep(self.pause - elapsed)
        self._last = time.monotonic()


def courses_in(state: str, api: Overpass) -> list[dict]:
    """Every golf course in a state, as id + bounding box + name.

    `out bb` rather than `out geom`: the extent is all that is needed to ask
    for the features, and a state's worth of course outlines is tens of
    megabytes of coordinates nobody reads.
    """
    answer = api(f"""
        [out:json][timeout:240];
        area["ISO3166-2"="{state}"]["admin_level"="4"]->.state;
        (
          way["leisure"="golf_course"](area.state);
          relation["leisure"="golf_course"](area.state);
        );
        out bb tags;
    """)
    courses = []
    for element in answer.get("elements", []):
        box = element.get("bounds")
        if not box:
            continue
        courses.append({
            "osmType": element["type"],
            "osmId": element["id"],
            "state": state,
            "name": (element.get("tags", {}).get("name")
                     or f"{element['type']}/{element['id']}"),
            "south": box["minlat"], "west": box["minlon"],
            "north": box["maxlat"], "east": box["maxlon"],
        })
    return courses


def green_centres_in(state: str, api: Overpass) -> list[tuple[float, float]]:
    """Every green in a state, as a point. One query, and it saves hundreds.

    The first version of this asked Overpass for the features of every golf
    course in a state and then threw away the four in five that turned out to
    be a name, a car park and no polygons at all. Florida has about fourteen
    hundred courses tagged; at the rate a shared Overpass will answer, that is
    an hour of queries to keep two hundred of them.

    A green is the cheapest possible test for "somebody actually mapped this".
    `out ids center` returns a point per green and nothing else — a state fits
    in a couple of hundred kilobytes — and counting how many fall inside a
    course's box is arithmetic, not bandwidth. Only the courses that pass get
    the expensive query.
    """
    answer = api(f"""
        [out:json][timeout:240];
        area["ISO3166-2"="{state}"]["admin_level"="4"]->.state;
        way["golf"="green"](area.state);
        out ids center;
    """)
    points = []
    for element in answer.get("elements", []):
        centre = element.get("center")
        if centre:
            points.append((centre["lat"], centre["lon"]))
    return points


def greens_inside(course: dict, centres: list[tuple[float, float]]) -> int:
    return sum(1 for lat, lon in centres
               if course["south"] <= lat <= course["north"]
               and course["west"] <= lon <= course["east"])


def features_of(course: dict, api: Overpass) -> list[dict]:
    """Every golf feature inside a course's box, as app-shaped GeoJSON.

    The box, not the course polygon: two courses that share a clubhouse
    overlap, and a green belonging to the neighbouring eighteen is still a
    green on this photograph. Labelling it is right; excluding it would paint
    it background.
    """
    south, west = course["south"], course["west"]
    north, east = course["north"], course["east"]
    answer = api(f"""
        [out:json][timeout:240];
        (
          way["golf"]({south},{west},{north},{east});
          way["natural"~"^(water|pond)$"]({south},{west},{north},{east});
          relation["golf"]({south},{west},{north},{east});
        );
        out geom;
    """)

    features: list[dict] = []
    for element in answer.get("elements", []):
        layer = _layer_of(element.get("tags", {}))
        if layer is None:
            continue
        geometry = _geometry_of(element)
        if geometry is None:
            continue
        features.append({
            "type": "Feature",
            "geometry": geometry,
            "properties": {
                "layerType": layer,
                "osmId": element["id"],
                "osmType": element["type"],
                "name": element.get("tags", {}).get("name"),
            },
        })
    return features


def _layer_of(tags: dict) -> str | None:
    golf = tags.get("golf")
    if golf in GOLF_TAGS:
        return GOLF_TAGS[golf]
    if golf is not None:
        return None         # clubhouse, driving_range, hole — not a surface
    if tags.get("natural") in NATURAL_WATER:
        return "WATER_HAZARD"
    return None


def _geometry_of(element: dict) -> dict | None:
    """A closed way becomes a polygon; anything else is dropped.

    Cart paths are the one open way worth keeping elsewhere in this codebase,
    and they are dropped here on purpose: the mask is painted by filling
    polygons, and a line has no inside to fill. A path buffered to a ribbon
    would be a different feature with a made-up width.
    """
    geometry = element.get("geometry")
    if not geometry or len(geometry) < 4:
        return None
    ring = [[point["lon"], point["lat"]] for point in geometry]
    if ring[0] != ring[-1]:
        return None
    return {"type": "Polygon", "coordinates": [ring]}


def completeness(features: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for feature in features:
        layer = feature["properties"]["layerType"]
        counts[layer] = counts.get(layer, 0) + 1
    return counts


def is_complete_enough(counts: dict[str, int]) -> bool:
    return all(counts.get(layer, 0) >= minimum
               for layer, minimum in REQUIRED.items())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="data/osm-us")
    parser.add_argument("--limit", type=int, default=400,
                        help="stop once this many complete courses are found")
    parser.add_argument("--per-state", type=int, default=60,
                        help="cap per state, so one big state cannot be the "
                             "whole corpus")
    parser.add_argument("--states", nargs="*", default=None)
    parser.add_argument("--pause", type=float, default=1.5)
    args = parser.parse_args()

    out = Path(args.out)
    (out / "courses").mkdir(parents=True, exist_ok=True)
    api = Overpass(pause=args.pause)

    index_path = out / "index.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {
        "source": "OpenStreetMap via Overpass",
        "license": "ODbL 1.0 — © OpenStreetMap contributors",
        "required": REQUIRED, "courses": [],
    }
    seen = {(c["osmType"], c["osmId"]) for c in index["courses"]}
    kept = len(index["courses"])

    for state in (args.states or STATES):
        if kept >= args.limit:
            break
        try:
            candidates = courses_in(state, api)
        except Exception as error:      # noqa: BLE001
            print(f"! {state}: {error}")
            continue
        try:
            centres = green_centres_in(state, api)
        except Exception as error:      # noqa: BLE001
            print(f"! {state} greens: {error}")
            continue
        # Cheap first: a course whose box holds fewer greens than the corpus
        # requires cannot pass the full test, so it never costs a query.
        candidates = [c for c in candidates
                      if greens_inside(c, centres) >= REQUIRED["GREEN"]]
        candidates.sort(key=lambda c: greens_inside(c, centres), reverse=True)
        print(f"{state}: {len(centres)} greens mapped, "
              f"{len(candidates)} courses worth asking about")

        in_state = 0
        for course in candidates:
            if kept >= args.limit or in_state >= args.per_state:
                break
            key = (course["osmType"], course["osmId"])
            if key in seen:
                continue
            seen.add(key)

            cache = out / "courses" / f"{course['osmType']}-{course['osmId']}.geojson"
            if cache.exists():
                features = json.loads(cache.read_text())["features"]
            else:
                try:
                    features = features_of(course, api)
                except Exception as error:      # noqa: BLE001
                    print(f"  ! {course['name'][:40]}: {error}")
                    continue

            counts = completeness(features)
            if not is_complete_enough(counts):
                continue

            box = bounds_of(features)
            if box is None:
                continue

            cache.write_text(json.dumps(
                {"type": "FeatureCollection", "features": features}))
            index["courses"].append({
                **course,
                "south": box[0], "west": box[1], "north": box[2], "east": box[3],
                "features": len(features),
                "counts": counts,
                "classes": sorted(
                    layer for layer in counts if layer in LAYER_TO_INDEX),
                "file": cache.name,
            })
            kept += 1
            in_state += 1
            print(f"  + {course['name'][:38]:38s} "
                  f"green {counts.get('GREEN', 0):3d} bunker "
                  f"{counts.get('BUNKER', 0):3d} water "
                  f"{counts.get('WATER_HAZARD', 0):3d}  [{kept}]")

            index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False))

    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False))
    print(f"\n{kept} complete courses -> {index_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
