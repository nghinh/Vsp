"""NAIP — the imagery a shipped model is allowed to have learned from.

Everything GolfSeg knows today it learned from Esri World Imagery, whose
licence says its tiles "cannot be used as direct input to automated
information extraction". That is not a detail to be resolved later: it means
the weights cannot ship, and the model card says so in as many words.

NAIP is the way out. The USDA Farm Service Agency flies the continental United
States at 0.6 m and puts the result in the public domain; Microsoft's Planetary
Computer serves it as cloud-optimised GeoTIFF through a STAC API. Public domain
imagery over the country that holds something like two fifths of the world's
golf courses, and OpenStreetMap has drawn a third of a million greens on top of
it under ODbL. Both halves of a training set, and neither of them Esri's.

Two things NAIP has that Esri tiles do not:

* **Near-infrared.** Grass reflects it strongly, sand and water hardly at all,
  so the one band Esri cannot give separates the three classes this model most
  often confuses. It is carried as a fourth channel — see `channel_dropout` in
  the training code for how a model trained with it still works on the RGB-only
  imagery Vietnam is served from.
* **A capture date per pixel, from a known flight.** A mask can be traced to
  the photograph and the day it was taken, which is what §7 asks for and what
  a tile server URL cannot answer.

What it does not have is Vietnam. This is a pretraining corpus; the fine-tune
and every evaluation number that decides whether something ships still come
from the 36 Vietnamese courses. Bermuda grass in Georgia is not paspalum in
Long Biên, and pretending otherwise would be the same mistake as trusting a
val score computed on patches from a training course.

Alignment: the array this returns is snapped to the same Web Mercator tile grid
`TileFetcher` uses, at the same zoom, so `ImageBounds` means exactly what it
means everywhere else and the mask rasteriser needs no special case. NAIP is
0.6 m and zoom 19 is roughly 0.2–0.3 m depending on latitude, so this is
upsampling — the detail is NAIP's, the sampling is the app's. That is the right
way round: the model sees objects at the pixel size it will see them at
inference, and softer than it will see them, which is the easy direction.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any

import numpy as np

from ..geo import webmercator as wm
from ..geo.tiles import ImageBounds

STAC_URL = "https://planetarycomputer.microsoft.com/api/stac/v1"

#: Public domain. Not "free to view" — free to run a model over and sell the
#: result, which is the only sense of "free" that matters here.
ATTRIBUTION = "Public domain — USDA Farm Service Agency, NAIP"

#: Band order as NAIP stores it, and as this returns it.
BANDS = ("red", "green", "blue", "nir")


@dataclass
class NaipScene:
    """One stitched NAIP picture, its frame, and where every pixel came from."""

    pixels: np.ndarray                  # H x W x 4, uint8
    bounds: ImageBounds
    attribution: str = ATTRIBUTION
    #: The NAIP scenes that contributed, newest first. Provenance, and the
    #: answer to "which photograph is this green drawn on".
    items: list[dict[str, Any]] = field(default_factory=list)
    #: Fraction of the frame NAIP actually covered. Below 1.0 means a course
    #: straddles the edge of everything the search returned.
    coverage: float = 0.0

    @property
    def rgb(self) -> np.ndarray:
        return self.pixels[:, :, :3]

    @property
    def nir(self) -> np.ndarray:
        return self.pixels[:, :, 3]

    def ndvi(self) -> np.ndarray:
        """Grass against everything that is not grass, in one channel.

        Returned as float in [-1, 1]. Not written into the training set — a
        1x1 convolution over red and NIR can learn this and anything better —
        but useful for eyeballing a scene and for the sanity check that the
        NIR band is really NIR and not a copy of red.
        """
        red = self.pixels[:, :, 0].astype(np.float32)
        nir = self.pixels[:, :, 3].astype(np.float32)
        denominator = nir + red
        return np.divide(nir - red, denominator,
                         out=np.zeros_like(denominator),
                         where=denominator > 0)


class NaipFetcher:
    """Fetches NAIP for a lat/lng box onto the app's own tile grid.

    Sorted newest first and stopping once the frame is covered, because a
    course rebuilt in 2019 should be learned as it is now and NAIP has flown
    most of the country half a dozen times.
    """

    def __init__(self, years: str = "2018-01-01/2026-12-31",
                 max_items: int = 12, timeout: int = 120):
        self.years = years
        self.max_items = max_items
        self.timeout = timeout
        self._catalog = None

    def _client(self):
        if self._catalog is None:
            import planetary_computer
            import pystac_client
            self._catalog = pystac_client.Client.open(
                STAC_URL, modifier=planetary_computer.sign_inplace)
        return self._catalog

    def search(self, south: float, west: float, north: float, east: float):
        """The NAIP scenes over this box, newest first."""
        search = self._client().search(
            collections=["naip"], bbox=[west, south, east, north],
            datetime=self.years)
        items = list(search.items())
        items.sort(key=lambda item: item.datetime, reverse=True)
        return items[:self.max_items]

    def fetch(self, south: float, west: float, north: float, east: float,
              zoom: int = 19) -> NaipScene:
        """The picture over this box, on the tile grid at `zoom`.

        Raises ValueError when NAIP has nothing here — which is every course
        outside the United States, and is not an error worth a stack trace at
        the call site.
        """
        import rasterio
        from rasterio.crs import CRS
        from rasterio.warp import Resampling, reproject, transform_bounds
        from rasterio.windows import Window, from_bounds

        bounds = self._grid(south, west, north, east, zoom)
        target_crs = CRS.from_epsg(3857)
        target_transform, target_bounds_m = self._target_frame(bounds)

        canvas = np.zeros((4, bounds.height, bounds.width), dtype=np.uint8)
        filled = np.zeros((bounds.height, bounds.width), dtype=bool)
        used: list[dict[str, Any]] = []

        for item in self.search(south, west, north, east):
            if filled.all():
                break
            href = item.assets["image"].href
            try:
                with rasterio.open(href) as source:
                    # Read only the window that touches this course. A NAIP
                    # quad is 7500 px square across four bands; pulling all of
                    # it over HTTP to keep a golf-hole-sized corner would be
                    # about two hundred megabytes for two.
                    window = self._source_window(
                        source, target_bounds_m, target_crs, from_bounds,
                        Window, transform_bounds)
                    if window is None:
                        continue
                    patch = source.read(window=window)
                    source_transform = source.window_transform(window)
                    source_crs = source.crs

                if patch.shape[0] < 4 or patch.size == 0:
                    continue

                landed = np.zeros_like(canvas)
                reproject(
                    source=patch, destination=landed,
                    src_transform=source_transform, src_crs=source_crs,
                    dst_transform=target_transform, dst_crs=target_crs,
                    resampling=Resampling.bilinear,
                    src_nodata=0, dst_nodata=0,
                )
            except Exception as error:      # noqa: BLE001
                # One unreadable scene is not a failed course: the next one in
                # the list is usually the same ground a year earlier.
                used.append({"id": item.id, "error": str(error)[:120]})
                continue

            fresh = (landed.any(axis=0)) & (~filled)
            if not fresh.any():
                continue
            canvas[:, fresh] = landed[:, fresh]
            filled |= fresh
            used.append({
                "id": item.id,
                "captured": item.datetime.date().isoformat(),
                "gsd": item.properties.get("gsd"),
                "share": round(float(fresh.mean()), 4),
            })

        coverage = float(filled.mean())
        if coverage == 0.0:
            raise ValueError(
                f"NAIP covers none of {south:.4f},{west:.4f} to "
                f"{north:.4f},{east:.4f} — outside the United States, or "
                f"outside {self.years}")

        bounds.metadata.update({
            "imageProvider": "naip",
            "imageFetched": date.today().isoformat(),
            "permitsAutomatedExtraction": True,
            "naipItems": [entry.get("id") for entry in used if "captured" in entry],
            "naipCoverage": round(coverage, 4),
            "bands": list(BANDS),
        })
        return NaipScene(
            pixels=np.transpose(canvas, (1, 2, 0)),
            bounds=bounds, items=used, coverage=coverage)

    @staticmethod
    def _grid(south: float, west: float, north: float, east: float,
              zoom: int) -> ImageBounds:
        """The whole tiles covering this box — the same frame TileFetcher uses.

        Snapping to the tile grid rather than to the requested box is what lets
        a NAIP patch and an Esri patch of the same course be the same pixels of
        the same ground. Cropping to the box instead is the mistake recorded in
        TileFetcher: it puts every mask a few metres north-west.
        """
        left, right = int(wm.tile_x(west, zoom)), int(wm.tile_x(east, zoom))
        top, bottom = int(wm.tile_y(north, zoom)), int(wm.tile_y(south, zoom))
        return ImageBounds(
            north=wm.latitude_of_tile_y(top, zoom),
            south=wm.latitude_of_tile_y(bottom + 1, zoom),
            east=wm.longitude_of_tile_x(right + 1, zoom),
            west=wm.longitude_of_tile_x(left, zoom),
            zoom=zoom,
            width=(right - left + 1) * wm.TILE_SIZE,
            height=(bottom - top + 1) * wm.TILE_SIZE,
            metadata={"tileX": left, "tileY": top, "zoom": zoom,
                      "mapProjection": "EPSG:3857"},
        )

    @staticmethod
    def _target_frame(bounds: ImageBounds):
        """The affine transform of the tile grid, in Web Mercator metres."""
        from rasterio.transform import from_bounds as transform_from_bounds

        west_m, north_m = wm.to_metres(bounds.north, bounds.west)
        east_m, south_m = wm.to_metres(bounds.south, bounds.east)
        transform = transform_from_bounds(
            west_m, south_m, east_m, north_m, bounds.width, bounds.height)
        return transform, (west_m, south_m, east_m, north_m)

    @staticmethod
    def _source_window(source, target_bounds_m, target_crs, from_bounds,
                       Window, transform_bounds):
        """The rectangle of the NAIP quad that touches this course, or None."""
        west_m, south_m, east_m, north_m = target_bounds_m
        left, bottom, right, top = transform_bounds(
            target_crs, source.crs, west_m, south_m, east_m, north_m,
            densify_pts=21)
        window = from_bounds(left, bottom, right, top, source.transform)
        # One pixel of slack each side, so bilinear resampling at the seam has
        # something to interpolate from rather than an edge.
        window = Window(window.col_off - 1, window.row_off - 1,
                        window.width + 2, window.height + 2)
        window = window.round_offsets().round_lengths()
        clipped = window.intersection(
            Window(0, 0, source.width, source.height))
        if clipped.width <= 0 or clipped.height <= 0:
            return None
        return clipped
