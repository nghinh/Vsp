"""Reading the GolfSeg patches, and standing them on their heads.

§43 wants rotation most of all, and the reason is specific to this problem: a
golf hole can run in any direction, so a model that has only seen greens at
the top of the frame has learnt the compass, not the green. Flips and 90°
rotations are free and exactly right; colour jitter earns its place because
the imagery this will meet in production is a different provider from the one
it trained on, and a model that keys on Esri's exact green is brittle.

Nothing here needs a GPU. It is written to be import-safe on the laptop so the
augmentation can be eyeballed before an hour of A100 time is spent on it.
"""

from __future__ import annotations

import json
import random
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch.utils.data import Dataset

IGNORE_INDEX = 255


#: The value the near-infrared channel takes when there is no near-infrared.
#:
#: Always four channels, whether or not the corpus has a fourth band, because
#: a model pretrained on NAIP has to accept a Vietnamese patch that Esri
#: served without one — and a first convolution reshaped between pretraining
#: and fine-tuning is a first convolution retrained from scratch.
#:
#: Zero after normalisation, which is the mean of the training distribution:
#: "no information" rather than "black", and the same thing the channel-dropout
#: augmentation puts there so the model has seen it thousands of times.
NIR_ABSENT = 0.0

#: How often to hide the NIR band during pretraining.
#:
#: Every corpus with NIR is American and every corpus without it is Vietnamese,
#: so a model free to lean on the fourth channel would learn "NIR present" as a
#: shortcut for the whole American domain and arrive in Vietnam having lost it
#: along with everything correlated to it. Hiding it half the time forces both
#: paths to work.
NIR_DROPOUT = 0.5


class GolfSegDataset(Dataset):

    def __init__(self, root: str | Path, split: str, *, augment: bool = False,
                 crop: int = 512, norm_mean=(0.485, 0.456, 0.406),
                 norm_std=(0.229, 0.224, 0.225),
                 nir_mean: float = 0.45, nir_std: float = 0.22,
                 nir_dropout: float = NIR_DROPOUT):
        self.root = Path(root)
        self.split = split
        self.augment = augment
        self.crop = crop
        self.mean = np.array(norm_mean, dtype=np.float32)
        self.std = np.array(norm_std, dtype=np.float32)
        self.nir_mean = nir_mean
        self.nir_std = nir_std
        self.nir_dropout = nir_dropout

        image_dir = self.root / "images" / split
        self.items = sorted(image_dir.glob("*.png"))
        if not self.items:
            raise FileNotFoundError(f"no patches under {image_dir}")

        self.nir_dir = self.root / "nir" / split
        #: True when this corpus carries a fourth band at all. NAIP does;
        #: Esri tiles cannot.
        self.has_nir = self.nir_dir.is_dir() and any(self.nir_dir.glob("*.png"))

        manifest = self.root / "manifest.json"
        self.manifest = json.loads(manifest.read_text()) if manifest.exists() else {}

    def __len__(self) -> int:
        return len(self.items)

    def mask_path(self, image_path: Path) -> Path:
        return self.root / "masks" / self.split / image_path.name

    def nir_path(self, image_path: Path) -> Path:
        return self.nir_dir / image_path.name

    def __getitem__(self, index: int):
        image_path = self.items[index]
        image = np.asarray(Image.open(image_path).convert("RGB"))
        mask = np.asarray(Image.open(self.mask_path(image_path)))

        nir = None
        if self.has_nir:
            nir_file = self.nir_path(image_path)
            if nir_file.exists():
                nir = np.asarray(Image.open(nir_file).convert("L"))

        if image.shape[:2] != (self.crop, self.crop):
            image, mask, nir = self._centre_crop(image, mask, nir)
        if self.augment:
            image, mask, nir = self._augment(image, mask, nir)

        normalised = (image.astype(np.float32) / 255.0 - self.mean) / self.std
        channels = torch.from_numpy(normalised).permute(2, 0, 1)

        drop = self.augment and random.random() < self.nir_dropout
        if nir is None or drop:
            band = torch.full(channels.shape[-2:], NIR_ABSENT, dtype=torch.float32)
        else:
            band = torch.from_numpy(
                (nir.astype(np.float32) / 255.0 - self.nir_mean) / self.nir_std)
        return (torch.cat([channels, band.unsqueeze(0)], dim=0),
                torch.from_numpy(mask.astype(np.int64)))

    def _centre_crop(self, image, mask, nir=None):
        h, w = mask.shape
        top = max(0, (h - self.crop) // 2)
        left = max(0, (w - self.crop) // 2)
        window = (slice(top, top + self.crop), slice(left, left + self.crop))
        return (image[window], mask[window],
                None if nir is None else nir[window])

    def _augment(self, image, mask, nir=None):
        # Dihedral group: the eight flips and 90° rotations, which are the
        # only geometric transforms that keep a mask exact (no interpolation
        # inventing a class between two).
        if random.random() < 0.5:
            image, mask = image[:, ::-1], mask[:, ::-1]
            nir = None if nir is None else nir[:, ::-1]
        if random.random() < 0.5:
            image, mask = image[::-1], mask[::-1]
            nir = None if nir is None else nir[::-1]
        turns = random.randint(0, 3)
        if turns:
            image = np.rot90(image, turns)
            mask = np.rot90(mask, turns)
            nir = None if nir is None else np.rot90(nir, turns)

        image = image.astype(np.float32)
        if random.random() < 0.5:      # brightness
            image *= random.uniform(0.8, 1.2)
        if random.random() < 0.5:      # contrast around the mid-grey
            image = 128 + (image - 128) * random.uniform(0.8, 1.2)
        if random.random() < 0.3:      # a per-channel cast, for the provider gap
            image *= np.array([random.uniform(0.92, 1.08) for _ in range(3)],
                              dtype=np.float32)

        # Blur, and only ever blur. NAIP is 0.6 m sampled onto a 0.24 m grid,
        # so an American patch is already softer than the Vietnamese one it
        # has to generalise to; sharpening towards the target domain would be
        # inventing detail the photograph does not contain. Softening the
        # sharper Vietnamese patches during fine-tuning is the honest
        # direction, and it is the one that closes the gap.
        if random.random() < 0.25:
            image = _blur(image, random.uniform(0.6, 1.4))

        return (np.ascontiguousarray(np.clip(image, 0, 255).astype(np.uint8)),
                np.ascontiguousarray(mask),
                None if nir is None else np.ascontiguousarray(nir))


def _blur(image: np.ndarray, sigma: float) -> np.ndarray:
    """A small Gaussian, applied per channel.

    cv2 is already a dependency of the dataset builders and is far faster than
    doing this in numpy, but this runs inside a DataLoader worker where cv2's
    own thread pool fights the loader's. One thread, set once.
    """
    import cv2

    cv2.setNumThreads(0)
    return cv2.GaussianBlur(image, (0, 0), sigmaX=sigma, sigmaY=sigma)


def class_pixel_counts(dataset: GolfSegDataset, num_classes: int) -> np.ndarray:
    """Pixels per class across the split — the input to a class weight.

    Read straight off the masks rather than trusting the manifest, because a
    filtered or re-split dataset makes the manifest stale, and a weight
    computed from the wrong counts quietly unbalances the very thing it is
    meant to balance.
    """
    counts = np.zeros(num_classes, dtype=np.int64)
    for image_path in dataset.items:
        mask = np.asarray(Image.open(dataset.mask_path(image_path)))
        valid = mask[mask != IGNORE_INDEX]
        binned = np.bincount(valid, minlength=num_classes)
        counts += binned[:num_classes]
    return counts
