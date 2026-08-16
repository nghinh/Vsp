"""§45–46 — scoring a prediction against shapes a person drew.

Pixel IoU on its own is the wrong metric for a rangefinder. A green predicted
at 0.8 IoU can still put its front edge eight metres from where the green
actually starts, and eight metres is a club. So this reports both: IoU,
because it is comparable across models, and boundary error in metres, because
it is the thing a golfer feels.

The ground truth is the OpenStreetMap layer this project already imported and
serves back under ODbL — 2,614 polygons a human digitised across 36 courses.
Nothing here is circular: the model has never seen any of it.

    .venv/bin/python evaluation/score_against_osm.py --course 8 --hole 10
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.classes import GolfFeature, LandCover           # noqa: E402
from golfvision.geo.tiles import ImageBounds                    # noqa: E402
from golfvision.imagery.fetcher import TileFetcher              # noqa: E402
from golfvision.masks.postprocess import MaskPostProcessor      # noqa: E402
from golfvision.providers.flair import (                        # noqa: E402
    NATIVE_METRES_PER_PIXEL as NATIVE_MPP, FlairLandCoverProvider)

API = "https://vps-api.vnteki.com"

#: Which OSM layer answers for which predicted class. Only the ones a generic
#: land-cover model could plausibly get right — asking it about tee boxes
#: would be scoring it on a question it was never asked.
SCORED = {
    "WATER_HAZARD": LandCover.WATER,
    "GREEN": LandCover.GRASS,
    "BUNKER": LandCover.BARE_LAND,
}


def ground_truth(course_id: int) -> list[dict]:
    # The edge in front of the API answers 403 to a bare urllib user agent.
    request = urllib.request.Request(
        f"{API}/open-data/osm-derived/{course_id}.geojson",
        headers={"User-Agent": "VSP-golf-vision/0.1 (evaluation)"})
    with urllib.request.urlopen(request, timeout=60) as body:
        return json.load(body)["features"]


def rasterize(features: list[dict], layer: str, bounds: ImageBounds,
              hole: int | None) -> np.ndarray:
    import cv2
    canvas = np.zeros((bounds.height, bounds.width), dtype=np.uint8)
    for feature in features:
        properties = feature["properties"]
        if properties.get("layerType") != layer:
            continue
        if hole is not None and properties.get("hole") not in (None, hole):
            continue
        geometry = feature["geometry"]
        rings = ([geometry["coordinates"]] if geometry["type"] == "Polygon"
                 else geometry["coordinates"])
        for ring in rings:
            points = np.array(
                [bounds.lat_lng_to_pixel(lat, lng) for lng, lat in ring[0]],
                dtype=np.int32)
            cv2.fillPoly(canvas, [points], 1)
    return canvas.astype(bool)


def iou(prediction: np.ndarray, truth: np.ndarray) -> tuple[float, float, float]:
    intersection = float((prediction & truth).sum())
    union = float((prediction | truth).sum())
    predicted = float(prediction.sum())
    actual = float(truth.sum())
    return (intersection / union if union else 0.0,
            intersection / predicted if predicted else 0.0,
            intersection / actual if actual else 0.0)


def boundary_error_m(prediction: np.ndarray, truth: np.ndarray,
                     metres_per_pixel: float) -> tuple[float, float]:
    """Mean and 95th-percentile distance from a true edge to the nearest
    predicted edge, in metres. Empty on either side gives no answer at all
    rather than a flattering zero."""
    import cv2
    if not prediction.any() or not truth.any():
        return float("nan"), float("nan")

    def edge(mask: np.ndarray) -> np.ndarray:
        eroded = cv2.erode(mask.astype(np.uint8),
                           np.ones((3, 3), np.uint8), iterations=1)
        return (mask.astype(np.uint8) - eroded).astype(bool)

    predicted_edge = edge(prediction)
    truth_edge = edge(truth)
    distance = cv2.distanceTransform(
        (~predicted_edge).astype(np.uint8), cv2.DIST_L2, 5)
    errors = distance[truth_edge] * metres_per_pixel
    return float(errors.mean()), float(np.percentile(errors, 95))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--course", type=int, required=True)
    parser.add_argument("--hole", type=int, required=True)
    parser.add_argument("--green", nargs=2, type=float, required=True,
                        metavar=("LAT", "LNG"))
    parser.add_argument("--tee", nargs=2, type=float, required=True,
                        metavar=("LAT", "LNG"))
    parser.add_argument("--margin", type=float, default=0.0010)
    parser.add_argument("--zoom", type=int, default=19)
    args = parser.parse_args()

    south = min(args.green[0], args.tee[0]) - args.margin
    north = max(args.green[0], args.tee[0]) + args.margin
    west = min(args.green[1], args.tee[1]) - args.margin
    east = max(args.green[1], args.tee[1]) + args.margin

    tile = TileFetcher().fetch(south, west, north, east, zoom=args.zoom)
    provider = FlairLandCoverProvider()
    if not provider.available:
        print(f"model unavailable: {provider._error}")
        return 1

    import cv2
    factor = tile.bounds.metres_per_pixel / NATIVE_MPP
    scaled = cv2.resize(tile.pixels, None, fx=factor, fy=factor,
                        interpolation=cv2.INTER_CUBIC)
    result = provider.segment(scaled, tile.bounds.metadata)

    truth_features = ground_truth(args.course)
    cleaner = MaskPostProcessor(tile.bounds.metres_per_pixel)

    print(f"course {args.course} hole {args.hole} — "
          f"{tile.bounds.width}x{tile.bounds.height} px at "
          f"{tile.bounds.metres_per_pixel:.3f} m/px, zoom {tile.bounds.zoom}")
    print(f"{'layer':14s} {'IoU':>6s} {'prec':>6s} {'recall':>6s} "
          f"{'edge µ':>8s} {'edge p95':>9s}   truth px")

    for layer, cover in SCORED.items():
        entry = result.by_label(cover.value)
        if entry is None:
            prediction = np.zeros((tile.bounds.height, tile.bounds.width), bool)
        else:
            prediction = cv2.resize(
                entry.mask.astype(np.uint8),
                (tile.bounds.width, tile.bounds.height),
                interpolation=cv2.INTER_NEAREST).astype(bool)
            feature = {"WATER_HAZARD": GolfFeature.WATER_HAZARD,
                       "GREEN": GolfFeature.GREEN,
                       "BUNKER": GolfFeature.BUNKER}[layer]
            prediction = cleaner.clean(prediction, feature)

        truth = rasterize(truth_features, layer, tile.bounds, None)
        score, precision, recall = iou(prediction, truth)
        mean_error, p95 = boundary_error_m(
            prediction, truth, tile.bounds.metres_per_pixel)
        print(f"{layer:14s} {score:6.3f} {precision:6.3f} {recall:6.3f} "
              f"{mean_error:7.1f}m {p95:8.1f}m   {int(truth.sum()):8d}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
