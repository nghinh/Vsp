"""§36 — turn the OpenStreetMap layer into a GolfSeg training set.

The corpus is the 2,614 polygons a human digitised across 36 Vietnamese
courses, which this project imported and serves back under ODbL. The imagery
is the satellite tile under each one. Together they are (image, mask) pairs in
the layout MMSegmentation and Hugging Face both read.

Two rules that decide whether the trained model is worth anything:

* **Split by course, never by patch.** Two 512-px patches from the same green
  share pixels; put one in train and one in val and the val score is a
  memory test. Whole courses go to one split or the other.
* **The mask is only as good as its source.** A course where OSM has the
  greens but not the bunkers would teach the model that this course has no
  bunkers. So a course contributes a class only where that class is actually
  mapped, and patches are labelled `ignore` outside what was drawn — the loss
  skips them rather than learning "background" from an unmapped fairway.

Licence: the masks are ODbL and stay attributable. The Esri imagery underneath
is the same licence problem flagged throughout — fine for this research
dataset, and a blocker for a shipped model trained on it. Recorded in the
manifest, not hidden.

    python datasets/build_golfseg_dataset.py --out data/golfseg --zoom 19
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from collections import Counter
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GOLF_SEG_LABELS, GolfFeature      # noqa: E402
from golfvision.geo import webmercator as wm                     # noqa: E402
from golfvision.imagery.fetcher import TileFetcher               # noqa: E402

API = "https://vps-api.vnteki.com"

#: OSM layer_type → GolfSeg training index (§36). Rough and cart path are in
#: the label set but barely in OSM, so they ride along where present.
LAYER_TO_INDEX = {
    "TEE": 1, "FAIRWAY": 2, "GREEN": 3, "BUNKER": 4,
    "ROUGH": 5, "WATER_HAZARD": 6, "CART_PATH": 7, "LANDMARK": 8,
}
IGNORE_INDEX = 255      # what the loss skips — the MMSeg / HF convention

PATCH = 512
STRIDE = 384            # 25% overlap, so a feature on a seam appears whole somewhere


def _get(url: str):
    request = urllib.request.Request(
        url, headers={"User-Agent": "VSP-golfseg-dataset/0.1"})
    with urllib.request.urlopen(request, timeout=90) as body:
        return json.load(body)


def course_index() -> list[dict]:
    return _get(f"{API}/open-data/osm-derived")["courses"]


def course_features(course_id: int) -> list[dict]:
    return _get(f"{API}/open-data/osm-derived/{course_id}.geojson")["features"]


def course_bounds(features: list[dict], margin_deg: float = 0.0006):
    lats, lngs = [], []
    for feature in features:
        for ring in _rings(feature["geometry"]):
            for lng, lat in ring:
                lats.append(lat)
                lngs.append(lng)
    if not lats:
        return None
    return (min(lats) - margin_deg, min(lngs) - margin_deg,
            max(lats) + margin_deg, max(lngs) + margin_deg)


def _rings(geometry: dict):
    if geometry["type"] == "Polygon":
        yield geometry["coordinates"][0]
    elif geometry["type"] == "MultiPolygon":
        for polygon in geometry["coordinates"]:
            yield polygon[0]


def rasterize(features: list[dict], bounds, present: set[int]) -> np.ndarray:
    """Paint the label mask for a whole course.

    Starts as ignore everywhere a class this course *has* was not drawn, so an
    unmapped corner is skipped by the loss rather than taught as background.
    Background (0) is only written where the course maps enough to define it —
    here, inside the convex reach of its own features.
    """
    import cv2
    height, width = bounds.height, bounds.width
    mask = np.full((height, width), IGNORE_INDEX, dtype=np.uint8)

    # A coarse "this is golf course" footprint from all features dilated, so
    # the gaps between mapped shapes become learnable background rather than
    # ignore. Without it the model only ever sees the inside of features.
    footprint = np.zeros((height, width), dtype=np.uint8)

    ordered = sorted(features, key=lambda f: _draw_order(
        f["properties"].get("layerType")))
    for feature in ordered:
        index = LAYER_TO_INDEX.get(feature["properties"].get("layerType"))
        if index is None or index not in present:
            continue
        for ring in _rings(feature["geometry"]):
            points = np.array([bounds.lat_lng_to_pixel(lat, lng)
                               for lng, lat in ring], dtype=np.int32)
            cv2.fillPoly(mask, [points], index)
            cv2.fillPoly(footprint, [points], 1)

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (81, 81))
    reachable = cv2.dilate(footprint, kernel) > 0
    background = reachable & (mask == IGNORE_INDEX)
    mask[background] = 0
    return mask


def _draw_order(layer: str | None) -> int:
    """Big things first, small things last, so a bunker on a fairway wins."""
    order = {"FAIRWAY": 0, "ROUGH": 0, "WATER_HAZARD": 1, "LANDMARK": 1,
             "GREEN": 2, "TEE": 3, "BUNKER": 4, "CART_PATH": 5}
    return order.get(layer or "", 9)


def patches_of(image: np.ndarray, mask: np.ndarray):
    """Slide a window, keeping only patches with something worth learning."""
    height, width = mask.shape
    ys = list(range(0, max(1, height - PATCH + 1), STRIDE))
    xs = list(range(0, max(1, width - PATCH + 1), STRIDE))
    if ys and ys[-1] + PATCH < height:
        ys.append(height - PATCH)
    if xs and xs[-1] + PATCH < width:
        xs.append(width - PATCH)

    for y in ys:
        for x in xs:
            mtile = mask[y:y + PATCH, x:x + PATCH]
            if mtile.shape != (PATCH, PATCH):
                continue
            labelled = mtile[mtile != IGNORE_INDEX]
            if labelled.size < 0.2 * PATCH * PATCH:
                continue        # mostly ignore — nothing to learn here
            if (labelled > 0).sum() < 0.02 * labelled.size:
                continue        # all background — a patch of empty rough
            yield x, y, image[y:y + PATCH, x:x + PATCH], mtile


def split_of(course_id: int, val_every: int, test_every: int) -> str:
    """Deterministic, by course id, so a rerun is stable and reproducible."""
    if course_id % test_every == 0:
        return "test"
    if course_id % val_every == 0:
        return "val"
    return "train"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="data/golfseg")
    parser.add_argument("--zoom", type=int, default=19)
    parser.add_argument("--max-tiles", type=int, default=1200)
    parser.add_argument("--only", type=int, nargs="*",
                        help="course ids to build; default is all")
    parser.add_argument("--val-every", type=int, default=5)
    parser.add_argument("--test-every", type=int, default=7)
    args = parser.parse_args()

    from PIL import Image

    out = Path(args.out)
    for split in ("train", "val", "test"):
        (out / "images" / split).mkdir(parents=True, exist_ok=True)
        (out / "masks" / split).mkdir(parents=True, exist_ok=True)

    fetcher = TileFetcher(max_tiles=args.max_tiles)
    courses = course_index()
    if args.only:
        courses = [c for c in courses if c["courseId"] in args.only]

    manifest = {
        "labels": {i: f.value for i, f in GOLF_SEG_LABELS.items()},
        "ignoreIndex": IGNORE_INDEX,
        "patch": PATCH, "stride": STRIDE, "zoom": args.zoom,
        "maskLicense": "ODbL 1.0 — © OpenStreetMap contributors",
        "imageryLicense": fetcher.provider.attribution,
        "imageryPermitsExtraction": fetcher.provider.permits_automated_extraction,
        "courses": [], "counts": {"train": 0, "val": 0, "test": 0},
    }
    class_pixels: Counter[int] = Counter()

    for course in courses:
        course_id = course["courseId"]
        split = split_of(course_id, args.val_every, args.test_every)
        try:
            features = course_features(course_id)
        except Exception as error:      # noqa: BLE001
            print(f"! course {course_id}: {error}")
            continue

        present = {LAYER_TO_INDEX[f["properties"]["layerType"]]
                   for f in features
                   if f["properties"].get("layerType") in LAYER_TO_INDEX}
        bounds_deg = course_bounds(features)
        if bounds_deg is None:
            continue
        south, west, north, east = bounds_deg

        tiles_wide = (int(wm.tile_x(east, args.zoom))
                      - int(wm.tile_x(west, args.zoom)) + 1)
        tiles_tall = (int(wm.tile_y(south, args.zoom))
                      - int(wm.tile_y(north, args.zoom)) + 1)
        if tiles_wide * tiles_tall > args.max_tiles:
            print(f"! course {course_id} {course['course']}: "
                  f"{tiles_wide * tiles_tall} tiles > cap {args.max_tiles}, skipped")
            continue

        try:
            tile = fetcher.fetch(south, west, north, east, zoom=args.zoom,
                                 max_pixels=100_000)
        except Exception as error:      # noqa: BLE001
            print(f"! course {course_id} imagery: {error}")
            continue

        mask = rasterize(features, tile.bounds, present)
        kept = 0
        for x, y, image_patch, mask_patch in patches_of(tile.pixels, mask):
            stem = f"c{course_id}_{x}_{y}"
            Image.fromarray(image_patch).save(out / "images" / split / f"{stem}.png")
            Image.fromarray(mask_patch).save(out / "masks" / split / f"{stem}.png")
            class_pixels.update(
                dict(zip(*np.unique(mask_patch[mask_patch != IGNORE_INDEX],
                                    return_counts=True))))
            kept += 1

        manifest["counts"][split] += kept
        manifest["courses"].append({
            "courseId": course_id, "name": course["course"], "split": split,
            "features": len(features), "patches": kept,
            "classes": sorted(GOLF_SEG_LABELS[i].value for i in present)})
        print(f"{course_id:5d} {course['course'][:34]:34s} {split:5s} "
              f"{tile.bounds.width}x{tile.bounds.height}px  {kept:4d} patches")

    manifest["classPixelShare"] = {
        GOLF_SEG_LABELS[int(k)].value: round(v / max(1, sum(class_pixels.values())), 5)
        for k, v in sorted(class_pixels.items())}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

    total = manifest["counts"]
    print(f"\ntrain {total['train']}  val {total['val']}  test {total['test']}  "
          f"patches -> {out}")
    print("class balance:", manifest["classPixelShare"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
