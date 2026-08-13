#!/usr/bin/env python3
"""Fetch the Vietnamese scorecards mscorecard.com still owes us — part two.

Run this on a machine that has NOT been blocked. It carries the list of the 77
courses already collected, so it needs nothing from the previous run and no
file copied across: it fetches only what is missing.

    Windows PowerShell
        $env:PHPSESSID="paste_the_cookie"
        python mscorecard_export_part2.py

    macOS / Linux
        PHPSESSID=paste_the_cookie python3 mscorecard_export_part2.py

The cookie has to come from the browser on THIS machine, logged in to
mscorecard: F12 -> Application -> Cookies -> mscorecard.com -> PHPSESSID.

It writes vn_scorecards_part2.json and updates it after every course, so being
cut off costs the one course in flight. Re-run the same command to continue —
it reads what it already has and skips it.

Twenty seconds a page. Eight was not enough: the first run was cut off at
course 78 of 148. About twenty-five minutes for the rest. If it stops early
anyway, raise it:

    $env:DELAY="40"
"""

import html
import json
import os
import random
import re
import sys
import time
import urllib.request

DONE = {
    "1198937652800",
    "1198942514552_1_1",
    "1198942514552_1_2",
    "1198942514552_1_3",
    "1198942514552_2_2",
    "1198942514552_2_3",
    "1198942514552_3_3",
    "1198974833945",
    "1199339738869",
    "1199340902630_1_1",
    "1199340902630_1_2",
    "1199340902630_1_3",
    "1199340902630_2_2",
    "1199340902630_2_3",
    "1199340902630_3_3",
    "1203590985101",
    "1207905630631",
    "1208227432263",
    "1217116282635",
    "1218179209640",
    "1221992788918",
    "1233121197683",
    "1234225755789",
    "1256870639382",
    "1267842097791",
    "1279378311508",
    "1289190090570",
    "1314338013001",
    "1316234320713",
    "1329817612215937",
    "1338967524968633",
    "1355468551866142",
    "137033712269633",
    "1372572183125",
    "1387506289912457_1_1",
    "1387506289912457_1_2",
    "1387506289912457_1_3",
    "1387506289912457_2_2",
    "1387506289912457_2_3",
    "1387506289912457_3_3",
    "1398932024758",
    "1403513952650063_1_1",
    "1403513952650063_1_2",
    "1403513952650063_1_3",
    "1403513952650063_2_2",
    "1403513952650063_2_3",
    "1403513952650063_3_3",
    "140949494152206",
    "1413452661939352",
    "1419690820874",
    "1447564090265",
    "1462335084251089",
    "1489082539981667",
    "1496933914754196",
    "1503921473916213",
    "1540955435607338",
    "1544589012327617",
    "15448885501426_1_1",
    "15448885501426_1_2",
    "15448885501426_1_3",
    "15448885501426_2_2",
    "15448885501426_2_3",
    "15448885501426_3_3",
    "1553879755526383_1_1",
    "1553879755526383_1_2",
    "1553879755526383_1_3",
    "1553879755526383_2_2",
    "1553879755526383_2_3",
    "1553879755526383_3_3",
    "1665561616396794",
    "1673710397551019",
    "1684825937951226",
    "1693630513616864",
    "1705020077651172",
    "1731136015689921",
    "1731342914298421",
    "1753254527479741",
}

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0 Safari/537.36")
BASE = "https://www.mscorecard.com/mscorecard"
OUT = os.environ.get("OUT", "vn_scorecards_part2.json")
DELAY = float(os.environ.get("DELAY", "20.0"))
SESSION = os.environ.get("PHPSESSID", "")


class Blocked(Exception):
    """The site stopped answering. Not something to retry around."""


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
        page_html = get(f"/courses.php?page={page}&CourseName=&Country=Vietnam"
                        f"&SubmitButton=Search")
        for chunk in page_html.split('href="showcourse.php?cid=')[1:]:
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

    cells = tokens[i + 2:]
    width = 3 + len(tees) + 2
    rows, k, expect = [], 0, 1
    while k < len(cells) and expect <= 18:
        if cells[k] == str(expect) and k + width <= len(cells):
            row = cells[k:k + width]
            par, si = number(row[1]), number(row[2])
            if par and si:
                rows.append({
                    "hole": expect,
                    "par": par,
                    "strokeIndex": si,
                    "yards": {tees[t]: number(row[3 + t])
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
    os.replace(tmp, OUT)


def main():
    if not SESSION:
        sys.exit("Set PHPSESSID first — see the notes at the top of this file.")

    out = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8") as f:
            out = json.load(f)
        print(f"resuming — {len(out)} already in {OUT}", file=sys.stderr)

    try:
        courses = course_list()
    except Blocked:
        sys.exit("Blocked before the listing even loaded. Wait longer and retry.")

    todo = [(c, n) for c, n in sorted(courses.items(), key=lambda x: x[1])
            if c not in DONE and c not in out]
    print(f"{len(courses)} listed, {len(DONE)} already collected earlier, "
          f"{len(todo)} to fetch, {DELAY:.0f}s apart", file=sys.stderr)

    for n, (cid, name) in enumerate(todo, 1):
        try:
            card = scorecard(cid)
        except Blocked:
            save(out)
            sys.exit(f"\nBlocked at {n}/{len(todo)}. {len(out)} saved in {OUT}.\n"
                     f"Send that file over, wait a few hours, then run this same\n"
                     f"command again — it picks up where it stopped. If it keeps\n"
                     f"happening, slow it down: DELAY=40")
        except Exception as exc:                      # noqa: BLE001
            print(f"  {n:3}/{len(todo)} {name[:42]:44} error: {exc}", file=sys.stderr)
            continue

        if not card:
            out[cid] = {"name": name, "holes": []}
            save(out)
            print(f"  {n:3}/{len(todo)} {name[:42]:44} no scorecard", file=sys.stderr)
            continue

        out[cid] = {"name": name, **card}
        save(out)
        print(f"  {n:3}/{len(todo)} {name[:42]:44} "
              f"{len(card['holes'])}h {len(card['tees'])} tees", file=sys.stderr)

    save(out)
    print(f"\ndone — {len(out)} new courses in {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
