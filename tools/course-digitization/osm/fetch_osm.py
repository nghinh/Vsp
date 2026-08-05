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

A bounding box is used rather than `area["ISO3166-1"="VN"]` because the area
lookup regularly times out (504) on the public instance. The box overhangs the
borders; that is harmless, since matching is by name similarity *and* distance.

Usage:
  python3 fetch_osm.py                       # -> data/osm-vietnam-golf-<date>.json.gz
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

DEFAULT_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]

FEATURE_KINDS = ["hole", "green", "tee", "bunker", "water_hazard", "fairway"]

USER_AGENT = "vsp-course-digitization/1.0 (Vietnam Smart Golf Platform; data pipeline)"


def facilities_query(bbox: str) -> str:
    return (
        "[out:json][timeout:180];"
        f'(way["leisure"="golf_course"]({bbox});'
        f'relation["leisure"="golf_course"]({bbox}););'
        "out center tags;"
    )


def features_query(bbox: str) -> str:
    kinds = "|".join(FEATURE_KINDS)
    return (
        "[out:json][timeout:300];"
        f'(way["golf"~"^({kinds})$"]({bbox});'
        f'relation["golf"~"^({kinds})$"]({bbox}););'
        "out geom tags;"
    )


def overpass(query: str, endpoints: list[str], attempts: int = 3) -> list[dict]:
    """POST a query, trying each endpoint in turn. Overpass 429/504 is routine."""
    body = urllib.parse.urlencode({"data": query}).encode()
    last = None
    for attempt in range(attempts):
        for endpoint in endpoints:
            req = urllib.request.Request(endpoint, data=body, headers={"User-Agent": USER_AGENT})
            try:
                with urllib.request.urlopen(req, timeout=600) as resp:
                    return json.load(resp)["elements"]
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
    ap.add_argument("--endpoint", action="append", dest="endpoints", help="Overpass URL (repeatable)")
    ap.add_argument("--out", type=pathlib.Path, default=here / "data" / f"osm-vietnam-golf-{today}.json.gz")
    args = ap.parse_args()

    endpoints = args.endpoints or DEFAULT_ENDPOINTS

    print(f"bbox {args.bbox}")
    print("fetching leisure=golf_course …")
    facilities = overpass(facilities_query(args.bbox), endpoints)
    print(f"  {len(facilities)} facilities")

    print(f"fetching golf={'|'.join(FEATURE_KINDS)} …")
    features = overpass(features_query(args.bbox), endpoints)
    print(f"  {len(features)} features")

    counts: dict[str, int] = {}
    for el in features:
        kind = (el.get("tags") or {}).get("golf", "?")
        counts[kind] = counts.get(kind, 0) + 1
    for kind in sorted(counts, key=lambda k: -counts[k]):
        print(f"    {kind:<13} {counts[kind]}")

    snapshot = {
        "fetched_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "bbox": args.bbox,
        "endpoints": endpoints,
        "queries": {
            "facilities": facilities_query(args.bbox),
            "features": features_query(args.bbox),
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
