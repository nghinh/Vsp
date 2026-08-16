"""Deciding what golf calls a shape the vision model found.

The measurement that produced this module: on three holes at Long Thành the
land-cover model found bunkers with recall 0.67–0.73 and put their edges
within 1.0–1.4 m — better than a golfer can judge — while precision sat at
0.35–0.52. It is not failing to see the bunkers. It is calling the cart
paths, the service tracks and the bare dirt behind the tee bunkers too,
because to a land-cover model they are all bare ground and that is the truth.

So the vision model is left alone to answer the question it can answer, and
what golf calls the answer is decided here, from shape and from position.
Both signals are needed. Shape alone keeps a round patch of dirt in a car
park; position alone keeps the cart path that runs up the middle of the hole.

Nothing here is a threshold. Every signal is a score, they multiply, and the
evidence is kept per feature so a wrong answer can be attributed rather than
guessed at.
"""

from __future__ import annotations

from dataclasses import dataclass

from shapely.geometry import LineString, Point

from ..classes import GolfFeature, LandCover
from ..vector.vectorize import VectorFeature
from . import scores as sc


@dataclass(frozen=True)
class HoleAnchor:
    """The two points this project already holds for 1,131 holes.

    An enormous prior, and free. §12 asks whether a green candidate sits "at
    the terminal end of a likely hole"; for these holes the terminal end is
    not inferred, it is recorded. §26's topology engine has to discover the
    tee-to-green line on a course nobody has surveyed. Here it is given.
    """

    tee_lat: float
    tee_lng: float
    green_lat: float
    green_lng: float
    par: int = 4

    @property
    def line_of_play(self) -> LineString:
        return LineString([(self.tee_lng, self.tee_lat),
                           (self.green_lng, self.green_lat)])

    @property
    def green_point(self) -> Point:
        return Point(self.green_lng, self.green_lat)

    @property
    def tee_point(self) -> Point:
        return Point(self.tee_lng, self.tee_lat)

    @property
    def length_m(self) -> float:
        x_scale, y_scale = sc.metric_scale(self.tee_lat)
        dx = (self.green_lng - self.tee_lng) * x_scale
        dy = (self.green_lat - self.tee_lat) * y_scale
        return (dx * dx + dy * dy) ** 0.5


@dataclass(frozen=True)
class Verdict:
    feature: GolfFeature | None
    scores: dict[str, float]
    evidence: dict[str, float | str]

    @property
    def confidence(self) -> float:
        product = 1.0
        for value in self.scores.values():
            product *= max(0.0, min(1.0, value))
        return product


