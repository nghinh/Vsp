"""Land cover from the French national mapping agency's aerial model.

Chosen over the obvious alternatives for a reason that is not accuracy. The
SegFormer checkpoints everyone reaches for are ADE20K — trained on
photographs taken by people standing up, which is a different manifold from
overhead imagery and fails on it. The ones that are trained on aerial data
are mostly CC-BY-NC: LoveDA, OpenEarthMap, OAM-TCD, and DeepGlobe's licence
has actually expired. FLAIR is Etalab 2.0, which grants commercial use
outright, and it was trained on 0.2 m aerial ortho — within touching distance
of the 0.287 m that Esri's zoom 19 gives at Vietnamese latitudes.

The honest caveat, from IGN's own model card: it "was trained with fixed
scale conditions", "no data augmentation method concerning scale change was
used", and it is "not intended to be generic to other type of very high
spatial resolution images but specific to BD ORTHO images". French farmland
in spring is not Vietnamese fairway under monsoon light. So the imagery is
rescaled to the scale it was trained at, and what comes out is measured
against real polygons rather than believed.
"""

from __future__ import annotations

import os
from typing import Any

import numpy as np
import torch

from ..classes import LandCover
from .base import ClassMask, LandCoverSegmentationProvider, SegmentationResult

#: The 19 logits the model emits. Four were switched off during training and
#: come back as zeros; they are listed so the indices line up.
FLAIR_CLASSES = [
    "building", "pervious surface", "impervious surface", "bare soil",
    "water", "coniferous", "deciduous", "brushwood", "vineyard",
    "herbaceous vegetation", "agricultural land", "plowed land",
    "swimming pool", "snow", "clear cut", "mixed", "ligneous", "greenhouse",
    "other",
]

#: French land cover to our generic vocabulary. Where FLAIR is finer than we
#: need, several of its classes collapse into one of ours; where it has no
#: word for something — sand, specifically — we do not invent one, and the
#: golf layer picks it out of bare soil by context instead.
TO_LAND_COVER: dict[str, LandCover] = {
    "building": LandCover.BUILDING,
    "pervious surface": LandCover.BARE_LAND,
    "impervious surface": LandCover.PAVEMENT,
    "bare soil": LandCover.BARE_LAND,
    "water": LandCover.WATER,
    "coniferous": LandCover.TREE,
    "deciduous": LandCover.TREE,
    "brushwood": LandCover.VEGETATION,
    "vineyard": LandCover.VEGETATION,
    "herbaceous vegetation": LandCover.GRASS,
    "agricultural land": LandCover.GRASS,
    "plowed land": LandCover.BARE_LAND,
    "swimming pool": LandCover.WATER,
    "snow": LandCover.UNKNOWN,
    "greenhouse": LandCover.BUILDING,
}

#: From the model card's training hyperparameters. Getting these wrong does
#: not throw — it quietly degrades every prediction.
NORM_MEANS = np.array([105.08, 110.87, 101.82], dtype=np.float32)
NORM_STDS = np.array([52.17, 45.38, 44.0], dtype=np.float32)

#: What the model was trained at, in metres per pixel.
NATIVE_METRES_PER_PIXEL = 0.2

DEFAULT_REPO = "IGNF/FLAIR-INC_rgb_15cl_resnet34-unet"
DEFAULT_WEIGHTS = "FLAIR-INC_rgb_15cl_resnet34-unet_weights.pth"


#: Wrapper prefixes seen in the published FLAIR checkpoints, longest first so
#: `model.seg_model.` is tried before `model.`.
_PREFIXES = ("model.seg_model.", "seg_model.", "model.")


def _strip(key: str) -> str:
    for prefix in _PREFIXES:
        if key.startswith(prefix):
            return key[len(prefix):]
    return key


