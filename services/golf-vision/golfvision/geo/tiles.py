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
    def metres_per_pixel(self) -> float:
        centre = (self.north + self.south) / 2
        return wm.metres_per_pixel(centre, self.zoom) * (
            (wm.tile_x(self.east, self.zoom) - wm.tile_x(self.west, self.zoom))
            * wm.TILE_SIZE / self.width)


@dataclass
class TileImage:
    """One stitched picture and the frame it occupies."""

    pixels: Any            # numpy array, H x W x 3, uint8
    bounds: ImageBounds
    attribution: str
