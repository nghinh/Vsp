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


class GolfSegDataset(Dataset):

    def __init__(self, root: str | Path, split: str, *, augment: bool = False,
                 crop: int = 512, norm_mean=(0.485, 0.456, 0.406),
                 norm_std=(0.229, 0.224, 0.225)):
        self.root = Path(root)
        self.split = split
        self.augment = augment
        self.crop = crop
        self.mean = np.array(norm_mean, dtype=np.float32)
        self.std = np.array(norm_std, dtype=np.float32)

        image_dir = self.root / "images" / split
        self.items = sorted(image_dir.glob("*.png"))
        if not self.items:
            raise FileNotFoundError(f"no patches under {image_dir}")

        manifest = self.root / "manifest.json"
        self.manifest = json.loads(manifest.read_text()) if manifest.exists() else {}

    def __len__(self) -> int:
        return len(self.items)

    def mask_path(self, image_path: Path) -> Path:
        return self.root / "masks" / self.split / image_path.name

    def __getitem__(self, index: int):
        image_path = self.items[index]
        image = np.asarray(Image.open(image_path).convert("RGB"))
        mask = np.asarray(Image.open(self.mask_path(image_path)))

        if image.shape[:2] != (self.crop, self.crop):
            image, mask = self._centre_crop(image, mask)
        if self.augment:
            image, mask = self._augment(image, mask)

        normalised = (image.astype(np.float32) / 255.0 - self.mean) / self.std
        return (torch.from_numpy(normalised).permute(2, 0, 1),
                torch.from_numpy(mask.astype(np.int64)))

    def _centre_crop(self, image, mask):
        h, w = mask.shape
        top = max(0, (h - self.crop) // 2)
        left = max(0, (w - self.crop) // 2)
        return (image[top:top + self.crop, left:left + self.crop],
                mask[top:top + self.crop, left:left + self.crop])

    def _augment(self, image, mask):
        # Dihedral group: the eight flips and 90° rotations, which are the
        # only geometric transforms that keep a mask exact (no interpolation
        # inventing a class between two).
        if random.random() < 0.5:
            image, mask = image[:, ::-1], mask[:, ::-1]
        if random.random() < 0.5:
            image, mask = image[::-1], mask[::-1]
        turns = random.randint(0, 3)
        if turns:
            image = np.rot90(image, turns)
            mask = np.rot90(mask, turns)

        image = image.astype(np.float32)
        if random.random() < 0.5:      # brightness
            image *= random.uniform(0.8, 1.2)
        if random.random() < 0.5:      # contrast around the mid-grey
            image = 128 + (image - 128) * random.uniform(0.8, 1.2)
        if random.random() < 0.3:      # a per-channel cast, for the provider gap
            image *= np.array([random.uniform(0.92, 1.08) for _ in range(3)],
                              dtype=np.float32)
        return np.ascontiguousarray(np.clip(image, 0, 255).astype(np.uint8)), \
            np.ascontiguousarray(mask)


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
