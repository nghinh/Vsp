"""The trainable model, behind the abstraction §4 asks for.

Two backbones, chosen for a reason that outlives the prototype:

* **SegFormer** (`nvidia/mit-b*`) is what §41 prefers, and it is the right
  first baseline — efficient, strong on small data. Its encoder is under
  NVIDIA's research licence, which is **non-commercial**. Fine for measuring
  feasibility, a blocker for a shipped weight. This is stated at load, loudly,
  so nobody discovers it in a licence audit after training on it for a week.

* **U-Net / ResNet** via segmentation-models-pytorch, MIT and
  commercially clean, for the model that actually ships.

Same interface, same training loop, one environment variable between them —
which is the point of §4. When GolfSeg-v2 wants a different backbone, it is a
config change, not a rewrite.
"""

from __future__ import annotations

import os
import warnings

import torch
import torch.nn as nn


class GolfSegModel(nn.Module):
    """Wraps whichever backbone so the loop only sees logits."""

    def __init__(self, backbone: nn.Module, kind: str, commercial_ok: bool):
        super().__init__()
        self.backbone = backbone
        self.kind = kind
        self.commercial_ok = commercial_ok

    def forward(self, pixels: torch.Tensor) -> torch.Tensor:
        if self.kind == "segformer":
            logits = self.backbone(pixel_values=pixels).logits
            # SegFormer emits at a quarter resolution; the loss and the mask
            # are full size, so it is brought back here rather than in three
            # different callers.
            return nn.functional.interpolate(
                logits, size=pixels.shape[-2:], mode="bilinear",
                align_corners=False)
        return self.backbone(pixels)


def build_model(num_classes: int, *, provider: str | None = None,
                name: str | None = None) -> GolfSegModel:
    provider = (provider or os.environ.get("GOLF_SEG_MODEL_PROVIDER")
                or "segformer").lower()
    name = name or os.environ.get("GOLF_SEG_MODEL_NAME")

    if provider == "segformer":
        from transformers import SegformerForSemanticSegmentation
        checkpoint = name or "nvidia/mit-b0"
        warnings.warn(
            f"SegFormer encoder '{checkpoint}' is under NVIDIA's research "
            f"licence — non-commercial. Use for feasibility only; retrain on "
            f"an MIT/Apache backbone (GOLF_SEG_MODEL_PROVIDER=smp) before "
            f"anything ships.", stacklevel=2)
        model = SegformerForSemanticSegmentation.from_pretrained(
            checkpoint, num_labels=num_classes,
            ignore_mismatched_sizes=True)
        return GolfSegModel(model, "segformer", commercial_ok=False)

    if provider == "smp":
        import segmentation_models_pytorch as smp
        encoder = name or "resnet34"
        model = smp.Unet(encoder_name=encoder, encoder_weights="imagenet",
                         in_channels=3, classes=num_classes)
        return GolfSegModel(model, "smp", commercial_ok=True)

    raise ValueError(f"unknown model provider: {provider!r}")
