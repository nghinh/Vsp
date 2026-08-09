# Generating course geometry from imagery — architecture and run plan

Target: usable hole maps for all 73 courses / 1,080 holes, without 73 site visits.

## 1. The bottleneck is not what it looks like

The obvious framing is "detect fairways, greens and bunkers from satellite
imagery". That is the second problem. The first one is this:

| | |
|---|---|
| Holes in the database | 1,080 |
| Holes whose tee and green are a real observed position | **127** (11.8%) |
| Courses with any real hole routing | **10** of 73 |

The other 953 holes have a tee and a green computed by the seed's arithmetic —
clubhouse point pushed along a fixed diagonal, green pushed due north. Every
"green" and "fairway" hanging off them was then derived from those invented
points:

| Layer | Rows | Observed | Synthetic |
|---|---|---|---|
| greens | 1,116 | 156 (OSM) | 960 buffers around an invented point |
| fairway_segments | 1,091 | 76 (OSM) | 1,015 rectangles along an invented line |
| bunkers | 565 | 565 (OSM) | — |
| tee_boxes | 406 | 406 (OSM) | — |
| water_hazards | 48 | 8 (OSM) + 40 (Sentinel-2) | — |
| penalty_areas / out_of_bounds / cart_paths | 0 | — | — |

So perfect bunker detection on a hole whose routing is fiction attaches a real
shape to an imaginary hole, which is worse than having no bunker: it makes the
fiction look surveyed. **Routing first, surfaces second.** Section 5 is the
part of this document that matters.

## 2. What already works, and what it is worth

`tools/course-digitization/satellite/detect_water_ndwi.py` is the precedent and
the template. Sentinel-2 L2A, free, fetched as COG range requests through the
Element 84 STAC API — a few MB for the whole country. It scores itself against
the water hazards OSM mapped by hand and reports **40% recall**, and its own
header says bunkers are impossible at 10 m/pixel and does not try.

That honesty is the standard the rest of this pipeline has to meet: every stage
measures itself against known-good geometry before anything ships.

## 3. The licence decides the architecture

This is the hard constraint, and it is not negotiable by engineering effort.

| Source | Resolution | Derive + store in our DB? |
|---|---|---|
| **Sentinel-2 L2A** (Copernicus) | 10 m | **Yes.** Free, derivative works permitted. Attribution: "Contains modified Copernicus Sentinel data ⟨year⟩" |
| Esri World Imagery | ~0.3 m | **No.** Our licence covers display in the app. Deriving a dataset and storing it is a different right |
| Mapbox Satellite / Google | 0.3–0.5 m | **No.** Same |
| Bing Aerial | ~0.3 m | **Only into OSM.** Microsoft permits tracing for OSM specifically — see 3.1 |
| Airbus Pléiades / Maxar archive | 0.3–0.5 m | **Yes, paid.** Licence covers derived products |
| Planet SkySat | 0.5 m | Yes, subscription |
| VN national ortho (Cục Đo đạc, Bản đồ và TTĐL) | 0.2–0.5 m where flown | Yes, subject to agreement. Domestic route, likely the cheapest for a VNPT product |
| The clubs' own as-built drawings | survey | Yes, per club. Gives class A/B, not C |
| Drone survey | 2–5 cm | Yes. Gives class A |

### What resolution is actually required — measured, not assumed

This does not need to be argued about. The database already holds 1,127 real
features traced from imagery by hand: 156 greens, 565 bunkers, 406 tee boxes on
Vietnamese courses. Measuring each one's *minimum inscribed width* and applying
the usual convention that delineating an outline needs the narrow dimension to
span at least five pixels gives the buy decision directly:

| Ground sample distance | Greens delineable | Bunkers | Tee boxes | Source at this resolution |
|---|---|---|---|---|
| 10 m | **0%** | 0% | 0% | Sentinel-2 (free) |
| 5 m | 6% | 1% | 1% | — |
| 2.5 m | 92% | 18% | 13% | VNREDSat-1 |
| **1.5 m** | **96%** | **76%** | **79%** | **SPOT-6/7 — Cục Viễn thám quốc gia** |
| 1.0 m | 99% | 94% | 96% | — |
| 0.5 m | 100% | 100% | 100% | Pléiades / WorldView (paid) |
| 0.3 m | 100% | 100% | 100% | Pléiades Neo (paid) |

