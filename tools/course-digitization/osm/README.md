# OSM course geometry pipeline

Everything the 50 seeded Vietnamese courses know about where they actually are
comes from OpenStreetMap, and this directory is the only thing that puts it
there. Two scripts, one committed snapshot, no hand-run SQL.

```
fetch_osm.py      network  ->  data/osm-vietnam-golf-<date>.json.gz
build_from_osm.py snapshot ->  database
```

The split matters. Overpass answers a different question every week as the map
grows, so a pipeline that reads the live API is not reproducible — re-running it
next month silently produces different geometry. The snapshot is the input of
record: it is committed, it is what CI and every other machine read, and any row
in the database can be traced back to a line in it.

## Running it

Prerequisites: the schema exists (boot the API once — dev builds it from the
entities, Flyway is off there) and `scripts/dev/seed_courses_vn.sql` has been
loaded, which creates the 50 facilities / 50 courses / 900 holes this pipeline
corrects.

```sh
cd tools/course-digitization/osm

python3 build_from_osm.py                 # dry run: does the whole thing, rolls back, prints the report
python3 build_from_osm.py --apply         # same, commits
python3 build_from_osm.py --print-sql     # emit the SQL and run nothing

python3 fetch_osm.py                      # only when you want a fresher snapshot
```

Nothing to install: standard library only, and `psql` inside the existing
`vsp_postgres` container. Point it elsewhere with
`--psql "psql postgresql://user:pw@host:5432/vsp"`.

`fetch_osm.py` refuses to write a snapshot whose two halves came from different
Overpass mirrors at different replication states. That is not hypothetical: on
the day this was written one public mirror was three months behind the other and
answered the identical query with 13% fewer bunkers, no error, no warning. The
snapshot records `osm_base`, the map timestamp it describes.

Re-running is safe. Against an unchanged snapshot the second run reports 0 for
every update — that is the check that it is idempotent, and it is worth reading
the report for exactly that reason. Derived and imported feature rows are
dropped and rebuilt each run (they have no stable identity to preserve), so
their counts stay constant rather than going to zero.

## What it produces

Current snapshot (2026-08-05), against the standard seed:

| | |
|---|---|
| facilities given real OSM coordinates | 21 of 50 |
| holes with real tee/green points | 61 of 900 |
| greens imported from OSM | 91 (covering 60 holes) |
| greens derived from the green point | 840 |
| bunkers imported from OSM | 332 |
| water hazards imported from OSM | 5 |
| fairway corridors derived | 900 |

Nothing lands above `accuracy_class = D_UNVERIFIED_COMMUNITY` or
`verification_status = PENDING_REVIEW`, and the run report asserts that.

## Why so few holes

`golf=hole` in OSM is a **LINESTRING from tee to green**, not a polygon, and
only about three quarters of them carry the hole number in `ref`. Of 374 hole
lines in Vietnam, 61 can be tied to a specific row in `holes` with enough
confidence to write coordinates. The rest of the country is not mapped
hole-by-hole. That is a gap in OSM, not a timid matcher — closing it is what
`../holes_todo.geojson` and `../import_digitized.py` are for.

## The matching rules, and where the data pushes back

**Facilities** — normalise both names (strip diacritics, lowercase, drop the
generic words *golf, club, resort, course, san, championship, links*), then
accept when either

* string similarity >= 0.90, **or**
* every word of the shorter name appears in the longer one (two words minimum),

*and* the OSM centroid is within 25 km. Matching is greedy and one-to-one: the
strongest pair claims its OSM course first, ways beat relations on a tie.

The word-containment half is not decoration. OSM and the seed disagree about how
much of a name to write down, and the disagreement is systematic:

| seed | OSM | similarity |
|---|---|---|
| BRG Kings Island Golf Resort | Mountain View - BRG Kings Island | 0.70 |
| FLC Hạ Long Golf Club | FLC Ha Long Bay Golf Club & Luxury Resort | 0.67 |
| Đại Lải Star Golf & Country Club | Sân Golf Đại Lải | 0.52 |
| Paradise Vũng Tàu Golf Resort | CLB Golf Vũng Tàu Paradise | 0.47 |

