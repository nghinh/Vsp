"""Getting the picture.

The imagery provider is abstracted for the same reason the model provider is,
and for one more: the terms attached to the tiles decide what may legally be
done with the masks. Esri's World Imagery licence says its tiles "cannot be
used as direct input to automated information extraction" and that derivatives
are "strictly for non-commercial use within ArcGIS". That makes it usable for
a feasibility prototype and unusable for the product, so the source is a
setting rather than a constant, and every provider states its own terms.
"""

from __future__ import annotations

import io
import os
from dataclasses import dataclass
from datetime import date

import numpy as np
import requests
from PIL import Image

from ..geo import webmercator as wm
from ..geo.tiles import ImageBounds, TileImage


@dataclass(frozen=True)
class ImageryProvider:
    name: str
    url_template: str
    attribution: str
    max_zoom: int

    #: Whether this deployment may run models over these pixels and sell the
    #: result. False is not a technical limit — it is the licence.
    permits_automated_extraction: bool

    def tile_url(self, z: int, x: int, y: int) -> str:
        return (self.url_template
                .replace("{z}", str(z))
                .replace("{x}", str(x))
                .replace("{y}", str(y)))


#: What the app is configured with today. Fine for a prototype, and the
#: licence has to be resolved before anything built on it ships.
ESRI_WORLD_IMAGERY = ImageryProvider(
    name="esri-world-imagery",
    url_template="https://server.arcgisonline.com/ArcGIS/rest/services/"
                 "World_Imagery/MapServer/tile/{z}/{y}/{x}",
    attribution="© Esri, Maxar, Earthstar Geographics",
    max_zoom=19,
    permits_automated_extraction=False,
)


def provider_from_env() -> ImageryProvider:
    url = os.environ.get("IMAGERY_TILE_URL")
    if not url:
        return ESRI_WORLD_IMAGERY
    return ImageryProvider(
        name=os.environ.get("IMAGERY_PROVIDER", "configured"),
        url_template=url,
        attribution=os.environ.get("IMAGERY_ATTRIBUTION", ""),
        max_zoom=int(os.environ.get("IMAGERY_MAX_ZOOM", "19")),
        permits_automated_extraction=os.environ.get(
            "IMAGERY_PERMITS_EXTRACTION", "false").lower() == "true",
    )


class TileFetcher:
    """Stitches the tiles covering a box into one image, with its frame."""

    def __init__(self, provider: ImageryProvider | None = None,
                 max_tiles: int = 144, timeout: int = 20):
        self.provider = provider or provider_from_env()
        self.max_tiles = max_tiles
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers["User-Agent"] = "VSP-golf-vision/0.1"

    def fetch(self, south: float, west: float, north: float, east: float,
              zoom: int | None = None, max_pixels: int = 2048) -> TileImage:
        zoom = zoom if zoom is not None else wm.zoom_for(
            south, west, north, east, max_pixels, self.provider.max_zoom)

        left = int(wm.tile_x(west, zoom))
        right = int(wm.tile_x(east, zoom))
        top = int(wm.tile_y(north, zoom))
        bottom = int(wm.tile_y(south, zoom))
        columns, rows = right - left + 1, bottom - top + 1
        if columns * rows > self.max_tiles:
            raise ValueError(
                f"{columns * rows} tiles at zoom {zoom} exceeds the cap of "
                f"{self.max_tiles}; lower the zoom or shrink the box")

        canvas = Image.new("RGB", (columns * wm.TILE_SIZE, rows * wm.TILE_SIZE))
        for column in range(columns):
            for row in range(rows):
                tile = self._tile(zoom, left + column, top + row)
                canvas.paste(tile, (column * wm.TILE_SIZE, row * wm.TILE_SIZE))

        # The stitched canvas covers whole tiles, so its frame is the tile
        # grid's rather than the box that was asked for. Cropping to the box
        # and keeping the box's own bounds is the mistake that puts every
        # mask a few metres north-west.
        bounds = ImageBounds(
            north=wm.latitude_of_tile_y(top, zoom),
            south=wm.latitude_of_tile_y(bottom + 1, zoom),
            east=wm.longitude_of_tile_x(right + 1, zoom),
            west=wm.longitude_of_tile_x(left, zoom),
            zoom=zoom,
            width=canvas.width,
            height=canvas.height,
            metadata={
                "tileX": left, "tileY": top,
                "tilesAcross": columns, "tilesDown": rows,
                "zoom": zoom,
                "mapProjection": "EPSG:3857",
                "imageProvider": self.provider.name,
                "imageFetched": date.today().isoformat(),
                "permitsAutomatedExtraction":
                    self.provider.permits_automated_extraction,
            },
        )
        return TileImage(np.asarray(canvas), bounds, self.provider.attribution)

    def _tile(self, z: int, x: int, y: int) -> Image.Image:
        response = self.session.get(self.provider.tile_url(z, x, y),
                                    timeout=self.timeout)
        response.raise_for_status()
        return Image.open(io.BytesIO(response.content)).convert("RGB")
