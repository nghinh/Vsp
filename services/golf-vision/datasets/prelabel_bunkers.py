"""§37 — fill in the bunkers OpenStreetMap did not map.

The measured limit of the corpus: Đường B maps three bunkers where the ground
has about twenty. A mask built from OSM alone teaches the model that sand is
background, which is worse than teaching it nothing.

The bare-ground detector already solves the harder half of this. Measured on
Long Thành it finds two thirds of the real bunkers with their edges inside
1.4 m, and once the golf semantic layer has thrown out the cart paths and the
service tracks it is right about 90% of what it keeps. That is good enough to
propose a label — not good enough to publish a distance, which is why these
go into the training mask and not into the app.

What it writes is deliberately conservative:

* only inside a course's own footprint, so a neighbouring building site never
  becomes a bunker;
* only where OSM has not already drawn one, because a mapper's polygon is
  better than a detector's every time;
* as class 4 where it is confident and as **ignore** where it is merely
  plausible — a pixel the loss skips costs nothing, and a pixel labelled
  wrongly costs the model its calibration.

    python datasets/prelabel_bunkers.py --data /root/golfseg/data --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GolfFeature, LandCover           # noqa: E402
from golfvision.geo.tiles import ImageBounds                    # noqa: E402
from golfvision.masks.postprocess import MaskPostProcessor      # noqa: E402
from golfvision.providers.flair import (                        # noqa: E402
    NATIVE_METRES_PER_PIXEL as NATIVE_MPP, FlairLandCoverProvider)
from golfvision.semantics.inference import (                    # noqa: E402
    GolfSemanticInferenceService)
from golfvision.vector.vectorize import MaskVectorizationService  # noqa: E402

BUNKER = 4
IGNORE = 255

#: Above this the detector's verdict is written as a bunker label; between
#: this and [MAYBE] it is written as ignore, so the loss neither learns it nor
#: learns against it. Below, nothing is written at all.
CONFIDENT = 0.55
MAYBE = 0.25


def prelabel(image: np.ndarray, mask: np.ndarray, provider,
             metres_per_pixel: float) -> tuple[np.ndarray, int, int]:
    """Returns the amended mask, pixels labelled, pixels left to ignore."""
    import cv2

    factor = metres_per_pixel / NATIVE_MPP
    scaled = cv2.resize(image, None, fx=factor, fy=factor,
                        interpolation=cv2.INTER_CUBIC) if abs(factor - 1) > 0.05 \
        else image
    result = provider.segment(scaled)

    bare = result.by_label(LandCover.BARE_LAND.value)
    if bare is None:
        return mask, 0, 0

    candidate = cv2.resize(bare.mask.astype(np.uint8), (mask.shape[1], mask.shape[0]),
                           interpolation=cv2.INTER_NEAREST).astype(bool)
    cleaner = MaskPostProcessor(metres_per_pixel)
    candidate = cleaner.clean(candidate, GolfFeature.BUNKER)
    if not candidate.any():
        return mask, 0, 0

    # A patch has no anchor — the hole's tee and green are not in scope here —
    # so the semantic layer judges on shape and size alone. That is the signal
    # that removes cart paths, which is the one that matters most.
    bounds = ImageBounds(north=0.001, south=0.0, east=0.001, west=0.0,
                         zoom=19, width=mask.shape[1], height=mask.shape[0])
    service = GolfSemanticInferenceService(anchor=None)
    vectorizer = MaskVectorizationService(bounds)

    confident = np.zeros_like(candidate)
    maybe = np.zeros_like(candidate)
    for feature in vectorizer.vectorize(candidate, "bunker", simplify_m=0.0):
        verdict = service.classify(feature, LandCover.BARE_LAND)
        if verdict.confidence < MAYBE:
            continue
        target = confident if verdict.confidence >= CONFIDENT else maybe
        points = np.array([bounds.lat_lng_to_pixel(y, x)
                           for x, y in feature.geometry.exterior.coords],
                          dtype=np.int32)
        cv2.fillPoly(target.view(np.uint8), [points], 1)

    amended = mask.copy()
    # A mapper's polygon always wins; only background and ignore are amended.
    open_ground = (amended == 0) | (amended == IGNORE)
    labelled = int((confident & open_ground).sum())
    hidden = int((maybe & open_ground & ~confident).sum())
    amended[confident & open_ground] = BUNKER
    amended[maybe & open_ground & ~confident] = IGNORE
    return amended, labelled, hidden


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--splits", nargs="*", default=["train"],
                        help="val and test are left alone by default: a "
                             "detector-written label in the test set would be "
                             "scoring the model against itself")
    parser.add_argument("--metres-per-pixel", type=float, default=0.293)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    from PIL import Image

    root = Path(args.data)
    provider = FlairLandCoverProvider()
    if not provider.available:
        print(f"land-cover model unavailable: {provider._error}")
        return 1

    total_labelled = 0
    total_hidden = 0
    touched = 0
    for split in args.splits:
        images = sorted((root / "images" / split).glob("*.png"))
        if args.limit:
            images = images[:args.limit]
        print(f"{split}: {len(images)} patches")

        for index, image_path in enumerate(images, 1):
            mask_path = root / "masks" / split / image_path.name
            if not mask_path.exists():
                continue
            image = np.asarray(Image.open(image_path).convert("RGB"))
            mask = np.asarray(Image.open(mask_path))

            amended, labelled, hidden = prelabel(
                image, mask, provider, args.metres_per_pixel)
            if labelled or hidden:
                touched += 1
                total_labelled += labelled
                total_hidden += hidden
                if not args.dry_run:
                    Image.fromarray(amended).save(mask_path)
            if index % 100 == 0:
                print(f"  {index}/{len(images)}  "
                      f"+{total_labelled} px bunker, {total_hidden} px ignored")

    print(f"\n{'would label' if args.dry_run else 'labelled'} "
          f"{total_labelled} px as bunker and hid {total_hidden} px as ignore, "
          f"across {touched} patches")

    if not args.dry_run:
        manifest_path = root / "manifest.json"
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text())
            manifest["prelabelledBunkers"] = {
                "splits": args.splits,
                "pixelsLabelled": total_labelled,
                "pixelsIgnored": total_hidden,
                "patches": touched,
                "detector": provider.name,
                "confidentAbove": CONFIDENT,
                "note": "Detector-proposed bunkers where OSM mapped none. "
                        "Training labels only — never served as geometry.",
            }
            manifest_path.write_text(json.dumps(manifest, indent=2,
                                                ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
