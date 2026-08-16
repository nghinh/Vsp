"""Cleaning a mask before it becomes a polygon.

A raw argmax is speckled: single pixels of "building" inside a fairway, holes
where a cart crossed, boundaries that jag by a pixel every pixel. Vectorising
that produces a polygon with six hundred points describing noise.

Every threshold is per feature type and in square metres, not pixels, because
the same course at zoom 18 and zoom 19 must clean to the same shapes. §20's
warning is taken literally: a tee box is genuinely small, and a minimum area
tuned on bunkers deletes them.
"""

from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np

from ..classes import GolfFeature


@dataclass(frozen=True)
class CleanupRule:
    """What a feature of this kind may look like after cleaning."""

    #: Anything smaller is noise. Square metres.
    min_area_m2: float
    #: Holes smaller than this are filled — a cart path crossing a fairway
    #: leaves one, and the fairway is still one fairway.
    fill_holes_below_m2: float
    #: Radius of the morphological open/close, in metres. Larger smooths more
    #: and erodes small features faster.
    smooth_radius_m: float


#: Numbers from what these things actually measure, not from tuning against
#: one course. A green is 400–900 m², a bunker tens to a few hundred, a tee
#: platform can be under 100.
RULES: dict[GolfFeature, CleanupRule] = {
    GolfFeature.GREEN: CleanupRule(200, 40, 1.0),
    GolfFeature.BUNKER: CleanupRule(15, 8, 0.6),
    GolfFeature.TEE_BOX: CleanupRule(25, 10, 0.6),
    GolfFeature.FAIRWAY: CleanupRule(1500, 250, 2.0),
    GolfFeature.ROUGH: CleanupRule(1500, 400, 2.0),
    GolfFeature.WATER_HAZARD: CleanupRule(80, 40, 1.0),
    GolfFeature.TREE: CleanupRule(100, 60, 1.5),
    GolfFeature.CART_PATH: CleanupRule(40, 10, 0.4),
}

DEFAULT_RULE = CleanupRule(100, 50, 1.0)


class MaskPostProcessor:

    def __init__(self, metres_per_pixel: float):
        if metres_per_pixel <= 0:
            raise ValueError("metres per pixel must be positive")
        self.metres_per_pixel = metres_per_pixel

    def _pixels(self, area_m2: float) -> int:
        return max(1, int(round(area_m2 / (self.metres_per_pixel ** 2))))

    def _radius(self, metres: float) -> int:
        return max(1, int(round(metres / self.metres_per_pixel)))

    def clean(self, mask: np.ndarray,
              feature: GolfFeature | None = None) -> np.ndarray:
        rule = RULES.get(feature, DEFAULT_RULE) if feature else DEFAULT_RULE
        work = mask.astype(np.uint8)

        radius = self._radius(rule.smooth_radius_m)
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE, (radius * 2 + 1, radius * 2 + 1))
        # Opening first, so the closing that follows does not weld noise onto
        # the feature before it can be removed.
        work = cv2.morphologyEx(work, cv2.MORPH_OPEN, kernel)
        work = cv2.morphologyEx(work, cv2.MORPH_CLOSE, kernel)

        work = self._drop_small_regions(work, self._pixels(rule.min_area_m2))
        work = self._fill_small_holes(work, self._pixels(rule.fill_holes_below_m2))
        return work.astype(bool)

    @staticmethod
    def _drop_small_regions(mask: np.ndarray, min_pixels: int) -> np.ndarray:
        count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
        kept = np.zeros_like(mask)
        for index in range(1, count):
            if stats[index, cv2.CC_STAT_AREA] >= min_pixels:
                kept[labels == index] = 1
        return kept

    @staticmethod
    def _fill_small_holes(mask: np.ndarray, max_pixels: int) -> np.ndarray:
        # Holes are the background's connected components that do not touch
        # the frame — the ones that do are outside the shape, not in it.
        inverted = 1 - mask
        count, labels, stats, _ = cv2.connectedComponentsWithStats(inverted, 8)
        filled = mask.copy()
        height, width = mask.shape
        for index in range(1, count):
            if stats[index, cv2.CC_STAT_AREA] > max_pixels:
                continue
            left = stats[index, cv2.CC_STAT_LEFT]
            top = stats[index, cv2.CC_STAT_TOP]
            right = left + stats[index, cv2.CC_STAT_WIDTH]
            bottom = top + stats[index, cv2.CC_STAT_HEIGHT]
            if left == 0 or top == 0 or right >= width or bottom >= height:
                continue
            filled[labels == index] = 1
        return filled
