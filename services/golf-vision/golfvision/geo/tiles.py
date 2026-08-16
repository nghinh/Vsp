"""The frame an image occupies on the ground, and how to move between them.

Every mask this service produces is a grid of pixels. Every polygon it stores
is degrees of latitude and longitude. This module is the only place the two
meet, which is why it is small, pure and tested: a rounding error here is a
distance a golfer clubs off.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from . import webmercator as wm

#: How far the two axes may disagree before a single scale is a lie. Two per
#: cent is comfortably above the floating-point noise of a real tile crop and
#: well below anything that would matter to a distance.
SQUARE_PIXEL_TOLERANCE = 0.02


@dataclass(frozen=True)
class ImageBounds:
    """Where a raster sits on the Earth, and at what scale.

    Interpolation happens in tile space rather than in degrees. Longitude is
    linear either way; latitude is not, and treating it as linear puts a green
    a few metres out consistently — which is exactly the kind of error nobody
    finds by looking.
    """

    north: float
    south: float
    east: float
    west: float
    zoom: int
    width: int
    height: int

    #: Everything §7 asks to be carried with a tile, so a mask can always be
    #: traced back to the picture and the day it was taken.
    metadata: dict[str, Any] = field(default_factory=dict)

    def longitude_at(self, fraction_x: float) -> float:
        left = wm.tile_x(self.west, self.zoom)
        right = wm.tile_x(self.east, self.zoom)
        return wm.longitude_of_tile_x(left + (right - left) * fraction_x, self.zoom)

    def latitude_at(self, fraction_y: float) -> float:
        top = wm.tile_y(self.north, self.zoom)
        bottom = wm.tile_y(self.south, self.zoom)
        return wm.latitude_of_tile_y(top + (bottom - top) * fraction_y, self.zoom)

    def fraction_of(self, latitude: float, longitude: float) -> tuple[float, float]:
        """The inverse. Exact, because the prompt and the reader must agree."""
        left = wm.tile_x(self.west, self.zoom)
        right = wm.tile_x(self.east, self.zoom)
        top = wm.tile_y(self.north, self.zoom)
        bottom = wm.tile_y(self.south, self.zoom)
        x = (wm.tile_x(longitude, self.zoom) - left) / (right - left)
        y = (wm.tile_y(latitude, self.zoom) - top) / (bottom - top)
        return x, y

    def pixel_to_lat_lng(self, px: float, py: float) -> tuple[float, float]:
        """Pixel centre to latitude/longitude.

        The half-pixel matters: a mask's pixel (0, 0) covers the ground from
        the corner to one pixel in, and its centre is half a pixel from the
        edge. At 0.3 m/px that is 15 cm, which is nothing on its own and adds
        up across a boundary of six hundred points.
        """
        return (self.latitude_at((py + 0.5) / self.height),
                self.longitude_at((px + 0.5) / self.width))

    def lat_lng_to_pixel(self, latitude: float, longitude: float) -> tuple[float, float]:
        x, y = self.fraction_of(latitude, longitude)
        return x * self.width - 0.5, y * self.height - 0.5

    @property
    def metres_per_pixel_x(self) -> float:
        centre = (self.north + self.south) / 2
        return wm.metres_per_pixel(centre, self.zoom) * (
            (wm.tile_x(self.east, self.zoom) - wm.tile_x(self.west, self.zoom))
            * wm.TILE_SIZE / self.width)

    @property
    def metres_per_pixel_y(self) -> float:
        centre = (self.north + self.south) / 2
        return wm.metres_per_pixel(centre, self.zoom) * (
            (wm.tile_y(self.south, self.zoom) - wm.tile_y(self.north, self.zoom))
            * wm.TILE_SIZE / self.height)

    @property
    def metres_per_pixel(self) -> float:
        """One number for the scale — only meaningful when pixels are square.

        In Web Mercator they are: the projection is conformal, so at a given
        zoom a pixel covers the same ground in both axes. A raster stitched
        from whole tiles therefore always has square pixels, and this is a
        safe scalar to hand to morphology and simplification.

        It stops being safe the moment a raster is resized in one axis, or
        constructed by hand with a width and height that do not match the
        ground it claims to cover. Then every area is silently wrong by the
        ratio — 14% in the case that found this — and nothing looks odd.
        """
        x, y = self.metres_per_pixel_x, self.metres_per_pixel_y
        if not self.pixels_are_square:
            raise ValueError(
                f"pixels are not square: {x:.4f} m across, {y:.4f} m down. "
                "Use metres_per_pixel_x and metres_per_pixel_y, or fix the "
                "raster's aspect ratio.")
        return (x + y) / 2

    @property
    def pixels_are_square(self) -> bool:
        x, y = self.metres_per_pixel_x, self.metres_per_pixel_y
        return abs(x - y) <= SQUARE_PIXEL_TOLERANCE * max(x, y)


@dataclass
class TileImage:
    """One stitched picture and the frame it occupies."""

    pixels: Any            # numpy array, H x W x 3, uint8
    bounds: ImageBounds
    attribution: str
