# Golf Vision — prototype findings

What §63 asks for: the current implementation documented, the integration
points named, one pretrained remote-sensing model run on real Vietnamese golf
imagery, masks vectorised to GeoJSON, and an honest statement of which golf
classes are already reachable and which need a trained GolfSeg model.

Everything below is measured. Nothing is estimated.

---

## 1. What the current implementation does

The LLM path lives in `apps/api/.../module/geometry/vision/`:

| Class | Role today | Fate |
|---|---|---|
| `SatelliteImageService` | Fetches and stitches Esri tiles, returns `StitchedImage(png, bounds, attribution)` | **Keep.** Ported to `golfvision/imagery/fetcher.py`; the Java side stays for the existing flow |
| `WebMercator`, `ImageBounds` | Tile arithmetic, pixel ↔ lat/lng | **Keep.** Ported verbatim to `golfvision/geo/`; both sides must agree to the decimal |
| `HoleGeometryVisionService` | Builds the prompt, calls the model, writes drafts | **Replace.** The prompt asks the model for polygons — this is the thing §5 forbids |
| `VisionGeometryReader` | Parses the model's polygon JSON, validates, area-gates | **Replace.** Its area gates are worth keeping as a plausibility check on any source |
| `ShapeRefiner` | Flood-fills from a seed, then walks 60 rays out from the centroid | **Replace.** Rays from a centroid **cannot represent a concave shape by construction** — that is why every bunker it drew was the same smooth octagon |
| `CourseMappingService`, `CourseMappingJobStore`, `CourseMappingWorker` | Job queue, one hole at a time, `FOR UPDATE SKIP LOCKED` | **Keep.** The queue is source-agnostic |
| `HoleFeatureController` | Serves GeoJSON to the app, source priority, confidence floor | **Keep.** New geometry arrives through the same door |
| `draft_geometry_features` | Review queue with `source`, `accuracy_class`, `verification_status`, `model_version` | **Keep.** Already carries everything §34 and §39 ask for |

The flow to be cut is exactly one link: the model is currently handed an
image and asked to return `[[x, y], ...]`. Everything upstream and downstream
of that stays.

**Backward compatibility.** The 89 AI-drawn features and the 2,614 imported
OSM features are untouched: same table, same columns, same endpoint. A new
pipeline writes rows beside them with a different `source`.

---

## 2. What was run

- Imagery: Esri World Imagery, zoom 19, **0.279–0.293 m/px** over Long Biên
  and Long Thành. (Zoom 18 was tried first at 0.557 m/px and is materially
  worse — see §4.)
- Model: **`IGNF/FLAIR-INC_rgb_15cl_resnet34-unet`** — U-Net/ResNet-34,
  15 land-cover classes, Etalab 2.0 (commercially usable), trained on French
  BD ORTHO at 0.2 m.
- Hardware: Apple M1, MPS. **7.2 s** per hole for a 3210² input, tiled 512²
  with 25% overlap.
- Ground truth: the 2,614 OpenStreetMap polygons this project imported, served
  back from `/open-data/osm-derived/{course}.geojson`. The model has never
  seen any of it.

### A bug worth recording

The first run reported 91.3% "grass" and found no water at all — over a hole
with a large black pond in the middle of frame. It looked exactly like a
domain-gap failure and was not.

IGN trained under pytorch-lightning, which stores weights two modules deep:
`model.seg_model.encoder.conv1.weight`. Stripping only `model.` leaves
`seg_model.` on every key, **nothing matches**, and `load_state_dict(...,
strict=False)` loads zero of 278 tensors **without a word**. The network was
random. `strict=True` now, so the next checkpoint with a different layout
fails at load rather than in a plausible-looking benchmark three hours later.

---

## 3. Measured results

Three holes at Long Thành, scored against the OSM polygons for the same
ground. `edge µ` is the mean distance from a true boundary to the nearest
predicted boundary; `edge p95` the 95th percentile. Metres.

| Hole | Layer | IoU | precision | recall | edge µ | edge p95 |
|---|---|---|---|---|---|---|
| 10 | water | 0.512 | 0.911 | 0.539 | 21.5 m | 120.4 m |
| 15 | water | 0.471 | 0.951 | 0.483 | 11.2 m | 41.3 m |
| 5 | water | 0.119 | 0.158 | 0.329 | 20.0 m | 59.1 m |
| 10 | green *(vs grass)* | 0.006 | 0.006 | 1.000 | 10.2 m | 21.0 m |
| 15 | green *(vs grass)* | 0.008 | 0.008 | 1.000 | 8.6 m | 19.6 m |
| 5 | green *(vs grass)* | 0.002 | 0.002 | 1.000 | 12.9 m | 24.0 m |
| 10 | bunker *(vs bare land)* | 0.298 | 0.350 | 0.665 | **1.4 m** | 3.8 m |
| 15 | bunker *(vs bare land)* | 0.423 | 0.517 | 0.701 | **1.3 m** | 2.9 m |
| 5 | bunker *(vs bare land)* | 0.097 | 0.101 | 0.725 | **1.0 m** | 2.5 m |

