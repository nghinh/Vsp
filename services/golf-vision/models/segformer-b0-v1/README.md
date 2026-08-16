# GolfSeg SegFormer-B0 v1 — feasibility baseline

The first trained GolfSeg model. Proof, with numbers, that a segmentation
model separates the golf classes a generic land-cover model cannot.

## What it is

- **Architecture**: SegFormer, `nvidia/mit-b0` encoder, 9-class decode head.
- **Trained on**: 1,051 patches / 26 courses from the OSM layer, 512 px at
  0.29 m/px, median-frequency class weights + Dice loss, 40 epochs, ~12 min on
  one A100 (shared with a live vLLM, capped at 9.6 GB).
- **Checkpoint**: `best.pt` (epoch 29, chosen on validation green IoU). Not in
  git — it is 14 MB of weights; the metrics beside it are.

## Measured on the 5 held-out test courses

The model never saw these courses in training.

| class | IoU | recall | edge µ | edge p95 |
|---|---|---|---|---|
| water_hazard | 0.743 | 0.79 | 6.4 m | 27.8 m |
| fairway | 0.657 | 0.92 | 5.6 m | 15.6 m |
| background | 0.641 | 0.73 | 6.1 m | 15.7 m |
| **green** | **0.528** | 0.89 | **2.5 m** | 6.7 m |
| bunker | 0.475 | 0.90 | 2.5 m | 6.0 m |
| tee_box | 0.192 | 0.82 | 4.4 m | 9.8 m |
| **mean IoU** | **0.539** | | | |

### Against the land-cover baseline (§3, §7)

| class | land-cover | GolfSeg-B0 |
|---|---|---|
| green | IoU 0.006 | **0.528** |
| fairway | not separable | **0.657** |
| bunker | 0.10–0.42, needs shape+position filter | 0.475, labelled directly |

Green — the class a rangefinder most needs and the one no generic model could
touch — went from 0.006 to 0.53, at a 2.5 m boundary error. That is the whole
argument of the refactor, now settled: **the geometry comes from a mask, and
the golf class comes from a model trained to see it.**

## Licence — do not ship this checkpoint

The `mit-b0` encoder is under NVIDIA's research licence: **non-commercial**.
This weight is for feasibility measurement only. The production model retrains
the same pipeline on an MIT/Apache backbone — `GOLF_SEG_MODEL_PROVIDER=smp`,
already wired — and the masks it learns from are ODbL. Both are recorded in
the checkpoint (`commercialOk: false`) and printed at the end of every run.

## What raises the numbers next, in order

1. **Better labels, not a bigger model.** OSM maps 3 of Đường B's ~20 bunkers;
   the model can only be as complete as its truth. Pre-label the sand the
   90%-precision bare-ground detector finds (§7), correct in review (§37), feed
   back (§38).
2. **SegFormer-B2** once labels are cleaner — B0 was chosen to prove the path
   cheaply, not because it is the ceiling.
3. **SAM boundary refinement** (§19) on the green and bunker edges, to pull the
   2.5 m boundary error toward the 1 m the land-cover bunkers already showed.
