"""The deploy decision, written down instead of felt.

Reads every fine-tune's TTA test score and allows a deploy only when a
candidate beats the measured baseline of what is serving today: mean IoU
0.573 and green 0.5554, which is naip-v3 asked with TTA on the same 163
patches. A new weight that is better on the mean but worse on the green
does not ship — the green is the whole point of a rangefinder.

Both gates are applied *before* the ranking, not after it. Ranking first
and gating the leader means a run that clears both bars can be thrown
away because a sibling with a higher mean failed the green — six hours of
training ending in "nothing deployed" for a reason nobody intended.
`winner` stays the best by mean so the log still says who led; `deploy`
is the best of those actually allowed to ship.
"""

import glob
import json

BASELINE_MEAN = 0.573
BASELINE_GREEN = 0.5554

candidates = []
for path in sorted(glob.glob("/data/golfseg/runs/vn-large-*/tta.test.json")):
    scores = json.load(open(path))
    candidates.append({
        "run": path.rsplit("/", 2)[-2],
        "checkpoint": path.replace("tta.test.json", "best.pt"),
        "meanIoU": scores.get("meanIoU", 0),
        "green": scores.get("perClass", {}).get("green", {}).get("iou", 0),
        "perClass": {k: v.get("iou") for k, v in scores.get("perClass", {}).items()},
    })

candidates.sort(key=lambda c: (c["meanIoU"], c["green"]), reverse=True)
for candidate in candidates:
    reasons = []
    if candidate["meanIoU"] <= BASELINE_MEAN:
        reasons.append(f"mean {candidate['meanIoU']:.4f} <= {BASELINE_MEAN}")
    if candidate["green"] < BASELINE_GREEN:
        reasons.append(f"green {candidate['green']:.4f} < {BASELINE_GREEN}")
    candidate["eligible"] = not reasons
    candidate["heldBackBy"] = reasons

winner = candidates[0] if candidates else None
eligible = [c for c in candidates if c["eligible"]]
deploy = eligible[0]["checkpoint"] if eligible else None

print(json.dumps({
    "baseline": {"meanIoU": BASELINE_MEAN, "green": BASELINE_GREEN,
                 "what": "naip-v3 + TTA on the 163-patch test split"},
    "candidates": candidates,
    "winner": winner["run"] if winner else None,
    "deployRun": eligible[0]["run"] if eligible else None,
    "deploy": deploy,
}, indent=2))
