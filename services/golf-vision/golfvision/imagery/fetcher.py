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


#: Below this many distinct colours per megapixel, a tile is not a photograph.
#:
#: Esri answers a request outside its high-resolution coverage with a flat
#: placeholder rather than a 404. Over Bắc Giang at zoom 19 that is 123 colours
#: across 400 000 pixels — a blank sheet — and two samples three kilometres
#: apart come back byte-identical. The model, shown a blank, does not say "I
#: cannot see": it returns a hundred and sixteen shapes at 0.22 confidence, and
#: those shapes get filed. A real photograph of the same ground at zoom 18 has
#: eighty-nine thousand colours. There is no borderline case here.
BLANK_COLOURS_PER_MP = 2_000


def looks_blank(pixels) -> bool:
    """True when a raster is the provider saying "nothing here"."""
    flat = pixels.reshape(-1, pixels.shape[-1])
    # Sampled, because np.unique over forty megapixels is slower than the
    # download it is checking, and a blank tile is blank in any subset.
    sample = flat[::max(1, flat.shape[0] // 200_000)]
    megapixels = max(1e-6, sample.shape[0] / 1e6)
    return len(np.unique(sample, axis=0)) / megapixels < BLANK_COLOURS_PER_MP


#: What the model was trained to look at, in metres per pixel.
#:
#: Vietnamese patches were cut at zoom 19 — 0.28 m at these latitudes — and the
#: American ones were 0.6 m NAIP resampled onto the same grid. Both taught the
#: model that a green is roughly a hundred pixels across, and that is the number
#: a convolutional network actually depends on.
TRAINING_METRES_PER_PIXEL = 0.28


def at_training_scale(tile: TileImage, target: float = TRAINING_METRES_PER_PIXEL):
    """The same ground, resampled so a green is the size the model expects.

    Imagery from a coarser zoom is not unusable, it is just smaller: at 0.56 m
    a green is fifty pixels across instead of a hundred, and a network whose
    receptive fields were tuned on the latter sees something it has no
    representation for. Enlarging does not invent detail — the detail is still
    0.56 m — but it puts the shapes back at the scale the filters know.

    This is exactly what the NAIP corpus does: 0.6 m photographs sampled onto a
    0.24 m grid, deliberately, for this reason. A model trained that way is
    already used to being shown ground softer than its pixel count suggests.

    Returns the tile unchanged when it is already at scale or finer.
    """
    from PIL import Image as PillowImage

    current = tile.bounds.metres_per_pixel
    if current <= target * 1.2:
        return tile

    factor = current / target
    width = int(round(tile.bounds.width * factor))
    height = int(round(tile.bounds.height * factor))
    enlarged = np.asarray(PillowImage.fromarray(tile.pixels).resize(
        (width, height), PillowImage.BILINEAR))

    metadata = dict(tile.bounds.metadata)
    metadata.update({"resampledFrom": round(current, 3),
                     "resampledTo": round(current / factor, 3),
                     "resampleFactor": round(factor, 3)})
    # Same corners, same zoom, more pixels — so every pixel-to-degree
    # conversion downstream stays correct without knowing this happened.
    bounds = ImageBounds(
        north=tile.bounds.north, south=tile.bounds.south,
        east=tile.bounds.east, west=tile.bounds.west,
        zoom=tile.bounds.zoom, width=width, height=height,
        metadata=metadata)
    return TileImage(enlarged, bounds, tile.attribution)


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

    def fetch_best(self, south: float, west: float, north: float, east: float,
                   zoom: int = 19, floor: int = 16,
                   max_pixels: int = 100_000) -> TileImage:
        """The finest zoom that returns an actual photograph of this ground.

        Coverage is not uniform. Esri has 0.28 m over Hanoi and nothing finer
        than 0.56 m over Bắc Giang, and it does not say so — it serves a blank
        at the zoom it lacks. Asking for the finest and stepping down until the
        answer is a picture is the difference between "this course has no
        imagery" and "this course has 0.56 m imagery", and only one of those is
        true.

        The tile records the zoom it settled on and how far that is from what
        was asked, because everything downstream — the scale the model expects,
        the confidence a shape deserves — depends on knowing.
        """
        asked = zoom
        for level in range(zoom, floor - 1, -1):
            tile = self.fetch(south, west, north, east, zoom=level,
                              max_pixels=max_pixels)
            if not looks_blank(tile.pixels):
                tile.bounds.metadata["zoomAsked"] = asked
                tile.bounds.metadata["zoomServed"] = level
                tile.bounds.metadata["metresPerPixel"] = \
                    round(tile.bounds.metres_per_pixel, 3)
                return tile
        raise ValueError(
            f"no imagery from {self.provider.name} at {south:.4f},{west:.4f} to "
            f"{north:.4f},{east:.4f} between zoom {zoom} and {floor} — every "
            f"level came back blank")

    def _tile(self, z: int, x: int, y: int) -> Image.Image:
        response = self.session.get(self.provider.tile_url(z, x, y),
                                    timeout=self.timeout)
        response.raise_for_status()
        return Image.open(io.BytesIO(response.content)).convert("RGB")
