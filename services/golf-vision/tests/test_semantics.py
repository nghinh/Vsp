"""Telling a bunker from a cart path.

The cases here are the ones the measurement produced. On three holes at Long
Thành the land-cover model called bare ground correctly and called half of it
a bunker wrongly — service tracks, cart paths, dirt behind a tee. Each test
below is one of those confusions, written as the shape it actually has.
"""

from __future__ import annotations

import pytest
from shapely.geometry import Polygon

from golfvision.classes import GolfFeature, LandCover
from golfvision.semantics import scores as sc
from golfvision.semantics.inference import GolfSemanticInferenceService, HoleAnchor
from golfvision.vector.vectorize import VectorFeature

#: Long Thành hole 10 — a real hole, 330 m from tee to green.
ANCHOR = HoleAnchor(tee_lat=10.86211, tee_lng=106.89363,
                    green_lat=10.85922, green_lng=106.89289)


def blob(lat: float, lng: float, radius_m: float = 8.0) -> VectorFeature:
    """A roughly circular patch, the shape a bunker actually is."""
    import math
    x_scale, y_scale = sc.metric_scale(lat)
    ring = [(lng + radius_m * math.cos(a) / x_scale,
             lat + radius_m * math.sin(a) / y_scale)
            for a in [i * math.pi / 18 for i in range(36)]]
    ring.append(ring[0])
    polygon = Polygon(ring)
    return VectorFeature("candidate", polygon, sc.area_m2(polygon))


def ribbon(lat: float, lng: float, length_m: float = 120.0,
           width_m: float = 3.0) -> VectorFeature:
    """A cart path: long, thin, and just as bare as sand."""
    x_scale, y_scale = sc.metric_scale(lat)
    half_w = width_m / 2 / y_scale
    half_l = length_m / 2 / x_scale
    polygon = Polygon([(lng - half_l, lat - half_w), (lng + half_l, lat - half_w),
                       (lng + half_l, lat + half_w), (lng - half_l, lat + half_w),
                       (lng - half_l, lat - half_w)])
    return VectorFeature("candidate", polygon, sc.area_m2(polygon))


class TestShapeScores:

    def test_a_circle_is_compact_and_a_ribbon_is_not(self):
        assert sc.compactness(blob(10.860, 106.893).geometry) > 0.9
        assert sc.compactness(ribbon(10.860, 106.893).geometry) < 0.15

    def test_elongation_separates_the_two(self):
        assert sc.elongation(blob(10.860, 106.893).geometry) < 1.2
        assert sc.elongation(ribbon(10.860, 106.893).geometry) > 20

    def test_width_is_the_short_side(self):
        assert sc.width_m(ribbon(10.860, 106.893, 120, 3).geometry) \
            == pytest.approx(3.0, abs=0.3)

    def test_area_plausibility_tails_off_rather_than_cliffs(self):
        """A bunker of 12 m² is unlikely and possible; 12,000 m² is a lake."""
        assert sc.area_plausibility(200, 15, 1000) == 1.0
        marginal = sc.area_plausibility(12, 15, 1000)
        absurd = sc.area_plausibility(12_000, 15, 1000)
        assert 0.3 < marginal < 1.0
        assert absurd < 0.02

    def test_along_the_line_says_where_on_the_hole(self):
        line = ANCHOR.line_of_play
        at_tee = blob(ANCHOR.tee_lat, ANCHOR.tee_lng).geometry
        at_green = blob(ANCHOR.green_lat, ANCHOR.green_lng).geometry

        assert sc.along_line(at_tee, line) == pytest.approx(0.0, abs=0.02)
        assert sc.along_line(at_green, line) == pytest.approx(1.0, abs=0.02)


