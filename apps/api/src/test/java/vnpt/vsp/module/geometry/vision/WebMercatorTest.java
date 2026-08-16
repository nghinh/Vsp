package vnpt.vsp.module.geometry.vision;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * The conversion between a place and a pixel.
 *
 * <p>Everything the satellite reader produces rests on this, and a sign or a
 * factor wrong here draws a perfectly plausible bunker in the next province.
 * Nothing downstream could tell: the polygon would be the right shape, the
 * right size, and in the wrong place.
 */
class WebMercatorTest {

    /// Long Biên's first tee, near enough.
    private static final double LAT = 21.0368534;
    private static final double LNG = 105.8963846;

    @Test
    @DisplayName("a point survives the round trip through tile space")
    void roundTrips() {
        for (int zoom : new int[]{14, 16, 18, 20}) {
            double x = WebMercator.tileX(LNG, zoom);
            double y = WebMercator.tileY(LAT, zoom);

            assertThat(WebMercator.longitudeOfTileX(x, zoom))
                    .isCloseTo(LNG, within(1e-9));
            assertThat(WebMercator.latitudeOfTileY(y, zoom))
                    .isCloseTo(LAT, within(1e-9));
        }
    }

    /// The known corner of the world: tile 0,0 at zoom 0 starts at the
    /// north-west limit of Web Mercator.
    @Test
    @DisplayName("the origin is the north-west corner, not the equator")
    void originIsNorthWest() {
        assertThat(WebMercator.longitudeOfTileX(0, 0)).isEqualTo(-180.0);
        assertThat(WebMercator.latitudeOfTileY(0, 0))
                .isCloseTo(85.0511, within(0.001));
        assertThat(WebMercator.tileX(0, 1)).isEqualTo(1.0);
        assertThat(WebMercator.tileY(0, 1)).isEqualTo(1.0);
    }

    /// y grows southward. Getting this backwards mirrors every hole.
    @Test
    @DisplayName("tile y increases as you go south")
    void yGrowsSouthward() {
        int zoom = 16;
        assertThat(WebMercator.tileY(21.05, zoom))
                .isLessThan(WebMercator.tileY(21.03, zoom));
        assertThat(WebMercator.tileX(105.88, zoom))
                .isLessThan(WebMercator.tileX(105.90, zoom));
    }

    @Test
    @DisplayName("a hole-sized box picks a zoom that fills the frame")
    void picksAZoomForAHole() {
        // Roughly 500 m by 200 m — a long par 5.
        double south = 21.0340, north = 21.0385;
        double west = 105.8910, east = 105.8965;

        int zoom = WebMercator.zoomFor(south, west, north, east, 1024, 20);

        double width = Math.abs(WebMercator.tileX(east, zoom)
                - WebMercator.tileX(west, zoom)) * WebMercator.TILE_SIZE;
        double height = Math.abs(WebMercator.tileY(south, zoom)
                - WebMercator.tileY(north, zoom)) * WebMercator.TILE_SIZE;

        assertThat(width).isLessThanOrEqualTo(1024);
        assertThat(height).isLessThanOrEqualTo(1024);
        // And it is the deepest such zoom: one more would overflow.
        double widerWidth = Math.abs(WebMercator.tileX(east, zoom + 1)
                - WebMercator.tileX(west, zoom + 1)) * WebMercator.TILE_SIZE;
        double tallerHeight = Math.abs(WebMercator.tileY(south, zoom + 1)
                - WebMercator.tileY(north, zoom + 1)) * WebMercator.TILE_SIZE;
        assertThat(Math.max(widerWidth, tallerHeight)).isGreaterThan(1024);
    }

    /// An operator whose licence stops at zoom 17 must not be asked for 18.
    @Test
    @DisplayName("never deeper than the imagery licence allows")
    void respectsTheMaxZoom() {
        int zoom = WebMercator.zoomFor(21.0340, 105.8910, 21.0385, 105.8965,
                1024, 17);

        assertThat(zoom).isLessThanOrEqualTo(17);
    }

    /// A metre near the equator and a metre in Hanoi are different numbers of
    /// pixels; at zoom 18 a hole is a few hundred pixels, which is what makes
    /// the image worth showing a model.
    @Test
    @DisplayName("a 400 m hole is a few hundred pixels at zoom 18")
    void scaleIsSane() {
        int zoom = 18;
        double metresPerDegreeLat = 111_320.0;
        double north = LAT + 400 / metresPerDegreeLat;

        double pixels = Math.abs(WebMercator.tileY(north, zoom)
                - WebMercator.tileY(LAT, zoom)) * WebMercator.TILE_SIZE;

        assertThat(pixels).isBetween(300.0, 800.0);
    }
}