Median widths behind those percentages: green 19.8 m, bunker 9.2 m, tee box
9.7 m; the tenth percentile is 14.2 m, 5.9 m and 6.3 m.

Three conclusions, and they change the plan:

1. **Sentinel-2 gets nothing.** Not "less" — zero percent, for every class
   including greens. The free tier can find the course outline and water and
   nothing else, which the existing water detector already said in its header
   and this now confirms with numbers.

2. **1.5 m is most of the answer, and 1.5 m is the domestic archive.** SPOT-6/7
   from Cục Viễn thám quốc gia delineates 96% of greens and around three
   quarters of bunkers and tees. That is not a fallback tier — it is enough to
   route every hole and draw most of the hazards, from a source that costs
   correspondence rather than dollars.

3. **Paying for 0.5 m buys the last quarter.** Going from 1.5 m to 0.5 m adds
   24 points of bunker coverage and 21 of tee coverage. Worth roughly US$1–3k,
   worth having, and not worth blocking the project on.

So the Phase 0 request order in 3.2 should be read with this in mind: ask the
national remote sensing archive for SPOT-6/7 **first**, and treat the
commercial 0.5 m purchase as a later top-up rather than the main event.

### 3.1 The OSM round trip

Worth stating because it turns the licence problem inside out. We already ingest
OSM under ODbL (`build_from_osm.py`), and Microsoft permits tracing Bing imagery
into OSM. Geometry traced into OSM comes back to us legally, and to everyone
else too.

Caveat, stated plainly: OSM's community forbids bulk machine-generated imports
without a published import proposal and review, and would be right to. This is a
route for **human-reviewed** tracing, at the pace review allows — not a
laundering channel for a classifier's output. Treated that way it is legitimate
and it is how several golf datasets in OSM were built.

## 3.2 Where the licence actually comes from

Six routes, cheapest first. They are not exclusive — the realistic answer is
two or three of them running at once, because they yield different accuracy
classes.

### A. Inside VNPT first

Before buying anything, find out what the group already holds. A telco of this
size usually has an enterprise imagery or GIS agreement somewhere — network
planning, infrastructure, or a smart-city unit — and an existing corporate
licence extended to one more internal product costs nothing and takes a
procurement email rather than a contract. This is the only route that can be
resolved in a day, so it is the one to check first.

### B. The domestic state route — most likely the right answer here

Two bodies hold what we need. Both sat under Bộ Tài nguyên và Môi trường until
the February 2025 ministry merger and now sit under **Bộ Nông nghiệp và Môi
trường** — worth confirming the current placement before writing to them.

- **Cục Đo đạc, Bản đồ và Thông tin địa lý Việt Nam** holds the national
  orthophoto and base map, including 0.2–0.5 m aerial coverage over developed
  areas. Supply of this data to organisations is governed by **Luật Đo đạc và
  bản đồ 2018** and **Nghị định 27/2019/NĐ-CP**, with a published fee schedule;
  copies are issued through its data centre (Trung tâm Thông tin dữ liệu đo đạc
  và bản đồ). This is the highest-resolution legal source in the country and
  the one a Vietnamese product has the best standing to ask for.

- **Cục Viễn thám quốc gia** operates the national satellite reception and
  archive — notably standing SPOT-6/7 coverage at 1.5 m. Its remit is set by
  **Nghị định 03/2019/NĐ-CP** on remote sensing. 1.5 m is not enough for
  bunkers, but a 500 m² green is roughly 220 pixels at 1.5 m, which is plenty
  for green outlines and therefore plenty for routing — the stage that actually
  unblocks the project.

- **VNREDSat-1** (2.5 m panchromatic), operated through VAST's national space
  centre, is a further domestic option. Marginal for our purposes.

The state route is slower than a credit card and much cheaper, and for a VNPT
product the institutional standing is real. Start it early because it runs on
correspondence, not checkout.

### C. Commercial archive

