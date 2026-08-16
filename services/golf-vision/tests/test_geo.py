"""The arithmetic that turns pixels into places.

Tested harder than anything else here because it fails silently. A model that
is wrong looks wrong; a sign error in a projection produces a plausible bunker
in the wrong field, and nobody notices until a golfer clubs off it.

The reference numbers come from the Java side — ``WebMercatorTest`` — because
the two implementations must agree to the decimal, not merely each be
self-consistent.
"""

from __future__ import annotations

import math

import pytest

from golfvision.geo import webmercator as wm
from golfvision.geo.tiles import ImageBounds


class TestWebMercator:

    def test_greenwich_equator_is_the_middle_of_the_world(self):
        assert wm.tile_x(0.0, 1) == pytest.approx(1.0)
        assert wm.tile_y(0.0, 1) == pytest.approx(1.0)

    def test_longitude_round_trips(self):
        for longitude in (-179.9, -105.8, 0.0, 105.89110, 179.9):
            x = wm.tile_x(longitude, 19)
            assert wm.longitude_of_tile_x(x, 19) == pytest.approx(longitude, abs=1e-9)

    def test_latitude_round_trips(self):
        for latitude in (-70.0, -21.0, 0.0, 10.85922, 21.03506, 70.0):
            y = wm.tile_y(latitude, 19)
            assert wm.latitude_of_tile_y(y, 19) == pytest.approx(latitude, abs=1e-9)

    def test_latitude_is_not_linear_in_degrees(self):
        """The error that produces a map where nothing looks wrong.

        Halfway down a tall box in projected space is not halfway in degrees.
        Treating it as such puts every feature a few metres out, consistently.
        """
        north, south = 60.0, 20.0
        middle = wm.latitude_of_tile_y(
            (wm.tile_y(north, 10) + wm.tile_y(south, 10)) / 2, 10)
        assert abs(middle - (north + south) / 2) > 1.0

    def test_ground_resolution_matches_published_figures(self):
        """Esri's own LOD table, at the latitudes this project cares about."""
        assert wm.metres_per_pixel(0.0, 19) == pytest.approx(0.2986, abs=0.001)
        # 16°N — the middle of Vietnam's golf.
        assert wm.metres_per_pixel(16.0, 19) == pytest.approx(0.287, abs=0.002)
        # One zoom out is exactly twice the ground per pixel.
        assert (wm.metres_per_pixel(16.0, 18)
                == pytest.approx(2 * wm.metres_per_pixel(16.0, 19)))

    def test_zoom_shrinks_to_fit_the_budget(self):
        south, west, north, east = 21.034, 105.891, 21.038, 105.895
        tight = wm.zoom_for(south, west, north, east, 512, 19)
        loose = wm.zoom_for(south, west, north, east, 4096, 19)
        assert tight < loose <= 19


class TestImageBounds:
    """A 500 m frame over Long Biên, which is where the real numbers live."""

    #: Eight tiles square at zoom 19 over Long Biên. The corners are the tile
    #: grid's, because that is what a stitched raster actually covers — and it
    #: is what makes the pixels square in both axes.
    NORTH, SOUTH = 21.0390052, 21.0338781
    EAST, WEST = 105.8958435, 105.8903503

    @classmethod
    def frame(cls, width: int = 1024, height: int = 1024) -> ImageBounds:
        return ImageBounds(north=cls.NORTH, south=cls.SOUTH,
                           east=cls.EAST, west=cls.WEST,
                           zoom=19, width=width, height=height)

    def test_corners_are_corners(self):
        bounds = self.frame()
        assert bounds.fraction_of(self.NORTH, self.WEST) == pytest.approx((0.0, 0.0), abs=1e-9)
        assert bounds.fraction_of(self.SOUTH, self.EAST) == pytest.approx((1.0, 1.0), abs=1e-9)

    def test_a_place_converts_to_a_fraction_and_back(self):
        bounds = self.frame()
        latitude, longitude = 21.03601, 105.89334
        x, y = bounds.fraction_of(latitude, longitude)
        assert 0 < x < 1 and 0 < y < 1
        assert bounds.longitude_at(x) == pytest.approx(longitude, abs=1e-9)
        assert bounds.latitude_at(y) == pytest.approx(latitude, abs=1e-9)

    def test_pixel_and_lat_lng_are_inverses(self):
        """Including the half-pixel.

        A mask's pixel (0, 0) covers ground from the corner inward, and its
        centre is half a pixel in. Dropping that biases every polygon up and
        left by half a pixel — 15 cm at 0.3 m/px, on every point of every
        boundary.
        """
        bounds = self.frame()
        for px, py in ((0, 0), (511.5, 300.25), (1023, 1023)):
            latitude, longitude = bounds.pixel_to_lat_lng(px, py)
            back_x, back_y = bounds.lat_lng_to_pixel(latitude, longitude)
            assert back_x == pytest.approx(px, abs=1e-6)
            assert back_y == pytest.approx(py, abs=1e-6)

    def test_north_is_up_and_east_is_right(self):
        """The orientation error that mirrors a course and looks fine."""
        bounds = self.frame()
        top = bounds.latitude_at(0.0)
        bottom = bounds.latitude_at(1.0)
        assert top > bottom
        assert bounds.longitude_at(0.0) < bounds.longitude_at(1.0)

    def test_metres_per_pixel_reflects_the_raster_size(self):
        """Twice the pixels over the same ground is half the metres each."""
        coarse = self.frame(512, 512).metres_per_pixel
        fine = self.frame(1024, 1024).metres_per_pixel
        assert fine == pytest.approx(coarse / 2, rel=1e-9)

    def test_a_hole_length_measures_what_it_should(self):
        """Long Biên Đường A hole 1 plays 514 yards from the back tee.

        Tee to green in a straight line is shorter than the card — a dogleg
        and the card is measured along the line of play — so this checks the
        order of magnitude, which is what catches a projection that is wrong
        by a factor rather than a metre.
        """
        bounds = self.frame()
        tee = (21.03752, 105.89444)
        green = (21.03506, 105.89110)
        tee_x, tee_y = bounds.lat_lng_to_pixel(*tee)
        green_x, green_y = bounds.lat_lng_to_pixel(*green)
        pixels = math.hypot(tee_x - green_x, tee_y - green_y)
        metres = pixels * bounds.metres_per_pixel
        assert 400 < metres < 500

    def test_a_raster_whose_aspect_lies_is_refused(self):
        """The bug this whole property exists to make loud.

        A box 571 m across and 500 m down, declared as 1024x1024, has pixels
        14% longer in one axis than the other. Every area computed from a
        single scale is wrong by that much and nothing looks odd — which is
        exactly how it survived until an area came out 14% short of a circle
        whose radius was known.
        """
        lying = ImageBounds(north=21.0385, south=21.0340, east=105.8965,
                            west=105.8910, zoom=19, width=1024, height=1024)

        assert not lying.pixels_are_square
        with pytest.raises(ValueError, match="not square"):
            _ = lying.metres_per_pixel
        # The per-axis numbers are still available, and still correct.
        assert lying.metres_per_pixel_x > lying.metres_per_pixel_y

    def test_a_real_tile_crop_has_square_pixels(self):
        assert self.frame(2048, 2048).pixels_are_square
        assert self.frame(512, 512).pixels_are_square
