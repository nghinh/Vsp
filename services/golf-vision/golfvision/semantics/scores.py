"""What a shape looks like, in numbers a scorer can weigh.

Every function here is pure geometry on a Shapely polygon in degrees, and
every one returns 0 to 1. Nothing thresholds — a hard cut-off throws away the
evidence that the next signal needed. A long thin blob is not disqualified
from being a bunker; it is given a low elongation score and left to the other
signals to rescue or condemn.
"""

from __future__ import annotations

import math

from shapely.geometry import LineString, Point, Polygon


def metric_scale(latitude: float) -> tuple[float, float]:
    """Metres per degree of longitude and latitude at this latitude."""
    return 111_320.0 * math.cos(math.radians(latitude)), 111_132.0


def area_m2(polygon: Polygon) -> float:
    x_scale, y_scale = metric_scale(polygon.centroid.y)
    return abs(polygon.area) * x_scale * y_scale


def perimeter_m(polygon: Polygon) -> float:
    x_scale, y_scale = metric_scale(polygon.centroid.y)
    total = 0.0
    coords = list(polygon.exterior.coords)
    for i in range(len(coords) - 1):
        dx = (coords[i + 1][0] - coords[i][0]) * x_scale
        dy = (coords[i + 1][1] - coords[i][1]) * y_scale
        total += math.hypot(dx, dy)
    return total


def compactness(polygon: Polygon) -> float:
    """1 for a circle, towards 0 for a ribbon.

    The Polsby–Popper measure. This is the single most useful signal for
    separating a bunker from a cart path: both are pale, both are bare, and
    one of them is 3 m wide and 200 m long.
    """
    perimeter = perimeter_m(polygon)
    if perimeter <= 0:
        return 0.0
    return min(1.0, 4 * math.pi * area_m2(polygon) / (perimeter ** 2))


def elongation(polygon: Polygon) -> float:
    """Length over width of the minimum rotated rectangle, 1 upward.

    Used the other way round from compactness: a fairway *should* be
    elongated, and a fairway that is not is probably a green complex.
    """
    box = polygon.minimum_rotated_rectangle
    if not isinstance(box, Polygon):
        return 1.0
    coords = list(box.exterior.coords)[:4]
    if len(coords) < 4:
        return 1.0
    x_scale, y_scale = metric_scale(polygon.centroid.y)

    def side(a, b) -> float:
        return math.hypot((b[0] - a[0]) * x_scale, (b[1] - a[1]) * y_scale)

    first = side(coords[0], coords[1])
    second = side(coords[1], coords[2])
    short = min(first, second)
    return (max(first, second) / short) if short > 0 else 1.0


def width_m(polygon: Polygon) -> float:
    """The short side of the minimum rotated rectangle."""
    box = polygon.minimum_rotated_rectangle
    if not isinstance(box, Polygon):
        return 0.0
    coords = list(box.exterior.coords)[:4]
    if len(coords) < 4:
        return 0.0
    x_scale, y_scale = metric_scale(polygon.centroid.y)

    def side(a, b) -> float:
        return math.hypot((b[0] - a[0]) * x_scale, (b[1] - a[1]) * y_scale)

    return min(side(coords[0], coords[1]), side(coords[1], coords[2]))


def area_plausibility(area: float, low: float, high: float,
                      softness: float = 0.35) -> float:
    """1 inside the range, tailing off outside rather than dropping to zero.

    A bunker of 12 m² is unlikely and not impossible; one of 12,000 m² is a
    lake. The tail lets the first survive on other evidence and kills the
    second on its own.
    """
    if area <= 0:
        return 0.0
    if low <= area <= high:
        return 1.0
    reference = low if area < low else high
    ratio = area / reference if area < low else reference / area
    return max(0.0, min(1.0, ratio ** (1 / softness)))


def distance_to_line_m(polygon: Polygon, line: LineString) -> float:
    """Shortest distance from the shape to the line of play, in metres."""
    x_scale, y_scale = metric_scale(polygon.centroid.y)
    scaled_polygon = _scale(polygon, x_scale, y_scale)
    scaled_line = LineString([(x * x_scale, y * y_scale) for x, y in line.coords])
    return scaled_polygon.distance(scaled_line)


def distance_to_point_m(polygon: Polygon, point: Point) -> float:
    x_scale, y_scale = metric_scale(polygon.centroid.y)
    return _scale(polygon, x_scale, y_scale).distance(
        Point(point.x * x_scale, point.y * y_scale))


def proximity(distance_m: float, ideal_m: float, tolerance_m: float) -> float:
    """1 at or inside ``ideal_m``, decaying to 0 by ``ideal_m + tolerance_m``."""
    if distance_m <= ideal_m:
        return 1.0
    if distance_m >= ideal_m + tolerance_m:
        return 0.0
    return 1.0 - (distance_m - ideal_m) / tolerance_m


def along_line(polygon: Polygon, line: LineString) -> float:
    """Where the shape sits along the line of play, 0 at the tee, 1 at the green.

    Can exceed 1 or fall below 0: a shape behind the tee or beyond the green
    is genuinely off the hole, and saying so is more useful than clamping it
    to the nearest end.
    """
    if line.length <= 0:
        return 0.0
    return line.project(polygon.centroid) / line.length


def _scale(polygon: Polygon, x_scale: float, y_scale: float) -> Polygon:
    from shapely.affinity import scale as affine_scale
    return affine_scale(polygon, xfact=x_scale, yfact=y_scale, origin=(0, 0))
