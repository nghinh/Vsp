#!/usr/bin/env python3
"""Load a club's whole card — every tee — out of the mscorecard export.

    python3 load_mscorecard_card.py vn_scorecards.json <cid> <course_id> > card.sql

WHY A SECOND LOADER
-------------------
`load_published_card.sql` takes one tee's yardages, because that is all a club
website usually prints. The mscorecard export carries every tee the club has —
Tràng An's Champion course lists six — and the tee tables now exist to hold
them. Loading one tee out of six throws away the distances five sets of golfers
actually play, and course rating and slope have nowhere to attach.

WHAT IT WRITES
--------------
The holes, the card, the card's stroke indexes, one tee row per tee, and that
tee's eighteen yardages. `holes.playing_length_meters` takes the longest tee,
because that is the number the course is measured at and what the coordinate
check compares against.

WHAT IT REFUSES
---------------
The same ladder every loader in this project has, each rung added after a real
failure:

  * pars must be 3-6 and stroke indexes a complete 1..n, each used once
  * a yardage outside 60-700 is a misread of the wrong row
  * a card whose holes are all the same par at all the same distance is a
    placeholder, not a card — Golfify serves those for courses it has no data
    for, and they sum to 72 over 5,400 and pass every other check
  * a tee whose yardages are missing for some holes and present for others is
    written for the holes it has, and the gap is reported

Nothing is written for a course that already carries a golfer-submitted card:
a card someone photographed at the tee beats one scraped from a directory, and
overwriting it would lose the ratings that only a photograph carries.
"""

import json
import sys

YARD_M = 0.9144


