#!/usr/bin/env python3
"""Load a club card the operator transcribed, once it agrees with itself.

    python3 load_operator_card.py <CARD_NAME> <course_id> [--drop Red,Blue] > card.sql

The cards live in operator_cards/cards.py, one dict each: the tee names, a row
per hole as (hole, par, stroke index, *yards per tee), and the OUT, IN and
TOTAL the source prints for every tee.

WHY THE TOTALS MATTER MORE THAN THE CELLS
-----------------------------------------
These arrive as tables rather than photographs, and a table can be a faithful
transcription or a reconstruction — there is no way to tell by looking. The
printed totals are what tells them apart: eighteen holes across five tees is
ninety numbers, and a table that sums to the OUT, IN and TOTAL it states for
every one of five tees was not invented.

It caught real errors. Royal Ninh Bình's file silently filled a blank Gold cell
with the Blue value and left the total unchanged, so its Gold column read 3,053
against a printed 2,741 — the photograph of the same card was self-consistent
and the file was not. PGA Ocean's five OUT totals were each about 200 yards
over, which is a table built from a different tee configuration. Neither was
loaded.

Where only some tees disagree, `--drop` leaves those out and takes the rest: a
Red column that misses its total by ten yards says one Red cell is wrong and
gives no way to find it, but it says nothing about Black.

THE CHECK THAT MATTERS MOST
---------------------------
No two courses may share a par sequence and a stroke index sequence.

Everything else here tests a table against itself, and that is exactly what a
generated table passes: the generator computes the totals from the numbers it
invented, so they agree perfectly. Twelve of the tables supplied for this
project carried the same eighteen pars AND the same eighteen stroke indexes as
each other — Corn Hill, Yên Bái Star, Silk Path, FLC's Ocean Dunes, ANARA,
Tuần Châu, Xuân Thành, Yên Dũng, Vinpearl Nha Trang and more. Two real courses
do not agree on all thirty-six of those numbers. Nine had already been loaded
before anyone compared them to each other.

So this compares every incoming card against every card already stored. It is
the only check here that cannot be satisfied by a table that is internally
tidy, because it asks a question about the world rather than about the table.

It runs where the stored cards are, not here: this script emits SQL and never
opens a connection, so the check is a `DO` block at the top of the transaction
that reads `scorecard_holes` and raises. That also makes it correct at the
moment of the write rather than at the moment of the transcription — two cards
generated from one template and loaded an hour apart would otherwise both pass.

A card with no stroke index row cannot be checked this way and is not refused
for it — par alone is far too weak, real courses share par sequences. The
script says so on stderr, and that card rests on its totals alone.

WHAT ELSE IS CHECKED
--------------------
  * par sums to the stated OUT, IN and TOTAL
  * every tee sums to its stated OUT, IN and TOTAL
  * stroke indexes are n distinct values inside 1..2n
  * no hole is longer off a shorter tee than off a longer one

The last is new here, and is what flagged Royal's blank cell: tees on one hole
run long to short, so a Gold that reads under its own Blue is a misprint.

And the arithmetic that needs no card to justify it: holes numbered 1..n with
none missing, par between 3 and 6, a yardage between 60 and 700.

Red is written as the ladies' tee where the source labels it "(Nữ)". Every
other tee is UNSPECIFIED — the source does not say, and reading an unlabelled
rating as the men's would be a guess that looks like data.

THE CARD FORMAT
---------------
    CARDS = {
        "DAI_LAI_C": {
            "club": "Đại Lải Star Golf & Country Club",
            "source": "club B+C card supplied by the operator",
            "tees": ["Black", "Blue", "White", "Red (Nữ)"],
            # hole, par, stroke index (None if the card prints no index row),
            # then one yardage per name in "tees", in that order.
            "holes": [
                (1, 5, None, 566, 542, 500, 481),
                ...
            ],
            # What the source prints beside each row. Eighteen holes take
            # (OUT, IN, TOTAL); a nine takes the one number it prints.
            "totals": {
                "par": 36,
                "Black": 3398, "Blue": 3196, "White": 2992, "Red (Nữ)": 2812,
            },
            # Optional, and only where the card states whose rating it is.
            "ratings": {"Red (Nữ)": {"LADIES": (71.2, 124)}},
        },
    }
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).parent / "operator_cards"))

YARD_M = 0.9144

# What a card writes when it labels a column as the women's tee. Anything else
# is UNSPECIFIED; see the note at the top about unlabelled ratings.
LADIES_MARKS = ("(nữ)", "(nu)", "(ladies)", "(women)", "(ladies')")


def fail(message):
    sys.exit(f"REFUSED: {message}")


def note(message):
    print(f"  {message}", file=sys.stderr)


def quote(text):
    return text.replace("'", "''")


def split_tee(name):
    """"Red (Nữ)" → ("Red", "LADIES"). Anything unlabelled stays UNSPECIFIED."""
    lowered = name.lower()
    for mark in LADIES_MARKS:
        if lowered.endswith(mark):
            return name[: -len(mark)].strip(), "LADIES"
    return name.strip(), "UNSPECIFIED"


def printed(totals, key, n):
    """The OUT, IN and TOTAL the source prints for one row.

    Eighteen holes take three numbers. A nine prints one, and stating it as a
    bare int rather than a one-tuple is how every card supplied writes it.
    """
    if key not in totals:
        fail(f"the card prints no total for {key}; that total is the whole "
             f"reason to trust the column beneath it")
    value = totals[key]
    if isinstance(value, int):
        value = (value,)
    value = tuple(value)

    if n == 18:
        if len(value) != 3:
            fail(f"{key} states {value}; eighteen holes print OUT, IN and TOTAL")
        if value[0] + value[1] != value[2]:
            fail(f"{key} prints OUT {value[0]} and IN {value[1]}, which is "
                 f"{value[0] + value[1]}, against its own TOTAL of {value[2]}")
        return value
    if len(value) == 1:
        return (value[0], None, value[0])
    fail(f"{key} states {value}; a nine prints one total")


def read_card(name):
    try:
        import cards
    except ModuleNotFoundError:
        fail("operator_cards/cards.py is not there. The transcriptions were "
             "removed in 04e32a0 — they shared a template. Put the card back "
             "in that file, in the format at the top of this script.")
    card = getattr(cards, "CARDS", {}).get(name)
    if not card:
        known = ", ".join(sorted(getattr(cards, "CARDS", {}))) or "none"
        fail(f"no card called {name} in operator_cards/cards.py (has: {known})")
    return card


def read_holes(card, tees):
    """The card's rows, as pars, stroke indexes and a yardage table per tee."""
    pars, indexes, yardages = {}, {}, {tee: {} for tee in tees}
    all_tees = card["tees"]

    for row in card["holes"]:
        if len(row) != 3 + len(all_tees):
            fail(f"row {row[0]} carries {len(row) - 3} yardage(s) against "
                 f"{len(all_tees)} tees; the row and the tee list disagree")
        hole, par, index = row[0], row[1], row[2]

        if not 3 <= par <= 6:
            fail(f"hole {hole} says par {par}; a hole is a 3, 4, 5 or 6")
        pars[hole] = par
        if index is not None:
            indexes[hole] = index

        for tee, yards in zip(all_tees, row[3:]):
            if tee not in yardages or yards is None:
                continue
            if not 60 <= yards <= 700:
                fail(f"hole {hole} off {tee} reads {yards} yards, which is a "
                     f"misread of the wrong row rather than a hole")
            yardages[tee][hole] = yards

    n = len(pars)
    if sorted(pars) != list(range(1, n + 1)):
        fail(f"the holes are {sorted(pars)}, which is not 1..{n}")
    if n not in (9, 18):
        fail(f"the card has {n} holes; a course is a nine or an eighteen")
    return pars, indexes, yardages


