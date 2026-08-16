"""Web Mercator tile arithmetic.

A deliberate port of ``vnpt.vsp.module.geometry.vision.WebMercator`` on the
Java side rather than a fresh implementation. The two have to agree to the
last decimal: the backend frames an image from a hole's coordinates, this
service reads pixels back out of it, and a half-tile disagreement between
them draws a bunker in the next province with nothing on screen looking
wrong.
"""

from __future__ import annotations

import math

#: The zoom at which one tile covers the whole world.
TILE_SIZE = 256


def tile_x(longitude: float, zoom: int) -> float:
    """Fractional tile column. The fraction is the position within the tile."""
    return (longitude + 180.0) / 360.0 * (1 << zoom)


def tile_y(latitude: float, zoom: int) -> float:
    """Fractional tile row.

    Latitude is projected, not scaled. Interpolating it linearly in degrees
    is the classic error here — it is wrong by metres at golf-hole scale and
    the result still looks plausible.
    """
    radians = math.radians(latitude)
    projected = math.log(math.tan(radians) + 1 / math.cos(radians))
    return (1 - projected / math.pi) / 2 * (1 << zoom)


def longitude_of_tile_x(x: float, zoom: int) -> float:
    return x / (1 << zoom) * 360.0 - 180.0


def latitude_of_tile_y(y: float, zoom: int) -> float:
    n = math.pi * (1 - 2 * y / (1 << zoom))
    return math.degrees(math.atan(math.sinh(n)))


#: Half the circumference of the sphere Web Mercator projects onto, which is
#: where the projection's metres run out: ±20 037 508.34 on both axes.
EARTH_RADIUS_M = 6_378_137.0


def to_metres(latitude: float, longitude: float) -> tuple[float, float]:
    """Degrees to EPSG:3857 metres — the units a GeoTIFF is warped into.

    Tile arithmetic above is enough for anything that stays on the tile grid.
    A GeoTIFF does not: rasterio wants an affine transform in projected units,
    and the only projection this service ever asks it for is the one the tile
    grid is already in. Same sphere, same origin, different units.
    """
    x = math.radians(longitude) * EARTH_RADIUS_M
    y = math.log(math.tan(math.pi / 4 + math.radians(latitude) / 2)) \
        * EARTH_RADIUS_M
    return x, y


def metres_per_pixel(latitude: float, zoom: int) -> float:
    """Ground resolution of one pixel, which is what decides the zoom.

    At 16°N — the middle of Vietnam's golf — zoom 19 is 0.287 m and zoom 18
    is 0.574 m. A model trained at 0.2 m cares about the difference.
    """
    equatorial = 156_543.03392804097
    return equatorial * math.cos(math.radians(latitude)) / (1 << zoom)


def zoom_for(south: float, west: float, north: float, east: float,
             max_pixels: int, max_zoom: int) -> int:
    """The finest zoom whose image still fits in ``max_pixels`` a side."""
    for zoom in range(max_zoom, 0, -1):
        width = abs(tile_x(east, zoom) - tile_x(west, zoom)) * TILE_SIZE
        height = abs(tile_y(south, zoom) - tile_y(north, zoom)) * TILE_SIZE
        if width <= max_pixels and height <= max_pixels:
            return zoom
    return 1
