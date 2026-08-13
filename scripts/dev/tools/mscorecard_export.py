#!/usr/bin/env python3
"""Export Vietnamese scorecards from mscorecard.com, slowly and resumably.

Run it on a machine that can still reach the site, logged in, and hand back the
JSON file it writes.

    PHPSESSID=xxxxxxxx python3 mscorecard_export.py

It writes vn_scorecards.json in the current directory and updates it after
every single course. That matters: the first version of this only wrote at the
end, so when the site cut it off at course 46 all forty-six went in the bin.
Now a block costs you the one course in flight and nothing else.

Re-run the same command to continue. It reads whatever is already in the file
and skips those, so you can go until it stops, wait, and go again.

Pacing: eight seconds a page by default, which is about twenty minutes for the
whole country. Three seconds was not enough — that is what got cut off. Raise
it if you get stopped again:

    DELAY=15 PHPSESSID=xxxxxxxx python3 mscorecard_export.py

Get PHPSESSID from the browser on that machine: DevTools -> Application ->
Cookies -> mscorecard.com. It has to be that machine's own cookie.

What it takes per course: par and stroke index per hole, the yardage of every
tee the club prints — the yardages are the point, since the round-setup picker
needs to say GOLD is seven thousand yards and WHITE is six — and the club's
coordinates where it stored any.
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
OUT = os.environ.get("OUT", "vn_scorecards.json")
DELAY = float(os.environ.get("DELAY", "8.0"))
SESSION = os.environ.get("PHPSESSID", "")


class Blocked(Exception):
    """The site has stopped answering. Not something to retry around."""


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
    # Jittered, because a request exactly every N seconds is itself a signal.
    time.sleep(DELAY + random.uniform(0, DELAY * 0.4))
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

    A row reads: hole, par, SI, one column per tee, then par and SI again for
    the ladies' card. Tee names sit between "Hole Par SI" and the second
    "Par SI". A cell is "-" where the club never filled it in, which happens
    often for distance and never for par, so a missing distance is not a reason
    to drop the hole.
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


def save(out):
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    os.replace(tmp, OUT)          # atomic, so a kill mid-write cannot truncate


def main():
    if not SESSION:
        sys.exit("Set PHPSESSID. See the docstring at the top of this file.")

    out = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8") as f:
            out = json.load(f)
        print(f"resuming with {len(out)} already saved", file=sys.stderr)

    try:
        courses = course_list()
    except Blocked:
        sys.exit("Blocked before the listing. Wait a few hours and re-run.")

    todo = [(c, n) for c, n in sorted(courses.items(), key=lambda x: x[1])
            if c not in out]
    print(f"{len(courses)} listed, {len(todo)} still to fetch, "
          f"{DELAY}s between pages", file=sys.stderr)

    for n, (cid, name) in enumerate(todo, 1):
        try:
            card = scorecard(cid)
        except Blocked:
            save(out)
            sys.exit(f"\nBlocked at {n}/{len(todo)}. {len(out)} saved in {OUT}.\n"
                     f"Wait a few hours, then run the same command again — it "
                     f"picks up where it stopped.\nIf it keeps happening, raise "
                     f"the delay: DELAY=20 PHPSESSID=... python3 {sys.argv[0]}")
        except Exception as exc:                      # noqa: BLE001
            print(f"  {n:3}/{len(todo)} {name[:42]:44} error: {exc}", file=sys.stderr)
            continue

        if not card:
            out[cid] = {"name": name, "holes": []}    # remembered, not refetched
            save(out)
            print(f"  {n:3}/{len(todo)} {name[:42]:44} no scorecard", file=sys.stderr)
            continue

        out[cid] = {"name": name, **card}
        save(out)
        print(f"  {n:3}/{len(todo)} {name[:42]:44} "
              f"{len(card['holes'])}h {len(card['tees'])} tees", file=sys.stderr)

    save(out)
    print(f"\ndone — {len(out)} courses in {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
