"""Training GolfSeg, and keeping the run honest.

§40–42. A small, legible loop rather than a framework, because the value is
in what it measures, not in how it schedules. Every choice that could quietly
ruin a run is made loud: the class balance is printed before the first step,
the split is by course, the boundary of every checkpoint is scored in metres
as well as IoU, and the best checkpoint is chosen on green IoU rather than the
mean — because on this problem the mean is carried by water and background,
and the green is the whole point.

VRAM discipline (§54, and this server specifically): a hard fraction cap and
an explicit device, so a training run can share an A100 with a production
vLLM without ever being the process that pushes it into OOM. If the cap is
too small for the batch, it fails at allocation on step one — loudly, before
anything downstream notices — rather than creeping up and taking the server's
real job down with it.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GOLF_SEG_LABELS                  # noqa: E402
from training.dataset import GolfSegDataset, class_pixel_counts  # noqa: E402
from training.losses import GolfSegLoss, median_frequency_weights  # noqa: E402
from training.metrics import ConfusionMatrix                    # noqa: E402
from training.models import build_model                         # noqa: E402

NUM_CLASSES = len(GOLF_SEG_LABELS)


def evaluate(model, loader, device, num_classes) -> ConfusionMatrix:
    model.eval()
    confusion = ConfusionMatrix(num_classes)
    with torch.no_grad():
        for pixels, target in loader:
            logits = model(pixels.to(device))
            prediction = logits.argmax(1)
            confusion.update(prediction, target.to(device))
    return confusion


def report(confusion: ConfusionMatrix) -> dict:
    iou = confusion.per_class_iou()
    recall = confusion.per_class_recall()
    support = confusion.support()
    rows = {}
    for index, feature in GOLF_SEG_LABELS.items():
        if support[index] == 0:
            continue
        rows[feature.value] = {
            "iou": round(float(iou[index]), 4),
            "recall": round(float(recall[index]), 4),
            "supportPx": int(support[index]),
        }
    return {"meanIoU": round(confusion.mean_iou(), 4), "perClass": rows}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--out", default="runs/golfseg")
    parser.add_argument("--provider", default="segformer",
                        help="segformer (feasibility) | smp (commercial)")
    parser.add_argument("--model-name", default=None)
    parser.add_argument("--epochs", type=int, default=40)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--crop", type=int, default=512)
    parser.add_argument("--lr", type=float, default=6e-5)
    parser.add_argument("--dice-weight", type=float, default=0.5)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--device", default=None)
    parser.add_argument("--vram-fraction", type=float, default=None,
                        help="hard cap on this process's share of the GPU, so "
                             "it can never starve a co-tenant")
    parser.add_argument("--select-on", default="green",
                        help="the class whose IoU picks the best checkpoint")
    args = parser.parse_args()

    device = torch.device(
        args.device or ("cuda" if torch.cuda.is_available() else "cpu"))
    if device.type == "cuda" and args.vram_fraction:
        # The guardrail that lets this run beside production. PyTorch will
        # refuse an allocation past the fraction rather than take the whole
        # card.
        torch.cuda.set_per_process_memory_fraction(args.vram_fraction, device.index or 0)
        print(f"VRAM capped at {args.vram_fraction:.0%} of GPU {device.index or 0}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    train_set = GolfSegDataset(args.data, "train", augment=True, crop=args.crop)
    val_set = GolfSegDataset(args.data, "val", augment=False, crop=args.crop)
    print(f"train {len(train_set)} patches | val {len(val_set)} patches")

    counts = class_pixel_counts(train_set, NUM_CLASSES)
    weights = median_frequency_weights(counts).to(device)
    print("class pixel share and weight:")
    total = max(1, counts.sum())
    for index, feature in GOLF_SEG_LABELS.items():
        print(f"  {index} {feature.value:14s} {counts[index]/total*100:6.2f}%  "
              f"w={weights[index]:.2f}")

    train_loader = DataLoader(train_set, batch_size=args.batch, shuffle=True,
                              num_workers=args.workers, drop_last=True,
                              pin_memory=device.type == "cuda")
    val_loader = DataLoader(val_set, batch_size=max(1, args.batch // 2),
                            num_workers=args.workers,
                            pin_memory=device.type == "cuda")

    model = build_model(NUM_CLASSES, provider=args.provider,
                        name=args.model_name).to(device)
    criterion = GolfSegLoss(NUM_CLASSES, class_weights=weights,
                            dice_weight=args.dice_weight)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr,
                                  weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=args.epochs)
    scaler = torch.cuda.amp.GradScaler(enabled=device.type == "cuda")

    history = []
    best_score = -1.0
    for epoch in range(1, args.epochs + 1):
        model.train()
        started = time.time()
        running = 0.0
        for pixels, target in train_loader:
            pixels, target = pixels.to(device), target.to(device)
            optimizer.zero_grad(set_to_none=True)
            with torch.autocast(device_type=device.type,
                                enabled=device.type == "cuda"):
                loss = criterion(model(pixels), target)
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            running += loss.item()
        scheduler.step()

        confusion = evaluate(model, val_loader, device, NUM_CLASSES)
        scores = report(confusion)
        selected = scores["perClass"].get(args.select_on, {}).get("iou", 0.0)
        elapsed = time.time() - started
        print(f"epoch {epoch:3d}  loss {running/max(1,len(train_loader)):.3f}  "
              f"mIoU {scores['meanIoU']:.3f}  {args.select_on} IoU {selected:.3f}  "
              f"({elapsed:.0f}s)")
        history.append({"epoch": epoch, "loss": running / max(1, len(train_loader)),
                        **scores, "selected": selected})

        if selected > best_score:
            best_score = selected
            torch.save({"model": model.state_dict(), "epoch": epoch,
                        "scores": scores, "args": vars(args),
                        "labels": {i: f.value for i, f in GOLF_SEG_LABELS.items()},
                        "commercialOk": model.commercial_ok},
                       out / "best.pt")
            (out / "best.json").write_text(json.dumps(scores, indent=2))
            print(f"  ↑ best {args.select_on} IoU {best_score:.3f} — saved")

    (out / "history.json").write_text(json.dumps(history, indent=2))
    print(f"\nbest {args.select_on} IoU {best_score:.3f} -> {out/'best.pt'}")
    if not model.commercial_ok:
        print("! this checkpoint's backbone is non-commercial (SegFormer/NVIDIA) "
              "— feasibility only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
