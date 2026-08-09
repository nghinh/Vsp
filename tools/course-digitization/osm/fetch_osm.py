#!/usr/bin/env python3
"""Fetch Vietnam golf geometry from OpenStreetMap and write a snapshot file.

This is step 1 of two. It talks to the network; `build_from_osm.py` never does.
The split is deliberate: Overpass answers differ from day to day (the map keeps
growing), so a run that reads the live API is not reproducible. The snapshot in
`data/` is the reproducible input — it is committed, and every derived row in
the database can be traced back to it.

Two Overpass queries:

  facilities  leisure=golf_course ways/relations  -> centre point + tags
  features    golf=hole|green|tee|bunker|water_hazard|fairway -> full geometry

Both are restricted to Vietnam's boundary area rather than a bounding box —
see scope() for why the box that used to be the only option pulled in four
neighbouring countries, and why the timeout this file used to warn about does
not apply to an area named by id.

Usage:
  python3 fetch_osm.py                       # -> data/osm-vietnam-golf-<date>.json.gz
  python3 fetch_osm.py --area ''             # fall back to the old bounding box
  python3 fetch_osm.py --out /tmp/snap.json.gz --endpoint https://overpass.kumi.systems/api/interpreter

Licensing: the result is OpenStreetMap data, (c) OpenStreetMap contributors,
ODbL-1.0. Anything derived from it carries that attribution into the database
(source / publisher / license columns) — do not strip it.
"""

import argparse
import datetime as dt
import gzip
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Vietnam plus a margin: south of Cà Mau to north of Hà Giang, west of the
# Mekong border to east of the Trường Sa longitude used by the seed data.
DEFAULT_BBOX = "8.0,102.0,23.6,110.0"

# Vietnam's boundary relation (OSM 49915) as an Overpass area. Used in place of
# the box above, which spans five countries — see scope().
DEFAULT_AREA = "3600049915"

DEFAULT_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

FEATURE_KINDS = ["hole", "green", "tee", "bunker", "water_hazard", "fairway"]

USER_AGENT = "vsp-course-digitization/1.0 (Vietnam Smart Golf Platform; data pipeline)"


def scope(area_id: str | None, bbox: str) -> tuple[str, str]:
    """How to restrict a query to Vietnam: (preamble, filter).

    Prefer the country area. The bounding box that used to be the only option
    runs from 102°E to 110°E and 8°N to 23.6°N, which is most of Cambodia, the
    Lao panhandle, north-east Thailand, Hainan and southern Guangxi as well as
    Vietnam — and it showed: of the 90 named golf courses in the committed
    snapshot, 42 were in those four countries. Nothing downstream is *wrong*
    because of it (a course in Phnom Penh matches no Vietnamese facility name),
    but every one of them is a course this project will never use, sitting in a
    file that says Vietnam on the tin.

    The header warns that the area lookup times out. That is true of
    `area["ISO3166-1"="VN"]`, which makes Overpass scan tags worldwide before it
    can start. Naming the area directly — 3600049915 is Vietnam's boundary
    relation 49915, offset by the 3600000000 Overpass uses for relation-derived
    areas — skips that scan and answers in seconds.
    """
    if area_id:
        return f"area({area_id})->.vn;", "area.vn"
    return "", bbox


def facilities_query(area_id: str | None, bbox: str) -> str:
    # Two `out` statements over the same set: Overpass returns the centre on one
    # pass and the ring on the other (asking for both at once silently drops the
    # geometry). The centre is what matches a course to a seeded facility; the
    # ring is what tells the satellite pipeline where the course ends and the
    # neighbouring fish ponds begin.
    pre, where = scope(area_id, bbox)
    return (
        "[out:json][timeout:180];"
        f"{pre}"
        f'(way["leisure"="golf_course"]({where});'
        f'relation["leisure"="golf_course"]({where});)->.c;'
        ".c out center tags;"
        ".c out geom;"
    )


def merge_facility_elements(elements: list[dict]) -> list[dict]:
    """Fold the two passes back into one element per OSM object."""
    merged: dict[tuple[str, int], dict] = {}
    for el in elements:
        key = (el["type"], el["id"])
        target = merged.setdefault(key, {"type": el["type"], "id": el["id"]})
        for field in ("tags", "center", "geometry", "members", "bounds"):
            if field in el:
                target[field] = el[field]
    return list(merged.values())


def features_query(area_id: str | None, bbox: str) -> str:
    kinds = "|".join(FEATURE_KINDS)
    pre, where = scope(area_id, bbox)
    return (
        "[out:json][timeout:300];"
        f"{pre}"
        f'(way["golf"~"^({kinds})$"]({where});'
        f'relation["golf"~"^({kinds})$"]({where}););'
        "out geom tags;"
    )