- **Airbus Defence and Space** — Pléiades Neo 0.3 m, Pléiades 0.5 m, SPOT 1.5 m.
- **Maxar** — WorldView, 0.3 m.
- **Planet** — SkySat 0.5 m tasking, PlanetScope 3 m daily.
- **Esri** — worth a separate ask. We already use World Imagery for display in
  the app under terms that forbid derivation; Esri sells the same imagery under
  different terms that permit it. Ask their Vietnam partner for a quote on a
  derivative-works licence rather than assuming the basemap terms are the only
  ones on offer.

All of these sell into Vietnam through local resellers rather than directly;
ask each vendor for their current Vietnam partner rather than trying to buy from
the global site.

### D. Licence surveyed golf data outright — the shortcut

Companies whose whole business is surveyed golf course geometry — the yardage
and GPS-rangefinder vendors — already hold this data for the major Vietnamese
courses, produced to a standard we cannot reach from imagery.

This is worth naming explicitly because **the schema already anticipates it**:
`B_LICENSED_PROVIDER` exists as an accuracy class precisely for bought,
surveyed data, and it outranks anything this pipeline can produce
(`C_VERIFIED_SATELLITE` at best). For the top courses it may be both cheaper
and better than generating.

### E. The clubs themselves

Every course was built from a design, and most hold as-built survey drawings —
usually CAD, sometimes already georeferenced. For a platform that intends to
partner with these clubs, asking 73 general managers is a real acquisition
channel with a zero licence fee, and it yields class A or B rather than C.

It is also the only route that scales *down* gracefully: even ten clubs saying
yes removes ten courses from the imagery problem entirely.

### F. Drone survey — class A, with a permit regime

Gives 2–5 cm and the only genuinely surveyed result. The constraint is legal,
not technical: UAV flight in Vietnam requires a flight permit, and the regime
changed with **Luật Phòng không nhân dân 2024** (in force 1 July 2025),
replacing the older Nghị định 36/2008/NĐ-CP arrangement. In practice this means
hiring a licensed Vietnamese survey operator who holds the permits, rather than
flying ourselves.

Some courses will never be permitted. Tân Sơn Nhất Golf Course sits inside an
active international airport's perimeter; that one is imagery or nothing.

### What the licence has to say

The common failure is buying imagery and discovering the licence covers looking
at it. Four rights are needed, and they should be named in the request:

1. **Create derived vector products** from the imagery.
2. **Store** those derivatives in a database indefinitely.
3. **Redistribute** the derivatives to end users — the course packages are
   downloaded onto golfers' phones, which is redistribution. Many imagery
   licences permit internal use and stop exactly here.
4. **Survive termination** — derivatives already created remain usable after the
   imagery licence lapses. Otherwise the map disappears when the subscription
   does.

Plus the attribution wording the provider requires, which goes into the
`publisher` and `license` columns and into the app's imagery credit.

### What to send them

One request serves every vendor on this list:

- 73 areas of interest, supplied as a GeoJSON of course boundaries with a 250 m
  buffer — **about 75–110 km² in total**.
- Resolution 0.5 m or better; 1.5 m acceptable as a fallback tier for routing
  only.
- Captured 2023 or later, cloud cover under 10% over the AOI, and dated —
  Vietnamese courses are rebuilt often and a 2019 scene will not show a 2024
  redesign.
- Delivery as GeoTIFF or COG, 4-band (RGB + NIR) if available; NIR materially
  improves the turf/sand separation.
- The four rights above, in writing.

Note the total area is small. 110 km² is a rounding error to these vendors and
may fall under a minimum order size, which is more likely to set the price than
the area itself — ask about minimums in the first email.

### Recommended order

Start B, D and E **in parallel today**, because all three run on correspondence
and none of them costs anything to ask. Run C as the fallback with a deadline —
if nothing has landed from the free routes in six weeks, buy the archive, since
US$1–3k is not worth a quarter of waiting. Keep F for the handful of flagship
courses where class A pays for itself.

Meanwhile Phase 1 proceeds regardless: Sentinel-2 needs no permission from
anyone.

## 4. Pipeline

Seven stages. Each writes to a staging table, is idempotent, and is scored
before it is allowed to write to the live tables.