def check_sums(label, by_hole, stated, n):
    """A row against the OUT, IN and TOTAL printed beside it."""
    missing = [h for h in range(1, n + 1) if h not in by_hole]
    if missing:
        fail(f"{label} has no value for hole(s) {missing}; a column that does "
             f"not add up cannot be checked against the total beside it")

    out = sum(by_hole[h] for h in range(1, min(n, 9) + 1))
    inn = sum(by_hole[h] for h in range(10, n + 1)) if n == 18 else None
    total = out + (inn or 0)

    want_out, want_in, want_total = stated
    if out != want_out or (n == 18 and inn != want_in) or total != want_total:
        got = f"{out} / {inn} / {total}" if n == 18 else str(total)
        want = (f"{want_out} / {want_in} / {want_total}" if n == 18
                else str(want_total))
        fail(f"{label} adds up to {got}, and the card prints {want}. One cell "
             f"in that column is wrong and the card does not say which — "
             f"`--drop {label}` takes the rest and leaves this one out.")


def check_indexes(indexes, n):
    if not indexes:
        return
    if len(indexes) != n:
        fail(f"{len(indexes)} of {n} holes carry a stroke index; a card prints "
             f"all of them or none")
    # n distinct values inside 1..2n, not 1..n: a nine belonging to a rotation
    # carries the indexes it has when played as half of an eighteen, so each of
    # Vinpearl Phú Quốc's three nines runs 1,3,5..17.
    values = sorted(indexes.values())
    if len(set(values)) != n or values[0] < 1 or values[-1] > 2 * n:
        fail(f"the stroke indexes are {values}, which is not {n} distinct "
             f"values inside 1..{2 * n}")


