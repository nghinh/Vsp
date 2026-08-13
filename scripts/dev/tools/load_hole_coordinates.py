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

     Measured against the longest tee on file, because the coordinates are the
     back tee and a card loaded from a forward tee would make every hole on
     the course look too long. Hoiana Shores is the case: its card is the
     White tee, the map points are the back, and all eighteen holes came out
     12-50% over on the first run.

  4. A whole course reading long by a consistent factor is a forward-tee card,
     not eighteen misplaced greens. Where the ratios across a course are tight
     — the shape of the card reproduced at a different scale — the holes are
     kept as *plausible* rather than refused, because a course of wrong points
     does not produce a tight ratio distribution. Kings Island's Lakeside is
     the counter-example: +250% on one hole and -47% on the next, which is
     hole numbering that does not line up, and those stay refused.

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


def read_tee_yards(path):
    """(course_id, hole_number) → the longest tee's yardage, in metres.

    The coordinates mark a back tee, so this is what they should be compared
    against. `holes.playing_length_meters` carries whichever single tee was
    loaded, and for a course whose card came off a forward tee that is a
    yardstick shorter than the thing being measured.
    """
    longest = {}
    for line in open(path, encoding="utf-8"):
        parts = line.rstrip("\n").split("|")
        if len(parts) < 3 or not parts[0].strip():
            continue
        course_id, hole, yards = parts[:3]
        longest[(int(course_id), int(hole))] = int(yards) * YARD_M
    return longest


