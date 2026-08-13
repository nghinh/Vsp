#!/usr/bin/env python3
"""Pull per-hole tee and green coordinates out of mscorecard's map editor.

    PHPSESSID=xxxxxxxx python3 mscorecard_coordinates.py

Writes vn_coordinates.json, updated after every course, and skips what it
already has when re-run.

Twenty-five seconds a page, and it skips the pairings — "Dai Lai A + B" holds
the same eighteen holes as "Dai Lai A" and "Dai Lai B" between them, so there
is nothing there to fetch twice. That takes the run from 148 pages to 106,
which matters: the two blocks so far both landed around the 150th page, and the
scorecard run of 71 pages at twenty seconds got through untouched. Fewer
requests is a better defence than a longer wait between them.

FIRST RUN — read this
---------------------
Run it with INSPECT=1 first, on one course:

    INSPECT=1 PHPSESSID=xxxxxxxx python3 mscorecard_coordinates.py

That fetches a single coordinates page, prints what it managed to find and a
short sample of the surrounding markup, and writes nothing. Send that output
back. The page was never visible from the machine this was written on — it is
IP-blocked there — so the extraction below is written against a screenshot and
may be reading the wrong shape. Better to find that out on one page than after
a hundred.

WHAT IT LOOKS FOR
-----------------
The editor shows five points per hole — green front, green middle, green back,
front tee, back tee — each as a lat/lon pair in a labelled input. "Show all
holes" implies every hole's points are already in the page rather than fetched
per hole, so this tries the whole-page data first and falls back to walking the
holes one at a time.

WHY THIS MATTERS
----------------
Every hole in the platform still has invented geometry: the tee is the
clubhouse point pushed along a fixed diagonal and the green is that tee pushed
due north. Distances shown to a golfer are computed from those. Real tee and
green points are the one thing that replaces them, and no other source has
published any.
"""

import html
import json
import os
import random
import re
import sys
import time
import urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0 Safari/537.36")
BASE = "https://www.mscorecard.com/mscorecard"
OUT = os.environ.get("OUT", "vn_coordinates.json")
DELAY = float(os.environ.get("DELAY", "25.0"))
SESSION = os.environ.get("PHPSESSID", "")
INSPECT = os.environ.get("INSPECT", "")


class Blocked(Exception):
    pass


def get(path):
    req = urllib.request.Request(BASE + path, headers={
        "User-Agent": UA,
        "Cookie": f"PHPSESSID={SESSION}",
        "Referer": BASE + "/courses.php",
    })
    with urllib.request.urlopen(req, timeout=40) as r:
        body = r.read().decode("utf-8", "replace")
    if "access has been blocked" in body:
        raise Blocked()
    time.sleep(DELAY + random.uniform(0, DELAY * 0.4))
    return body


# ─── extraction ──────────────────────────────────────────────────────────────
#
# The page draws itself with one call per point:
#
#     addMarker(hole, poi, location, sideFW, new google.maps.LatLng(lat, lng));
#
# and defines the two lookups it indexes into, so nothing here is guesswork:
#
#     strPoi      = ["", "Green", "Green Bunker", "Fairway Bunker", "Water",
#                    "Trees", "100 Marker", "150 Marker", "200 Marker",
#                    "Dogleg", "Road", "Front Tee", "Back Tee"]
#     strLocation = ["", "Front", "Middle", "Back"]
#
# So addMarker(1, 1, 3, 2, ...) is hole 1's green, back edge, and
# addMarker(1, 12, 2, 2, ...) is hole 1's back tee. Read by index rather than
# by the order the calls happen to appear: a club that never placed a back tee
# leaves a gap, and counting positions would shift every hole after it onto the
# wrong coordinates — plausible on a map, wrong on the card.

POI = ["", "Green", "Green Bunker", "Fairway Bunker", "Water", "Trees",
       "100 Marker", "150 Marker", "200 Marker", "Dogleg", "Road",
       "Front Tee", "Back Tee"]
LOCATION = ["", "Front", "Middle", "Back"]
SIDE = ["", "Left", "Middle", "Right"]

ADD_MARKER = re.compile(
    r"addMarker\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,"
    r"\s*new\s+google\.maps\.LatLng\(\s*(-?\d+\.?\d*)\s*,"
    r"\s*(-?\d+\.?\d*)\s*\)")


def name(table, i):
    return table[i] if 0 < i < len(table) else str(i)


def coordinates(cid):
    page = get(f"/coordinates.php?cid={cid}")
    m = re.search(r"var\s+numHoles\s*=\s*(\d+)", page)
    hole_count = int(m.group(1)) if m else None

    holes = {}
    for hole, poi, loc, side, lat, lng in ADD_MARKER.findall(page):
        holes.setdefault(int(hole), []).append({
            "poi": name(POI, int(poi)),
            "location": name(LOCATION, int(loc)),
            "side": name(SIDE, int(side)),
            "lat": float(lat),
            "lng": float(lng),
        })
    if not holes:
        return None, page
    return {"numHoles": hole_count, "holes": holes}, page


