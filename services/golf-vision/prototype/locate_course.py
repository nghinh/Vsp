"""Finding a golf course nobody has mapped.

Yên Dũng Resort has thirty-six holes across a hundred and ninety hectares of
Bắc Giang, and as far as this system is concerned it does not exist. Its holes
carry coordinates on a neat lattice — every tee and green at the same
longitude, spaced evenly — which is what a placeholder looks like when nobody
says it is one. OpenStreetMap has no course there either: the whole province
holds one driving range. Nominatim cannot geocode it. So the model was being
pointed at rice paddy and correctly finding nothing.

The way in is the district. OSM always has administrative geography even where
it has no golf, so a name that fails to geocode as a course still geocodes as
the commune it sits in, and that is a search box.

Then the model does the finding. Not by looking at the whole box — GolfSeg
wants about 0.25 m per pixel and a six-kilometre box at that scale is twenty
thousand pixels a side, which is neither downloadable nor necessary. A golf
course is a hundred hectares of a distinctive thing; it does not hide between
sample points. So this samples: a grid of patches at native scale, each one a
143 m square of ground, spaced far enough apart to cover the box cheaply and
close enough that a course cannot fall between them.

What comes back is a heat map of one number per sample — the share of pixels
the model calls fairway, green or bunker. Rice paddy scores near zero. A golf
course lights up, and the lit cells are contiguous, which is the second signal:
one bright cell is a false positive, forty adjacent bright cells is a course.

    python prototype/locate_course.py --lat 21.21 --lng 106.16 --radius-km 3.5
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

#: The classes that mean "somebody mows this for golf". Water and rough are
#: deliberately not among them: a fish pond is water and most of Vietnam is
#: rough, and both would light up the entire Red River delta.
GOLF_LABELS = {"FAIRWAY", "GREEN", "BUNKER", "TEE"}

#: How bright a cell has to be before it counts as golf at all.
GOLF_FLOOR = 0.08


def geocode(query: str) -> dict | None:
    """A place name to a box, using OSM's own geocoder.

    Asked for a course it does not have, Nominatim answers nothing — which is
    the case this whole script exists for. Asked for the commune or district
    in the same string, it answers, because administrative boundaries are the
    one thing OSM has everywhere.
    """
    url = ("https://nominatim.openstreetmap.org/search?"
           + urllib.parse.urlencode({"q": query, "format": "json", "limit": 1,
                                     "countrycodes": "vn"}))
    request = urllib.request.Request(
        url, headers={"User-Agent": "VSP-golf-locate/1.0 (vsp golf mapping)"})
    hits = json.load(urllib.request.urlopen(request, timeout=60))
    if not hits:
        return None
    hit = hits[0]
    south, north, west, east = (float(x) for x in hit["boundingbox"])
    return {"lat": float(hit["lat"]), "lng": float(hit["lon"]),
            "south": south, "north": north, "west": west, "east": east,
            "name": hit.get("display_name", "")}


def sample_grid(lat: float, lng: float, radius_km: float, step_m: int):
    """Sample centres over a square box, in metres on the ground.

    A degree of latitude is 111 km everywhere; a degree of longitude is that
    times the cosine of the latitude, which at 21°N is 104 km. Getting this
    the wrong way round stretches the grid east-west by seven per cent, which
    is not enough to notice and is enough to miss a corner.
    """
    lat_per_m = 1.0 / 111_320.0
    lng_per_m = 1.0 / (111_320.0 * math.cos(math.radians(lat)))
    reach = int(radius_km * 1000)
    for north in range(-reach, reach + 1, step_m):
        for east in range(-reach, reach + 1, step_m):
            yield (lat + north * lat_per_m, lng + east * lng_per_m)


def golfness(vision: str, key: str | None, lat: float, lng: float,
             span_m: int = 120, timeout: int = 60) -> tuple[float, dict]:
    """How much of one sample the model calls golf.

    The trace endpoint wants a hole — a tee and a green — so it is handed a
    short segment through the sample point. What comes back is the same
    vectorised answer a real hole gets; the area of it is the signal.
    """
    half = span_m / 2 / 111_320.0
    payload = {"courseId": 0, "holeNumber": 0,
               "teeLat": lat - half, "teeLng": lng,
               "greenLat": lat + half, "greenLng": lng,
               "marginDeg": 0.0004}
    request = urllib.request.Request(
        f"{vision}/trace/hole", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json",
                 "User-Agent": "VSP-golf-locate/1.0"})
    if key:
        request.add_header("Authorization", f"Bearer {key}")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as body:
            answer = json.load(body)
    except Exception:                       # noqa: BLE001
        return 0.0, {}

    by_label: dict[str, float] = {}
    for feature in answer.get("features", []):
        label = feature["properties"].get("label")
        if label in GOLF_LABELS:
            by_label[label] = by_label.get(label, 0.0) + \
                feature["properties"].get("areaM2", 0.0)
    # As a share of the ground the sample covers, so a bigger frame does not
    # score higher for being bigger.
    frame_m2 = (span_m + 90) ** 2
    return sum(by_label.values()) / frame_m2, by_label


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--place", help="a commune or district to search in, "
                                        "when there are no coordinates at all")
    parser.add_argument("--lat", type=float)
    parser.add_argument("--lng", type=float)
    parser.add_argument("--radius-km", type=float, default=3.0)
    parser.add_argument("--step-m", type=int, default=400)
    parser.add_argument("--vision", default="http://127.0.0.1:18100")
    parser.add_argument("--vision-key",
                        default=os.environ.get("GOLF_VISION_API_KEY"))
    parser.add_argument("--out", default=None, help="write the heat map here")
    args = parser.parse_args()

    lat, lng = args.lat, args.lng
    if lat is None or lng is None:
        if not args.place:
            parser.error("give --lat/--lng or --place")
        found = geocode(args.place)
        if not found:
            print(f"'{args.place}' does not geocode")
            return 1
        lat, lng = found["lat"], found["lng"]
        print(f"{args.place} → {lat:.5f},{lng:.5f}  ({found['name'][:60]})")

    points = list(sample_grid(lat, lng, args.radius_km, args.step_m))
    print(f"{len(points)} samples, {args.step_m} m apart, "
          f"{args.radius_km * 2:.1f} km across")

    scored = []
    for index, (plat, plng) in enumerate(points, 1):
        share, labels = golfness(args.vision, args.vision_key, plat, plng)
        scored.append({"lat": plat, "lng": plng, "score": share,
                       "labels": {k: round(v) for k, v in labels.items()}})
        if share >= GOLF_FLOOR:
            print(f"  [{index:4d}/{len(points)}] {plat:.5f},{plng:.5f}  "
                  f"{share:5.2f}  {labels and sorted(labels) or ''}")
        elif index % 25 == 0:
            print(f"  [{index:4d}/{len(points)}] …")

    hot = [s for s in scored if s["score"] >= GOLF_FLOOR]
    hot.sort(key=lambda s: s["score"], reverse=True)
    print(f"\n{len(hot)} of {len(scored)} samples look like golf")
    for s in hot[:10]:
        print(f"  {s['lat']:.5f},{s['lng']:.5f}  {s['score']:5.2f}  {s['labels']}")

    if hot:
        lats = [s["lat"] for s in hot]
        lngs = [s["lng"] for s in hot]
        print(f"\ncentre of the lit area: {sum(lats)/len(lats):.5f},"
              f"{sum(lngs)/len(lngs):.5f}")
        print(f"extent: {min(lats):.5f},{min(lngs):.5f} → "
              f"{max(lats):.5f},{max(lngs):.5f}")

    if args.out:
        Path(args.out).write_text(json.dumps(scored, indent=1))
        print(f"heat map → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