def check_tee_order(yardages, order, n):
    """On one hole the tees run long to short.

    This is what flagged Royal Ninh Bình: a blank Gold cell had been filled
    with the Blue value beside it, and Gold is the longer tee, so the copy read
    shorter than the tee it was copied from.
    """
    faults = []
    for hole in range(1, n + 1):
        for longer, shorter in zip(order, order[1:]):
            a, b = yardages[longer].get(hole), yardages[shorter].get(hole)
            if a is None or b is None:
                continue
            if a < b:
                faults.append(f"hole {hole}: {longer} reads {a} against "
                              f"{shorter}'s {b}")
    if faults:
        fail("a hole reads longer off the shorter tee, which is a misprint:\n  "
             + "\n  ".join(faults))


def duplicate_card_guard(course_id, pars, indexes, n):
    """The cross-course check, as SQL, because that is where the cards are."""
    par_sig = ",".join(str(pars[h]) for h in range(1, n + 1))
    index_sig = ",".join(str(indexes.get(h, -1)) for h in range(1, n + 1))
    return f"""-- No two courses share a par sequence AND a stroke index sequence. Twelve of
-- the tables supplied for this project shared both with each other, and every
-- other check here passed all twelve: a generated table computes its totals
-- from the numbers it invented, so it agrees with itself perfectly. This is
-- the one question asked about the world rather than about the table.
DO $$
DECLARE
    clash text;
BEGIN
    SELECT string_agg(label, '; ' ORDER BY label) INTO clash FROM (
        SELECT f.name || ' / ' || s.name AS label
        FROM scorecards s
        JOIN scorecard_holes sh ON sh.scorecard_id = s.id
        JOIN golf_facilities f ON f.id = s.facility_id
        WHERE NOT EXISTS (SELECT 1 FROM scorecard_segments g
                          WHERE g.scorecard_id = s.id AND g.course_id = {course_id})
        GROUP BY s.id, f.name, s.name
        HAVING string_agg(sh.par::text, ',' ORDER BY sh.hole_number) = '{par_sig}'
           AND string_agg(coalesce(sh.stroke_index, -1)::text, ',' ORDER BY sh.hole_number) = '{index_sig}'
    ) AS clashes;

    IF clash IS NOT NULL THEN
        RAISE EXCEPTION 'This card carries the same % pars AND the same % stroke indexes as %. Two real courses do not agree on all % of those numbers; a template does.',
            {n}, {n}, clash, {2 * n};
    END IF;
END $$;
"""


