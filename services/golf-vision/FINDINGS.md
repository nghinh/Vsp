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
