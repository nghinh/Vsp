"""Masks becoming polygons.

Synthetic masks on purpose: a shape of known size in a known place, so "is
the polygon right" is a question with an answer. Satellite imagery would make
this a test of the weather.
"""

from __future__ import annotations

import numpy as np
import pytest

from golfvision.classes import GolfFeature
from golfvision.geo.tiles import ImageBounds
from golfvision.masks.postprocess import MaskPostProcessor
from golfvision.vector.vectorize import MaskVectorizationService


def frame(width: int = 1024, height: int = 1024) -> ImageBounds:
    """A real crop: eight tiles square at zoom 19 over Long Biên.

    The corners are the tile grid's, not round numbers, because that is what
    a stitched raster actually covers — and it is what makes the pixels
    square. An invented box of 1024x1024 over ground that is 571 m across and
    500 m down has pixels 14% longer in one axis than the other, and every
    area computed from it is wrong by that much with nothing looking odd.
    That mistake is what this fixture used to make.
    """
    return ImageBounds(north=21.0390052, south=21.0338781,
                       east=105.8958435, west=105.8903503,
                       zoom=19, width=width, height=height)


def disc(size: int, cx: int, cy: int, radius: int) -> np.ndarray:
    ys, xs = np.ogrid[:size, :size]
    return ((xs - cx) ** 2 + (ys - cy) ** 2) <= radius ** 2


class TestVectorization:

    def test_a_disc_becomes_one_polygon_of_the_right_area(self):
        bounds = frame()
        service = MaskVectorizationService(bounds)
        radius = 40
        mask = disc(1024, 500, 500, radius)

        features = service.vectorize(mask, "green", simplify_m=0.2)

        assert len(features) == 1
        expected = math_area(radius, bounds.metres_per_pixel)
        # Within 5%: a rasterised circle is a staircase, and simplification
        # shaves the corners off the staircase.
        assert features[0].area_m2 == pytest.approx(expected, rel=0.05)

    def test_a_polygon_lands_where_the_mask_was(self):
        bounds = frame()
        service = MaskVectorizationService(bounds)
        mask = disc(1024, 700, 300, 30)

        centroid = service.vectorize(mask, "bunker")[0].geometry.centroid
        latitude, longitude = bounds.pixel_to_lat_lng(700, 300)

        assert centroid.y == pytest.approx(latitude, abs=1e-5)
        assert centroid.x == pytest.approx(longitude, abs=1e-5)

    def test_two_separate_blobs_are_two_polygons(self):
        service = MaskVectorizationService(frame())
        mask = disc(1024, 200, 200, 30) | disc(1024, 800, 800, 40)

        features = service.vectorize(mask, "bunker")

        assert len(features) == 2
        # Sorted largest first, so a reviewer sees the one that matters.
        assert features[0].area_m2 > features[1].area_m2

    def test_a_hole_in_a_shape_is_a_hole_in_the_polygon(self):
        """An island green in a pond is a real thing, and a pond drawn solid
        over its own island measures a carry that does not exist."""
        service = MaskVectorizationService(frame())
        mask = disc(1024, 500, 500, 100) & ~disc(1024, 500, 500, 40)

        feature = service.vectorize(mask, "water_hazard")[0]

        assert len(feature.geometry.interiors) == 1
        solid = math_area(100, frame().metres_per_pixel)
        assert feature.area_m2 < solid * 0.9

    def test_a_concave_shape_stays_concave(self):
        """What the implementation this replaces could not do.

        Sixty rays from a centroid produce a convex hull whatever the shape
        was — which is why every bunker on the old map was the same octagon.
        """
        service = MaskVectorizationService(frame())
        mask = disc(1024, 500, 500, 120)
        mask[380:620, 500:] &= ~disc(1024, 620, 500, 100)[380:620, 500:]

        feature = service.vectorize(mask, "bunker")[0]

        hull_area = feature.geometry.convex_hull.area
        assert feature.geometry.area < hull_area * 0.9

    def test_geometry_is_valid_and_closed(self):
        service = MaskVectorizationService(frame())
        for feature in service.vectorize(disc(1024, 500, 500, 60), "green"):
            assert feature.geometry.is_valid
            ring = list(feature.geometry.exterior.coords)
            assert ring[0] == ring[-1]

    def test_simplification_removes_points_without_moving_the_edge(self):
        service = MaskVectorizationService(frame())
        mask = disc(1024, 500, 500, 90)

        detailed = service.vectorize(mask, "green", simplify_m=0.0)[0]
        simple = service.vectorize(mask, "green", simplify_m=1.0)[0]

        assert len(simple.geometry.exterior.coords) < len(detailed.geometry.exterior.coords)
        assert simple.area_m2 == pytest.approx(detailed.area_m2, rel=0.03)

    def test_an_empty_mask_produces_nothing(self):
        service = MaskVectorizationService(frame())
        assert service.vectorize(np.zeros((256, 256), bool), "green") == []

    def test_confidence_is_the_product_of_its_parts(self):
        """§24 — kept as sub-scores so a bad number can be blamed on the
        stage that produced it."""
        service = MaskVectorizationService(frame())
        feature = service.vectorize(disc(1024, 500, 500, 50), "green")[0]
        feature.scores.update(vision=0.9, geometry=0.8, topology=0.5)

        assert feature.confidence == pytest.approx(0.36)
        assert feature.to_geojson()["properties"]["scores"]["topology"] == 0.5


class TestMaskPostProcessor:

    def test_speckle_is_removed_and_the_feature_survives(self):
        cleaner = MaskPostProcessor(metres_per_pixel=0.3)
        mask = disc(512, 256, 256, 40)          # about 450 m²
        mask[10, 10] = mask[20, 400] = mask[300, 40] = True

        cleaned = cleaner.clean(mask, GolfFeature.GREEN)

        assert cleaned[256, 256]
        assert not cleaned[10, 10] and not cleaned[20, 400]

    def test_a_small_hole_is_filled(self):
        """A cart crossing a fairway leaves one, and the fairway is still one
        fairway."""
        cleaner = MaskPostProcessor(metres_per_pixel=0.3)
        mask = disc(512, 256, 256, 120)
        mask &= ~disc(512, 256, 256, 6)

        assert cleaner.clean(mask, GolfFeature.FAIRWAY)[256, 256]

    def test_a_tee_box_is_not_deleted_by_a_bunker_threshold(self):
        """§20 says this in as many words. A tee platform is genuinely small,
        and a minimum area tuned on greens removes every one of them."""
        cleaner = MaskPostProcessor(metres_per_pixel=0.3)
        tee = disc(512, 256, 256, 18)           # roughly 90 m²

        assert cleaner.clean(tee, GolfFeature.TEE_BOX).any()
        assert not cleaner.clean(tee, GolfFeature.GREEN).any()

    def test_thresholds_are_ground_area_not_pixel_count(self):
        """The same course at two zooms must clean to the same shapes."""
        shape = disc(512, 256, 256, 30)
        fine = MaskPostProcessor(0.15).clean(shape, GolfFeature.BUNKER)
        coarse = MaskPostProcessor(0.6).clean(shape, GolfFeature.BUNKER)

        assert fine.any() and coarse.any()


def math_area(radius_px: float, metres_per_pixel: float) -> float:
    import math
    return math.pi * (radius_px * metres_per_pixel) ** 2