```
0  extent      facility point/boundary -> AOI polygon + buffer
1  imagery     fetch tiles for AOI, cache locally by (source, AOI, date)
2  surfaces    per-pixel class: water | sand | mown-turf | rough | tree | path | built
3  objects     mask -> polygons: greens, tees, bunkers, water, cart paths
4  routing     greens + tees -> 18 hole lines, ordered            <-- the crux
5  attach      each polygon to its hole; fairway corridor per hole
6  validate    IoU vs known-good, topology, area bands, count sanity
7  publish     staging -> live tables, D_UNVERIFIED_COMMUNITY / PENDING_REVIEW
```

### Stage 2 — surfaces

Golf is an unusually easy segmentation target: mown bentgrass, fairway,
rough, sand and water separate cleanly in colour and texture. Two
implementations, in order of cost:

- **Rule-based on superpixels.** SLIC over HSV + local variance, then labels by
  band: sand = high value, low saturation, low variance; green = high
  saturation green, *very* low variance (mowing); fairway = green, low
  variance, striped; rough = green, high variance; water = low value, low
  variance; tree = green, very high variance with shadow. No training, no GPU,
  fully explainable — which matters when a reviewer asks why a shape is there.
- **Small U-Net, if the rules plateau.** We already hold the labels: 565 OSM
  bunkers, 156 greens, 406 tee boxes, 76 fairways on 10 courses. That is a real
  training set for a 4-class model, and the same set is the holdout for
  measuring it.

Start with the rules. Reach for the model only when a measured number says the
rules are the limit.

### Stage 3 — objects

Marching-squares vectorisation, Douglas–Peucker simplification at ~0.5 m,
morphological open/close to drop specks, then reject by class-specific area and
shape bands: green 250–1,200 m² and roughly convex; tee 60–600 m² and
rectangular; bunker 15–900 m²; water ≥ 200 m².

## 5. Stage 4 — routing, and why it is the whole game

Input: a set of detected greens and a set of detected tee pads inside one course
boundary. Output: an ordered list of holes, each a tee position, a green
position, a length and a plausible par.

This is a constrained assignment problem, and the constraints are strong enough
that it is solvable:

1. **Tee pads cluster.** Four to six pads in a line 20–60 m apart are one hole's
   tee complex, not five holes.
2. **Length must be plausible.** `ParPlausibility` already encodes the bands the
   API validates against — par 3 ≤ 260 m, par 4 200–470 m, par 5 ≥ 380 m, par 6
   ≥ 520 m. A tee–green pairing outside every band is not a hole.
3. **Consecutive holes are adjacent.** The walk from green *i* to tee *i+1* is
   short, typically under 150 m. This is what turns 18 unordered pairs into a
   sequence.
4. **Holes do not cross.** Routings are planar almost everywhere; a candidate
   solution with crossing corridors is nearly always wrong.
5. **Total par is 70–73** on a full-length 18.
6. **Cart paths are detectable** and the green→next-tee walk usually follows
   one, which sharpens constraint 3 into a graph shortest path.

Implementation: Hungarian assignment for tee-cluster ↔ green pairing under a
cost combining distance plausibility and corridor turf continuity, then order
the resulting holes by a shortest-Hamiltonian-path over green→tee transfers,
then score the whole routing against constraints 4–5 and keep the best of *k*
seeds. Where the club publishes a scorecard, the par sequence is a hard
constraint that collapses the search space almost completely.

**This is the piece with no precedent in the repo and the highest technical
risk.** It is also what takes the project from "127 real holes" to "1,080".

## 6. Validation — the gate, not a formality

Ten courses have OSM routing and OSM surfaces. They are the holdout and they are
never used to tune anything.

Per class, per course: intersection-over-union against the OSM polygon, plus
recall and precision at the object level. For routing: fraction of holes whose
inferred number matches OSM's `ref`, and median tee/green position error in
metres.

Publication thresholds — a class that misses its threshold does not ship, and
the number is reported either way:

| Class | Must reach | Why that number |
|---|---|---|
| Course boundary | IoU ≥ 0.90 | Cheap and easy; anything less means the AOI is wrong |
| Green | IoU ≥ 0.75, recall ≥ 0.90 | A green centroid drives "distance to green" — the app's single most used number |
| Routing | ≥ 95% of holes numbered correctly | A hole map on the wrong hole is worse than none |
| Tee box | IoU ≥ 0.60 | Tee position sets hole length |
| Bunker | recall ≥ 0.70, precision ≥ 0.85 | A bunker that is not there changes a club selection |
| Water | recall ≥ 0.60 | Today's Sentinel detector gets 40%; high-res should beat it |
| Fairway | IoU ≥ 0.65 | Wide feature, forgiving |

