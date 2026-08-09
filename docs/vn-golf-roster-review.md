# Vietnam golf roster — what is in the database, and what is still missing

State after `seed_courses_vn_osm.sql`, `seed_courses_vn_roster.sql`,
`seed_courses_vn_located.sql` and `build_from_osm.py --apply` against the
`2026-08-08` snapshot.

| | | was |
|---|---|---|
| Facilities | 73 | 50 |
| Courses | 73 | 50 |
| Holes | 1,080 | 900 |
| On a real coordinate (`osm:…`) | 52 | 21 |
| Known by name only (`roster:name-only`, `location IS NULL`) | 13 | — |
| Still on an invented point (`seed:approximate-facility-point`) | 8 | 29 |

**74 operating courses are believed to exist in Vietnam; 73 are in here.** The
missing one is deliberate — see "excluded on purpose" below. The "roughly a
hundred" figure that gets quoted counts approved projects, not playable
courses: two independent bookable-club directories list 71 and ~72 real clubs,
and Vietnamese Wikipedia's own text says 58.

## How a row gets its location

| Source | Meaning | Rows |
|---|---|---|
| `osm:way/…`, `osm:node/…` | Real, ODbL, accurate to the drawn geometry | 52 |
| `roster:name-only` | `location IS NULL`. The course exists; nobody has located it | 13 |
| `seed:approximate-facility-point` | Somebody typed a coordinate to two decimal places. Wrong by up to 31 km in the cases now corrected | 8 |

Nothing claims better than `D_UNVERIFIED_COMMUNITY`. A boundary centroid is not
a survey.

**`location IS NULL` travels all the way to the phone.** The API omits
`latitude`/`longitude`, the client models them nullable, and the course lists
with no distance beside it. It used to be coerced to `0.0` on the client, which
is not "unknown" — it is a point in the Gulf of Guinea that nothing downstream
could tell from a real answer.

## Why pairings are adjudicated by hand

Name similarity plus a distance ceiling looks like the right tool and is not.
Folded to ASCII, *Sân Golf Đầm Vạc* and *Tam Đảo Golf Resort* become `dam vac`
and `tam dao` — 0.67 similar by coincidence of letters, 18 km apart, which
passes a 25 km gate. Applied automatically it moves Tam Đảo onto a lake in Vĩnh
Yên. (Đầm Vạc is Heron Lake.) The same trap caught *Tràng An*: the club is at Kỳ
Phú, Nho Quan, and the forty-odd OSM objects named "Tràng An" 30 km away are the
scenic area's roads and homestays.

Six unnamed polygons were identified by two independent investigations — one
working forward from course directories to locations, one working backward from
OSM geometry to identities. They agreed on all six. That agreement, not a
threshold, is why those rows shipped.

## Open item 1 — 8 facilities still on an invented point

| Facility | Province | Why not fixed |
|---|---|---|
| Diamond Bay Golf & Villas | Khánh Hòa | No golf geometry anywhere in Nha Trang. The only candidate is a resort-brand node, and two Diamond Bay properties share that brand on the same boulevard |
| Legend Valley Country Club | Hà Nam | OSM has nothing |
| Stone Valley Golf Resort | Hà Nam | OSM has nothing |
| Tràng An Golf & Country Club | Ninh Bình | OSM has nothing at Kỳ Phú, Nho Quan (address corrected from the wrong "TP. Ninh Bình") |
| West Lakes Golf & Villas | Long An | OSM has nothing |
| Xuân Thành Golf & Resort | Hà Tĩnh | OSM has nothing |
| Yên Dũng Resort & Golf Club | Bắc Giang | OSM has nothing. Also trades as *Amber Hills Golf & Resort* |
| The Grand Hồ Tràm Golf Club | Bà Rịa – Vũng Tàu | Probably not a separate course — see below |

Each was checked twice: a locality bounding box, and a Vietnam-wide sweep of
every `leisure=golf_course` and `golf=*` object. These need a boundary drawn, in
OSM or in the portal geometry editor.

### The Grand Hồ Tràm is probably The Bluffs under another name

`way/516689819` is The Bluffs: `node/4264413692` carries `name:vi="Bluffs Golf
Club"` and sits 0.15 km inside the ring, while the whole Grand Ho Tram
casino/hotel cluster is 1.0–1.6 km north-east and outside it. There is no second
polygon to give The Grand, and the operator's own material describes one 18-hole
Greg Norman course, *The Bluffs Grand Ho Tram*.

Both investigations reached this independently and both recommend merging row 47
into row 46. **Not done** — deleting a facility is not reversible from a seed
file, and the call is the product owner's.

## Open item 2 — 13 courses known by name only

`location IS NULL`, no `holes` rows. `holes.par` is `NOT NULL`, so writing a
hole means inventing a par, and eighteen invented pars is a scorecard for a
course nobody has seen. Scoring does not need them; the map tab shows the
unsurveyed view, which is the truth.

