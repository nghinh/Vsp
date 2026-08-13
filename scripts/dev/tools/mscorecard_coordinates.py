#!/usr/bin/env python3
"""Pull per-hole tee and green coordinates out of mscorecard's map editor.

    PHPSESSID=xxxxxxxx python3 mscorecard_coordinates.py

Writes vn_coordinates.json, updated after every course, and skips what it
already has when re-run. Twenty seconds a page.

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
DELAY = float(os.environ.get("DELAY", "20.0"))
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
# Three shapes, tried in order. The first that yields holes wins.

LABELS = {
    "green (front)": "greenFront",
    "green (middle)": "greenMiddle",
    "green (back)": "greenBack",
    "front tee": "frontTee",
    "back tee": "backTee",
}


def from_js_arrays(page):
    """Whole-course data sitting in a script tag.

    "Show all holes" draws every marker at once, so the page almost certainly
    carries all eighteen holes rather than fetching them one at a time.
    """
    out = {}
    # e.g.  holes[3] = {greenFront: {lat: 21.03, lng: 105.89}, ...}
    for m in re.finditer(
            r'(?:hole|holes)\s*\[\s*(\d+)\s*\]\s*=\s*(\{.{0,600}?\})\s*[;\n]',
            page, re.S):
        n = int(m.group(1))
        pairs = re.findall(
            r'(\w+)\s*:\s*\{[^}]*?lat\w*\s*:\s*"?(-?\d+\.\d+)"?[^}]*?'
            r'(?:lng|lon)\w*\s*:\s*"?(-?\d+\.\d+)"?', m.group(2))
        if pairs:
            out[n] = {k: {"lat": float(a), "lng": float(b)} for k, a, b in pairs}
    return out


def from_marker_calls(page):
    """Markers pushed one call at a time, carrying a hole number and a label."""
    out = {}
    for m in re.finditer(
            r'(-?\d{1,2}\.\d{4,})\s*,\s*(\d{2,3}\.\d{4,})[^)]{0,120}?'
            r'(?:hole|title|label)\D{0,12}(\d{1,2})',
            page, re.I):
        n = int(m.group(3))
        out.setdefault(n, {}).setdefault("points", []).append(
            {"lat": float(m.group(1)), "lng": float(m.group(2))})
    return out


def from_inputs(page):
    """The labelled Lat/Lon boxes down the left of the editor, for one hole."""
    text = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", page)))
    found = {}
    for label, key in LABELS.items():
        m = re.search(re.escape(label) + r"\s*Lat:?\s*(-?\d+\.\d+)\s*Lon:?\s*(-?\d+\.\d+)",
                      text, re.I)
        if m:
            found[key] = {"lat": float(m.group(1)), "lng": float(m.group(2))}
    if found:
        return found
    # value="21.035128" pairs in document order, five points to a hole
    vals = [float(v) for v in re.findall(r'value="(-?\d{1,3}\.\d{4,})"', page)]
    pairs = list(zip(vals[0::2], vals[1::2]))
    if pairs:
        return {list(LABELS.values())[i]: {"lat": a, "lng": b}
                for i, (a, b) in enumerate(pairs[:len(LABELS)])}
    return {}


def coordinates(cid):
    page = get(f"/coordinates.php?cid={cid}")
    for extract in (from_js_arrays, from_marker_calls):
        holes = extract(page)
        if holes:
            return {"holes": holes, "how": extract.__name__}, page
    single = from_inputs(page)
    if single:
        return {"holes": {1: single}, "how": "from_inputs (hole 1 only)"}, page
    return None, page


def inspect(cid):
    print(f"fetching coordinates.php?cid={cid}\n", file=sys.stderr)
    result, page = coordinates(cid)
    print(f"page length: {len(page)}")
    print(f"'Lat' appears {page.count('Lat')}x, 'Lon' {page.count('Lon')}x, "
          f"'marker' {page.lower().count('marker')}x")
    nums = re.findall(r"-?\d{1,3}\.\d{4,}", page)
    print(f"decimal numbers that look like coordinates: {len(nums)}")
    print(f"first few: {nums[:12]}")
    if result:
        print(f"\nEXTRACTED via {result['how']}: {len(result['holes'])} hole(s)")
        first = sorted(result["holes"])[0]
        print(json.dumps({str(first): result["holes"][first]}, indent=1))
    else:
        print("\nNOTHING EXTRACTED — the samples below are what to write against.")
    for needle in ("Lat", "greenFront", "marker", "LatLng"):
        i = page.find(needle)
        if i > 0:
            print(f"\n--- around {needle!r} ---")
            print(page[max(0, i - 300):i + 500])
            break


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

    todo = [(c, n) for c, n in sorted(courses.items(), key=lambda x: x[1])
            if c not in out]
    print(f"{len(courses)} courses, {len(todo)} to fetch, {DELAY:.0f}s apart",
          file=sys.stderr)

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