def overpass(query: str, endpoints: list[str], attempts: int = 3) -> tuple[list[dict], str, str]:
    """POST a query, trying each endpoint in turn. Overpass 429/504 is routine.

    Returns (elements, endpoint, osm_base_timestamp). That timestamp matters:
    the public mirrors replicate independently and one of them was three months
    behind the other on the day this was written, answering the identical query
    with 13% fewer bunkers and no error of any kind. A snapshot half-filled from
    each would be quietly, undetectably wrong.
    """
    body = urllib.parse.urlencode({"data": query}).encode()
    last = None
    for attempt in range(attempts):
        for endpoint in endpoints:
            req = urllib.request.Request(endpoint, data=body, headers={"User-Agent": USER_AGENT})
            try:
                with urllib.request.urlopen(req, timeout=600) as resp:
                    payload = json.load(resp)
                base = payload.get("osm3s", {}).get("timestamp_osm_base", "unknown")
                return payload["elements"], endpoint, base
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                last = f"{endpoint}: {exc}"
                print(f"  ! {last}", file=sys.stderr)
        if attempt + 1 < attempts:
            wait = 15 * (attempt + 1)
            print(f"  … retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)
    sys.exit(f"Overpass unreachable after {attempts} attempts. Last error: {last}")


def main() -> None:
    here = pathlib.Path(__file__).resolve().parent
    today = dt.date.today().isoformat()

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bbox", default=DEFAULT_BBOX, help=f"south,west,north,east (default {DEFAULT_BBOX})")
    ap.add_argument(
        "--area",
        default=DEFAULT_AREA,
        help=f"Overpass area id to restrict to (default {DEFAULT_AREA} = Vietnam). "
             "Pass --area '' to fall back to --bbox.",
    )
    ap.add_argument("--endpoint", action="append", dest="endpoints", help="Overpass URL (repeatable)")
    ap.add_argument("--out", type=pathlib.Path, default=here / "data" / f"osm-vietnam-golf-{today}.json.gz")
    args = ap.parse_args()

    endpoints = args.endpoints or DEFAULT_ENDPOINTS

    print("scope " + (f"area {args.area}" if args.area else f"bbox {args.bbox}"))
    print("fetching leisure=golf_course …")
    raw, endpoint, base_a = overpass(facilities_query(args.area, args.bbox), endpoints)
    facilities = merge_facility_elements(raw)
    with_ring = sum(1 for f in facilities if f.get("geometry"))
    print(f"  {len(facilities)} facilities ({with_ring} with a boundary ring)"
          f"  [{endpoint.split('/')[2]}, OSM base {base_a}]")

    # Same server for the second query, so both halves see the same map.
    print(f"fetching golf={'|'.join(FEATURE_KINDS)} …")
    features, endpoint_b, base_b = overpass(features_query(args.area, args.bbox), [endpoint] + endpoints)
    print(f"  {len(features)} features  [{endpoint_b.split('/')[2]}, OSM base {base_b}]")

    if base_a != base_b:
        sys.exit(f"Refusing to write a mixed snapshot: facilities are from {base_a} "
                 f"({endpoint}) but features are from {base_b} ({endpoint_b}). "
                 "Re-run; the mirrors replicate independently.")

    counts: dict[str, int] = {}
    for el in features:
        kind = (el.get("tags") or {}).get("golf", "?")
        counts[kind] = counts.get(kind, 0) + 1
    for kind in sorted(counts, key=lambda k: -counts[k]):
        print(f"    {kind:<13} {counts[kind]}")

    snapshot = {
        "fetched_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "osm_base": base_a,          # the map state this snapshot describes
        "endpoint": endpoint,
        "bbox": args.bbox,
        "area": args.area,
        "endpoints": endpoints,
        "queries": {
            "facilities": facilities_query(args.area, args.bbox),
            "features": features_query(args.area, args.bbox),
        },
        "attribution": {
            "source_prefix": "osm:",
            "publisher": "OpenStreetMap contributors",
            "license": "ODbL-1.0",
        },
        "facilities": facilities,
        "features": features,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(snapshot, separators=(",", ":"), ensure_ascii=False).encode()
    if args.out.suffix == ".gz":
        args.out.write_bytes(gzip.compress(payload, 9))
    else:
        args.out.write_bytes(payload)
    print(f"wrote {args.out} ({args.out.stat().st_size / 1024:.0f} KiB)")


if __name__ == "__main__":
    main()
