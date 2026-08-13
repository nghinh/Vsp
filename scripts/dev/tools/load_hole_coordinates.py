#!/usr/bin/env python3
"""Turn mscorecard's map points into hole geometry, where the card agrees.

    python3 load_hole_coordinates.py vn_coordinates.json \
        --courses courses.txt --holes holes.txt > load_coordinates.sql

Emits SQL that sets `teeing_ground_location` and `green_location` on the holes
that survive the checks below, and writes a report of everything it refused to
stderr. Nothing is written for a hole it could not corroborate.

WHAT IT REPLACES
----------------
Every hole still carries the seed's invention: the tee is the clubhouse point
pushed along a fixed diagonal, the green is that tee pushed due north, and both
are stamped `synthetic:seed-arithmetic`. These are the first real positions the
platform has had.

WHERE THEY GO AFTERWARDS
------------------------
Straight into `holes`, which is the table three of the four readers consult
live — the portal's geometry review, the admin hole editor, and the shot
dispersion overlay. The fourth is the downloadable course package, a snapshot
built per published version; no course this loads for has one, so there is
nothing to rebuild and equally nothing the hole map will show until a package
is built for those courses.

Two gates stand between a loaded coordinate and a golfer, and they are the same
gate: the hole map and mid-round hole detection both skip any hole that is not
`VERIFIED` and better than class D. That promotion has a route already — the
portal's geometry review moves a reviewed hole D → C and marks it verified. So
holes land here at D/UNVERIFIED by default and wait for that screen.

With PROMOTE=1 the holes in the corroborated band are stamped C/VERIFIED
directly, on the argument that comparing against an independently published
yardage is a stricter test than the visual check the review screen offers. The
band below decides which holes qualify; nothing else is promoted.

THE CHECKS
----------
The coordinates are placed by hand by mscorecard's users, so some are wrong, and
a green dropped fifty metres off still looks perfectly reasonable on a satellite
tile. Three tests, cheapest first:

  1. The points sit near the club. Fuzzy name matching has attached foreign
     courses to Vietnamese clubs three separate times in this project — Otter
     Creek in Iowa onto Blue Diamond, Hanover in Virginia onto Glory. A course
     whose holes land more than 20 km from its facility is not that facility's
     course, whatever the name said, and the whole course is refused.

  2. The straight line is a golf hole at all: 50 to 700 yards.

  3. The straight line from back tee to the middle of the green comes out near
     the yardage the club printed. Long Biên's đường A, hole 1: 483 yards from
     the coordinates against 473 on the club's card.

     within 8%          corroborated — two independent sources agree
     8–30% shorter      plausible — a dogleg is legitimately shorter than the
                        walk, but so is a green placed on the wrong hole
     anything else      refused — a straight line cannot meaningfully exceed
                        the played length, so a longer one has a point in the
                        wrong place, and 30% short is past what a dogleg buys
     no yardage on file unchecked — written, flagged, listed at the end

REFERENCE FILES
---------------
Both come out of the database, so the checks compare against what is actually
loaded rather than against a copy that has drifted:

  ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
    psql -U vsp -d vsp -At -F'|' -c \\"
      SELECT c.id, f.name, c.name,
             (SELECT count(*) FROM holes h WHERE h.course_id=c.id),
             round(ST_Y(f.location::geometry)::numeric,5),
             round(ST_X(f.location::geometry)::numeric,5)
      FROM courses c JOIN golf_facilities f ON f.id=c.facility_id
      ORDER BY f.name, c.name\\"" > courses.txt

  ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
    psql -U vsp -d vsp -At -F'|' -c \\"
      SELECT h.course_id, h.hole_number, h.par,
             coalesce(round(h.playing_length_meters::numeric,1)::text,'')
      FROM holes h WHERE h.source <> 'synthetic:seed-arithmetic'
      ORDER BY h.course_id, h.hole_number\\"" > holes.txt
"""

import json
import math
import os
import sys

EARTH_M = 6371000.0
YARD_M = 0.9144
FACILITY_LIMIT_M = 20000.0
MIN_YARDS, MAX_YARDS = 50.0, 700.0
CORROBORATED = 0.08
DOGLEG = 0.30

PROMOTE = os.environ.get("PROMOTE", "")
SOURCE = "mscorecard.com map editor; checked against the club's card"
# Doubled for the SQL literal: the source names the club's card, apostrophe
# and all, and an unescaped one ends the string early and breaks the file.
SOURCE_SQL = SOURCE.replace("'", "''")


def metres(a, b):
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp = p2 - p1
    dl = math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_M * math.asin(math.sqrt(h))


def point(hole_points, poi, location=None):
    for p in hole_points:
        if p["poi"] == poi and (location is None or p["location"] == location):
            return (p["lat"], p["lng"])
    return None


def tee_and_green(points):
    """Back tee where the club placed one, front tee otherwise; green middle.

    Back tee, because that is the tee the card's headline yardage is measured
    from and so the one the check can be run against. Green middle rather than
    front or back for the same reason — it is the point a yardage means.
    """
    tee = point(points, "Back Tee") or point(points, "Front Tee")
    green = (point(points, "Green", "Middle")
             or point(points, "Green", "Front")
             or point(points, "Green", "Back"))
    return tee, green


def read_courses(path):
    """course_id → (label, facility point or None)."""
    courses = {}
    for line in open(path, encoding="utf-8"):
        parts = line.rstrip("\n").split("|")
        if len(parts) < 6 or not parts[0].strip():
            continue
        cid, facility, course, _holes, lat, lng = parts[:6]
        here = (float(lat), float(lng)) if lat and lng else None
        courses[int(cid)] = (f"{facility} / {course}", here)
    return courses