def emit(card, course_id, pars, indexes, yardages, order, ratings, n):
    club = card["club"]
    source = card.get("source") or "club card supplied by the operator"
    source = f"{source}; every tee sums to its printed OUT, IN and TOTAL"
    par_total = sum(pars.values())
    longest = yardages[order[0]] if order else {}

    out = [f"-- {club}: {card.get('name', '')}".rstrip(": "),
           f"-- {n} holes, par {par_total}, {len(order)} tee(s) "
           f"({', '.join(order)})",
           f"-- Longest tee: {order[0]} at {sum(longest.values())} yards"
           if order else "-- No tee carries distances",
           "",
           "\\set ON_ERROR_STOP on",
           "",
           "BEGIN;",
           ""]

    if indexes:
        out.append(duplicate_card_guard(course_id, pars, indexes, n))
    else:
        out.append("-- This card prints no stroke index row, so the cross-course\n"
                   "-- duplicate check cannot run: par alone is far too weak, real\n"
                   "-- courses share par sequences. It rests on its totals alone.\n")

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

    out.append(f"DELETE FROM holes WHERE course_id = {course_id};")
    out.append("INSERT INTO holes (course_id, hole_number, par, playing_length_meters,")
    out.append("    accuracy_class, verification_status, confidence,")
    out.append("    source, publisher, license, effective_date, version, created_at, updated_at)")
    out.append("VALUES")
    rows = []
    for hole in range(1, n + 1):
        yards = longest.get(hole)
        length = f"{yards * YARD_M:.2f}" if yards else "NULL"
        rows.append(f"  ({course_id}, {hole}, {pars[hole]}, {length}, "
                    f"'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', 60.0, "
                    f"'{quote(source)}', '{quote(club)}', 'club-published', "
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
    '{quote(source)}', '{quote(club)}', 'club-published',
    'D_UNVERIFIED_COMMUNITY', 'UNVERIFIED', CURRENT_DATE, now(), now()
FROM courses c WHERE c.id = {course_id};

INSERT INTO scorecard_segments (scorecard_id, position, course_id)
SELECT currval('scorecards_id_seq'), 1, {course_id};
""")

    out.append("INSERT INTO scorecard_holes (scorecard_id, hole_number, par, stroke_index)")
    out.append("VALUES")
    rows = [f"  (currval('scorecards_id_seq'), {h}, {pars[h]}, "
            f"{indexes.get(h, 'NULL')})" for h in range(1, n + 1)]
    out.append(",\n".join(rows) + ";")

    for tee in order:
        by_hole = yardages[tee]
        name, gender = split_tee(tee)
        # A card may print both a men's and a ladies' rating against one tee.
        # Each becomes its own row — the unique key is (card, name, gender) —
        # and both share the tee's yardages.
        stated = ratings.get(tee) or {gender: (None, None)}
        for row_gender, (course_rating, slope) in sorted(stated.items()):
            out.append(f"""
-- {tee}: {len(by_hole)} holes, {sum(by_hole.values())} yards"""
                       + (f", {row_gender} {course_rating}/{slope}"
                          if course_rating else ""))
            out.append("INSERT INTO scorecard_tees (scorecard_id, name, gender, "
                       "course_rating, slope_rating)")
            out.append(f"VALUES (currval('scorecards_id_seq'), '{quote(name)}', "
                       f"'{row_gender}', "
                       f"{course_rating if course_rating else 'NULL'}, "
                       f"{slope if slope else 'NULL'});")
            out.append("INSERT INTO scorecard_tee_yardages (scorecard_tee_id, hole_number, yards)")
            out.append("VALUES")
            out.append(",\n".join(
                f"  (currval('scorecard_tees_id_seq'), {h}, {by_hole[h]})"
                for h in range(1, n + 1)) + ";")

    out.append("\nCOMMIT;")
    return "\n".join(out)


def main():
    argv = sys.argv[1:]
    dropped = []
    if "--drop" in argv:
        at = argv.index("--drop")
        dropped = [t.strip() for t in argv[at + 1].split(",") if t.strip()]
        del argv[at:at + 2]
    if len(argv) != 2:
        sys.exit(__doc__)
    name, course_id = argv[0], int(argv[1])

    card = read_card(name)
    unknown = [t for t in dropped if t not in card["tees"]]
    if unknown:
        fail(f"--drop names {unknown}, which this card does not have "
             f"({', '.join(card['tees'])})")
    tees = [t for t in card["tees"] if t not in dropped]

    pars, indexes, yardages = read_holes(card, tees)
    n = len(pars)
    totals = card["totals"]

    check_sums("par", pars, printed(totals, "par", n), n)
    for tee in tees:
        check_sums(tee, yardages[tee], printed(totals, tee, n), n)
    check_indexes(indexes, n)

    # Longest first, by the total the card prints — the order the monotonic
    # check needs, and the tee `holes.playing_length_meters` is measured at.
    order = sorted(tees, key=lambda t: sum(yardages[t].values()), reverse=True)
    check_tee_order(yardages, order, n)

    ratings = card.get("ratings", {})
    unknown = [t for t in ratings if t not in card["tees"]]
    if unknown:
        fail(f"the card states ratings for {unknown}, which are not its tees")

    print(emit(card, course_id, pars, indexes, yardages, order, ratings, n))

    print(f"\n{card['club']}: {n} holes, par {sum(pars.values())}, "
          f"{len(indexes)} stroke index(es), {len(order)} tee(s), "
          f"{sum(len(yardages[t]) for t in order)} yardages", file=sys.stderr)
    for tee in dropped:
        note(f"dropped: {tee}")
    if not indexes:
        note("no stroke index row, so the cross-course duplicate check cannot "
             "run — this card rests on its totals alone")


if __name__ == "__main__":
    main()
