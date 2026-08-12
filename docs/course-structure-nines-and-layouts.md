# Multi-course facilities and nines — what the model can say, and what it cannot

Đồng Mô is three courses. Long Biên is three nines. The database says each of
them is one eighteen-hole course called "— Championship", and one of those two
statements can be fixed by typing and the other cannot.

State as of `V39`, against the production database on `vps-api.vnteki.com`.

## 1. What the schema allows today

`V16__facilities_courses_holes.sql` builds three levels:

```
golf_facilities  1 ──── N  courses  1 ──── N  holes
                            │                   └─ hole_number, unique per course
                            └─ tee_sets 1 ── N tee_boxes
```

A facility may hold many courses. **Pattern A — a property with several full
eighteens — is already representable.** Kings Island as three `courses` rows
under one `golf_facilities` row needs no migration at all, only data.

## 2. What the data actually contains

| | count |
|---|---|
| Facilities | 73 |
| Courses | 73 |
| Facilities with more than one course | **0** |
| Courses named `… — Championship` | 73 |
| Hole rows | 1,080 = 60 × 18 |
| Courses with no hole rows | 13 |

Every course was written by `scripts/dev/seed_courses_vn.sql:105`:

```sql
(facilities[i][1] || ' — Championship', fid, 18, 72, …)
```

One course per facility, eighteen holes, par 72 — a seed shape, never a survey.
The roster pass added thirteen more without holes, three of which already
contradict the eighteen:

| id | name | holes_count | hole rows |
|---|---|---|---|
| 1001 | Yên Bái Star Golf & Resort — Championship | 27 | 0 |
| 1003 | Glory Golf Club — Championship | 9 | 0 |
| 1012 | Eschuri Vũng Bầu Golf — Championship | 27 | 0 |

A row that says 27 holes and calls itself "Championship" is not a course anyone
can play a round on. It is a facility wearing a course's clothes.

**The source data already knew better.** The OSM snapshot
(`osm-vietnam-golf-2026-08-08.json.gz`) carries 81 `leisure=golf_course`
polygons for these 73 facilities, and the extras are exactly the case in
question — `Mountain View - BRG Kings Island` and `King's Island Golf` are two
separate ways, and `KN Golf Links Cam Ranh` appears twice. The import collapsed
each property to one facility and invented one course inside it. The
distinction was in the input and was thrown away.

## 3. The two shapes, and why only one of them is a schema problem

**A. Several full 18s at one property** — Đồng Mô (King's, Mountainview,
Lakeside), KN Cam Ranh, the Vinpearl properties. Each course is played as a
round on its own. *Representable today.* Three `courses` rows, 18 holes each,
one facility. The work is data entry and a search UI that shows the course name
next to the facility name — which `CourseSearchResultDto` already carries
(`facilityName` + `courseName`).

**B. N nines combined into a round** — Long Biên (đường A, B, C), and every
27- or 36-hole club that rotates its loops. The thing a golfer plays is not a
course in the table; it is *a pair of nines chosen on the day*: A+B this
morning, B+C this afternoon. **Not representable today, at any level.**

## 4. What breaks under shape B — concretely

1. **Par is written wrong into every score.**
   `ScoreServiceImpl.resolvePar` (line 294) resolves par as
   `holes.find(course_id, hole_number)` — the round's hole number *is* the
   course's hole number. Play A+C on a 27-hole row and round hole 10 resolves
   to hole 10 of the 27, which is nine B's first hole. The wrong par is stored
   in `score_entries.par`, and every statistic — to-par, birdie counts,
   strokes-gained — derives from that column. Silent, not an error.

2. **The numbering spaces collide.**
   `uq_hole_course_number (course_id, hole_number)` needs 1..27 for the
   physical holes, while a round needs 1..18. One column cannot be both.

3. **A hole cannot say which nine it belongs to.** There is no
   `nine`/`loop`/`đường` concept anywhere in the schema — `\d holes` has
   `course_id`, `hole_number`, `par` and geometry, nothing else.

4. **Nothing can be rated.** `tee_sets` has no `course_rating` and no
   `slope_rating`; `holes` has no `stroke_index`. In WHS each 18-hole
   *combination* is rated per tee and carries its own stroke-index allocation
   (odd numbers on one nine, even on the other). Handicapping A+B is not a
   variation on handicapping the course; it is a different rated object.

5. **Packages are all-or-nothing.** `course_package_manifest.course_id` (V32)
   makes the download unit the whole 27 holes or nothing.

6. **The phone is already waiting for this.**
   `round_setup_bloc.dart:260` builds a `LayoutOption` list — and hardcodes it
   to a single entry named after the facility. `_LayoutSelector` hides itself
   when `layouts.length <= 1`, so the dropdown has never once appeared. The UI
   for choosing a configuration exists; there is no data to put in it.

## 5. The organisation, as decided

Vocabulary, fixed:

| level | Vietnamese | what it is | table |
|---|---|---|---|
| property | **sân golf** | the club, the gate you drive through | `golf_facilities` |
| named unit | **đường** | 9 or 18 holes the club names and signs | `courses` |
| what was played | **vòng** | an ordered list of đường, chosen by the golfer | `rounds` + `round_segments` |

```
sân golf             BRG Kings Island          Long Biên
   │
   └── đường         King's Course (18)        Đường A (9)
                     Mountainview (18)         Đường B (9)
                     Lakeside (18)             Đường C (9)
                       └── holes 1..N, numbered inside the đường
```

There is no table of published combinations. **The golfer picks the đường at
round setup** — one for an eighteen, two for a 27-hole club — and the round
records what was chosen:

```sql
-- Which đường were played, in the order they were played.
CREATE TABLE round_segments (
    round_id   UUID     NOT NULL REFERENCES rounds(id) ON DELETE CASCADE,
    position   SMALLINT NOT NULL,             -- 1 = the first nine
    course_id  BIGINT   NOT NULL REFERENCES courses(id),
    PRIMARY KEY (round_id, position)
);
```

A round on a single eighteen gets one row and behaves exactly as today. Par
resolution walks the segments by cumulative hole count:

```
round hole 12 on A+B  →  A holds 9  →  segment 2 (B), B's hole 3
```

This is why the segments carry a `position` and not a hardcoded nine: a club
that pairs a nine with a par-3 loop, or plays A+A, still resolves correctly.

**What this costs:** a golfer-chosen combination cannot carry a course rating,
because a rating is issued against a specific published eighteen. Net scoring
and handicap differentials for 27-hole clubs are therefore out of reach until
someone publishes ratings — which is the accepted trade for not making an
operator maintain a combination table.

**Tees stay on the đường.** `tee_sets.course_id` is unchanged, so "Trắng" at
Long Biên is three rows, one per đường. Round setup asks for a tee per segment;
where the colours match — they usually do — the second selector can default to
the first one's name and stay out of the way.

## 6. Stroke index — per pairing, submitted by golfers, reviewed by admins

The index is printed on the club's scorecard and exists in no open dataset.
It is also the last thing standing between the app and net scoring: without it
no handicap allocation can be computed, not for a 27-hole club and not for the
60 eighteens that already have hole data.

**It cannot live on the hole.** A club with đường A, B and C prints a card per
pairing, and the index on it runs 1..18 across the two nines it was printed
for. Hole 3 of đường A is index 7 on the A+B card and something else on A+C. A
column on `holes` would be storing one card's numbers and claiming they belong
to the hole.

So the card is the row:

```sql
CREATE TABLE scorecards (            -- one printed card, for one pairing
    id, facility_id, name,           -- 'A + B'
    holes_count CHECK (IN (9,18)), par_total,
    source/publisher/verification_status/effective_date,
    UNIQUE (facility_id, name));

CREATE TABLE scorecard_segments (    -- which đường, in which order
    scorecard_id, position CHECK (BETWEEN 1 AND 2), course_id,
    PRIMARY KEY (scorecard_id, position),
    UNIQUE (scorecard_id, course_id));

CREATE TABLE scorecard_holes (
    scorecard_id, hole_number CHECK (BETWEEN 1 AND 18),
    par CHECK (BETWEEN 3 AND 6), stroke_index CHECK (BETWEEN 1 AND 18),
    PRIMARY KEY (scorecard_id, hole_number),
    UNIQUE (scorecard_id, stroke_index));   -- an index is handed out once
```

A club with a single eighteen has one card with one segment — the same shape,
nothing special about it. Par is read from the card when one matches the
round's pairing, and falls back to `holes.par` when none does; a round on a
pairing nobody has photographed still scores, it just cannot compute net.

**Nothing new is needed for the review side.** `course_corrections` (V23)
already carries reporter → evidence → queue → approve / reject / request info /
convert-to-draft, and the portal already renders that queue
(`apps/portal/src/components/corrections/`, nine components). What it does not
have is a correction that is not geometric: `chk_correction_type` allows
`GEOMETRY, PIN_POSITION, BUNKER, WATER, OB, CART_PATH, LANDMARK,
COURSE_CONDITION, GREEN_SPEED, OTHER` — every one of them a shape on the
ground. `SCORECARD` joins the list, carrying the proposed card in
`proposed_scorecard`:

```json
{"name": "A + B", "segmentCourseIds": [12, 13],
 "holes": [{"hole": 1, "par": 4, "strokeIndex": 7}, …]}
```

One photograph is one queue item and one decision, not eighteen of them.
`reporter_evidence_url` already exists for the photo.

## 7. Implementation slices

Each slice ships on its own and leaves the app working.

**Slice 1 — schema.** `round_segments`, the three `scorecards` tables, and
`course_corrections.proposed_scorecard` + the `SCORECARD` type. Backfill one
`round_segments` row per existing round from `rounds.course_id` — 164 rounds,
all of them with a `course_id`, so the backfill leaves none behind.
Nothing reads the new tables yet.

**Slice 2 — par resolution through segments.** `ScoreServiceImpl.resolvePar`
walks `round_segments` instead of `holes.find(course_id, hole_number)`. With
one segment per round the behaviour is identical, which is what makes it safe
to ship before any đường exists.

**Slice 3 — round setup picks đường.** The API returns a facility's đường;
`round_setup_bloc` stops hardcoding its single `LayoutOption`; the golfer picks
one or two and the round posts its segments. `_LayoutSelector` — already
written, never yet visible — becomes the picker.

**Slice 4 — scorecard submission and review.** Mobile: photograph the card,
type par and index for 9 holes, submit as a `SCORECARD` correction. Portal:
the existing queue gains a table view of the proposed card and an approve that
writes a `scorecards` row with its eighteen lines.

**Slice 5 — the data itself.** `scripts/dev/split_facility_into_duong.sql`
adds the đường of one facility from names you give it. It refuses two things
on purpose: it invents no hole rows — `holes.par` is NOT NULL and eighteen
invented pars is a scorecard for a course nobody has read, so pars arrive
through the SCORECARD queue instead — and it leaves the "— Championship" row
alone, because 164 rounds point at course ids and deleting one takes a
golfer's round with it.

What it needs is the đường names as the club signs them and how many holes
each has. Long Biên and Đại Lải are confirmed as having them; the rest is a
directory pass over 73 clubs, and it is the one part of this work that cannot
be done from inside the repository.

Packages stay keyed on `course_id`: a golfer playing A+B downloads two
packages of nine holes, which is also the granularity the club thinks in.