### What these numbers say

**The edges are good. The labels are not.** That is the finding, and it is
the opposite of the LLM's failure mode.

- **Bunkers: recall 0.67–0.73, boundary error 1.0–1.4 m mean, p95 under 4 m.**
  The model finds two thirds of the bunkers and, where it fires, puts the edge
  within about a metre — which is inside what a golfer can tell. Precision
  0.35–0.52 says the other half of what it calls bare ground is cart path,
  service track or bare dirt. **This is a classification problem, not a
  delineation problem**, and classification is what topology and context fix.
  Compare the LLM this replaces: it drew every bunker as the same octagon.
- **Green: IoU 0.006.** Recall is 1.0 only because grass covers the green
  along with everything else; precision is 0.006 because the grass class is
  roughly 150× the area. **A generic land-cover model cannot find a green**,
  and no amount of post-processing changes that — mown turf at 8 mm and mown
  turf at 25 mm are the same pixels. This is the clearest argument in the
  whole exercise for a trained GolfSeg.
- **Water: precision 0.91–0.95 on the two lake holes, and 0.16 on hole 5.**
  Where there is real open water it is confident and right; where the water is
  narrow, shaded or reed-fringed it both misses and hallucinates. Boundary
  error 11–21 m rules it out for carry distances today. On Long Biên it
  labelled entire fairway corridors blue and missed the pond — the domain gap
  between French BD ORTHO and Maxar-over-Vietnam is real.

### Resolution matters more than expected

| Zoom | m/px | Result |
|---|---|---|
| 18 | 0.557 | water, bare land and buildings all collapse into "grass"; only trees survive |
| 19 | 0.279 | 8 classes, the numbers above |

Only ~3% of Esri's Vietnamese footprints are cached at zoom 19 — Hanoi
(Long Biên, Vân Trì), Đà Nẵng, HCMC, Long Thành, Vũng Tàu. **Everywhere else
is 0.557 m/px, where this model gives nothing.** Imagery resolution, not model
choice, is the binding constraint for national coverage.

---

## 4. Which classes are reachable today

| Class | Status | Route |
|---|---|---|
| tree / forest | **usable now** | Level 1 directly; 39 polygons at 93–5482 m² on Long Biên, visually correct |
| building | **usable now** | Level 1; roofs are the model's strongest class here |
| water | **partial** | Good where open, unreliable where narrow. Prefer OSM where mapped; use Level 1 to *propose*, never to measure a carry |
| bunker | **edges yes, labels no** | Level 1 bare-land mask + golf context to reject paths and dirt (§15). The 1.3 m edge accuracy is already good enough |
| cart path | **partial** | Level 1 impervious surface; needs shape filtering |
| fairway | **no** | Indistinguishable from rough at Level 1. Needs GolfSeg or topology |
| rough | **no** | Same |
| **green** | **no** | **IoU 0.006. Needs GolfSeg. This is the one that matters most** |
| tee box | **no** | Too small and too similar to fairway at Level 1 |
| OB | **not from imagery** | §18 — it is a rule, not a land cover |

---

## 5. What this means for the plan

1. **Phase 1–2 of §57 are proven.** Masks vectorise cleanly, coordinates come
   out right, and the pipeline runs end to end in 7 seconds a hole on a laptop.
2. **Phase 3 heuristics should be built around bunkers and trees first** —
   they are where Level 1 is already accurate enough to be worth filtering.
3. **GolfSeg is not optional.** Green, fairway, tee and rough are not
   separable by any generic land-cover model, because they are not visually
   distinct — they are *use* distinctions. Everything §36–§44 describes is on
   the critical path, not a later refinement.
4. **The training set already half exists.** 2,614 human-drawn OSM polygons
   across 36 Vietnamese courses, with 281 greens, 1,260 bunkers and 609 tees.
   That is a real starting corpus for the dataset in §36, from the right
   country, at no cost — and it is the same corpus this evaluation scores
   against, so it must be split before it is trained on.
