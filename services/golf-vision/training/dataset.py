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

#: The classes worth copying, because they are the classes the loss starves
#: on. Tees are 0.67% of labelled pixels, greens 1.45%, bunkers 2.2% — a
#: batch can go by without a single tee in it, and tee_box is the worst class
#: in every checkpoint this project has trained (IoU 0.19–0.22). Fairway and
#: water need no help: they are a third of the pixels between them.
COPY_PASTE_CLASSES = (1, 3, 4)  # tee_box, green, bunker

#: How often a training patch has instances pasted into it, and how many.
#:
#: Copy-paste (Ghiasi et al.) is the cheapest known remedy for rare-class
#: starvation: cut a real instance out of one patch, put it down in another,
#: and the mask moves with it, so the label is exact by construction. The
#: paste is deliberately unblended — the paper measured feathering and found
#: it buys nothing — and the ordinary blur augmentation that follows softens
#: a quarter of the collages anyway.
COPY_PASTE_PROBABILITY = 0.5
COPY_PASTE_MAX_INSTANCES = 3


class GolfSegDataset(Dataset):

    def __init__(self, root: str | Path, split: str, *, augment: bool = False,
                 crop: int = 512, norm_mean=(0.485, 0.456, 0.406),
                 norm_std=(0.229, 0.224, 0.225),
                 nir_mean: float = 0.45, nir_std: float = 0.22,
                 nir_dropout: float = NIR_DROPOUT,
                 copy_paste: float = COPY_PASTE_PROBABILITY):
        self.root = Path(root)
        self.split = split
        self.augment = augment
        self.crop = crop
        self.copy_paste = copy_paste if augment else 0.0
        #: (patch index, class index, bounding box) per rare instance —
        #: references rather than pixels, so a big corpus costs a list and not
        #: RAM. Built before the DataLoader forks its workers, so every worker
        #: shares one bank instead of each reading every mask again.
        self._instance_bank: list[tuple[int, int, tuple[int, int, int, int]]] = []
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

        if self.copy_paste > 0:
            self._instance_bank = self._build_instance_bank()

    def _build_instance_bank(self):
        """Every rare-class instance in the split, as references.

        One pass over the masks, cached beside the corpus: a thousand-patch
        split is seconds, but the American corpus is seventy thousand, and
        re-reading every mask at the start of every run is an hour nobody
        gets back. The cache keys on the patch list so a rebuilt corpus
        invalidates it.
        """
        import cv2

        cache = self.root / f"instance-bank.{self.split}.json"
        key = f"{len(self.items)}:{self.items[0].name}:{self.items[-1].name}"
        if cache.exists():
            stored = json.loads(cache.read_text())
            if stored.get("key") == key:
                return [tuple(entry[:2]) + (tuple(entry[2]),)
                        for entry in stored["instances"]]

        bank = []
        for patch_index, image_path in enumerate(self.items):
            mask = np.asarray(Image.open(self.mask_path(image_path)))
            for class_index in COPY_PASTE_CLASSES:
                of_class = (mask == class_index).astype(np.uint8)
                if not of_class.any():
                    continue
                count, labels = cv2.connectedComponents(of_class, 8)
                for component in range(1, count):
                    ys, xs = np.nonzero(labels == component)
                    # A sliver is not an instance worth teaching; a monster
                    # would not fit anywhere it is pasted.
                    if len(ys) < 40 or len(ys) > (self.crop * self.crop) // 4:
                        continue
                    bank.append((patch_index, class_index,
                                 (int(ys.min()), int(xs.min()),
                                  int(ys.max()) + 1, int(xs.max()) + 1)))
        try:
            cache.write_text(json.dumps(
                {"key": key, "instances": [list(e[:2]) + [list(e[2])]
                                           for e in bank]}))
        except OSError:
            pass  # a read-only corpus still trains, just slower to start
        return bank

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

    def _paste_instances(self, image, mask, nir=None):
        """Rare instances from elsewhere in the split, put down here.

        The image pixels, the mask pixels and the near-infrared move
        together, so the label is exact by construction — the one property
        that separates copy-paste from every synthetic-data scheme. Each
        instance arrives with a random dihedral pose, lands anywhere it fits,
        and covers whatever was under it, mask included; occlusion is part of
        the method, and the mask stays truthful about it.
        """
        if not self._instance_bank:
            return image, mask, nir
        image = image.copy()
        mask = mask.copy()
        nir = None if nir is None else nir.copy()

        for _ in range(random.randint(1, COPY_PASTE_MAX_INSTANCES)):
            patch_index, class_index, (top, left, bottom, right) = \
                random.choice(self._instance_bank)
            source_path = self.items[patch_index]
            source = np.asarray(Image.open(source_path).convert("RGB"))
            source_mask = np.asarray(Image.open(self.mask_path(source_path)))
            box = (slice(top, bottom), slice(left, right))
            cut = source[box]
            cut_mask = source_mask[box] == class_index
            cut_nir = None
            if nir is not None:
                nir_file = self.nir_path(source_path)
                if nir_file.exists():
                    cut_nir = np.asarray(
                        Image.open(nir_file).convert("L"))[box]

            # A random pose, so a bank of west-facing tees does not teach a
            # compass; same dihedral group as the patch augmentation.
            turns = random.randint(0, 3)
            if turns:
                cut = np.rot90(cut, turns)
                cut_mask = np.rot90(cut_mask, turns)
                cut_nir = None if cut_nir is None else np.rot90(cut_nir, turns)
            if random.random() < 0.5:
                cut = cut[:, ::-1]
                cut_mask = cut_mask[:, ::-1]
                cut_nir = None if cut_nir is None else cut_nir[:, ::-1]

            height, width = cut_mask.shape
            if height >= mask.shape[0] or width >= mask.shape[1]:
                continue
            y = random.randint(0, mask.shape[0] - height)
            x = random.randint(0, mask.shape[1] - width)
            window = (slice(y, y + height), slice(x, x + width))
            image[window][cut_mask] = cut[cut_mask]
            mask[window][cut_mask] = class_index
            if nir is not None and cut_nir is not None:
                nir[window][cut_mask] = cut_nir[cut_mask]

        return image, mask, nir

    def _augment(self, image, mask, nir=None):
        if random.random() < self.copy_paste:
            image, mask, nir = self._paste_instances(image, mask, nir)

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
