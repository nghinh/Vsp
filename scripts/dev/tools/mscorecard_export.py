#!/usr/bin/env python3
"""Export Vietnamese scorecards from mscorecard.com, gently.

Run this on a machine that can still reach the site, logged in, and hand back
the JSON it writes. It is deliberately slow: the first attempt at this fetched
about 150 pages in a couple of minutes and got the IP blocked, which is what
this pacing exists to avoid. At the default delay a full run is roughly fifteen
minutes and nobody notices it.

    PHPSESSID=xxxxxxxx python3 mscorecard_export.py > vn_scorecards.json

Get PHPSESSID from the browser: DevTools -> Application -> Cookies ->
mscorecard.com. It expires when you log out.

What it takes per course: par and stroke index per hole, and the yardage of
every tee the club prints — the yardages are the point, because the round-setup
picker needs to tell a golfer that GOLD is seven thousand yards and WHITE is
six. Also the coordinates, if the club stored any.
"""

import html
import json
import os
import re
import sys
import time
import urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0 Safari/537.36")
BASE = "https://www.mscorecard.com/mscorecard"
DELAY = float(os.environ.get("DELAY", "3.0"))     # seconds between requests
SESSION = os.environ.get("PHPSESSID", "")


def get(path):
    req = urllib.request.Request(BASE + path, headers={
        "User-Agent": UA,
        "Cookie": f"PHPSESSID={SESSION}",
    })
    with urllib.request.urlopen(req, timeout=40) as r:
        body = r.read().decode("utf-8", "replace")
    if "access has been blocked" in body:
        sys.exit("Blocked. Stop, wait, and mail support@mscorecard.com.")
    time.sleep(DELAY)
    return body


def flatten(s):
    s = re.sub(r"<script.*?</script>", " ", s, flags=re.S)
    s = re.sub(r"<style.*?</style>", " ", s, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s)))


def number(tok):
    try:
        return int(tok)
    except ValueError:
        return None


def course_list():
    """Every Vietnamese course, from the three pages the search returns."""
    found = {}
    for page in (1, 2, 3):
        body = get(f"/courses.php?page={page}&CourseName=&Country=Vietnam"
                   f"&SubmitButton=Search")
        for chunk in body.split('href="showcourse.php?cid=')[1:]:
            cid = chunk.split('"')[0]
            text = flatten(chunk[:1200]).strip()
            text = re.sub(r'^[^ ]*"?>?\s*', "", text)
            text = re.sub(r"^(flag\s*)?(GPS\s*)?", "", text)
            m = re.match(r"(.*?),\s*[^,]*,\s*Vietnam", text)
            found[cid] = (m.group(1) if m else text[:70]).strip()
    return found


def scorecard(cid):
    """Par, stroke index and every tee's yardage, in the club's own unit.

    The row is: hole, par, SI, one column per tee, then par and SI again for
    the ladies' card. Tee names sit between "Hole Par SI" and the second
    "Par SI", and a column is "-" when the club never entered it — which is
    common for distance and never for par, so a missing distance is not a
    reason to drop the hole.
    """
    text = flatten(get(f"/showcourse.php?cid={cid}"))
    unit = "Meters" if "measurement Meters" in text else "Yards"

    start = text.find("Hole Par SI ")
    if start < 0:
        return None
    tokens = text[start + len("Hole Par SI "):].split()

    tees, i = [], 0
    while i < len(tokens) and not (tokens[i] == "Par"
                                   and i + 1 < len(tokens)
                                   and tokens[i + 1] == "SI"):
        if not tokens[i].isalpha():
            return None
        tees.append(tokens[i])
        i += 1

    body = tokens[i + 2:]
    width = 3 + len(tees) + 2
    rows, k, expect = [], 0, 1
    while k < len(body) and expect <= 18:
        if body[k] == str(expect) and k + width <= len(body):
            cells = body[k:k + width]
            par, si = number(cells[1]), number(cells[2])
            if par and si:
                rows.append({
                    "hole": expect,
                    "par": par,
                    "strokeIndex": si,
                    "yards": {tees[t]: number(cells[3 + t])
                              for t in range(len(tees))},
                })
                expect += 1
                k += width
                continue
        k += 1

    if not rows:
        return None

    coords = re.search(r"Coordinates\s+(-?\d+\.\d+)[,\s]+(-?\d+\.\d+)", text)
    return {
        "unit": unit,
        "tees": tees,
        "holes": rows,
        "location": ({"lat": float(coords.group(1)),
                      "lng": float(coords.group(2))} if coords else None),
    }


def main():
    if not SESSION:
        sys.exit("Set PHPSESSID. See the docstring.")
    courses = course_list()
    print(f"{len(courses)} courses listed", file=sys.stderr)
    out = {}
    for n, (cid, name) in enumerate(sorted(courses.items(), key=lambda x: x[1]), 1):
        try:
            card = scorecard(cid)
        except Exception as exc:                     # noqa: BLE001
            print(f"  {n:3}/{len(courses)} {name[:44]:46} error: {exc}", file=sys.stderr)
            continue
        if not card:
            print(f"  {n:3}/{len(courses)} {name[:44]:46} no scorecard", file=sys.stderr)
            continue
        out[cid] = {"name": name, **card}
        print(f"  {n:3}/{len(courses)} {name[:44]:46} "
              f"{len(card['holes'])}h {len(card['tees'])} tees", file=sys.stderr)
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
    print(f"\nexported {len(out)}", file=sys.stderr)


if __name__ == "__main__":
    main()