class TestBunkerInference:

    @staticmethod
    def service() -> GolfSemanticInferenceService:
        return GolfSemanticInferenceService(ANCHOR)

    def test_sand_beside_the_line_of_play_is_a_bunker(self):
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)
        verdict = self.service().classify(blob(*midpoint), LandCover.BARE_LAND)

        assert verdict.feature is GolfFeature.BUNKER
        assert verdict.confidence > 0.7

    def test_a_cart_path_is_not_a_bunker_however_close_it_runs(self):
        """The confusion that cost precision. It is bare, it is pale, and it
        runs straight up the middle of the hole — position cannot save it,
        only shape can."""
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)
        verdict = self.service().classify(ribbon(*midpoint), LandCover.BARE_LAND)

        assert verdict.confidence < 0.15
        assert self.service().apply(ribbon(*midpoint), LandCover.BARE_LAND) is None

    def test_bare_ground_off_the_hole_is_not_this_hole_s_bunker(self):
        """Sand nobody can reach belongs to another hole, or a building site.
        Shape alone would keep it — position is what removes it."""
        far = blob(ANCHOR.tee_lat + 0.0030, ANCHOR.tee_lng + 0.0030)
        verdict = self.service().classify(far, LandCover.BARE_LAND)

        assert verdict.scores["position"] == 0.0
        assert verdict.confidence == 0.0

    def test_a_hectare_of_bare_ground_is_a_building_site(self):
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)
        huge = blob(*midpoint, radius_m=60)     # about 11,000 m²

        assert self.service().classify(huge, LandCover.BARE_LAND).scores["size"] < 0.05

    def test_a_greenside_bunker_just_past_the_green_survives(self):
        """§27's warning, in miniature: the recorded green point is not the
        back of the green, so sand beyond it is normal rather than suspect."""
        beyond = blob(ANCHOR.green_lat - 0.00015, ANCHOR.green_lng)
        verdict = self.service().classify(beyond, LandCover.BARE_LAND)

        assert verdict.scores["onHole"] == 1.0
        assert verdict.confidence > 0.6

    def test_the_evidence_says_why(self):
        """§59 — a classification nobody can interrogate cannot be improved."""
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)
        verdict = self.service().classify(blob(*midpoint), LandCover.BARE_LAND)

        assert set(verdict.evidence) >= {
            "areaM2", "compactness", "widthM", "distanceToLineM", "alongLine"}
        assert set(verdict.scores) >= {"shape", "size", "position", "onHole"}

    def test_without_an_anchor_only_shape_is_judged(self):
        """A course with no recorded tee or green still gets an answer, from
        the signals that do not need one."""
        blind = GolfSemanticInferenceService(anchor=None)
        verdict = blind.classify(blob(10.860, 106.893), LandCover.BARE_LAND)

        assert verdict.feature is GolfFeature.BUNKER
        assert "position" not in verdict.scores
        assert verdict.confidence > 0.7


class TestOtherClasses:

    def test_a_green_is_not_guessed_at(self):
        """The honest gap. Mown turf at 8 mm and at 25 mm are the same pixels,
        so grass produces no golf class at all rather than a confident one."""
        service = GolfSemanticInferenceService(ANCHOR)
        verdict = service.classify(blob(ANCHOR.green_lat, ANCHOR.green_lng),
                                   LandCover.GRASS)

        assert verdict.feature is None

    def test_water_near_the_hole_is_a_hazard(self):
        service = GolfSemanticInferenceService(ANCHOR)
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)
        verdict = service.classify(blob(*midpoint, radius_m=25), LandCover.WATER)

        assert verdict.feature is GolfFeature.WATER_HAZARD
        assert verdict.confidence > 0.8

    def test_a_ribbon_of_pavement_is_a_cart_path(self):
        service = GolfSemanticInferenceService(ANCHOR)
        verdict = service.classify(ribbon(10.860, 106.893), LandCover.PAVEMENT)

        assert verdict.feature is GolfFeature.CART_PATH
        assert verdict.confidence > 0.5

    def test_scrub_is_too_small_to_be_an_obstruction(self):
        """§17 asks for playable obstructions, not every tree."""
        service = GolfSemanticInferenceService(ANCHOR)
        midpoint = ((ANCHOR.tee_lat + ANCHOR.green_lat) / 2,
                    (ANCHOR.tee_lng + ANCHOR.green_lng) / 2)

        scrub = service.classify(blob(*midpoint, radius_m=2), LandCover.TREE)
        canopy = service.classify(blob(*midpoint, radius_m=20), LandCover.TREE)

        assert scrub.scores["size"] < canopy.scores["size"]
        assert canopy.scores["size"] == 1.0