def inspect(cid):
    """Print the assignment code, not a guess at it.

    The first pass showed the shape of the page — numHoles, a strPoi table of
    point types, a marker array of 19 — and that the coordinates appear in a
    fixed order per hole: green back, green middle, green front, front tee,
    back tee. But the count came out odd, 95 numbers where nine holes of five
    points would be 90, so something else in the page is also a decimal. Order
    alone is not safe to parse on: one stray pair shifts every hole after it.

    So this dumps the lines that actually assign the values.
    """
    print(f"fetching coordinates.php?cid={cid}\n", file=sys.stderr)
    _, page = coordinates(cid)
    print(f"page length: {len(page)}")

    m = re.search(r"var\s+numHoles\s*=\s*(\d+)", page)
    print(f"numHoles: {m.group(1) if m else '?'}")

    coord = re.compile(r"-?\d{1,3}\.\d{4,}")
    nums = coord.findall(page)
    print(f"coordinate-looking numbers: {len(nums)}")

    # Every line carrying two of them: that is where a point is set.
    lines = [l.strip() for l in page.splitlines() if len(coord.findall(l)) >= 2]
    print(f"\nlines with two or more coordinates: {len(lines)}")
    for l in lines[:14]:
        print("   ", l[:190])

    # And any line that mentions a marker slot, whether or not it has numbers,
    # so the indexing is visible: marker[hole][poi][location] or otherwise.
    slots = [l.strip() for l in page.splitlines()
             if re.search(r"marker\s*\[", l) and "=" in l]
    print(f"\nlines assigning into marker[...]: {len(slots)}")
    for l in slots[:14]:
        print("   ", l[:190])

    # The first coordinate in context, in case it lives in an attribute
    # rather than on a line of its own.
    i = coord.search(page)
    if i:
        print("\n--- 600 chars around the first coordinate ---")
        print(page[max(0, i.start() - 300):i.start() + 300])


def save(out):
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    os.replace(tmp, OUT)


def course_list():
    found = {}
    for page in (1, 2, 3):
        body = get(f"/courses.php?page={page}&CourseName=&Country=Vietnam"
                   f"&SubmitButton=Search")
        for chunk in body.split('href="showcourse.php?cid=')[1:]:
            cid = chunk.split('"')[0]
            text = re.sub(r"\s+", " ",
                          html.unescape(re.sub(r"<[^>]+>", " ", chunk[:1200]))).strip()
            text = re.sub(r'^[^ ]*"?>?\s*', "", text)
            text = re.sub(r"^(flag\s*)?(GPS\s*)?", "", text)
            m = re.match(r"(.*?),\s*[^,]*,\s*Vietnam", text)
            found[cid] = (m.group(1) if m else text[:70]).strip()
    return found


def main():
    if not SESSION:
        sys.exit("Set PHPSESSID — see the notes at the top of this file.")

    if INSPECT:
        cid = os.environ.get("CID", "1403513952650063_1_1")
        try:
            inspect(cid)
        except Blocked:
            sys.exit("Blocked. Wait, then try again.")
        return

    out = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8") as f:
            out = json.load(f)
        print(f"resuming — {len(out)} already in {OUT}", file=sys.stderr)

    try:
        courses = course_list()
    except Blocked:
        sys.exit("Blocked before the listing loaded. Wait a few hours.")

    # "Dai Lai A + B" is đường A followed by đường B; both are fetched on their
    # own, so its holes are already covered. Forty-two of the hundred and
    # forty-eight are pairings like that.
    pairings = [c for c, n in courses.items() if " + " in n]
    todo = [(c, n) for c, n in sorted(courses.items(), key=lambda x: x[1])
            if c not in out and " + " not in n]
    print(f"{len(courses)} courses, {len(pairings)} pairings skipped, "
          f"{len(todo)} to fetch, {DELAY:.0f}s apart "
          f"(~{len(todo) * DELAY * 1.2 / 60:.0f} min)", file=sys.stderr)

    for n, (cid, name) in enumerate(todo, 1):
        try:
            result, _ = coordinates(cid)
        except Blocked:
            save(out)
            sys.exit(f"\nBlocked at {n}/{len(todo)}. {len(out)} saved in {OUT}.\n"
                     f"Send that file over, wait, and run this again.")
        except Exception as exc:                       # noqa: BLE001
            print(f"  {n:3}/{len(todo)} {name[:40]:42} error: {exc}", file=sys.stderr)
            continue

        out[cid] = {"name": name, **(result or {"holes": {}})}
        save(out)
        count = len(result["holes"]) if result else 0
        print(f"  {n:3}/{len(todo)} {name[:40]:42} "
              f"{count} hole(s)" + ("" if count else "  — none stored"),
              file=sys.stderr)

    save(out)
    print(f"\ndone — {len(out)} courses in {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