def forward_tee_offset(ratios):
    """The factor a whole course reads long by, when it reads long uniformly.

    A card printed for a forward tee makes every hole on the course come out
    over by roughly the same proportion, because the greens are where they
    are and only the tees moved. Eighteen misplaced points do not do that:
    Kings Island's Lakeside came back +250% on one hole and -47% on the next.

    So: the median ratio, but only when at least two thirds of the holes sit
    within a tenth of it, and only when the course reads long. Returns None
    otherwise, and the holes are judged one by one as before.
    """
    if len(ratios) < 6:
        return None
    ordered = sorted(ratios)
    median = ordered[len(ordered) // 2]
    if median <= 1.05:
        return None
    close = sum(1 for r in ratios if abs(r - median) <= 0.10 * median)
    return median if close >= len(ratios) * 2 / 3 else None


def classify(straight_m, card_m, offset=None):
    """corroborated | plausible | refused | unchecked, and a reason."""
    yards = straight_m / YARD_M
    if not MIN_YARDS <= yards <= MAX_YARDS:
        return "refused", f"{yards:.0f}y is not a golf hole"
    if card_m is None:
        return "unchecked", f"{yards:.0f}y, no yardage on file to check it"

    # Where the whole course reads long by one factor, the card is a forward
    # tee and the comparison is against the card scaled to it. Kept as
    # plausible rather than corroborated even when it lands dead on: the shape
    # agrees, the tee it was measured from does not.
    if offset is not None:
        scaled = card_m * offset
        drift = (straight_m - scaled) / scaled
        if abs(drift) <= 0.12:
            return "plausible", (f"{yards:.0f}y vs card {card_m / YARD_M:.0f}y, "
                                 f"which reads as a forward-tee card "
                                 f"(course runs {offset:.2f}x long)")
        return "refused", (f"{yards:.0f}y vs card {card_m / YARD_M:.0f}y "
                           f"({drift:+.1%} off the course's own {offset:.2f}x)")

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
COURSE_BY_CID = {
    # ── Read against the database's own names, one by one. Fuzzy matching has
    # attached foreign courses to Vietnamese clubs three times in this project;
    # what is not here is listed under SKIPPED below with the reason.
    "1496933914754196": 30,    # Ba Na Hills → Championship
    "1338967524968633": 996,   # Cửa Lò
    "15448885501426_1_1": 1419,   # Đại Lải Star / Đường A
    "15448885501426_2_2": 1420,   # Đại Lải Star / Đường B
    "15448885501426_3_3": 1421,   # Đại Lải Star / Đường C
    "1233121197683": 33,       # Dalat Palace
    "137033712269633": 37,     # Diamond Bay
    "1198942514552_1_1": 1416,    # Đồng Nai / Đường A
    "1198942514552_2_2": 1417,    # Đồng Nai / Đường B
    "1198942514552_3_3": 1418,    # Đồng Nai / Đường C
    "1489082539981667": 26,    # FLC Sầm Sơn
    "1387506289912457_1_1": 1446, # Hà Nội Golf Club / Đường A
    "1387506289912457_2_2": 1447, # Hà Nội Golf Club / Đường B
    "1387506289912457_3_3": 1448, # Hà Nội Golf Club / Đường C
    "1540955435607338": 43,    # Harmonie Golf Park
    "1289190090570": 12,       # Heron Lake
    "1553879755526383_1_1": 1451, # Hilltop Valley / Đường A
    "1553879755526383_2_2": 1452, # Hilltop Valley / Đường B
    "1553879755526383_3_3": 1453, # Hilltop Valley / Đường C
    "1665561616396794": 31,    # Hoiana Shores
    "1544589012327617": 1411,  # KN Golf Links / Links Course
    "1372572183125": 32,       # Laguna Lăng Cô
    "1355468551866142": 9,     # BRG Legend Hill
    "1403513952650063_1_1": 1351, # Long Biên / Đường A
    "1403513952650063_2_2": 1352, # Long Biên / Đường B
    "1403513952650063_3_3": 1353, # Long Biên / Đường C
    "1234225755789": 1406,     # Long Thành / Hill Course
    "1198974833945": 1407,     # Long Thành / Lake Course
    "140949494152206": 995,    # Móng Cái
    "1217116282635": 29,       # Montgomerie Links
    "1203590985101": 1387,     # Phoenix / Champion
    "1208227432263": 1386,     # Phoenix / Dragon
    "1221992788918": 1385,     # Phoenix / Phoenix
    "1413452661939352": 998,   # Royal Island
    "1256870639382": 17,       # BRG Ruby Tree
    "1398932024758": 34,       # Sacom Tuyền Lâm, now SAM Tuyền Lâm — same club, Đà Lạt
    "1218179209640": 39,       # Sea Links
    "1329817612215937": 1389,  # Sky Lake / Lake Course
    "1419690820874": 1388,     # Sky Lake / Sky Course
    "1753254527479741": 1017,  # Sonadezi Châu Đức
    "1199340902630_3_3": 1436,    # Sông Bé / Desert
    "1199340902630_1_1": 1434,    # Sông Bé / Lotus
    "1199340902630_2_2": 1435,    # Sông Bé / Palm
    "1314338013001": 18,       # Sono Belle Hải Phòng — Championship (18)
    "1731136015689921": 1410,  # Sono Belle / Hill Course (the executive nine)
    "1541731529201714_1_1": 1422, # Stone Valley / Đường A
    "1541731529201714_2_2": 1423, # Stone Valley / Đường B
    "1511845569674543": 24,    # FLC Hạ Long
    "1355468902462127": 35,    # Dalat at 1200
    "1324654287519_1_1": 1413,    # Chí Linh / Đường A
    "1324654287519_2_2": 1414,    # Chí Linh / Đường B
    "1324654287519_3_3": 1415,    # Chí Linh / Đường C
    "1527478823434517": 1354,  # Kings Island / Kings Course
    # mscorecard calls this page "Lake Side", and it is not. Measured against
    # the club's own cards it agrees with Mountain View on 14 of 18 holes and
    # with Lakeside on 1. Both cards came from Golfify URLs that name the
    # course explicitly, so the mislabelling is on the user-contributed side.
    "1223263951812": 1355,     # Kings Island / Mountain View Course
    "1249531199282": 4,        # Tam Đảo
    "1428837436119618_1_1": 1392, # Tân Sơn Nhất / Đường A
    "1428837436119618_2_2": 1393, # Tân Sơn Nhất / Đường B
    "1428837436119618_3_3": 1394, # Tân Sơn Nhất / Đường C
    "1428837436119618_4_4": 1395, # Tân Sơn Nhất / Đường D
    "1643077576696859": 13,    # Thanh Lanh Valley
    "1397132823587": 46,       # The Bluffs Hồ Tràm
    "1451119617767": 1398,     # Tràng An / Champion Course
    "1730875129399598": 1399,  # Tràng An / Pine Night
    "1146809480500_1_1": 1431,    # Twin Doves / Luna
    "1146809480500_3_3": 1433,    # Twin Doves / Sole
    "1146809480500_2_2": 1432,    # Twin Doves / Stella
    "1270298785567": 1390,     # Vietnam Golf & CC / East
    "1270299755138": 1391,     # Vietnam Golf & CC / West
    "1316225488149": 36,       # Vinpearl Nha Trang
    "1537501434236616": 5,     # Vinpearl Nam Hội An
    "1451731662112_2_2": 1441,    # Paradise Vũng Tàu / Đường B
    "1541902476728376": 49,    # West Lakes Golf & Villas
}

# SKIPPED, and why. Every one of these is a case where writing something would
# have been worse than writing nothing.
#
#   Danang Golf Resort Nicklaus, Danang Golf Resort Norman
#       BRG Đà Nẵng has two layouts and the database has one course row. Either
#       choice puts one layout's coordinates on the other's holes.
#   Taekwang Jeongsan ×2, jeongsan country club
#       Three exports, one course row, no way to tell which layout is loaded.
#   Vinpearl Golf Haiphong Lake Course, Marsh
#       Two layouts, one Championship row.
#   Vinpearl Golf Phú Quốc ×2
#       Two nines against an eighteen-hole row: both would claim holes 1-9.
#   Monty links, Sam Son Golf Links
#       The same clubs as Montgomerie Links and FLC Sầm Sơn, listed twice.
#   FLC Quy Nhơn ×2, Ocean Dunes Phan Thiết, Nhà Hàng Sân Golf Thủ Đức
#       No such club in the database.
#   Kings Island Lakeside, West Lakes, Royal Island — coordinates withdrawn
#       Their exports line up with their cards on neither the hole numbers
#       given nor any rotation of them: the best shift scores 7 of 18, where a
#       real off-by-n scores 17 or 18. Kings Island's turned out to be the
#       Mountain View layout under the wrong name and is remapped above; the
#       other two have one course each at their club, so there is nothing to
#       cross-check against and nothing safe to write.
#   Golf Bac Giang Hillside
#       Yên Dũng is the database's Bắc Giang course, but the name does not say
#       so and a wrong guess here is a whole course of wrong holes.


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    def opt(flag, default=None):
        return args[args.index(flag) + 1] if flag in args else default

    data = json.load(open(args[0], encoding="utf-8"))
    courses = read_courses(opt("--courses", "courses.txt"))
    card = read_holes(opt("--holes", "holes.txt"))
    tee_yards = read_tee_yards(opt("--tee-yards", "tee-yards.txt"))

    def reference(course_id, hole_no):
        """The longest tee on file, or the single length loaded onto the hole."""
        return (tee_yards.get((course_id, hole_no))
                or card.get((course_id, hole_no)))

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

        # One pass to see whether the whole course reads long by one factor,
        # which is what a card printed for a forward tee looks like.
        ratios = []
        for (hole_no, _), (tee, green) in zip(holes, points):
            if not tee or not green:
                continue
            printed = reference(course_id, int(hole_no))
            if printed:
                ratios.append(metres(tee, green) / printed)
        offset = forward_tee_offset(ratios)
        if offset:
            notes.append(f"{label}: reads {offset:.2f}x long across the course "
                         f"— the card on file is a forward tee, so these are "
                         f"written unverified")

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
            verdict, why = classify(straight, reference(course_id, hole_no), offset)
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
