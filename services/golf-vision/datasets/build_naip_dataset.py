"""OpenStreetMap over NAIP — the pretraining corpus, and a clean licence.

The companion to `build_golfseg_dataset.py`, which builds the Vietnamese
corpus from this project's own digitised polygons over Esri tiles. That one is
the fine-tune set and the only place evaluation numbers come from. This one is
where the model learns what a golf course looks like at all, and it exists for
two reasons that happen to have one answer.

**Scale.** Thirty-six courses is not a training set, it is a pilot. OSM has
drawn a third of a million greens, and NAIP has photographed the ones in the
United States at 0.6 m. Two orders of magnitude more courses, for the cost of
bandwidth.

**Licence.** Esri's World Imagery terms forbid automated extraction, so a model
trained on it cannot ship — which is written in v2's model card in as many
words. NAIP is public domain. A model pretrained here and fine-tuned on
Vietnamese imagery the project has its own right to use has never seen an Esri
pixel, and the manifest this writes is the evidence.

Three choices worth defending:

* **Zoom 19, which upsamples.** NAIP is 0.6 m; zoom 19 is 0.19–0.27 m across
  American latitudes. So these patches are softer than their pixel count
  suggests. The alternative — zoom 18, near NAIP's native scale — would show
  the model a green half the pixel size it will be at inference in Vietnam,
  and a convolutional network cares far more about object scale than about
  sharpness. Blur is a standard augmentation; scale mismatch is a different
  task. Softer at the right size beats sharper at the wrong one.

* **Stride 512 rather than 384.** The Vietnamese builder overlaps its windows
  by a quarter because it has thirty-six courses and needs every patch. Here
  there are hundreds, and variety between courses is worth more than variety
  between two views of the same bunker.

* **NIR in its own file.** RGB goes to `images/`, near-infrared to `nir/`,
  masks to `masks/`, one stem apiece. The fourth channel could ride in an
  RGBA png and it would be half the files — and every human who opened one to
  check it would see a golf course fading strangely into nothing, because a
  viewer reads the fourth channel as transparency. A dataset people look at
  should look like what it is.

    python datasets/build_naip_dataset.py --index data/osm-us --out data/golfseg-us
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GOLF_SEG_LABELS                   # noqa: E402
from golfvision.masks.labels import (                            # noqa: E402
    IGNORE_INDEX, PATCH, bounds_of, classes_present, patches_of, rasterize,
)
from golfvision.providers.naip import (                          # noqa: E402
    ATTRIBUTION, BANDS, NaipFetcher,
)

#: No overlap — see the module docstring.
STRIDE = PATCH

#: Enough of the frame has to be real photograph before a course is worth
#: keeping. Below this something has gone wrong with the search rather than
#: with the course.
MIN_COVERAGE = 0.85


def split_of(osm_id: int, val_every: int) -> str:
    """Deterministic, by OSM id, and by course rather than by patch.

    Two 512-px windows from the same course share ground, share weather and
    share whoever mowed it that morning. Split them across train and val and
    the val score measures memory. Whole courses go one way or the other.

    There is no test split here on purpose. The question this corpus cannot
    answer is the only one that matters — does the model work in Vietnam —
    and that is measured on the held-out Vietnamese courses.
    """
    return "val" if osm_id % val_every == 0 else "train"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", default="data/osm-us",
                        help="output directory of discover_osm_courses.py")
    parser.add_argument("--out", default="data/golfseg-us")
    parser.add_argument("--zoom", type=int, default=19)
    parser.add_argument("--stride", type=int, default=STRIDE)
    parser.add_argument("--max-patches", type=int, default=120,
                        help="per course, so one enormous resort cannot "
                             "outweigh twenty ordinary clubs")
    parser.add_argument("--max-pixels", type=int, default=14000,
                        help="skip a course whose frame is larger than this on "
                             "a side. Not about labels — a 36-hole resort is "
                             "four courses of them and welcome — but about "
                             "memory: the canvas is four bytes a pixel and two "
                             "of them exist at once while a NAIP quad is "
                             "reprojected in, so 14 000 is about 2 GB. The "
                             "first cap was 9 000 and it threw away two fifths "
                             "of Florida, including PGA National.")
    parser.add_argument("--val-every", type=int, default=11)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--resume", action="store_true",
                        help="skip courses already in the output manifest")
    args = parser.parse_args()

    from PIL import Image

    index_dir = Path(args.index)
    index = json.loads((index_dir / "index.json").read_text())
    courses = index["courses"]
    if args.limit:
        courses = courses[:args.limit]

    out = Path(args.out)
    for kind in ("images", "nir", "masks"):
        for split in ("train", "val"):
            (out / kind / split).mkdir(parents=True, exist_ok=True)

    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if (
        args.resume and manifest_path.exists()) else {
        "purpose": "pretraining corpus — the fine-tune and every evaluation "
                   "number come from the Vietnamese courses",
        "labels": {i: f.value for i, f in GOLF_SEG_LABELS.items()},
        "ignoreIndex": IGNORE_INDEX,
        "patch": PATCH, "stride": args.stride, "zoom": args.zoom,
        "bands": list(BANDS),
        "maskLicense": index.get("license"),
        "imageryLicense": ATTRIBUTION,
        "imageryPermitsExtraction": True,
        "imagerySource": "naip",
        "courses": [], "counts": {"train": 0, "val": 0},
    }
    done = {c["osmId"] for c in manifest["courses"]}
    class_pixels: Counter[int] = Counter(
        {int(k): v for k, v in manifest.get("_classPixels", {}).items()})

    fetcher = NaipFetcher()

    for course in courses:
        if course["osmId"] in done:
            continue
        split = split_of(course["osmId"], args.val_every)
        name = course["name"][:38]

        features = json.loads(
            (index_dir / "courses" / course["file"]).read_text())["features"]
        present = classes_present(features)
        box = bounds_of(features)
        if box is None:
            continue
        south, west, north, east = box

        try:
            scene = fetcher.fetch(south, west, north, east, zoom=args.zoom)
        except Exception as error:      # noqa: BLE001
            print(f"! {name:38s} imagery: {str(error)[:70]}")
            continue

        if scene.coverage < MIN_COVERAGE:
            print(f"! {name:38s} NAIP covers {scene.coverage:.0%}, skipped")
            continue
        if max(scene.bounds.width, scene.bounds.height) > args.max_pixels:
            print(f"! {name:38s} {scene.bounds.width}x{scene.bounds.height}px "
                  f"> cap, skipped")
            continue

        mask = rasterize(features, scene.bounds, present)

        kept = 0
        for x, y, tile, mask_tile in patches_of(
                scene.pixels, mask, patch=PATCH, stride=args.stride):
            if kept >= args.max_patches:
                break
            stem = f"{course['osmType'][0]}{course['osmId']}_{x}_{y}"
            Image.fromarray(tile[:, :, :3]).save(
                out / "images" / split / f"{stem}.png")
            Image.fromarray(tile[:, :, 3]).save(
                out / "nir" / split / f"{stem}.png")
            Image.fromarray(mask_tile).save(
                out / "masks" / split / f"{stem}.png")
            class_pixels.update(dict(zip(*np.unique(
                mask_tile[mask_tile != IGNORE_INDEX], return_counts=True))))
            kept += 1

        manifest["counts"][split] += kept
        manifest["courses"].append({
            "osmType": course["osmType"], "osmId": course["osmId"],
            "name": course["name"], "state": course["state"], "split": split,
            "features": len(features), "patches": kept,
            "classes": sorted(GOLF_SEG_LABELS[i].value for i in present),
            "naip": [item for item in scene.items if "captured" in item],
            "coverage": round(scene.coverage, 4),
        })
        print(f"{course['state']} {name:38s} {split:5s} "
              f"{scene.bounds.width}x{scene.bounds.height}px  {kept:4d} patches")

        manifest["_classPixels"] = {str(k): int(v) for k, v in class_pixels.items()}
        manifest["classPixelShare"] = {
            GOLF_SEG_LABELS[int(k)].value:
                round(v / max(1, sum(class_pixels.values())), 5)
            for k, v in sorted(class_pixels.items())}
        manifest_path.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False))

    total = manifest["counts"]
    print(f"\ntrain {total['train']}  val {total['val']} patches -> {out}")
    print("class balance:", manifest.get("classPixelShare"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