class FlairLandCoverProvider(LandCoverSegmentationProvider):

    def __init__(self, repo: str | None = None, weights: str | None = None,
                 device: str | None = None, tile: int = 512, overlap: float = 0.25):
        self.repo = repo or os.environ.get("LAND_COVER_MODEL_NAME", DEFAULT_REPO)
        self.weights_file = weights or DEFAULT_WEIGHTS
        self.tile = tile
        self.overlap = overlap
        self._model = None
        self._error: str | None = None
        self.device = torch.device(
            device or os.environ.get("GOLF_VISION_DEVICE") or
            ("mps" if torch.backends.mps.is_available()
             else "cuda" if torch.cuda.is_available() else "cpu"))

    @property
    def name(self) -> str:
        return f"flair:{self.repo}"

    @property
    def available(self) -> bool:
        try:
            self._load()
            return True
        except Exception as error:      # noqa: BLE001 — availability, not correctness
            self._error = str(error)
            return False

    def _load(self):
        if self._model is not None:
            return self._model
        import segmentation_models_pytorch as smp
        from huggingface_hub import hf_hub_download

        path = hf_hub_download(self.repo, self.weights_file)
        model = smp.Unet(encoder_name="resnet34", encoder_weights=None,
                         in_channels=3, classes=19)
        state = torch.load(path, map_location="cpu", weights_only=False)
        if isinstance(state, dict) and "state_dict" in state:
            state = state["state_dict"]

        # IGN trained under pytorch-lightning, which stores the weights two
        # modules deep: `model.seg_model.encoder.conv1.weight`. Stripping only
        # `model.` leaves `seg_model.` on every key, nothing matches, and
        # `strict=False` loads exactly zero of the 278 tensors without a word
        # — a network of random numbers that segments a lake as grass and
        # looks, from the outside, like a domain-gap problem.
        state = {_strip(key): value for key, value in state.items()
                 if not key.startswith("criterion.")}

        # strict=True, so the next checkpoint whose layout differs fails here
        # rather than three hours later in a confusing benchmark.
        model.load_state_dict(state, strict=True)
        model.eval().to(self.device)
        self._model = model
        return model

    def segment(self, image: np.ndarray,
                metadata: dict[str, Any] | None = None) -> SegmentationResult:
        model = self._load()
        height, width = image.shape[:2]

        normalised = (image.astype(np.float32) - NORM_MEANS) / NORM_STDS
        tensor = torch.from_numpy(normalised).permute(2, 0, 1).unsqueeze(0)

        logits = self._infer_tiled(model, tensor, height, width)
        probabilities = torch.softmax(logits, dim=0).cpu().numpy()
        predicted = probabilities.argmax(axis=0)

        # Several FLAIR classes collapse into one of ours, so the masks are
        # accumulated rather than assigned.
        merged: dict[LandCover, np.ndarray] = {}
        scores: dict[LandCover, list[float]] = {}
        for index, flair_name in enumerate(FLAIR_CLASSES):
            target = TO_LAND_COVER.get(flair_name)
            if target is None:
                continue
            mask = predicted == index
            if not mask.any():
                continue
            merged[target] = merged.get(
                target, np.zeros((height, width), dtype=bool)) | mask
            scores.setdefault(target, []).append(
                float(probabilities[index][mask].mean()))

        classes = [
            ClassMask(label=cover.value, mask=mask,
                      confidence=float(np.mean(scores[cover])),
                      mean_probability=float(np.mean(scores[cover])))
            for cover, mask in merged.items()
        ]
        classes.sort(key=lambda entry: entry.pixel_count, reverse=True)

        return SegmentationResult(
            width=width, height=height, classes=classes,
            model_name="FLAIR-INC_rgb_15cl_resnet34-unet",
            model_version="etalab-2.0/IGN",
            model_checkpoint=f"{self.repo}/{self.weights_file}",
            pipeline_version="golfvision-0.1",
            extra={"device": str(self.device),
                   "nativeMetresPerPixel": NATIVE_METRES_PER_PIXEL},
        )

    def _infer_tiled(self, model, tensor: torch.Tensor,
                     height: int, width: int) -> torch.Tensor:
        """Overlapping windows, averaged where they meet.

        §8: a fairway crosses tile edges, and a model run on abutting windows
        leaves a visible seam down the middle of it. Overlapping and averaging
        the logits removes the seam without any stitching logic downstream.
        """
        step = max(1, int(self.tile * (1 - self.overlap)))
        accumulated = torch.zeros((19, height, width), dtype=torch.float32)
        weights = torch.zeros((1, height, width), dtype=torch.float32)

        ys = list(range(0, max(1, height - self.tile + 1), step))
        xs = list(range(0, max(1, width - self.tile + 1), step))
        if ys[-1] + self.tile < height:
            ys.append(height - self.tile)
        if xs[-1] + self.tile < width:
            xs.append(width - self.tile)

        with torch.no_grad():
            for y in ys:
                for x in xs:
                    window = tensor[:, :, y:y + self.tile, x:x + self.tile]
                    if window.shape[-1] < 8 or window.shape[-2] < 8:
                        continue
                    out = model(window.to(self.device))[0].float().cpu()
                    accumulated[:, y:y + out.shape[1], x:x + out.shape[2]] += out
                    weights[:, y:y + out.shape[1], x:x + out.shape[2]] += 1

        return accumulated / weights.clamp(min=1)
