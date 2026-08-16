"""Turning drawn polygons into a label raster, whoever drew them.

Lifted out of `datasets/build_golfseg_dataset.py` when a second corpus arrived —
OpenStreetMap over NAIP in the United States, alongside the Vietnamese courses
this project digitised. Two builders, one definition of what a mask means. A
copy of this logic that drifted would produce two training sets whose class 3
meant subtly different things, and the model would average them.

The one rule worth restating, because everything here exists to serve it: a
course contributes a class only where that class is actually mapped. Where OSM
has the greens but not the bunkers, the sand is `ignore`, not `background`.
Teaching a model that an unmapped bunker is background is how it learns that
bunkers are rare, and it is a lesson that no amount of extra data undoes.
"""

from __future__ import annotations

from typing import Iterator

import numpy as np

#: App layer name → GolfSeg training index (§36). Rough and cart path are in
#: the label set but thin on the ground in OSM, so they ride along where
#: present rather than being required.
LAYER_TO_INDEX: dict[str, int] = {
    "TEE": 1, "FAIRWAY": 2, "GREEN": 3, "BUNKER": 4,
    "ROUGH": 5, "WATER_HAZARD": 6, "CART_PATH": 7, "LANDMARK": 8,
}

#: What the loss skips — the MMSegmentation and Hugging Face convention.
IGNORE_INDEX = 255

PATCH = 512
#: 25% overlap, so a feature landing on a seam appears whole somewhere.
STRIDE = 384

#: How far out from the drawn features still counts as "this course", in
#: pixels of the raster being painted. Everything inside it that nobody drew
#: becomes learnable background; everything beyond stays ignore.
FOOTPRINT_DILATION_PX = 81


def rings(geometry: dict) -> Iterator[list]:
    """Every outer ring of a polygon or multipolygon.

    Interior rings are dropped. An island green's pond is a real hole in a
    real polygon, and painting it would be more correct — but the classes are
    painted in size order anyway, so the pond goes down after the green and
    covers it. Handling interiors as well would be doing the same work twice
    in opposite directions.
    """
    if geometry["type"] == "Polygon":
        yield geometry["coordinates"][0]
    elif geometry["type"] == "MultiPolygon":
        for polygon in geometry["coordinates"]:
            yield polygon[0]


def draw_order(layer: str | None) -> int:
    """Big things first, small things last, so a bunker on a fairway wins."""
    order = {"FAIRWAY": 0, "ROUGH": 0, "WATER_HAZARD": 1, "LANDMARK": 1,
             "GREEN": 2, "TEE": 3, "BUNKER": 4, "CART_PATH": 5}
    return order.get(layer or "", 9)


def rasterize(features: list[dict], bounds, present: set[int]) -> np.ndarray:
    """Paint the label mask for a whole course.

    Starts as ignore everywhere, so an unmapped corner is skipped by the loss
    rather than taught as background. Background (0) is written only inside
    the reach of the course's own features, which is the one region where
    "nobody drew anything here" is evidence rather than absence.

    `present` is the set of class indices this course actually maps — pass the
    classes seen in its own features, never the full label set.
    """
    import cv2

    height, width = bounds.height, bounds.width
    mask = np.full((height, width), IGNORE_INDEX, dtype=np.uint8)
    footprint = np.zeros((height, width), dtype=np.uint8)

    ordered = sorted(features, key=lambda f: draw_order(
        f["properties"].get("layerType")))
    for feature in ordered:
        index = LAYER_TO_INDEX.get(feature["properties"].get("layerType"))
        if index is None or index not in present:
            continue
        for ring in rings(feature["geometry"]):
            points = np.array([bounds.lat_lng_to_pixel(lat, lng)
                               for lng, lat in ring], dtype=np.int32)
            cv2.fillPoly(mask, [points], index)
            cv2.fillPoly(footprint, [points], 1)

    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (FOOTPRINT_DILATION_PX, FOOTPRINT_DILATION_PX))
    reachable = cv2.dilate(footprint, kernel) > 0
    mask[reachable & (mask == IGNORE_INDEX)] = 0
    return mask


def classes_present(features: list[dict]) -> set[int]:
    """The classes this course actually maps."""
    return {LAYER_TO_INDEX[f["properties"]["layerType"]]
            for f in features
            if f.get("properties", {}).get("layerType") in LAYER_TO_INDEX}


def bounds_of(features: list[dict], margin_deg: float = 0.0006):
    """The lat/lng box around everything drawn, with a margin.

    Returns (south, west, north, east), or None for a course with no geometry.
    """
    lats: list[float] = []
    lngs: list[float] = []
    for feature in features:
        for ring in rings(feature["geometry"]):
            for lng, lat in ring:
                lats.append(lat)
                lngs.append(lng)
    if not lats:
        return None
    return (min(lats) - margin_deg, min(lngs) - margin_deg,
            max(lats) + margin_deg, max(lngs) + margin_deg)


def patches_of(image: np.ndarray, mask: np.ndarray,
               patch: int = PATCH, stride: int = STRIDE):
    """Slide a window, keeping only patches with something worth learning.

    Two thresholds, both of them about not wasting a training step: a patch
    that is mostly `ignore` teaches nothing, and a patch that is entirely
    background is a picture of empty rough. Neither is wrong — they are the
    two ways a tile can be true and useless.
    """
    height, width = mask.shape
    ys = list(range(0, max(1, height - patch + 1), stride))
    xs = list(range(0, max(1, width - patch + 1), stride))
    if ys and ys[-1] + patch < height:
        ys.append(height - patch)
    if xs and xs[-1] + patch < width:
        xs.append(width - patch)

    for y in ys:
        for x in xs:
            tile = mask[y:y + patch, x:x + patch]
            if tile.shape != (patch, patch):
                continue
            labelled = tile[tile != IGNORE_INDEX]
            if labelled.size < 0.2 * patch * patch:
                continue
            if (labelled > 0).sum() < 0.02 * labelled.size:
                continue
            yield x, y, image[y:y + patch, x:x + patch], tile
