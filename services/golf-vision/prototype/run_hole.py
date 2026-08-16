"""§58 — the feasibility prototype, run on one real hole.

Deliberately isolated from the backend. It answers one question before any
of the architecture is worth building: does a pretrained remote-sensing model
find anything useful on a Vietnamese golf hole, and does the mask survive
becoming a polygon?

It is measured rather than eyeballed. The holes chosen have geometry drawn by
hand in OpenStreetMap, so every predicted water body and tree line can be
scored against a shape somebody surveyed — IoU, and the number that actually
matters for a rangefinder, boundary error in metres.

    .venv/bin/python prototype/run_hole.py --lat 21.03506 --lng 105.89110 \
        --tee-lat 21.03752 --tee-lng 105.89444 --name longbien-a1
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GolfFeature, LandCover           # noqa: E402
from golfvision.geo import webmercator as wm                    # noqa: E402
from golfvision.imagery.fetcher import TileFetcher              # noqa: E402
from golfvision.masks.postprocess import MaskPostProcessor      # noqa: E402
from golfvision.providers.flair import (                        # noqa: E402
    NATIVE_METRES_PER_PIXEL as NATIVE_MPP, FlairLandCoverProvider)
from golfvision.vector.vectorize import (                       # noqa: E402
    MaskVectorizationService, feature_collection)

#: Which generic class stands in for which golf feature, before any golf model
#: exists. MODE 2 of §10 — and each of these is a hypothesis to be measured,
#: not a claim.
LAND_COVER_STAND_IN = {
    LandCover.WATER: GolfFeature.WATER_HAZARD,
    LandCover.TREE: GolfFeature.TREE,
    LandCover.BARE_LAND: GolfFeature.BUNKER,
    LandCover.GRASS: GolfFeature.FAIRWAY,
    LandCover.PAVEMENT: GolfFeature.CART_PATH,
}


def rescale_to_native(image: np.ndarray, metres_per_pixel: float,
                      native: float) -> tuple[np.ndarray, float]:
    """Resample so the model sees the scale it was trained at.

    FLAIR's card is explicit that it was trained at one fixed scale with no
    scale augmentation. Handing it 0.287 m/px when it learned 0.2 m/px is a
    40% scale shift on every object it knows.
    """
    import cv2
    factor = metres_per_pixel / native
    if abs(factor - 1.0) < 0.05:
        return image, metres_per_pixel
    height = int(round(image.shape[0] * factor))
    width = int(round(image.shape[1] * factor))
    resized = cv2.resize(image, (width, height), interpolation=cv2.INTER_CUBIC)
    return resized, native


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lat", type=float, required=True, help="green latitude")
    parser.add_argument("--lng", type=float, required=True, help="green longitude")
    parser.add_argument("--tee-lat", type=float, required=True)
    parser.add_argument("--tee-lng", type=float, required=True)
    parser.add_argument("--name", default="hole")
    parser.add_argument("--margin", type=float, default=0.0012,
                        help="degrees of padding around the hole")
    parser.add_argument("--zoom", type=int, default=None)
    parser.add_argument("--out", default="out")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    south = min(args.lat, args.tee_lat) - args.margin
    north = max(args.lat, args.tee_lat) + args.margin
    west = min(args.lng, args.tee_lng) - args.margin
    east = max(args.lng, args.tee_lng) + args.margin

    fetcher = TileFetcher()
    if not fetcher.provider.permits_automated_extraction:
        print(f"! {fetcher.provider.name} does not licence automated "
              f"extraction — prototype only, not for production output")

    started = time.time()
    tile = fetcher.fetch(south, west, north, east, zoom=args.zoom)
    fetched = time.time() - started
    print(f"image  {tile.bounds.width}x{tile.bounds.height} px  "
          f"zoom {tile.bounds.zoom}  "
          f"{tile.bounds.metres_per_pixel:.3f} m/px  ({fetched:.1f}s)")

    provider = FlairLandCoverProvider()
    if not provider.available:
        print(f"! land-cover model unavailable: {provider._error}")
        return 1

    scaled, scaled_mpp = rescale_to_native(
        tile.pixels, tile.bounds.metres_per_pixel,
        NATIVE_MPP)
    print(f"model  input {scaled.shape[1]}x{scaled.shape[0]} px "
          f"at {scaled_mpp:.3f} m/px on {provider.device}")

    started = time.time()
    result = provider.segment(scaled, tile.bounds.metadata)
    inference = time.time() - started
    print(f"segment {inference:.1f}s -> {len(result.classes)} class(es)")

    import cv2
    total = scaled.shape[0] * scaled.shape[1]
    cleaner = MaskPostProcessor(tile.bounds.metres_per_pixel)
    vectorizer = MaskVectorizationService(tile.bounds)

    features = []
    summary = []
    for entry in result.classes:
        share = entry.pixel_count / total
        cover = LandCover(entry.label)
        stand_in = LAND_COVER_STAND_IN.get(cover)
        summary.append((entry.label, share, entry.confidence,
                        stand_in.value if stand_in else "-"))
        if stand_in is None:
            continue

        # Back to the image's own scale before anything becomes a coordinate.
        mask = cv2.resize(entry.mask.astype(np.uint8),
                          (tile.bounds.width, tile.bounds.height),
                          interpolation=cv2.INTER_NEAREST).astype(bool)
        mask = cleaner.clean(mask, stand_in)
        if not mask.any():
            continue

        for feature in vectorizer.vectorize(mask, stand_in.value,
                                            simplify_m=0.5):
            feature.scores["vision"] = entry.confidence
            feature.scores["geometry"] = 1.0
            feature.evidence["landCover"] = entry.label
            features.append(feature)

    print("\n  class            share   conf   stands in for")
    for label, share, confidence, stand_in in summary:
        print(f"  {label:15s} {share*100:5.1f}%  {confidence:.2f}   {stand_in}")

    collection = feature_collection(
        features, tile.attribution,
        {**tile.bounds.metadata,
         "modelName": result.model_name,
         "modelCheckpoint": result.model_checkpoint,
         "pipelineVersion": result.pipeline_version,
         "metresPerPixel": round(tile.bounds.metres_per_pixel, 4)})

    geojson_path = out / f"{args.name}.geojson"
    geojson_path.write_text(json.dumps(collection, ensure_ascii=False))
    print(f"\n{len(features)} polygon(s) -> {geojson_path}")

    for label in sorted({f.label for f in features}):
        areas = [f.area_m2 for f in features if f.label == label]
        print(f"  {label:14s} {len(areas):3d}  "
              f"{min(areas):8.0f} – {max(areas):8.0f} m²")

    _write_visuals(out, args.name, tile, result, features)
    return 0


def _write_visuals(out: Path, name: str, tile, result, features) -> None:
    """§59 — the mask and the polygons, side by side with the picture.

    Without this it is impossible to say why a region was called water, and a
    pipeline nobody can inspect is a pipeline nobody can improve.
    """
    import cv2
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    colours = {
        "water": (59, 130, 246), "tree": (34, 139, 34),
        "grass": (134, 200, 90), "bare_land": (214, 198, 160),
        "pavement": (148, 163, 184), "building": (220, 38, 38),
        "vegetation": (101, 163, 13), "unknown": (100, 100, 100),
    }

    overlay = tile.pixels.copy()
    for entry in result.classes:
        colour = colours.get(entry.label)
        if colour is None:
            continue
        mask = cv2.resize(entry.mask.astype(np.uint8),
                          (tile.bounds.width, tile.bounds.height),
                          interpolation=cv2.INTER_NEAREST).astype(bool)
        overlay[mask] = (0.55 * np.array(colour) + 0.45 * overlay[mask]).astype(np.uint8)

    polygons = tile.pixels.copy()
    outline = {"water_hazard": (59, 130, 246), "tree": (34, 197, 94),
               "fairway": (163, 230, 53), "bunker": (250, 204, 21),
               "cart_path": (203, 213, 225)}
    for feature in features:
        colour = outline.get(feature.label, (255, 255, 255))
        geoms = ([feature.geometry] if feature.geometry.geom_type == "Polygon"
                 else list(feature.geometry.geoms))
        for geom in geoms:
            points = np.array(
                [tile.bounds.lat_lng_to_pixel(y, x) for x, y in geom.exterior.coords],
                dtype=np.int32)
            cv2.polylines(polygons, [points], True, colour, 2)

    figure, axes = plt.subplots(1, 3, figsize=(22, 8))
    for axis, image, title in zip(
            axes, [tile.pixels, overlay, polygons],
            ["satellite", "land-cover mask", "vectorised polygons"]):
        axis.imshow(image)
        axis.set_title(title)
        axis.axis("off")
    figure.suptitle(f"{name} — {result.model_name} @ "
                    f"{tile.bounds.metres_per_pixel:.2f} m/px")
    figure.tight_layout()
    figure.savefig(out / f"{name}.png", dpi=110, bbox_inches="tight")
    plt.close(figure)
    print(f"visual -> {out / f'{name}.png'}")


if __name__ == "__main__":
    raise SystemExit(main())