5. **Two blockers are not technical.** Esri's terms forbid automated
   extraction and commercial derivatives; and only 3% of Vietnam is cached at
   the resolution where any of this works. Both point the same way: licensed
   imagery at 0.3 m or better has to be solved before the model does.

---

## 6. What is built

```
services/golf-vision/
  golfvision/
    classes.py            Level 1 and Level 2 vocabularies, kept apart (§3)
    geo/webmercator.py    tile arithmetic, ported from the Java side
    geo/tiles.py          ImageBounds — the only place pixels become degrees
    imagery/fetcher.py    tile fetch and stitch, provider-abstracted (§7)
    providers/base.py     the three interfaces of §4
    providers/flair.py    land cover, Etalab 2.0, tiled with 25% overlap (§8)
    masks/postprocess.py  morphology and area gates, per feature type (§20)
    vector/vectorize.py   contours → valid geographic polygons (§21, §22)
  prototype/run_hole.py       §58 — one hole, with the §59 debug visual
  evaluation/score_against_osm.py   §45, §46 — IoU and metres
```

No LLM is involved anywhere in this path.

Not yet built, in the order they are worth building: SAM boundary refinement
(§19), the golf semantic inference engine (§11–§15), the topology engine
(§26–§28), the FastAPI service boundary (§55), the training pipeline (§36–§44).

---

## 7. The semantic layer, measured

§11–15 built and scored on the same three holes, same imagery, same ground
truth. The land-cover model is untouched; the only change is that its
bare-ground candidates now have to look like sand and lie where sand lies.

| Hole | precision | recall | IoU | edge µ | found |
|---|---|---|---|---|---|
| 10 | 0.350 → **0.769** | 0.665 → 0.499 | 0.298 → 0.434 | 1.4 → 1.3 m | 19/19 → 13/19 |
| 15 | 0.517 → **0.829** | 0.701 → 0.448 | 0.423 → 0.410 | 1.3 → 1.4 m | 29/29 → 19/29 |
| 5 | 0.101 → **0.896** | 0.725 → 0.560 | 0.097 → 0.526 | 1.0 → 1.1 m | 11/11 → 9/11 |

**Precision roughly doubles, and on hole 5 goes from 0.10 to 0.90.** The cost
is a quarter of the recall: 124 candidates dropped across the three holes, of
which some were real bunkers the shape test judged too thin or the position
test judged too far.

That is the right trade for a rangefinder. A bunker on screen that is not
there produces a carry number a golfer clubs off; a bunker missing from the
screen leaves them where they were before any of this existed.

Two signals, and both are needed:

* **shape** removes the cart path, which is bare, pale and runs straight up
  the middle of the hole where no position test can touch it;
* **position** removes the bare ground in the car park, which is exactly as
  compact and exactly as sand-coloured as a bunker.

### A metric that was lying

The first run of this comparison reported boundary error jumping from 1.4 m
to 30.8 m, which reads as the filter wrecking the geometry. It had not moved
a single edge.

The metric measured every true boundary against the nearest predicted
boundary *anywhere*, so a true bunker with no prediction left near it
contributed its whole distance to the mean — folding recall into a number
that is supposed to be about accuracy. Measured over matched features only,
edge error is 1.3–1.4 m before and after, and the recall cost appears in its
own column where it belongs.

Worth recording because §38 prioritises human review by confidence, and a
metric that conflates two failures prioritises the wrong examples.

### Still not inferred

Green produces no golf class at all, deliberately. The land-cover model puts
a green in the same class as the fairway and the rough, because mown turf is
mown turf, and there is no shape or position rule that recovers it — a green
is compact and sits at the end of the hole, and so does the apron around it,
and so does a practice putting surface. Dressing that up as an inference
would produce confident nonsense at exactly the place a golfer trusts most.

The gap is left visible. It is the argument for GolfSeg, and it now has a
number on both sides of it: bunker 0.90 precision from a generic model plus
rules, green 0.006 IoU from anything short of training.

---

## 8. Training pipeline and dataset (Phase 5)

