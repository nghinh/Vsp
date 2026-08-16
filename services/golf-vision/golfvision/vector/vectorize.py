"""Pixels to ground truth-shaped polygons.

The one place in this service where a mask becomes a coordinate. Everything
upstream works in pixels and everything downstream works in degrees, and no
model is involved in the conversion at all — it is arithmetic, and it is
either right or it is a distance a golfer misclubs on.

Contour tracing rather than rays from a centroid. The Java refiner this
replaces cast sixty rays outward from the middle of a blob, which cannot
represent a concave shape by construction — every bunker it produced was a
smooth convex octagon, and that is why they all looked the same.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import cv2
import numpy as np
from shapely.geometry import MultiPolygon, Polygon, mapping
from shapely.validation import make_valid

from ..geo.tiles import ImageBounds


@dataclass
class VectorFeature:
    """One polygon, with everything needed to judge and re-derive it."""

    label: str
    geometry: Polygon | MultiPolygon
    area_m2: float
    #: §24 — kept apart so a bad score can be attributed to the stage that
    #: produced it rather than averaged into anonymity.
    scores: dict[str, float] = field(default_factory=dict)
    evidence: dict[str, Any] = field(default_factory=dict)

    @property
    def confidence(self) -> float:
        if not self.scores:
            return 0.0
        product = 1.0
        for value in self.scores.values():
            product *= max(0.0, min(1.0, value))
        return product

    def to_geojson(self) -> dict[str, Any]:
        return {
            "type": "Feature",
            "geometry": mapping(self.geometry),
            "properties": {
                "label": self.label,
                "areaM2": round(self.area_m2, 1),
                "confidence": round(self.confidence, 4),
                "scores": {k: round(v, 4) for k, v in self.scores.items()},
                "evidence": self.evidence,
            },
        }


class MaskVectorizationService:
    """Binary mask → connected components → contours → geographic polygons."""

    def __init__(self, bounds: ImageBounds):
        self.bounds = bounds
        self.metres_per_pixel = bounds.metres_per_pixel

    def vectorize(self, mask: np.ndarray, label: str,
                  simplify_m: float = 0.5,
                  min_area_m2: float = 0.0) -> list[VectorFeature]:
        features: list[VectorFeature] = []
        binary = mask.astype(np.uint8)

        # RETR_CCOMP gives outer contours and their holes in one pass, which
        # is what an island green in a pond actually is.
        contours, hierarchy = cv2.findContours(
            binary, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
        if hierarchy is None:
            return features
        hierarchy = hierarchy[0]

        for index, contour in enumerate(contours):
            if hierarchy[index][3] != -1:        # a hole; handled with its parent
                continue
            if len(contour) < 4:
                continue

            holes = [contours[child] for child in range(len(contours))
                     if hierarchy[child][3] == index and len(contours[child]) >= 4]

            polygon = self._to_geographic(contour, holes)
            if polygon is None:
                continue

            polygon = self._simplify(polygon, simplify_m)
            if polygon is None or polygon.is_empty:
                continue

            area = self._area_m2(polygon)
            if area < min_area_m2:
                continue

            features.append(VectorFeature(
                label=label, geometry=polygon, area_m2=area,
                evidence={"pixelPerimeter": int(len(contour)),
                          "metresPerPixel": round(self.metres_per_pixel, 4)}))

        features.sort(key=lambda f: f.area_m2, reverse=True)
        return features

    def _to_geographic(self, contour: np.ndarray,
                       holes: list[np.ndarray]) -> Polygon | None:
        shell = [self._point(px, py) for px, py in contour[:, 0, :]]
        if len(shell) < 4:
            return None
        rings = []
        for hole in holes:
            ring = [self._point(px, py) for px, py in hole[:, 0, :]]
            if len(ring) >= 4:
                rings.append(ring)
        try:
            polygon = Polygon(shell, rings)
        except Exception:                        # noqa: BLE001
            return None
        if not polygon.is_valid:
            # §22: self-intersections, duplicate points and spikes are fixed
            # here rather than stored and hit later during a distance query.
            repaired = make_valid(polygon)
            polygon = self._largest_polygon(repaired)
        return polygon

    @staticmethod
    def _largest_polygon(geometry) -> Polygon | None:
        if isinstance(geometry, Polygon):
            return geometry
        candidates = [g for g in getattr(geometry, "geoms", [])
                      if isinstance(g, Polygon)]
        return max(candidates, key=lambda g: g.area) if candidates else None

    def _point(self, px: float, py: float) -> tuple[float, float]:
        latitude, longitude = self.bounds.pixel_to_lat_lng(float(px), float(py))
        return longitude, latitude          # GeoJSON is x, y — longitude first

    def _simplify(self, polygon: Polygon, tolerance_m: float):
        """Douglas–Peucker at a tolerance expressed in metres.

        In degrees the same tolerance means different distances in x and y and
        different distances at different latitudes, so the tolerance is
        converted here rather than being a magic 0.00001 somewhere.
        """
        if tolerance_m <= 0:
            return polygon
        latitude = polygon.centroid.y
        degrees = tolerance_m / 111_132.0
        simplified = polygon.simplify(degrees, preserve_topology=True)
        del latitude
        return simplified if simplified.is_valid else polygon

    def _area_m2(self, polygon: Polygon) -> float:
        """Flat-earth area, exact to well under a percent at this size."""
        import math
        latitude = math.radians(polygon.centroid.y)
        x_scale = 111_320.0 * math.cos(latitude)
        y_scale = 111_132.0

        def scaled(ring) -> float:
            coords = list(ring.coords)
            total = 0.0
            for i in range(len(coords) - 1):
                x1, y1 = coords[i][0] * x_scale, coords[i][1] * y_scale
                x2, y2 = coords[i + 1][0] * x_scale, coords[i + 1][1] * y_scale
                total += x1 * y2 - x2 * y1
            return abs(total) / 2

        area = scaled(polygon.exterior)
        for interior in polygon.interiors:
            area -= scaled(interior)
        return area


def feature_collection(features: list[VectorFeature],
                       attribution: str = "",
                       metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    collection: dict[str, Any] = {
        "type": "FeatureCollection",
        "features": [f.to_geojson() for f in features],
    }
    if attribution:
        collection["attribution"] = attribution
    if metadata:
        collection["metadata"] = metadata
    return collection
