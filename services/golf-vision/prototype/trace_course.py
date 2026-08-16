"""Trace a whole course, hole by hole, and file the result.

The orchestration the network topology forced and the architecture wanted
anyway. The API runs on a private network; the GPU is on a public host; they
cannot reach each other. Tracing is a batch job rather than something on a
request path, so this runs where both are reachable — a laptop, a CI box —
reads each hole's coordinates from the API, asks the vision service for the
geometry, and posts what comes back to the ingest endpoint.

Nothing about it is specific to GolfSeg. Anything that answers with a GeoJSON
FeatureCollection for a hole goes through the same door and is judged by the
same rules: the confidence floor, the area bounds golf actually has, and a
place below anything a person drew.

    python prototype/trace_course.py --course 1351 \
        --api https://vps-api.vnteki.com --vision http://127.0.0.1:18100
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request


def _request(url: str, token: str | None = None, payload: dict | None = None,
             timeout: int = 300):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    request.add_header("User-Agent", "VSP-golf-vision/0.1")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=timeout) as body:
        raw = body.read()
        return json.loads(raw) if raw else {}


def login(api: str, identifier: str, password: str) -> str:
    return _request(f"{api}/auth/login",
                    payload={"identifier": identifier, "password": password}
                    )["accessToken"]


def _point_of(wkb_hex: str) -> tuple[float, float] | None:
    """Longitude and latitude out of a PostGIS EWKB point.

    The admin API hands geography columns back exactly as Postgres stores
    them — `0101000020E6100000...` — so this decodes rather than asks for a
    format nobody offers. Little-endian point, SRID flag set, two doubles.
    """
    import struct
    try:
        raw = bytes.fromhex(wkb_hex)
    except (ValueError, TypeError):
        return None
    if len(raw) < 21:
        return None
    little = raw[0] == 1
    order = "<" if little else ">"
    type_and_flags = struct.unpack(order + "I", raw[1:5])[0]
    offset = 9 if type_and_flags & 0x20000000 else 5   # skip SRID when present
    if len(raw) < offset + 16:
        return None
    lng, lat = struct.unpack(order + "dd", raw[offset:offset + 16])
    return lng, lat


def holes_of(api: str, token: str, course_id: int) -> list[dict]:
    """Every hole with both coordinates — the rest cannot be framed.

    Read from the admin endpoint: the public course detail deliberately does
    not publish where the tees and greens are.
    """
    rows = _request(f"{api}/admin/courses/{course_id}/holes", token)
    if isinstance(rows, dict):
        rows = rows.get("content") or rows.get("holes") or []

    holes = []
    for hole in rows:
        tee = _point_of(hole.get("teeingGroundLocation") or "")
        green = _point_of(hole.get("greenLocation") or "")
        if tee is None or green is None:
            continue
        holes.append({
            "holeNumber": hole["holeNumber"],
            "teeLat": tee[1], "teeLng": tee[0],
            "greenLat": green[1], "greenLng": green[0],
        })
    return holes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--course", type=int, required=True)
    parser.add_argument("--api", default="https://vps-api.vnteki.com")
    parser.add_argument("--vision", default="http://127.0.0.1:18100")
    parser.add_argument("--vision-key", default=os.environ.get("GOLF_VISION_API_KEY"),
                        help="the vision service's shared secret. Defaults to "
                             "GOLF_VISION_API_KEY in the environment, so it "
                             "need not appear in a shell history or a process "
                             "listing. The service refuses every trace without "
                             "it, and refuses every trace when it is unset on "
                             "the server too — an unauthenticated model "
                             "endpoint on the open internet is not a default "
                             "anyone should be able to fall into.")
    parser.add_argument("--identifier", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--holes", nargs="*", type=int,
                        help="hole numbers; default is every hole with coordinates")
    parser.add_argument("--dry-run", action="store_true",
                        help="trace and report, but file nothing")
    args = parser.parse_args()

    token = login(args.api, args.identifier, args.password)
    holes = holes_of(args.api, token, args.course)
    if args.holes:
        holes = [h for h in holes if h["holeNumber"] in args.holes]
    if not holes:
        print("no holes with coordinates on this course")
        return 1

    print(f"course {args.course}: {len(holes)} hole(s) with coordinates")
    total: dict[str, int] = {}
    for hole in sorted(holes, key=lambda h: h["holeNumber"]):
        number = hole["holeNumber"]
        started = time.time()
        try:
            traced = _request(f"{args.vision}/trace/hole",
                              token=args.vision_key,
                              payload={"courseId": args.course, **hole})
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"  hole {number:2d}  vision service: {error}")
            continue

        found = len(traced.get("features", []))
        if args.dry_run:
            print(f"  hole {number:2d}  {found:3d} traced  "
                  f"({time.time() - started:.1f}s)  [dry run]")
            continue

        try:
            filed = _request(
                f"{args.api}/admin/courses/{args.course}/holes/{number}"
                f"/geometry/ingest", token, traced)["filed"]
        except urllib.error.HTTPError as error:
            print(f"  hole {number:2d}  ingest refused: "
                  f"{error.code} {error.read()[:120].decode(errors='replace')}")
            continue

        for layer, count in filed.items():
            total[layer] = total.get(layer, 0) + count
        kept = sum(filed.values())
        # Traced against filed is the interesting number: the gap is what the
        # area bounds and the confidence floor threw out, which on the first
        # live run was most of it.
        print(f"  hole {number:2d}  {found:3d} traced → {kept:3d} filed  "
              f"{filed}  ({time.time() - started:.1f}s)")

    print(f"\nfiled in total: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