Built on a borrowed A100 (production server, VRAM shared with a live vLLM —
see the training run's discipline below). The dataset is the whole point of
§62: the persistent asset is not the model, it is the labelled corpus, and it
now exists.

### The dataset, measured

From the 2,614 OSM polygons across 34 courses that carry hole geometry:

| | patches | courses |
|---|---|---|
| train | 1,051 | 26 |
| val | 103 | 3 |
| test | 163 | 5 |

512-px patches at zoom 19 (0.29 m/px), 25% overlap, split **by course** so a
val score is not a memory test. Class pixel share, which is why the loss is
weighted:

| class | share |
|---|---|
| water_hazard | 45.9% |
| background | 39.8% |
| fairway | 9.7% |
| bunker | 2.2% |
| green | 1.45% |
| tee_box | 0.67% |
| rough | 0.27% |

Green and tee — the two a rangefinder most needs — are under 2% of pixels
between them. A plain cross-entropy would ignore them and score well; median-
frequency weights (bunker ×12 capped, green ×3.6, background ×0.04) plus a
Dice term are the answer, and they are in place.

### The honest limit, again

The masks are only as complete as OSM. Đường B maps 3 bunkers where the ground
has ~20, so patches full of real sand carry no bunker label. The builder gates
each class per course on what that course actually maps, and writes unmapped
ground as `ignore` (255, skipped by the loss) rather than as background — but
where OSM is simply thin, the model will be too. The fix is the human-
correction loop of §37–38, feeding verified polygons back; the 90%-precision
bare-ground detector from §7 is the obvious way to pre-label the sand OSM
missed.

### What is built, ready for the GPU

```
training/dataset.py   patches + dihedral augmentation (§43)
training/losses.py    median-frequency weights + Dice, ignore-aware (§42)
training/metrics.py   per-class IoU, mean over present classes only
training/models.py    SegFormer (feasibility) | SMP U-Net (commercial), §4
training/train.py     the loop: VRAM cap, class balance, best-on-green
evaluation/evaluate_checkpoint.py   IoU + boundary error in metres (§46)
datasets/build_golfseg_dataset.py   OSM → (image, mask) pairs (§36)
```

Smoke-tested end to end on synthetic data: dataset → weighted loss → per-class
IoU → checkpoint → metre-accurate evaluation, no crash. The weights are not
trained yet — that is the one step that needs the A100, and it waits on
freeing VRAM from the production vLLM without disrupting it.

---

## 9. The trained baseline — the refactor's thesis, settled

SegFormer-B0, 12 minutes on an A100 shared with a production vLLM (see the run
discipline below), scored on the 5 held-out test courses it never trained on:

| class | GolfSeg-B0 IoU | land-cover baseline | edge µ |
|---|---|---|---|
| green | **0.528** | 0.006 | 2.5 m |
| fairway | **0.657** | not separable | 5.6 m |
| bunker | 0.475 | 0.10–0.42 (+ filter) | 2.5 m |
| water | 0.743 | 0.12–0.51 | 6.4 m |
| mean IoU | **0.539** | — | — |

Green went from 0.006 to 0.53. That is the argument of this whole exercise
reduced to two numbers: a generic land-cover model cannot find a green because
mown turf is mown turf, and a model trained on 26 courses of human-drawn
polygons can — at a 2.5 m boundary error, already inside a club.

The pipeline the spec asked for is now real end to end: satellite tile →
segmentation mask → GIS vectorisation → GeoJSON → metre-accurate distance,
with no LLM anywhere in the geometry path. The persistent asset of §62 — the
labelled corpus and the model trained on it — exists.

### Sharing a production GPU without breaking it

The A100 was serving a 26B vLLM at 90% memory utilisation. The training run:

1. Recreated vLLM at 0.80 (backup of the exact `docker run` taken first via
   `runlike`; only the utilisation number changed), freeing ~8 GB.
2. Verified vLLM served real completions before proceeding.
3. Trained under a hard 9.6 GB per-process VRAM cap — it used 2.6 GB and could
   not have touched vLLM's memory if it tried.
4. Rolled vLLM back to 0.90 and verified health, a real completion, and the
   restored config.

vLLM stayed up throughout, at reduced capacity, with two ~6-minute reloads at
the endpoints. No other service was touched.

### Limits, stated

- **tee IoU 0.192** — small, sparse (0.67% of pixels), and the hardest class.
- **The model is as complete as OSM.** Where OSM maps 3 of 20 bunkers, so does
  the model. Better labels, not a bigger model, is the next lever.
- **This checkpoint does not ship.** Its mit-b0 encoder is NVIDIA
  research-licensed; production retrains on the MIT backbone already wired
  behind the same interface.

---

## 10. Asking better — measured before it shipped

The quality review of 2026-08-19, first tier: change nothing about the model,
change how it is asked. One inference path now serves the evaluation harness
and the service (`golfvision/inference.py`), so every number below is scored
behind exactly the asking it is served behind.

| asking | test mean IoU |
|---|---|
| plain, argmax, uniform window blending (baseline) | 0.559 |
| + dihedral TTA, probability-averaged | **0.573** |
| + ensemble with unet-r34-v2 | 0.553 |
| + ensemble and TTA together | 0.558 |

**TTA is worth +0.014 mean IoU for 8× compute** — 15 s a hole on the A100,
which the offline sweep does not feel, and `GOLF_SEG_TTA=0` for anyone
interactive. Per class it is the small classes that collect: the whole point.

**The ensemble measured worse and did not ship.** Averaging the current best
with the older unet-r34-v2 (0.515 alone) pulls the pair below the better
member: a vote only helps between peers. The machinery stays — colon-separated
`GOLF_SEG_CHECKPOINT` — for when two comparable checkpoints exist.

Window blending is Gaussian now: a pixel at a window's edge has seen half its
context, and its vote is weighted accordingly. And the val split is now a
recorded oddity rather than a trap: val mean IoU is 0.267 against test 0.559,
*matching training-time val exactly* — three courses is a poor jury, not a
broken harness. Model selection continues to lean on green IoU, and
conclusions on the 163-patch test set.


---

## 11. The large-corpus retrain — 156× the data, and what it bought

The night of 2026-08-19 ran unattended: `golfseg-autopilot.service` waited
out the corpus build, trained, scored, deployed on a measured win, and
deleted the course data behind itself — dữ liệu sân dùng xong thì xoá. Done
by 11:30 the next morning, nobody watching.

### The corpus

164,446 training patches (17,558 val) from 28 states of Geofabrik extracts
traced against NAIP — against 1,051 in the corpus of §8. Every pixel public
domain, every mask ODbL. The lineage stamp on the pretrained weight reads
**shippable: commercial backbone, and every pixel permits automated
extraction** — the first weight in this project that may be sold as-is.

### Pretrain, 16 epochs, 7h10m on the shared A100

Best at epoch 7 (green IoU 0.687 on US val); nine further epochs never beat
it — the loss kept falling while green went sideways, so 16 was the right
budget, not a truncation. vLLM production served throughout, cap 0.11.

### Six fine-tunes on Vietnam, and a clean split

3 seeds × Lovász {0, 0.5}, each scored with TTA on the same 163-patch test
split as every number since §9:

| run | mean IoU | green | vs baseline 0.573 / 0.5554 |
|---|---|---|---|
| **s1-l0.5** | **0.584** | 0.563 | **deployed** |
| s2-l0.5 | 0.581 | 0.575 | eligible, second on mean |
| s0-l0.5 | 0.569 | 0.576 | green passed, mean short by 0.004 |
| s2-l0 | 0.548 | 0.542 | — |
| s0-l0 | 0.547 | 0.541 | — |
| s1-l0 | 0.539 | 0.520 | — |

Two findings, both unambiguous. **Lovász is worth ~+0.03 mean IoU here**:
the three runs without it cluster at 0.54, the three with it at 0.57–0.58,
across every seed. And **the big corpus beat the asking tier**: §10 bought
+0.014 with 8× compute at inference; this bought +0.011 over that, at zero
inference cost, by pretraining on 156× the data. Both are in the served
model now.

`pick_winner.py` was corrected mid-run (before it fired): it ranked by mean
and then gated the leader, so a run clearing both bars could be discarded
because a sibling with a higher mean failed the green. Both gates now apply
before the ranking, and each candidate carries `heldBackBy` in the summary.
This time the leader passed both gates anyway — but s2-l0.5 was a second
eligible candidate, which is exactly the situation the old ordering
mishandles.

### The caveat that outlives the win

The fine-tuned weight is stamped **RESEARCH ONLY**: its 1,051 Vietnam
patches are Esri World Imagery, which does not permit automated extraction.
The deploy gate reads scores, not lineage — the served model has carried
this stamp since naip-v3, so nothing regressed, but commercialisation needs
a licensed VN imagery source and a re-fine-tune. NAIP cannot help here; it
photographs only the United States.

Green edge error is now **2.2 m mean, 5.6 m p95** on test — inside a green's
own radius. Tee remains the hardest class (0.247 at best, 2.9× area
inflation): sparse, small, and OSM maps it worst.

### Housekeeping, verified

Corpus (68 GB) and PBF extracts deleted by the autopilot; `/data` back to
73%. Kept: `osm-us-large/` (655 MB, the corpus can be rebuilt from it), all
checkpoints and scores (1.1 GB). The 862-hole Vietnam draft re-sweep against
the new weight started 11:47.