## 7. Provenance and what the golfer is told

Nothing generated lands above `D_UNVERIFIED_COMMUNITY` / `PENDING_REVIEW`.
`C_VERIFIED_SATELLITE` is reachable **only** through a human review action —
that is exactly what the class name means, and the app's gate
(`verified && accuracyClass != D`) already draws unverified shapes as
provisional dashed outlines rather than course data.

`source` records the imagery scene and the algorithm version, e.g.
`derived:pleiades-2026-03-14/seg-v2`, so any shape can be traced to the pixels
and the code that produced it. `publisher` and `license` carry the imagery
provider's required attribution.

Existing rows are never silently overwritten: a generated shape that lands on a
hole already carrying OSM or human-verified geometry is dropped and counted, the
same rule `build_from_osm.py` already follows.

## 8. Review — the real throughput limit

1,080 holes will not be reviewed one form at a time. The portal already has
`GeometryEditor.vue`, `DrawTools`, `LayerPanel` and an undo/redo manager; what
is missing is a **batch review mode**: one hole per screen, imagery underneath,
proposed polygons on top, keyboard accept / reject / edit per feature, next.

At 10 seconds a hole that is 3 hours of human time for the country; at a more
realistic 30 seconds it is 9 hours. Either is a day of work, and it is the
difference between a database of proposals and a database of course data. It is
also the cheapest thing in this document to build.

## 9. Run plan

Each phase ends at a gate with a number. A phase that misses its gate stops and
reports; it does not proceed on hope.

**Phase 0 — Licence (blocking, not engineering).**
Decide the high-res source: commercial archive quote (Airbus/Maxar), the
national mapping agency, or the OSM tracing route. Nothing past Phase 2 can
legally ship without this. *Gate: a written licence that permits derived
products, or a decision to go the OSM route.*

**Phase 1 — Extend the free tier. RUN, and it failed its gate.**
Built: `satellite/sentinel2.py`, the shared harness factored out of the water
detector, and `satellite/detect_course_boundary.py`. *Gate was boundary
IoU ≥ 0.90; measured best is about 0.25, so the boundary objective is
abandoned at 10 m.* What the phase actually produced is in §12.

**Phase 2 — Segmentation prototype, one course.**
Long Thành: full OSM routing, 18 holes, real greens, bunkers and tee boxes to
score against. Build stages 2–3, tune on other courses, measure here.
*Gate: green IoU ≥ 0.75 and bunker recall ≥ 0.70 on Long Thành.*

**Phase 3 — Routing.**
Stage 4 against the 10 courses with OSM routing, 127 holes.
*Gate: ≥ 95% of holes numbered correctly, median green error ≤ 5 m.*

**Phase 4 — Batch review UI.**
Portal review mode. Can be built in parallel with 2–3.
*Gate: a reviewer clears 100 holes in under an hour.*

**Phase 5 — National run.**
All 73 courses through stages 0–7 into staging, scored, published as
D/PENDING_REVIEW. *Gate: per-course scorecard published; courses below
threshold flagged, not shipped.*

**Phase 6 — Review and promote.**
Work the queue. Reviewed holes become `C_VERIFIED_SATELLITE`; the app starts
drawing them as course data instead of provisional outlines.
*Gate: package rebuild, and the badge on those courses stops saying "chưa xác minh".*

**Phase 7 — Top-20 upgrade (optional, ongoing).**
Drone survey or club as-built drawings for the highest-traffic courses, giving
class A/B where it is worth paying for.

## 10. Cost and effort — estimates, flagged as such

- **Imagery.** ~75–110 km² covers all 73 courses with buffer. Commercial archive
  at 0.5 m runs on the order of US$10–20/km², so **roughly US$1–3k one-off**,
  subject to minimum order areas that can dominate at this size. Needs a quote;
  the national-ortho route may be cheaper or free for a VNPT product.
- **Compute.** Negligible. ~800 megapixels total; a laptop-week at most, no GPU
  unless the U-Net is needed.