class GolfSemanticInferenceService:
    """Level 1 shapes in, golf classes out.

    Deliberately conservative about what it will claim. A green is not
    inferred at all: the land-cover model puts it in the same class as the
    fairway and the rough, because mown turf is mown turf, and dressing that
    up as an inference would produce confident nonsense. That gap is the
    argument for a trained GolfSeg, and it is left visible.
    """

    #: Below this a candidate is not worth carrying forward at all. Low on
    #: purpose — the point is to rank, not to reject early.
    MINIMUM_CONFIDENCE = 0.12

    def __init__(self, anchor: HoleAnchor | None = None):
        self.anchor = anchor

    def classify(self, feature: VectorFeature,
                 land_cover: LandCover) -> Verdict:
        if land_cover == LandCover.BARE_LAND:
            return self._bunker(feature)
        if land_cover == LandCover.WATER:
            return self._water(feature)
        if land_cover == LandCover.TREE:
            return self._trees(feature)
        if land_cover == LandCover.PAVEMENT:
            return self._cart_path(feature)
        return Verdict(None, {}, {"landCover": land_cover.value})

    # ── §15 ────────────────────────────────────────────────────────────────

    def _bunker(self, feature: VectorFeature) -> Verdict:
        """Bare ground that is shaped like sand and lies where sand lies.

        The three things that separate a bunker from everything else pale on
        a golf course:

        * it is compact. A cart path is 3 m wide and runs the length of the
          hole; a bunker is a blob. This one signal does most of the work.
        * it is bunker-sized. Fifteen square metres to a thousand covers a
          pot bunker and a waste area; a hectare of bare ground is a building
          site.
        * it is near the line of play. Sand nobody can reach is somebody
          else's hole, or the car park.
        """
        polygon = feature.geometry
        area = sc.area_m2(polygon)
        shape = sc.compactness(polygon)
        width = sc.width_m(polygon)

        signals = {
            "shape": shape,
            "size": sc.area_plausibility(area, 15, 1_000),
            # A ribbon under four metres wide is a path however compact the
            # measure says it is.
            "width": sc.proximity(4.0, width, 4.0) if width < 4.0 else 1.0,
        }
        evidence: dict[str, float | str] = {
            "areaM2": round(area, 1),
            "compactness": round(shape, 3),
            "widthM": round(width, 1),
            "landCover": LandCover.BARE_LAND.value,
        }

        if self.anchor is not None:
            distance = sc.distance_to_line_m(polygon, self.anchor.line_of_play)
            position = sc.along_line(polygon, self.anchor.line_of_play)
            signals["position"] = sc.proximity(distance, 45.0, 55.0)
            # Behind the tee or well past the green is off this hole. Not
            # fatal — a green-side bunker sits slightly beyond the green
            # point — but it costs.
            signals["onHole"] = 1.0 if -0.08 <= position <= 1.12 else 0.35
            evidence["distanceToLineM"] = round(distance, 1)
            evidence["alongLine"] = round(position, 3)

        return Verdict(GolfFeature.BUNKER, signals, evidence)

    # ── §16 ────────────────────────────────────────────────────────────────

    def _water(self, feature: VectorFeature) -> Verdict:
        """Water is water. The only question is whether it is in play.

        Measured precision on open lakes was 0.91–0.95, so the class itself
        is trustworthy where it fires; what it cannot say is whether a pond
        belongs to this hole or the next one.
        """
        polygon = feature.geometry
        area = sc.area_m2(polygon)
        signals = {"size": sc.area_plausibility(area, 50, 200_000)}
        evidence: dict[str, float | str] = {
            "areaM2": round(area, 1), "landCover": LandCover.WATER.value}

        if self.anchor is not None:
            distance = sc.distance_to_line_m(polygon, self.anchor.line_of_play)
            signals["position"] = sc.proximity(distance, 70.0, 90.0)
            evidence["distanceToLineM"] = round(distance, 1)

        return Verdict(GolfFeature.WATER_HAZARD, signals, evidence)

    # ── §17 ────────────────────────────────────────────────────────────────

    def _trees(self, feature: VectorFeature) -> Verdict:
        """Canopy that is big enough to block a shot.

        §17 asks for playable obstructions rather than every tree. A hundred
        square metres is roughly one mature tree; below that it is scrub and
        drawing it helps nobody.
        """
        polygon = feature.geometry
        area = sc.area_m2(polygon)
        signals = {"size": sc.area_plausibility(area, 100, 100_000)}
        evidence: dict[str, float | str] = {
            "areaM2": round(area, 1), "landCover": LandCover.TREE.value}

        if self.anchor is not None:
            distance = sc.distance_to_line_m(polygon, self.anchor.line_of_play)
            signals["position"] = sc.proximity(distance, 60.0, 80.0)
            evidence["distanceToLineM"] = round(distance, 1)

        return Verdict(GolfFeature.TREE, signals, evidence)

    # ────────────────────────────────────────────────────────────────────────

    def _cart_path(self, feature: VectorFeature) -> Verdict:
        """The opposite test to a bunker: long, thin and not compact."""
        polygon = feature.geometry
        signals = {
            "shape": min(1.0, sc.elongation(polygon) / 6.0),
            "width": 1.0 if sc.width_m(polygon) <= 8.0 else 0.3,
        }
        return Verdict(GolfFeature.CART_PATH, signals,
                       {"widthM": round(sc.width_m(polygon), 1),
                        "elongation": round(sc.elongation(polygon), 2)})

    def apply(self, feature: VectorFeature,
              land_cover: LandCover) -> VectorFeature | None:
        """Classify in place, or drop the candidate.

        Returns None below the floor, so a caller can filter without
        second-guessing the score.
        """
        verdict = self.classify(feature, land_cover)
        if verdict.feature is None or verdict.confidence < self.MINIMUM_CONFIDENCE:
            return None
        feature.label = verdict.feature.value
        feature.scores.update(verdict.scores)
        feature.evidence.update(verdict.evidence)
        return feature
