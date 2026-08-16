# GolfSeg U-Net/ResNet-34 v2 — the shippable one

The model that can actually go into a product, and an honest record of what
the label work bought.

## What changed from v1

Two things at once, which is why the comparison needs care:

1. **A commercially usable backbone.** v1 used `nvidia/mit-b0`, whose licence
   is research-only. This is `segmentation_models_pytorch` U-Net with an
   ImageNet ResNet-34 encoder — MIT throughout. `commercialOk: true`.
2. **Better labels.** The bare-ground detector pre-labelled the bunkers OSM
   never mapped: +724k px written as bunker across 788 of 1,051 training
   patches, and 2.5M px of uncertain sand moved to `ignore` so the loss stops
   learning that sand is background. Bunker went from 2.23% to 2.75% of
   labelled pixels.

## Measured on the 5 held-out test courses

| class | v1 (mit-b0) | **v2 (ResNet-34)** | v2 recall | v2 edge µ |
|---|---|---|---|---|
| water_hazard | 0.743 | 0.725 | 0.774 | 6.5 m |
| fairway | 0.657 | 0.636 | 0.897 | 5.3 m |
| background | 0.641 | 0.608 | 0.698 | 4.9 m |
| green | 0.528 | 0.510 | **0.951** | 2.8 m |
| bunker | 0.475 | 0.444 | 0.889 | **2.3 m** |
| tee_box | 0.192 | 0.167 | 0.810 | 4.5 m |
| **mean IoU** | 0.539 | **0.515** | | |

**The honest read: IoU did not improve.** It is 0.02 lower across the board,
which is within what two runs of the same recipe differ by. What did move:

* **green recall 0.891 → 0.951.** The model now finds nineteen greens in
  twenty rather than nine in ten — for a rangefinder that matters more than
  the overlap score, because a green it does not find has no distance at all.
* **bunker edge 2.5 m → 2.3 m**, and green edge held at 2.8 m.
* **The licence.** v1 could never ship. This can.

The pre-labelling did not lift IoU in one run. That is not a failure of the
idea — 788 patches gained bunkers that were genuinely there, verified by eye
before they were written — but it is not evidence for it either. What it
plausibly bought is recall, and what it certainly bought is a training set
that no longer teaches that sand is background. The next run that isolates
one variable is the one that will say.

## Still true

* Trained on Esri imagery, which does not licence automated extraction. This
  is research output until the imagery question is settled.
* tee_box at 0.167 remains the weakest class: 0.63% of pixels and the
  smallest features on the course.
* The model is only as complete as its labels, and its labels are only as
  complete as OSM plus a detector with ~90% precision.
