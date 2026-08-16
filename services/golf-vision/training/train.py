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
    parser.add_argument("--in-channels", type=int, default=4,
                        help="4 carries near-infrared; the band is a constant "
                             "on corpora that have none, so the shape is the "
                             "same either way and a pretrained stem transfers")
    parser.add_argument("--init-from", default=None,
                        help="checkpoint to start from — this is the "
                             "fine-tuning step")
    parser.add_argument("--nir-dropout", type=float, default=None,
                        help="how often to hide the fourth band; defaults to "
                             "half on a corpus that has one")
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

    kwargs = {} if args.nir_dropout is None else {"nir_dropout": args.nir_dropout}
    train_set = GolfSegDataset(args.data, "train", augment=True, crop=args.crop,
                               **kwargs)
    val_set = GolfSegDataset(args.data, "val", augment=False, crop=args.crop)
    print(f"train {len(train_set)} patches | val {len(val_set)} patches | "
          f"near-infrared: {'yes' if train_set.has_nir else 'no'}")

    lineage = corpus_lineage(train_set, args.init_from, len(train_set))

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
                        name=args.model_name,
                        in_channels=args.in_channels).to(device)
    if args.init_from:
        prior = torch.load(args.init_from, map_location=device,
                           weights_only=False)
        missing, unexpected = model.load_state_dict(prior["model"], strict=False)
        if missing or unexpected:
            # Not fatal — a changed class count or a widened stem is a
            # legitimate reason for a few tensors not to line up — but it is
            # never something to discover from a disappointing score.
            print(f"! init-from: {len(missing)} missing, "
                  f"{len(unexpected)} unexpected tensors")
        print(f"initialised from {args.init_from} "
              f"(epoch {prior.get('epoch')}, "
              f"{args.select_on} IoU "
              f"{prior.get('scores', {}).get('perClass', {})
                 .get(args.select_on, {}).get('iou')})")
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
                        "inChannels": args.in_channels,
                        "commercialOk": model.commercial_ok,
                        "lineage": lineage,
                        "shippable": is_shippable(model, lineage)},
                       out / "best.pt")
            (out / "best.json").write_text(json.dumps(
                {**scores, "lineage": lineage,
                 "shippable": is_shippable(model, lineage)}, indent=2))
            print(f"  ↑ best {args.select_on} IoU {best_score:.3f} — saved")

    (out / "history.json").write_text(json.dumps(history, indent=2))
    print(f"\nbest {args.select_on} IoU {best_score:.3f} -> {out/'best.pt'}")
    if not model.commercial_ok:
        print("! this checkpoint's backbone is non-commercial (SegFormer/NVIDIA) "
              "— feasibility only")
    print_lineage(model, lineage)
    return 0


def corpus_lineage(dataset, init_from: str | None, patches: int) -> list[dict]:
    """Every corpus whose pixels have reached these weights, in order.

    The point of writing this down is one question that is otherwise
    unanswerable six months later: *may this checkpoint ship?* Esri's World
    Imagery licence forbids automated extraction, so a weight that has seen an
    Esri patch cannot be sold however good it is, and nothing about the file
    itself says so. A NAIP-only weight can. The difference is not visible in
    the tensors and it is not recoverable from a directory name.

    Fine-tuning inherits: a model pretrained on NAIP and fine-tuned on Esri
    carries both, and is therefore as restricted as its most restricted source.
    That is the correct reading of the licence and the conservative one.
    """
    manifest = dataset.manifest or {}
    entry = {
        "corpus": str(dataset.root),
        "patches": patches,
        "imagerySource": manifest.get("imagerySource", "unknown"),
        "imageryLicense": manifest.get("imageryLicense", "unknown"),
        "permitsAutomatedExtraction": bool(
            manifest.get("imageryPermitsExtraction", False)),
        "maskLicense": manifest.get("maskLicense", "unknown"),
    }
    if not init_from:
        return [entry]

    prior = torch.load(init_from, map_location="cpu", weights_only=False)
    return [*prior.get("lineage", []), entry]


def is_shippable(model, lineage: list[dict]) -> bool:
    """True when both the backbone and every pixel it saw allow it."""
    return bool(model.commercial_ok) and all(
        step["permitsAutomatedExtraction"] for step in lineage)


def print_lineage(model, lineage: list[dict]) -> None:
    print("\nimagery this weight has seen:")
    for step in lineage:
        mark = "ok " if step["permitsAutomatedExtraction"] else "NO "
        print(f"  [{mark}] {step['imagerySource']:20s} {step['patches']:6d} "
              f"patches  {step['imageryLicense']}")
    if is_shippable(model, lineage):
        print("→ shippable: commercial backbone, and every pixel permits "
              "automated extraction")
    else:
        print("→ NOT shippable: research only. See the entries marked NO, and "
              "the backbone licence above.")


if __name__ == "__main__":
    raise SystemExit(main())