All four are the same place. A pure 0.90 similarity rule finds 17 facilities and
misses every one of them; adding containment finds 21. Requiring two words and a
25 km radius keeps it honest — *Long Thành* and *Long Biên* share a word but not
a word set, so they never collide.

**Holes** — an OSM hole line matches a DB hole when its `ref` equals the hole
number, its centroid is within 3 km of the facility, and its length is within
25% of `playing_length_meters`. The length test is what disambiguates a 36-hole
resort, where two different "hole 1" lines sit a few hundred metres apart. The
assignment is forced one-to-one in both directions; without that, one OSM way
gets written onto two different holes, which is precisely the defect this
pipeline was written to clean up.

A hole line has no guaranteed direction, so the end nearer a `golf=green`
feature is taken as the green end and the line is flipped if needed (3 of 61 in
the current snapshot).

**Features** — each OSM green / bunker / water hazard is attached to the nearest
matched hole line within 45 m (greens) or 60 m (bunkers, water), one hole per
feature. Holes that get no real green fall back to a 14 m buffer around the
green point (~615 m², about right); every hole gets a fairway corridor buffered
around its tee→green line at `length * 0.09` metres, clamped to 18-35 m.

Derived shapes inherit the licence of what they were derived from: buffers built
on OSM points stay ODbL and land as `PENDING_REVIEW`; buffers built on the
synthetic seed points are `publisher = VSP`, `license = internal-derived`, and
land as `UNVERIFIED` — there is nothing at those coordinates for a reviewer to
confirm, so asking for a review would waste their time.

## What it will not touch

A row is protected when `verification_status = 'VERIFIED'` **and**
`source <> 'SEED'` — a human looked at it and signed it off. Protected rows are
never updated, never deleted, and never duplicated by a re-import; the run
report counts them under *skipped* and *kept*.

`source = 'SEED'` rows are deliberately not protected, even though the seed
stamps them `VERIFIED` at 95% confidence. Those coordinates come out of a loop in
`scripts/dev/seed_courses_vn.sql` — `tee = facility + hole_number × 0.0008°` —
and are wrong by kilometres. Replacing them is the whole point. It is not
silent: the report line *"synthetic SEED coordinate replaced"* counts every one,
and `--respect-seed-verified` turns the behaviour off (after which the pipeline
has almost nothing left to do).

## Convergence

If a hole carries an `osm:` source that the current snapshot no longer produces
— the way was deleted upstream, its `ref` changed, or an earlier hand-run
assigned one way to two holes — the pipeline resets it to the seed's clubhouse
offset and relabels it `derived:facility-offset`, `UNVERIFIED`, confidence 0.20.
Otherwise the database keeps geometry that no input explains, which is the exact
condition this pipeline exists to end. Eight holes were in that state when it
first ran.

## What else is staged

`osm_golf_staging` also carries `kind = 'course_boundary'`: the outline of each
`leisure=golf_course` way (156 of them). Nothing in this pipeline uses it — the
satellite pipeline does, to tell a water hazard from the fish pond over the
fence. It is staged here because this is where OSM data enters the system.

## Why there is no migration

The pipeline writes rows, not columns. `osm_golf_staging` and `osm_hole_match`
are its own scratch/audit tables and it drops and rebuilds them itself, so there
is nothing for Flyway to own — and it could not own them anyway, since the
Flyway schema still uses UUID keys where the entities use `bigint` (see the note
in `application-dev.yml`), so a migration referencing `holes(id)` would not
apply cleanly there.

## Licensing

OpenStreetMap data, © OpenStreetMap contributors, ODbL-1.0. Every imported row
records `source = 'osm:way/<id>'`, `publisher = 'OpenStreetMap contributors'`,
`license = 'ODbL-1.0'`, and shapes derived from OSM geometry keep the licence.
Do not strip that — ODbL attribution travels with derivative works, and the
`data_licenses` / package-manifest machinery reads these columns.