def fail(message):
    sys.exit(f"REFUSED: {message}")


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    export, cid, course_id = sys.argv[1], sys.argv[2], int(sys.argv[3])

    data = json.load(open(export, encoding="utf-8"))
    card = data.get(cid)
    if not card:
        fail(f"no course {cid} in {export}")

    holes = card.get("holes") or []
    if not holes:
        fail(f"{card.get('name')} has no holes in the export")

    pars, indexes = {}, {}
    yardages = {}          # tee name → {hole: yards}
    for line in holes:
        hole = int(line["hole"])
        par = line.get("par")
        if par is None or not 3 <= int(par) <= 6:
            fail(f"hole {hole} says par {par}; a hole is a 3, 4, 5 or 6")
        pars[hole] = int(par)

        index = line.get("strokeIndex")
        if index is not None:
            indexes[hole] = int(index)

        for tee, yards in (line.get("yards") or {}).items():
            if yards is None:
                continue
            if not 60 <= int(yards) <= 700:
                # One bad cell, not one bad card: the rest of the tee is still
                # worth having, and the gap is reported at the end.
                continue
            yardages.setdefault(tee, {})[hole] = int(yards)

    n = len(pars)
    if sorted(pars) != list(range(1, n + 1)):
        fail(f"the holes are {sorted(pars)}, which is not 1..{n}")

    if indexes:
        if len(indexes) != n:
            fail(f"{len(indexes)} of {n} holes carry a stroke index; a card "
                 f"prints all of them or none")
        if sorted(indexes.values()) != list(range(1, n + 1)):
            fail(f"the stroke indexes are {sorted(indexes.values())}, "
                 f"which is not a complete 1..{n}")

    # The placeholder test. A directory with no data for a course serves
    # eighteen identical holes, which is self-consistent and passes everything
    # above.
    longest = max(yardages.items(), key=lambda kv: sum(kv[1].values()),
                  default=(None, {}))
    if len(set(pars.values())) == 1 and longest[1] and len(set(longest[1].values())) == 1:
        fail(f"every hole is par {next(iter(pars.values()))} over "
             f"{next(iter(longest[1].values()))} yards — a placeholder, not a card")

    par_total = sum(pars.values())
    name = card.get("name", "").split("  ")[0].strip()

    out = []
    out.append(f"-- {name}")
    out.append(f"-- {n} holes, par {par_total}, {len(yardages)} tee(s) "
               f"({', '.join(sorted(yardages))})")
    out.append(f"-- Longest tee: {longest[0]} at {sum(longest[1].values())} yards")
    out.append("\n\\set ON_ERROR_STOP on\n\nBEGIN;\n")

    out.append(f"""-- A card a golfer photographed carries ratings that exist nowhere else.
-- Refuse rather than overwrite one.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM scorecards s
               JOIN scorecard_segments g ON g.scorecard_id = s.id
               WHERE g.course_id = {course_id}
                 AND s.source = 'golfer-submitted-scorecard') THEN
        RAISE EXCEPTION 'Course {course_id} already carries a golfer-submitted card.';
    END IF;
END $$;
""")

    source = f"mscorecard.com/{cid}; all {len(yardages)} tees"
    out.append(f"DELETE FROM holes WHERE course_id = {course_id};")
    out.append("INSERT INTO holes (course_id, hole_number, par, playing_length_meters,")
    out.append("    accuracy_class, verification_status, confidence,")
    out.append("    source, publisher, license, effective_date, version, created_at, updated_at)")
    out.append("VALUES")
    rows = []
    for hole in sorted(pars):
        metres = longest[1].get(hole)
        length = f"{metres * YARD_M:.2f}" if metres else "NULL"
        rows.append(f"  ({course_id}, {hole}, {pars[hole]}, {length}, "
                    f"'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 60.0, "
                    f"'{source}', 'mscorecard.com contributors', 'community-contributed', "
                    f"CURRENT_DATE, 1, now(), now())")
    out.append(",\n".join(rows) + ";")

    out.append(f"""
UPDATE courses SET holes_count = {n}, par_total = {par_total}, updated_at = now()
WHERE id = {course_id};

DELETE FROM scorecards WHERE id IN (
    SELECT s.id FROM scorecards s JOIN scorecard_segments g ON g.scorecard_id = s.id
    WHERE g.course_id = {course_id});

INSERT INTO scorecards (facility_id, name, holes_count, par_total,
    source, publisher, license, accuracy_class, verification_status,
    effective_date, created_at, updated_at)
SELECT c.facility_id, c.name, {n}, {par_total},
    '{source}', 'mscorecard.com contributors', 'community-contributed',
    'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', CURRENT_DATE, now(), now()
FROM courses c WHERE c.id = {course_id};

INSERT INTO scorecard_segments (scorecard_id, position, course_id)
SELECT currval('scorecards_id_seq'), 1, {course_id};
""")

    out.append("INSERT INTO scorecard_holes (scorecard_id, hole_number, par, stroke_index)")
    out.append("VALUES")
    rows = [f"  (currval('scorecards_id_seq'), {h}, {pars[h]}, "
            f"{indexes.get(h, 'NULL')})" for h in sorted(pars)]
    out.append(",\n".join(rows) + ";")

    gaps = []
    for tee in sorted(yardages):
        by_hole = yardages[tee]
        missing = [h for h in sorted(pars) if h not in by_hole]
        if missing:
            gaps.append(f"{tee} has no yardage for hole(s) {missing}")
        out.append(f"""
-- {tee}: {len(by_hole)} hole(s), {sum(by_hole.values())} yards
INSERT INTO scorecard_tees (scorecard_id, name, gender)
VALUES (currval('scorecards_id_seq'), '{tee.replace("'", "''")}', 'UNSPECIFIED');""")
        out.append("INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)")
        out.append("VALUES")
        rows = [f"  (currval('scorecard_tees_id_seq'), {h}, {by_hole[h]})"
                for h in sorted(by_hole)]
        out.append(",\n".join(rows) + ";")

    out.append("\nCOMMIT;")
    print("\n".join(out))

    print(f"\n{n} holes, par {par_total}, {len(indexes)} stroke index(es), "
          f"{len(yardages)} tees, {sum(len(v) for v in yardages.values())} yardages",
          file=sys.stderr)
    for gap in gaps:
        print(f"  gap: {gap}", file=sys.stderr)


if __name__ == "__main__":
    main()
