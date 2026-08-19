# The gold test set — what it is, why nothing else can substitute for it

Every IoU this project reports is scored against OpenStreetMap, and OSM is
incomplete in a way that is now the **binding measurement problem**: Đường B
maps 3 bunkers where the ground has about twenty. A model that finds the other
seventeen — the exact improvement everything in this repo is chasing — is
scored as *wrong seventeen times*. Past a certain quality, real improvements
show up as flat or falling numbers, and there is no way to know from inside
the numbers whether that point has been passed.

The fix is one deliberate act of labour: **five courses digitised completely,
by a person, and then frozen.** Not a sample of each course — every green,
every bunker, every tee on it, including the practice areas OSM never
bothers with. From then on, every number is real.

## The five courses

These are the held-out test courses (no checkpoint trained on them), with what their
labels look like today. `osm` rows are human-drawn and trustworthy but thin;
`golfseg` rows are the model's own drafts and **must not be promoted into
test ground truth un-reviewed** — a test set that grades the model against
its own guesses always awards an A.

| course | name | test patches | human-drawn today | the gap a digitiser closes |
|---|---|---|---|---|
| 1407 | Long Thành — Lake | 48 | 17 greens, 84 bunkers, 43 tees, 11 water | the best mapped; verify + fill, fastest win |
| 42 | Sông Bé — Championship | 57 | 9 greens, 62 bunkers, 23 tees | greens: 9 mapped for 18 holes |
| 1435 | Sông Bé — Palm | 24 | 7 greens, 36 bunkers, 14 tees | roughly half of everything |
| 1351 | Long Biên — Đường A | 10 | **2 greens**, 0 bunkers, 0 tees | nearly everything |
| 1393 | Tân Sơn Nhất — Đường B | 24 | **nothing but 4 ponds** | everything — this is the "3 of 20 bunkers" course |

Priority order is the table order: 1407 first because verifying is faster
than drawing and it anchors the metric quickly; 1393 last because it is a
full course's work from a blank page.

## How to digitise (the part that needs a person)

1. Open the course in the portal's geometry editor (the same
   `draft_geometry_features` review screen the sweep files into), imagery at
   zoom 19.
2. The model's `golfseg` drafts are already there — **use them as tracing
   aids**: confirm the right ones, correct their edges, delete the wrong
   ones, and draw what is missing. Confirming a correct draft is minutes;
   drawing from nothing is not, which is why the drafts exist.
3. Completeness rules, per course, before it may be called gold:
   - every green, including the practice green and chipping green;
   - every bunker, including greenside pots and the driving-range ones;
   - every tee box of every colour, however small;
   - fairway outlines for all 18; ponds and lakes as they are wet today.
4. Mark the finished course — `verification_status = VERIFIED` on its
   features. The dataset builder gates on what a course actually maps, so
   the verified set becomes the mask on the next corpus build:

   ```
   python datasets/build_golfseg_dataset.py --only 1407 42 1435 1351 1393
   ```

5. **Freeze.** After the gold rebuild, the five test courses' masks change
   only to fix a digitising mistake, never because a model disagreed.

Estimated effort, measured against how long the OSM imports took to review:
1407 in half a day; 42 and 1435 a day together; 1351 and 1393 a day
together. Two to three days of drawing for a permanently honest metric.

## Two decisions only the owner can make

Recorded here because everything above works around them rather than
solving them:

1. **Drone orthomosaics for partner courses.** One flight per course gives
   3–5 cm imagery with clean ownership, makes tee boxes — the worst class at
   IoU 0.19–0.22 — trivially visible, and removes the Esri licence question
   for those courses entirely. Needs: permission from each course, a
   pilot/day, and a decision about which courses are worth it first.
2. **Licensed satellite for national coverage.** 97% of Vietnam has no
   z19 imagery; a course AOI is 1–2 km², and archive tasking at 0.3 m is
   priced per km² with a minimum order. Needs: a budget decision and a
   provider conversation (Pléiades Neo / Maxar archive were the candidates
   in the review that produced this file).