def read_holes(path):
    """(course_id, hole_number) → card length in metres, or None."""
    lengths = {}
    for line in open(path, encoding="utf-8"):
        parts = line.rstrip("\n").split("|")
        if len(parts) < 4 or not parts[0].strip():
            continue
        course_id, hole, _par, metres_text = parts[:4]
        lengths[(int(course_id), int(hole))] = (
            float(metres_text) if metres_text else None)
    return lengths


def classify(straight_m, card_m):
    """corroborated | plausible | refused | unchecked, and a reason."""
    yards = straight_m / YARD_M
    if not MIN_YARDS <= yards <= MAX_YARDS:
        return "refused", f"{yards:.0f}y is not a golf hole"
    if card_m is None:
        return "unchecked", f"{yards:.0f}y, no yardage on file to check it"

    off = (straight_m - card_m) / card_m
    if abs(off) <= CORROBORATED:
        return "corroborated", f"{yards:.0f}y vs card {card_m / YARD_M:.0f}y ({off:+.1%})"
    if -DOGLEG <= off < -CORROBORATED:
        return "plausible", f"{yards:.0f}y vs card {card_m / YARD_M:.0f}y ({off:+.1%}), reads as a dogleg"
    return "refused", f"{yards:.0f}y vs card {card_m / YARD_M:.0f}y ({off:+.1%})"


# Filled in once the export is in hand and each name has been read against the
# database's own. The facility-distance check below is a backstop, not a
# licence to guess: it catches a course on the wrong continent, not đường A
# mapped onto đường B at the same club.
COURSE_BY_CID = {}


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    def opt(flag, default=None):
        return args[args.index(flag) + 1] if flag in args else default

    data = json.load(open(args[0], encoding="utf-8"))
    courses = read_courses(opt("--courses", "courses.txt"))
    card = read_holes(opt("--holes", "holes.txt"))

    counts = {"corroborated": 0, "plausible": 0, "refused": 0, "unchecked": 0}
    notes = []
    written = []

    for cid, course in sorted(data.items(), key=lambda x: x[1].get("name", "")):
        course_id = COURSE_BY_CID.get(cid)
        if not course_id:
            continue
        if course_id not in courses:
            notes.append(f"{course['name']}: course {course_id} is not in the database")
            continue
        label, facility_point = courses[course_id]

        holes = sorted(course.get("holes", {}).items(), key=lambda x: int(x[0]))
        points = [tee_and_green(p) for _, p in holes]

        # Check 1, before anything is emitted: are these this club's holes?
        if facility_point:
            near = [metres(t, facility_point) for t, _ in points if t]
            if near and min(near) > FACILITY_LIMIT_M:
                notes.append(
                    f"{label}: REFUSED WHOLE COURSE — nearest hole is "
                    f"{min(near) / 1000:.0f} km from the club. "
                    f"cid {cid} ({course['name']}) is mapped to the wrong course.")
                continue
        else:
            notes.append(f"{label}: the facility has no coordinates, so the "
                         f"distance check could not run")

        for (hole_no, _), (tee, green) in zip(holes, points):
            if not tee or not green:
                continue
            hole_no = int(hole_no)
            # A hole number the database does not have would produce an UPDATE
            # matching nothing — a silent no-op that reads as a successful
            # write. Usually it means the export's nine is the club's other
            # nine, which is worth knowing about rather than swallowing.
            if (course_id, hole_no) not in card:
                notes.append(f"{label}: no hole {hole_no} on this course, skipped")
                continue
            straight = metres(tee, green)
            verdict, why = classify(straight, card[(course_id, hole_no)])
            counts[verdict] += 1
            if verdict == "refused":
                notes.append(f"{label} hole {hole_no}: refused — {why}")
                continue
            written.append((label, course_id, hole_no, tee, green, verdict, why))

    print("-- Real tee and green points, from mscorecard's map editor.")
    print("-- Generated by scripts/dev/tools/load_hole_coordinates.py; do not hand-edit.")
    print(f"-- {counts['corroborated']} corroborated, {counts['plausible']} plausible, "
          f"{counts['unchecked']} unchecked, {counts['refused']} refused.")
    print(f"-- Promotion to C/VERIFIED: {'on' if PROMOTE else 'off'}"
          f" (PROMOTE=1 turns it on; only corroborated holes qualify).")
    print("\n\\set ON_ERROR_STOP on\n\nBEGIN;")

    last = None
    for label, course_id, hole_no, tee, green, verdict, why in written:
        if label != last:
            print(f"\n-- ── {label} " + "─" * max(0, 60 - len(label)))
            last = label
        promote = PROMOTE and verdict == "corroborated"
        print(f"-- hole {hole_no}: {verdict}, {why}")
        print(f"""UPDATE holes SET
  teeing_ground_location = ST_SetSRID(ST_MakePoint({tee[1]}, {tee[0]}), 4326),
  green_location         = ST_SetSRID(ST_MakePoint({green[1]}, {green[0]}), 4326),
  source                 = '{SOURCE_SQL}',""" + ("""
  accuracy_class         = 'C_VERIFIED_SATELLITE',
  verification_status    = 'VERIFIED',
  confidence             = 85.0,
  last_verified_at       = now(),""" if promote else "") + f"""
  updated_at             = now()
WHERE course_id = {course_id} AND hole_number = {hole_no};""")

    print("\nCOMMIT;")

    out = sys.stderr
    print(f"\n{len(written)} hole(s) to write — "
          f"{counts['corroborated']} corroborated, {counts['plausible']} plausible, "
          f"{counts['unchecked']} unchecked. {counts['refused']} refused.", file=out)
    if notes:
        print(f"\n{len(notes)} thing(s) to look at:", file=out)
        for n in notes:
            print(f"  {n}", file=out)


if __name__ == "__main__":
    main()
