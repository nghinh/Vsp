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

## 5. Proposed organisation

Keep the three levels, redefine the middle one, and add the thing that is
actually missing: **the playing configuration**.

```
golf_facility        BRG Kings Island          Long Biên
   │
   ├── course        King's Course (18)        Đường A (9)
   │                 Mountainview (18)         Đường B (9)
   │                 Lakeside (18)             Đường C (9)
   │                   └── holes 1..N, numbered within the course
   │
   └── layout        King's Course             A + B
                     Mountainview              B + C
                     Lakeside                  A + C
                       └── ordered segments → courses
```

- **`courses` becomes the named physical unit the club markets** — an eighteen
  or a nine. "King's Course", "Đường A". This is what the club puts on a sign.
- **Holes are numbered within their course.** Đường A holds holes 1..9.
- **A layout is an ordered list of courses played as one round.** An eighteen
  is the trivial layout of one segment; A+B is two.
- **A round points at a layout**, not at a course.

```sql
CREATE TABLE course_layouts (
    id           BIGSERIAL PRIMARY KEY,
    facility_id  BIGINT NOT NULL REFERENCES golf_facilities(id) ON DELETE CASCADE,
    name         VARCHAR(255) NOT NULL,        -- 'A + B', "King's Course"
    holes_count  INTEGER NOT NULL,
    par_total    INTEGER,
    is_default   BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_layout_facility_name UNIQUE (facility_id, name)
);

CREATE TABLE course_layout_segments (
    layout_id  BIGINT   NOT NULL REFERENCES course_layouts(id) ON DELETE CASCADE,
    position   SMALLINT NOT NULL,              -- 1 = the first nine played
    course_id  BIGINT   NOT NULL REFERENCES courses(id),
    PRIMARY KEY (layout_id, position)
);

-- The flattened scorecard: one row per hole of the round, generated when a
-- layout is created. Makes par resolution a single indexed lookup and keeps
-- the arithmetic out of the client, the sync endpoint and the exporters.
CREATE TABLE layout_holes (
    layout_id          BIGINT  NOT NULL REFERENCES course_layouts(id) ON DELETE CASCADE,
    round_hole_number  INTEGER NOT NULL,       -- 1..18 as the golfer counts
    hole_id            BIGINT  NOT NULL REFERENCES holes(id),
    stroke_index       INTEGER,                -- allocation for THIS layout
    PRIMARY KEY (layout_id, round_hole_number)
);
```

`resolvePar` becomes `layout_holes.find(layout_id, holeNumber) → hole.par`, one
lookup, no division by nine, and it stays correct if a facility ever combines a
nine with something that is not a nine.

Ratings hang off the layout, not the course, because that is where the real
world puts them:

```sql
CREATE TABLE layout_tee_ratings (
    layout_id      BIGINT NOT NULL REFERENCES course_layouts(id) ON DELETE CASCADE,
    tee_set_id     BIGINT NOT NULL REFERENCES tee_sets(id),
    course_rating  NUMERIC(4,1),
    slope_rating   INTEGER CHECK (slope_rating BETWEEN 55 AND 155),
    par            INTEGER,
    PRIMARY KEY (layout_id, tee_set_id)
);
```

## 6. Migration path, in an order that never leaves the app broken

**Step 1 — give every existing course a trivial layout.** One layout per
course, one segment, `is_default = true`, `layout_holes` backfilled from
`holes`. `rounds.layout_id` added nullable and backfilled from `course_id`;
both columns coexist until step 4. Nothing changes for a golfer. 73 layouts,
1,080 layout_holes.

**Step 2 — serve layouts.** Course detail returns the facility's layouts;
`round_setup_bloc` stops hardcoding its single `LayoutOption` and the dropdown
that has always been hidden starts appearing — but still with one entry
everywhere, so no visible change yet.

**Step 3 — split the facilities that are really several courses.** Data work,
not migration. Đồng Mô's one row becomes three courses and three layouts; Long
Biên's becomes three nines and three combinations. Each split needs real hole
data, which is the same blocker as everything else in
`course-geometry-autogen-architecture.md` — the pars are known from the club's
scorecard even when the geometry is not, and pars are all scoring needs.

**Step 4 — make `layout_id` the contract.** Score sync resolves par through
`layout_holes`; `rounds.course_id` becomes derived (the layout's first segment)
or is dropped.

Packages (step 5, independent): key the manifest on `layout_id` so a golfer
playing A+B downloads exactly those eighteen holes, or keep it on `course_id`
and let the phone fetch two packages. The second is less work and matches how
the club thinks about its nines.

## 7. What has to be decided before step 3

1. **Who picks the combination?** Either the club publishes today's eighteen
   ("A+B") and the golfer picks one layout, or the golfer picks two nines at
   round setup and the layout is created on the fly. The first is one dropdown
   and a table the operator maintains; the second needs no operator but cannot
   carry a rating.
2. **Tee colours per nine or per facility?** `tee_sets.course_id` makes a tee
   belong to one nine, so "White at Long Biên" is three rows today. If a tee
   colour is a property of the facility, `tee_sets` wants to move up a level
   before layouts start referencing them.
3. **Where does stroke index come from?** It is on the club's scorecard and
   nowhere in OSM. Without it, net scoring and handicap allocation cannot be
   computed for any layout — including the 60 eighteens that already have hole
   data.
4. **What do we call these in Vietnamese?** The UI has no word for either
   concept yet. "Sân" is the property *and* the course in ordinary speech;
   "đường" is the nine. Suggest: facility = *khu sân*, course = *sân*, layout =
   *vòng đấu* or *tổ hợp sân*.
5. **How many of the 73 are actually multi-course?** The OSM snapshot suggests
   at least three (Kings Island ×2 polygons, KN Cam Ranh ×2). The roster review
   in `vn-golf-roster-review.md` was built one-facility-per-row and did not ask
   the question. Answering it is a directory pass over 73 clubs, not a code
   change, and it decides how much of step 3 there is.
