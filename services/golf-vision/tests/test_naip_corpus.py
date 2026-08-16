"""The two things about the NAIP corpus that fail silently.

Neither of these throws when it is wrong. A misaligned frame produces a
training set where every mask is a few metres from the thing it labels, and the
model trains happily to a mediocre score that looks like a hard problem rather
than a broken one. A mislabelled `ignore` produces a model that has been taught
that bunkers are background — also without complaint, and also indistinguishable
from "this is difficult" once it reaches a chart.

So they are tested here rather than trusted, and tested without a network: the
frame arithmetic is pure, and the mask rules only need polygons.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from golfvision.geo import webmercator as wm                     # noqa: E402
from golfvision.geo.tiles import ImageBounds                     # noqa: E402
from golfvision.masks.labels import (                            # noqa: E402
    IGNORE_INDEX, bounds_of, classes_present, patches_of, rasterize,
)
from golfvision.providers.naip import NaipFetcher                 # noqa: E402


def square(west, south, east, north, layer):
    """One axis-aligned polygon, in the shape the mask builder consumes."""
    return {
        "type": "Feature",
        "geometry": {"type": "Polygon", "coordinates": [[
            [west, south], [east, south], [east, north],
            [west, north], [west, south]]]},
        "properties": {"layerType": layer},
    }


class TestTheFrameMatchesTheTileGrid:
    """NAIP must land on exactly the pixels Esri would have landed on.

    Not for tidiness. The mask rasteriser converts degrees to pixels through
    `ImageBounds`, and it is the only converter — so if the NAIP frame and the
    tile frame disagree by half a tile, every polygon in the American corpus is
    painted in the wrong place and the model learns an offset.
    """

    def test_the_frame_is_whole_tiles(self):
        bounds = NaipFetcher._grid(36.5620, -121.9530, 36.5750, -121.9370,
                                   zoom=19)

        assert bounds.width % wm.TILE_SIZE == 0
        assert bounds.height % wm.TILE_SIZE == 0

    def test_the_frame_contains_what_was_asked_for(self):
        # Snapping outwards, never inwards: a course clipped to save a tile is
        # a course with a hole missing from one edge of its mask.
        south, west, north, east = 36.5620, -121.9530, 36.5750, -121.9370
        bounds = NaipFetcher._grid(south, west, north, east, zoom=19)

        assert bounds.south <= south
        assert bounds.west <= west
        assert bounds.north >= north
        assert bounds.east >= east

    def test_pixels_are_square(self):
        # Everything downstream that measures a distance assumes this, and
        # `metres_per_pixel` refuses to answer when it is false.
        bounds = NaipFetcher._grid(29.7, -95.5, 29.72, -95.47, zoom=19)

        assert bounds.pixels_are_square
        assert 0.15 < bounds.metres_per_pixel < 0.35

    def test_it_is_the_same_frame_the_tile_fetcher_builds(self):
        # The comparison that matters: same box, same zoom, same corners. The
        # tile fetcher derives these from the tile indices it pastes into a
        # canvas; this derives them from arithmetic. They have to agree.
        south, west, north, east = 33.5, -84.5, 33.53, -84.46
        zoom = 19
        bounds = NaipFetcher._grid(south, west, north, east, zoom)

        left, right = int(wm.tile_x(west, zoom)), int(wm.tile_x(east, zoom))
        top, bottom = int(wm.tile_y(north, zoom)), int(wm.tile_y(south, zoom))

        assert bounds.north == wm.latitude_of_tile_y(top, zoom)
        assert bounds.south == wm.latitude_of_tile_y(bottom + 1, zoom)
        assert bounds.west == wm.longitude_of_tile_x(left, zoom)
        assert bounds.east == wm.longitude_of_tile_x(right + 1, zoom)

    def test_web_mercator_metres_round_trip(self):
        # The affine transform handed to rasterio is built from these, and an
        # error here moves a whole course rather than blurring it.
        for latitude, longitude in [(36.57, -121.95), (25.79, -80.13),
                                    (21.03, 105.88)]:
            x, y = wm.to_metres(latitude, longitude)
            # Same origin as the tile grid: longitude 0 is x 0.
            assert abs(x) < 20_037_509 and abs(y) < 20_037_509
            back = wm.to_metres(latitude, 0.0)
            assert back[0] == pytest.approx(0.0, abs=1e-6)
            assert back[1] == pytest.approx(y, rel=1e-12)


class TestAnUnmappedClassIsNotBackground:
    """The rule the whole corpus rests on.

    OSM is positive-only and incomplete. Where a course has greens drawn and
    no bunkers, the sand is unlabelled — not labelled background — and a loss
    that learns "background" from it learns that bunkers are rare. This is the
    single most expensive mistake available in this pipeline and it is
    invisible in every metric until the model meets a real bunker.
    """

    def frame(self):
        return ImageBounds(north=33.53, south=33.50, east=-84.46, west=-84.50,
                           zoom=19, width=512, height=512)

    def test_a_class_the_course_never_mapped_is_ignored(self):
        # A green drawn, a bunker sitting inside it in the imagery and drawn by
        # nobody. `present` says this course maps greens only.
        features = [square(-84.49, 33.51, -84.48, 33.52, "GREEN")]
        mask = rasterize(features, self.frame(), classes_present(features))

        assert set(np.unique(mask)) <= {0, 3, IGNORE_INDEX}
        # Class 4 is bunker. It must appear nowhere: not as bunker, because
        # nobody drew one, and not as background either.
        assert 4 not in np.unique(mask)

    def test_ground_far_from_anything_drawn_stays_ignored(self):
        features = [square(-84.495, 33.505, -84.494, 33.506, "GREEN")]
        mask = rasterize(features, self.frame(), classes_present(features))

        # The far corner is beyond the dilated footprint: outside the course,
        # and the loss should not learn anything from it either way.
        assert mask[-1, -1] == IGNORE_INDEX

    def test_ground_between_features_becomes_learnable_background(self):
        # Inside the reach of the course, "nobody drew anything" is evidence:
        # this is the rough and the paths and the trees, and a model that never
        # sees them cannot tell them from a fairway.
        features = [square(-84.495, 33.505, -84.490, 33.515, "FAIRWAY"),
                    square(-84.480, 33.505, -84.475, 33.515, "FAIRWAY")]
        mask = rasterize(features, self.frame(), classes_present(features))

        assert 0 in np.unique(mask)

    def test_a_bunker_drawn_on_a_fairway_wins(self):
        # Draw order, and it is not cosmetic: a bunker is inside a fairway on
        # every hole ever built, and painting them in the wrong order labels
        # every bunker as fairway.
        features = [square(-84.495, 33.505, -84.470, 33.525, "FAIRWAY"),
                    square(-84.485, 33.512, -84.483, 33.514, "BUNKER")]
        mask = rasterize(features, self.frame(), classes_present(features))

        assert 4 in np.unique(mask)      # the bunker survived the fairway


class TestPatchesEarnTheirPlace:

    def test_a_patch_that_is_mostly_ignore_is_dropped(self):
        image = np.zeros((512, 512, 4), dtype=np.uint8)
        mask = np.full((512, 512), IGNORE_INDEX, dtype=np.uint8)
        mask[:100, :100] = 3        # a green in the corner, and nothing else

        assert list(patches_of(image, mask)) == []

    def test_a_patch_of_pure_background_is_dropped(self):
        image = np.zeros((512, 512, 4), dtype=np.uint8)
        mask = np.zeros((512, 512), dtype=np.uint8)

        assert list(patches_of(image, mask)) == []

    def test_a_patch_with_a_feature_is_kept_with_all_four_bands(self):
        image = np.random.randint(0, 255, (512, 512, 4), dtype=np.uint8)
        mask = np.zeros((512, 512), dtype=np.uint8)
        mask[100:300, 100:300] = 3

        kept = list(patches_of(image, mask))

        assert len(kept) == 1
        _, _, tile, _ = kept[0]
        assert tile.shape == (512, 512, 4)


class TestCourseBounds:

    def test_the_box_covers_every_feature_with_a_margin(self):
        features = [square(-84.50, 33.50, -84.49, 33.51, "GREEN"),
                    square(-84.46, 33.53, -84.45, 33.54, "BUNKER")]

        south, west, north, east = bounds_of(features)

        assert south < 33.50 and west < -84.50
        assert north > 33.54 and east > -84.45

    def test_a_course_with_nothing_drawn_has_no_box(self):
        assert bounds_of([]) is None
