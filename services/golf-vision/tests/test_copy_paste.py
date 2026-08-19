"""Copy-paste has one promise: the image and the mask move together.

A paste that moves pixels without labels manufactures exactly the corruption
the corpus already suffers from OSM's gaps — real sand labelled background —
at unlimited scale. So every test here is about the image/mask contract, on a
corpus small enough to enumerate by hand.
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from training.dataset import GolfSegDataset  # noqa: E402

TEE, GREEN, BUNKER = 1, 3, 4


def corpus(tmp_path: Path, crop: int = 64) -> Path:
    """Two patches: one with a bunker and a tee, one entirely background."""
    for name in ("images", "masks"):
        (tmp_path / name / "train").mkdir(parents=True)

    donor_mask = np.zeros((crop, crop), np.uint8)
    donor_mask[10:20, 10:22] = BUNKER
    donor_mask[40:52, 30:38] = TEE
    donor = np.zeros((crop, crop, 3), np.uint8)
    donor[donor_mask == BUNKER] = (210, 200, 160)   # sand
    donor[donor_mask == TEE] = (40, 120, 40)        # turf

    empty = np.full((crop, crop, 3), 90, np.uint8)
    empty_mask = np.zeros((crop, crop), np.uint8)

    for stem, image, mask in (("donor", donor, donor_mask),
                              ("empty", empty, empty_mask)):
        Image.fromarray(image).save(tmp_path / "images/train" / f"{stem}.png")
        Image.fromarray(mask).save(tmp_path / "masks/train" / f"{stem}.png")
    return tmp_path


def test_the_bank_finds_every_instance(tmp_path):
    dataset = GolfSegDataset(corpus(tmp_path), "train", augment=True,
                             crop=64, copy_paste=1.0)
    classes = sorted(entry[1] for entry in dataset._instance_bank)
    assert classes == [TEE, BUNKER], "one bunker and one tee, nothing else"


def test_pixels_and_labels_move_together(tmp_path):
    dataset = GolfSegDataset(corpus(tmp_path), "train", augment=True,
                             crop=64, copy_paste=1.0)
    empty = np.full((64, 64, 3), 90, np.uint8)
    empty_mask = np.zeros((64, 64), np.uint8)

    random.seed(7)
    image, mask, _ = dataset._paste_instances(empty, empty_mask)

    assert (mask != 0).any(), "something was pasted"
    for class_index, colour in ((BUNKER, (210, 200, 160)),
                                (TEE, (40, 120, 40))):
        where = mask == class_index
        if where.any():
            assert (image[where] == colour).all(), (
                "every pixel labelled with the class wears its colour — the "
                "image and the mask moved together")
    # And the contrapositive: no donor colour landed anywhere unlabelled.
    sand = (image == (210, 200, 160)).all(axis=-1)
    assert not (sand & (mask != BUNKER)).any(), (
        "sand pixels outside the bunker label are the OSM bug, manufactured")


def test_the_originals_are_never_written(tmp_path):
    dataset = GolfSegDataset(corpus(tmp_path), "train", augment=True,
                             crop=64, copy_paste=1.0)
    empty = np.full((64, 64, 3), 90, np.uint8)
    empty_mask = np.zeros((64, 64), np.uint8)
    kept, kept_mask = empty.copy(), empty_mask.copy()

    random.seed(11)
    dataset._paste_instances(empty, empty_mask)

    assert (empty == kept).all() and (empty_mask == kept_mask).all(), (
        "the paste works on copies; a DataLoader may hand the same array out "
        "twice")


def test_off_means_off(tmp_path):
    dataset = GolfSegDataset(corpus(tmp_path), "train", augment=False)
    assert dataset.copy_paste == 0.0
    assert dataset._instance_bank == []


def test_the_bank_cache_is_honoured_and_invalidated(tmp_path):
    root = corpus(tmp_path)
    first = GolfSegDataset(root, "train", augment=True, crop=64,
                           copy_paste=1.0)
    cache = root / "instance-bank.train.json"
    assert cache.exists()

    again = GolfSegDataset(root, "train", augment=True, crop=64,
                           copy_paste=1.0)
    assert again._instance_bank == first._instance_bank

    # A rebuilt corpus must not serve a stale bank.
    extra_mask = np.zeros((64, 64), np.uint8)
    extra_mask[5:15, 5:15] = GREEN
    Image.fromarray(np.zeros((64, 64, 3), np.uint8)).save(
        root / "images/train/zz-new.png")
    Image.fromarray(extra_mask).save(root / "masks/train/zz-new.png")
    rebuilt = GolfSegDataset(root, "train", augment=True, crop=64,
                             copy_paste=1.0)
    assert any(entry[1] == GREEN for entry in rebuilt._instance_bank)
