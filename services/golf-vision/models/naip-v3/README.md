# GolfSeg v3 — pretrained where the imagery is public domain

Three checkpoints from one experiment, and the honest reading of what
separates them. The question was whether pretraining on OpenStreetMap over
NAIP buys anything in Vietnam, and whether a weight that has never seen an
Esri pixel is worth having on its own.

## The three

| | corpus | imagery | may it ship |
|---|---|---|---|
| **A** `naip-pretrain` | 89 US courses, 5 744 patches | NAIP, public domain | **yes** |
| **B** `vn-finetuned` | A, then 34 VN courses, 1 051 patches | NAIP then Esri | no |
| **C** `vn-only` | 34 VN courses, 1 051 patches | Esri | no |

C exists because without it the experiment says nothing. B differs from the
v2 baseline in the corpus *and* in the recipe — four input channels, a blur
augmentation, a different number of epochs — so comparing B to v2 would credit
pretraining with whatever those changed. C is B's recipe with the pretraining
removed and nothing else.

All three scored on the same 5 held-out Vietnamese courses, 163 patches,
which none of them trained on.

## Per-class IoU on the Vietnamese test set

| class | A (NAIP only) | B (NAIP→VN) | C (VN only) | B − C |
|---|---|---|---|---|
| green | 0.240 | **0.555** | 0.532 | +0.023 |
| bunker | 0.433 | **0.450** | 0.436 | +0.014 |
| tee_box | 0.055 | **0.218** | 0.181 | +0.038 |
| fairway | 0.026 | 0.698 | **0.710** | −0.012 |
| water_hazard | 0.461 | **0.766** | 0.763 | +0.003 |
| **mean IoU** | 0.251 | **0.559** | 0.548 | +0.012 |

Green recall: A 0.517, B **0.935**, C 0.880.

## What this actually shows

**Pretraining helps, and by less than it is tempting to say.** +0.012 mean IoU
is at the noise floor this project already recorded — the v2 card puts
run-to-run variation at about 0.02, and this is one seed. The pattern is more
convincing than the magnitude: every class improves except fairway, and the
two largest gains are on the two weakest classes. tee_box, the worst class in
every version of this model, gains 21% relative. Green recall gains five and a
half points, which for a rangefinder matters more than IoU does — a green the
model does not find has no distance at all.

The mechanism is visible in the corpora. tee_box is 0.63% of labelled pixels
in Vietnam and 2.04% in the American corpus; green is roughly 0.5% against
2.47%. The American courses are not better photographed, they are better
*mapped*, and the classes that were starved are the classes that improved.

**A is worth having, and it is not a golf map.** A has never seen Vietnam and
scores 0.433 IoU on Vietnamese bunkers with a 1.9 m mean edge error — better
edges than any previous checkpoint, including ones trained on the country.
Greens it finds half the time. Fairway collapses completely: 0.026 IoU, and it
predicts nine per cent of the fairway area that is there. Tee goes the other
way, predicting seven times too much.

So the domain gap is real and it is not uniform. Sand is sand — a bunker in
Florida and a bunker in Long Biên are the same object photographed the same
way. Mown grass is not: what an American course calls fairway and what a
Vietnamese paspalum course looks like from 300 m are different enough that the
model transfers essentially none of it.

**Every model here paints too much of everything small.** Area ratio,
predicted over true:

| class | B | C |
|---|---|---|
| green | 1.62 | 1.54 |
| bunker | 1.97 | 2.00 |
| tee_box | 3.51 | 4.09 |

Measured independently against the live Long Biên database, GolfSeg's greens
came out at 1.46× the area a mapper drew across 11 matched pairs. Three
different measurements, one direction, every time. This is not a model that
needs more data — it is a decision threshold sitting at 0.5 on classes whose
real edges are gradual, and moving it is a cheaper and better-behaved fix than
anything else in this document. A green 1.6× too large has a front edge about
three metres nearer than the truth, which a golfer clubs off.

## The licence, which was the point

The v2 card ends: *"Trained on Esri imagery, which does not licence automated
extraction. This is research output until the imagery question is settled."*

A settles it, for what A can do. Public-domain imagery, ODbL labels, an MIT
backbone, and a lineage recorded in the checkpoint itself:

```
imagery this weight has seen:
  [ok ] naip    5744 patches  Public domain — USDA Farm Service Agency, NAIP
→ shippable: commercial backbone, and every pixel permits automated extraction
```

B is the better model and carries Esri in its lineage, so it is research only
and says so at load. That is not a workaround waiting to be found — the
Vietnamese corpus *is* Esri imagery, and no free high-resolution alternative
covers Vietnam. Sentinel-2 is free and 10 m, which cannot see a bunker;
Google and Bing carry the same restriction Esri does.

Which makes B − C the number that prices the alternative. Fine-tuning on
Vietnamese imagery is worth roughly +0.01 mean IoU and +0.05 green recall over
pretraining alone — no, that is the wrong reading. **A → B is worth +0.31 mean
IoU**: the fine-tune is not a refinement, it is most of the model. Buying
licensed high-resolution imagery over Vietnam's courses — Pléiades at 0.3 m,
roughly 150 km² for a hundred courses — is what converts B's score into a
weight that may ship. That is the decision this experiment was run to inform.

## Reproducing

```bash
python datasets/discover_osm_courses.py --out data/osm-us --limit 220
python datasets/build_naip_dataset.py --index data/osm-us --out data/golfseg-us --shard 0/6   # ×6
python datasets/build_naip_dataset.py --out data/golfseg-us --merge

python training/train.py --data data/golfseg-us --out runs/naip-pretrain \
  --provider smp --epochs 40 --batch 8 --select-on green
python training/train.py --data data/golfseg --out runs/vn-finetuned \
  --init-from runs/naip-pretrain/best.pt --provider smp --epochs 40 --batch 8
python training/train.py --data data/golfseg --out runs/vn-only \
  --provider smp --epochs 40 --batch 8

python evaluation/evaluate_checkpoint.py --data data/golfseg --checkpoint <ckpt> --split test
```

## What to do next, in order of what it is worth

1. **Calibrate the thresholds.** Three independent measurements say the shapes
   are too big by a consistent factor. This is a day's work and it moves the
   number a golfer reads.
2. **More courses.** 89 were built of 140 discovered, and discovery had not
   finished. The curve has not flattened.
3. **Multiple seeds.** +0.012 with one seed is not a result. Three seeds each
   for B and C would say whether it is one.
4. **Licensed Vietnamese imagery**, priced by the A → B gap above.
