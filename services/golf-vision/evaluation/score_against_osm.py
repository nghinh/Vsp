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
from golfvision.semantics.inference import (                    # noqa: E402
    GolfSemanticInferenceService, HoleAnchor)
from golfvision.vector.vectorize import MaskVectorizationService  # noqa: E402

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


def _edge(mask: np.ndarray) -> np.ndarray:
    import cv2
    eroded = cv2.erode(mask.astype(np.uint8), np.ones((3, 3), np.uint8), 1)
    return (mask.astype(np.uint8) - eroded).astype(bool)


def boundary_error_m(prediction: np.ndarray, truth: np.ndarray,
                     metres_per_pixel: float) -> tuple[float, float, int, int]:
    """How far a found feature's edge is from the real one, in metres.

    Measured over matched features only, and this matters. The first version
    of this measured every true edge against the nearest predicted edge
    anywhere, which quietly folds recall into the answer: filtering out half
    the false positives made the number jump from 1.4 m to 30.8 m, not
    because any edge moved but because the true bunkers that now had no
    prediction at all contributed their whole distance to the mean.

    Two numbers cannot share one metric. Recall says how many were found;
    this says how well the found ones were drawn. A component of truth counts
    as found when a prediction overlaps it at all.

    :returns: mean, 95th percentile, matched components, total components
    """
    import cv2
    if not truth.any():
        return float("nan"), float("nan"), 0, 0

    count, labels = cv2.connectedComponents(truth.astype(np.uint8), 8)
    predicted_edge = _edge(prediction)
    if not predicted_edge.any():
        return float("nan"), float("nan"), 0, count - 1

    distance = cv2.distanceTransform(
        (~predicted_edge).astype(np.uint8), cv2.DIST_L2, 5)

    errors: list[float] = []
    matched = 0
    for index in range(1, count):
        component = labels == index
        if not (component & prediction).any():
            continue                    # not found — that is recall's business
        matched += 1
        errors.extend(distance[_edge(component)] * metres_per_pixel)

    if not errors:
        return float("nan"), float("nan"), 0, count - 1
    array = np.asarray(errors)
    return (float(array.mean()), float(np.percentile(array, 95)),
            matched, count - 1)


def _through_semantics(mask, bounds, anchor):
    """Vectorise, classify, and rasterise only what survived.

    Scoring the filtered mask rather than the polygon list keeps the metric
    identical on both sides of the comparison — the only thing that changes
    is which candidates are still there.
    """
    import cv2
    from golfvision.classes import LandCover

    service = GolfSemanticInferenceService(anchor)
    vectorizer = MaskVectorizationService(bounds)
    kept = np.zeros_like(mask, dtype=np.uint8)
    dropped = 0

    for feature in vectorizer.vectorize(mask, "bunker", simplify_m=0.3):
        if service.apply(feature, LandCover.BARE_LAND) is None:
            dropped += 1
            continue
        geoms = ([feature.geometry] if feature.geometry.geom_type == "Polygon"
                 else list(feature.geometry.geoms))
        for geom in geoms:
            points = np.array(
                [bounds.lat_lng_to_pixel(y, x) for x, y in geom.exterior.coords],
                dtype=np.int32)
            cv2.fillPoly(kept, [points], 1)

    print(f"  semantics dropped {dropped} candidate(s)")
    return kept.astype(bool)


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
    parser.add_argument("--semantics", action="store_true",
                        help="filter candidates through the golf inference "
                             "engine before scoring, so its effect on "
                             "precision is visible")
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
          f"{'edge µ':>8s} {'edge p95':>9s} {'found':>9s}")

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

        if args.semantics and layer == "BUNKER":
            prediction = _through_semantics(
                prediction, tile.bounds,
                HoleAnchor(args.tee[0], args.tee[1],
                           args.green[0], args.green[1]))

        truth = rasterize(truth_features, layer, tile.bounds, None)
        score, precision, recall = iou(prediction, truth)
        mean_error, p95, matched, total = boundary_error_m(
            prediction, truth, tile.bounds.metres_per_pixel)
        print(f"{layer:14s} {score:6.3f} {precision:6.3f} {recall:6.3f} "
              f"{mean_error:7.1f}m {p95:8.1f}m {matched:4d}/{total:<4d}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