Lào Cai, Yên Bái, Phú Thọ and Thái Nguyên have no golf mapping in OSM at all:

Sapa Grand · Yên Bái Star · Văn Lang Empire T&T · Glory (Thái Nguyên) · Stone
Highland (Bắc Giang — *not* Stone Valley, Hà Nam) · Corn Hill · Silk Path Đông
Triều · Montaña (Hòa Bình) · Blue Diamond (Quảng Bình) · Golden Sands (Huế) ·
ANARA Bình Tiên · Vinpearl Golf Léman Củ Chi · Eschuri Vũng Bầu

## Open item 3 — one course excluded on purpose

**FLC Quy Nhơn Golf Links** is in the database by name only. The single OSM
polygon on the site is 37.8 ha and tagged *Sân tập Golf Quy Nhơn Golflinks* —
"sân tập" is a driving range. It reverse-geocodes to Nhơn Lý, i.e. the FLC site,
and a node named "FLC Quy Nhon Beach & Golf Resort" sits 1.5 km north. Either
OSM has mis-tagged part of the links or this is a range beside it. Both
investigations flagged it; one recommended a blank outright.

## Rebrands and aliases that look like missing courses

Recorded because each one appears on current directory listings as though it
were a separate club:

| Trades as | Is |
|---|---|
| Amber Hills Golf & Resort | Yên Dũng Resort & Golf Club |
| Sono Felice / Sono Belle Hải Phòng | Sông Giá Golf Resort |
| BRG Rose Canyon Golf Resort | Legend Valley Country Club |
| Emerald Country Club (renamed 09/2025) | Taekwang Jeongsan CC |
| Bo Chang Đồng Nai Golf Resort | Đồng Nai Golf Resort |
| Legend Đà Nẵng Golf Resort | BRG Đà Nẵng Golf Resort |
| Đồ Sơn Seaside Golf Resort | BRG Ruby Tree — **not** Dragon Golf Links, which is a separate Đồ Sơn course 5 km south |
| Mường Thanh Xuân Thành | Xuân Thành Golf & Resort |
| Sân Golf Đầm Vạc | Heron Lake Golf Course & Resort |
| Sacom Golf Club | SAM Tuyền Lâm Golf & Resort |

*Du Parc / Ocean Dunes Phan Thiết* is on several current lists but closed in
2014 and became housing. Not operating, not planned, not in the database.

## Not gaps

- **Central Highlands and the Mekong Delta have no operating courses.** Only Cồn
  Ấu (Cần Thơ), Đak Đoa (Gia Lai) and Kon Tum, all projects. The database's
  silence there is correct.
- **Eight courses are under construction** and are deliberately absent, because
  a course you cannot play is not a course you can pick: Trump International
  Hưng Yên (54 holes, groundbreaking 05/2025), Vinpearl Bãi Tre, Quang Hanh,
  Liên Hồng (Hải Dương), Độc Lập (Hòa Bình), Cồn Ấu, Đak Đoa, Kon Tum.
- **30 OSM golf polygons under 12 ha** are driving ranges, academies and one
  mini-golf. The largest practice facility is 11.1 ha and the smallest real
  course is 35.5 ha, so the 30-ha threshold separating them is arbitrary but the
  gap in the data is not.

## Known caveats

- **Provinces are written pre-merger**, matching the existing rows. The 2025
  merger renames several: Bắc Giang→Bắc Ninh, Quảng Bình→Quảng Trị, Ninh
  Thuận→Khánh Hòa, Bình Định→Gia Lai, Bà Rịa–Vũng Tàu→TP. Hồ Chí Minh. Moving to
  post-merger names is a decision affecting both the new rows and about a dozen
  existing ones.
- **Montaña Golf Club and Hilltop Valley** are both in Kỳ Sơn, Hòa Bình, and are
  recorded as separate courses on the strength of a different designer and a
  02/04/2026 opening. If they share a site, Montaña is the row to delete.
- **`holes_count` is 18 on every course row** even where the resort has 27 or
  36 (FLC Quảng Bình, Dragon Golf Links, Sonadezi Châu Đức, FLC Quy Nhơn, Yên
  Bái Star, Eschuri Vũng Bầu). One modelled eighteen is what the app plays.
- Coordinates for the six unnamed-polygon identifications rest on locality and
  elimination, not on a name tag. Each is re-checkable from the evidence in
  `seed_courses_vn_located.sql`.

## Reproducing this

```bash
python3 tools/course-digitization/osm/fetch_osm.py          # Vietnam only
psql … -f scripts/dev/seed_courses_vn_osm.sql               # all three are
psql … -f scripts/dev/seed_courses_vn_roster.sql            # idempotent
psql … -f scripts/dev/seed_courses_vn_located.sql
python3 tools/course-digitization/osm/build_from_osm.py --apply
```

Data © OpenStreetMap contributors, ODbL-1.0.