- **Engineering.** Phases 1–5 are on the order of 3–5 focused weeks, of which
  routing (Phase 3) is the largest and least predictable single piece.
- **Review.** ~1 person-day for the country, plus the reviewers' judgement,
  which is the part that cannot be bought.
- **Drone (Phase 7).** Market rate in Vietnam is roughly US$300–800 per course;
  20 courses ≈ US$6–16k.

## 11. How this fails

Written down so the failure is recognised early rather than argued about late.

- **The licence never lands.** Then only Phase 1 ships and the hole maps stay
  unbuilt. This is the single largest risk and it is not technical.
- **Routing does not reach 95%.** Then geometry can still be published
  *unattached* to holes — an accurate map of the course with no per-hole
  distances. Less valuable, still honest, still better than today.
- **Review never happens.** Then 1,080 holes of D-class proposals sit in the
  database looking like progress while the app correctly refuses to show them as
  course data. Phase 4 exists to stop this, and Phase 6 should not start until
  Phase 4's gate is met.
- **The imagery is older than the course.** Vietnamese courses are being built
  and rebuilt constantly; a 2019 scene will not show a 2024 redesign. The scene
  date belongs in `source` and in the reviewer's view, and it already is.
- **It works, and gets trusted too much.** A 0.5 m ortho gives shapes good to a
  few metres. A few metres is the difference between a 7-iron and an 8-iron. The
  class ceiling for anything in this pipeline is C, never A or B, and the app's
  existing gate is what keeps that promise.

## 12. Phase 1 outcome — what a failed gate bought

Phase 1 ran. Its headline objective — course boundaries from free imagery —
does not work, and the measurement is worth more than the objective was.

**Boundaries at 10 m: no.** NDVI temporal stability was the idea: rice cycles
between bare and green two or three times a year, mown irrigated turf does not,
so the discriminator is not greenness but *unchanging* greenness. Scored
against OSM outlines at the loosest threshold that keeps any recall:

| Course | Landscape | Recall | Precision |
|---|---|---|---|
| Sea Links (Mũi Né) | coastal links on dunes | 0.73 | 0.25 |
| Long Thành (Đồng Nai) | rubber plantation country | 0.56 | 0.36 |
| Sky Lake (Hà Nội) | northern, real winter | **0.09** | 0.13 |

No national threshold exists. Tightening for precision drives Sky Lake to zero;
loosening for recall flags 1,000 ha around a 160 ha course. Two causes, neither
fixable by tuning: southern rubber is stably green and merges with the course,
and northern turf goes dormant, so the premise fails outright for half the
country.

**Ruled out, measured, so nobody tries it again.** 3×3 spatial texture of NDVI,
proposed to separate mown turf from tree canopy, separates nothing at 10 m —
median 0.054 inside the Long Thành boundary, 0.052 outside.

**Two bugs that produced plausible wrong answers**, both now guarded in code
and documented at the point of the guard:

- Choosing the MGRS tile with the most scenes is not choosing a tile that
  covers the course. Long Thành sits on the edge of the busiest tile and
  rasterio silently clipped the read window to 730 m instead of 4 km.
- The twelve clearest scenes of a Vietnamese year all fall between April and
  June. Stability measured inside one growing season is not a discriminator;
  rice is perfectly stable there too.

**What Phase 1 leaves behind that is worth having.**

1. **The resolution table in §3** — the single most useful output of the phase,
   and it redirects Phase 0. Measured on 1,127 hand-traced features: 1.5 m
   delineates 96% of greens and ~76% of bunkers and tees, so the domestic
   SPOT-6/7 archive is most of the answer and the commercial 0.5 m buy is a
   top-up, not the main event.
2. **`satellite/sentinel2.py`** — STAC search, per-AOI cloud assessment, BOA
   offset handling, windowed COG reads, connected components, vectorising. All
   of it carries over to 1.5 m imagery unchanged; only thresholds move.
3. **A negative result that saves the next attempt.** The free tier cannot
   deliver the geometry, and no further engineering at 10 m will change that.
   The project's dependency is imagery, exactly as §3 said, and now it is
   demonstrated rather than argued.

**Revised recommendation.** Stop spending on the free tier. Phase 0 — the
licence — is now the only thing on the critical path.
