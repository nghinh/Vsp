"""§45–46 — score a trained checkpoint the way a golfer would feel it.

IoU decides which model is better in the abstract. Metres decide whether the
number on the phone is one a golfer can club off. A green at 0.75 IoU can
still have a front edge eight metres from the truth, and this reports that
directly: for every green in the test set, how far its predicted front, centre
and back sit from the human-drawn ones, in metres, along the line of play.

Run on the held-out test split — courses the model never trained on — so the
number is what it would do on the next course, not a memory of this one.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GOLF_SEG_LABELS                  # noqa: E402
from training.dataset import GolfSegDataset                     # noqa: E402
from training.metrics import ConfusionMatrix                    # noqa: E402
from training.models import build_model                         # noqa: E402

NUM_CLASSES = len(GOLF_SEG_LABELS)


def boundary_errors_m(prediction: np.ndarray, truth: np.ndarray,
                      class_index: int, metres_per_pixel: float) -> list[float]:
    """Distance from each true edge pixel to the nearest predicted edge, for
    one class, over matched components only — the same honest metric the
    land-cover evaluation settled on, so the two are comparable."""
    import cv2

    def edge(mask):
        eroded = cv2.erode(mask.astype(np.uint8), np.ones((3, 3), np.uint8), 1)
        return (mask.astype(np.uint8) - eroded).astype(bool)

    pred = prediction == class_index
    true = truth == class_index
    if not pred.any() or not true.any():
        return []

    count, labels = cv2.connectedComponents(true.astype(np.uint8), 8)
    predicted_edge = edge(pred)
    if not predicted_edge.any():
        return []
    distance = cv2.distanceTransform((~predicted_edge).astype(np.uint8),
                                     cv2.DIST_L2, 5)
    errors = []
    for index in range(1, count):
        component = labels == index
        if not (component & pred).any():
            continue
        errors.extend((distance[edge(component)] * metres_per_pixel).tolist())
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--split", default="test")
    parser.add_argument("--device", default=None)
    # Patches were cut at zoom 19 over Vietnam — 0.29 m/px. Passed rather than
    # assumed so a dataset built at another zoom scores correctly.
    parser.add_argument("--metres-per-pixel", type=float, default=0.293)
    args = parser.parse_args()

    device = torch.device(
        args.device or ("cuda" if torch.cuda.is_available() else "cpu"))
    state = torch.load(args.checkpoint, map_location="cpu", weights_only=False)

    # The checkpoint says how wide its stem is. Read rather than assumed: the
    # near-infrared corpus made four channels the default, and scoring a
    # three-channel checkpoint from before that against a four-channel model
    # fails at load with a shape error that reads like a corrupt file.
    model = build_model(NUM_CLASSES,
                        provider=state["args"].get("provider", "segformer"),
                        name=state["args"].get("model_name"),
                        in_channels=state.get("inChannels", 3))
    model.load_state_dict(state["model"])
    model.eval().to(device)

    dataset = GolfSegDataset(args.data, args.split, augment=False,
                             crop=state["args"].get("crop", 512))
    print(f"scoring {len(dataset)} {args.split} patches with {args.checkpoint}")

    # What this weight is allowed to be. A score is only half the question —
    # the other half is whether the imagery underneath it may be sold, and the
    # answer travels with the checkpoint rather than with whoever ran it.
    for step in state.get("lineage", []):
        mark = "ok " if step.get("permitsAutomatedExtraction") else "NO "
        print(f"  [{mark}] {step.get('imagerySource'):20s} "
              f"{step.get('patches', 0):6d} patches  "
              f"{step.get('imageryLicense')}")
    if "shippable" in state:
        print("  shippable" if state["shippable"] else
              "  RESEARCH ONLY — see the entries marked NO above")

    confusion = ConfusionMatrix(NUM_CLASSES)
    edge_errors: dict[int, list[float]] = {i: [] for i in GOLF_SEG_LABELS}
    with torch.no_grad():
        for i in range(len(dataset)):
            pixels, target = dataset[i]
            prediction = model(pixels.unsqueeze(0).to(device)).argmax(1)[0]
            pred_np = prediction.cpu().numpy()
            true_np = target.numpy()
            confusion.update(prediction, target.to(device))
            for index in GOLF_SEG_LABELS:
                edge_errors[index].extend(
                    boundary_errors_m(pred_np, true_np, index,
                                      args.metres_per_pixel))

    iou = confusion.per_class_iou()
    recall = confusion.per_class_recall()
    support = confusion.support()
    print(f"\n{'class':14s} {'IoU':>6s} {'recall':>7s} {'edge µ':>8s} "
          f"{'edge p95':>9s}  {'test px':>10s}")
    result = {"split": args.split, "meanIoU": round(confusion.mean_iou(), 4),
              "perClass": {}}
    for index, feature in GOLF_SEG_LABELS.items():
        if support[index] == 0:
            continue
        errors = np.asarray(edge_errors[index]) if edge_errors[index] else None
        mean_e = float(errors.mean()) if errors is not None else float("nan")
        p95 = float(np.percentile(errors, 95)) if errors is not None else float("nan")
        print(f"{feature.value:14s} {iou[index]:6.3f} {recall[index]:7.3f} "
              f"{mean_e:7.1f}m {p95:8.1f}m  {int(support[index]):10d}")
        result["perClass"][feature.value] = {
            "iou": round(float(iou[index]), 4),
            "recall": round(float(recall[index]), 4),
            "edgeMeanM": round(mean_e, 2), "edgeP95M": round(p95, 2)}

    print(f"\nmean IoU {result['meanIoU']:.3f}")
    out = Path(args.checkpoint).with_suffix(".test.json")
    out.write_text(json.dumps(result, indent=2))
    print(f"-> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
