package vnpt.vsp.module.geometry.vision;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import vnpt.vsp.module.geometry.LayerType;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * Reading a vision model's answer without believing all of it.
 *
 * <p>The model is asked for shapes in image space and everything it returns
 * is checked before it becomes a proposal a human has to review. Forty
 * rejected drafts cost a reviewer more than no drafts at all, so nonsense is
 * dropped here rather than passed along politely.
 */
class VisionGeometryReaderTest {

    /// A 500 m square over Long Biên, near enough for the arithmetic.
    private static final ImageBounds BOUNDS =
            new ImageBounds(21.0385, 21.0340, 105.8965, 105.8910, 18);

    private final VisionGeometryReader reader =
            new VisionGeometryReader(new ObjectMapper());

    private static String json(String features) {
        return "{\"features\": [" + features + "]}";
    }

    @Test
    @DisplayName("a green in image space lands on the ground it was seen on")
    void convertsToGround() {
        var detected = reader.read(json("""
                {"layer": "green", "confidence": 0.9,
                 "polygon": [[0.5,0.5],[0.545,0.5],[0.545,0.55],[0.5,0.55]]}
                """), BOUNDS);

        assertThat(detected).hasSize(1);
        var green = detected.get(0);
        assertThat(green.layerType()).isEqualTo(LayerType.GREEN);
        // The middle of the image is the middle of the box.
        assertThat(green.ring().get(0)[1])
                .isCloseTo((105.8965 + 105.8910) / 2, within(1e-6));
        assertThat(green.ring().get(0)[0])
                .isCloseTo((21.0385 + 21.0340) / 2, within(1e-4));
    }

    /// The ring has to close or Postgres refuses the polygon at insert time,
    /// which is a failure discovered far away from its cause.
    @Test
    @DisplayName("an open ring is closed")
    void closesTheRing() {
        var detected = reader.read(json("""
                {"layer": "bunker",
                 "polygon": [[0.1,0.1],[0.13,0.1],[0.13,0.13],[0.1,0.13]]}
                """), BOUNDS);

        var ring = detected.get(0).ring();
        assertThat(ring.get(0)).isEqualTo(ring.get(ring.size() - 1));
        assertThat(detected.get(0).toWkt())
                .startsWith("POLYGON((")
                .endsWith("))");
    }

    @Test
    @DisplayName("the words a model reaches for are mapped to our layers")
    void mapsSynonyms() {
        var detected = reader.read(json("""
                {"layer": "water", "polygon": [[0.1,0.1],[0.2,0.1],[0.2,0.2],[0.1,0.2]]},
                {"layer": "sand trap", "polygon": [[0.3,0.3],[0.33,0.3],[0.33,0.33],[0.3,0.33]]},
                {"layer": "teeing ground", "polygon": [[0.5,0.5],[0.53,0.5],[0.53,0.53],[0.5,0.53]]}
                """), BOUNDS);

        assertThat(detected).extracting(DetectedFeature::layerType)
                .containsExactly(LayerType.WATER_HAZARD, LayerType.BUNKER,
                        LayerType.TEE);
    }

    @Test
    @DisplayName("a layer this app has no table for is dropped")
    void dropsUnknownLayers() {
        var detected = reader.read(json("""
                {"layer": "clubhouse", "polygon": [[0.1,0.1],[0.2,0.1],[0.2,0.2],[0.1,0.2]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    /// Coordinates outside the frame mean the model was working in some
    /// other space — pixels, metres, degrees — and none of its answer can be
    /// trusted to be where it says.
    @Test
    @DisplayName("points outside the image are refused, not clamped")
    void refusesPointsOutsideTheFrame() {
        var detected = reader.read(json("""
                {"layer": "green", "polygon": [[0.5,0.5],[1.4,0.5],[1.4,0.6],[0.5,0.6]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    @Test
    @DisplayName("three points are not a polygon")
    void refusesTooFewPoints() {
        var detected = reader.read(json("""
                {"layer": "green", "polygon": [[0.5,0.5],[0.6,0.5],[0.6,0.6]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    /// A shape covering the whole frame is the model outlining the picture.
    @Test
    @DisplayName("a feature the size of the image is refused")
    void refusesTheWholeFrame() {
        var detected = reader.read(json("""
                {"layer": "fairway", "polygon": [[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    @Test
    @DisplayName("a fenced code block is still JSON")
    void survivesAFencedBlock() {
        var detected = reader.read("""
                ```json
                {"features": [{"layer": "green",
                  "polygon": [[0.5,0.5],[0.545,0.5],[0.545,0.55],[0.5,0.55]]}]}
                ```
                """, BOUNDS);

        assertThat(detected).hasSize(1);
    }

    @Test
    @DisplayName("an answer that is not JSON at all produces nothing")
    void survivesRubbish() {
        assertThat(reader.read("I cannot see a golf course here.", BOUNDS))
                .isEmpty();
        assertThat(reader.read(null, BOUNDS)).isEmpty();
    }

    /// Longitude interpolates linearly; latitude does not, because Web
    /// Mercator stretches it. Interpolating it linearly puts a green a few
    /// metres out, consistently, and nothing on the map looks wrong.
    @Test
    @DisplayName("latitude is interpolated in projected space, not degrees")
    void latitudeIsNotLinear() {
        // A tall box, where the difference is visible.
        var tall = new ImageBounds(60.0, 20.0, 105.9, 105.8, 10);

        double linear = 60.0 + (20.0 - 60.0) * 0.5;
        assertThat(tall.latitudeAt(0.5)).isNotCloseTo(linear, within(0.5));
    }

    /// The prompt tells the model where the tee is in image fractions, so
    /// the conversion has to be exactly the inverse of the one that reads
    /// its answer back — otherwise it is told the tee is somewhere it can
    /// see it is not, and anchors on the wrong thing.
    @Test
    @DisplayName("a place converts to a fraction and back to itself")
    void fractionRoundTrips() {
        double lat = 21.0368, lng = 105.8940;

        double[] fraction = BOUNDS.fractionOf(lat, lng);

        assertThat(fraction[0]).isBetween(0.0, 1.0);
        assertThat(fraction[1]).isBetween(0.0, 1.0);
        assertThat(BOUNDS.longitudeAt(fraction[0])).isCloseTo(lng, within(1e-9));
        assertThat(BOUNDS.latitudeAt(fraction[1])).isCloseTo(lat, within(1e-9));
    }

    @Test
    @DisplayName("the corners are the corners")
    void cornersAreCorners() {
        assertThat(BOUNDS.fractionOf(21.0385, 105.8910)[0]).isCloseTo(0.0, within(1e-9));
        assertThat(BOUNDS.fractionOf(21.0385, 105.8910)[1]).isCloseTo(0.0, within(1e-9));
        assertThat(BOUNDS.fractionOf(21.0340, 105.8965)[0]).isCloseTo(1.0, within(1e-9));
        assertThat(BOUNDS.fractionOf(21.0340, 105.8965)[1]).isCloseTo(1.0, within(1e-9));
    }

    /// A flood fill that leaked along a cart path into the next bunker comes
    /// back looking exactly like a polygon. Golf is the check.
    @Test
    @DisplayName("a bunker the size of a fairway is not a bunker")
    void refusesAnImplausibleRefinement() {
        // A synthetic image where everything is one colour: the flood fills
        // the whole window, which the refiner already rejects — and even if
        // it did not, the area check would.
        var image = new java.awt.image.BufferedImage(
                400, 400, java.awt.image.BufferedImage.TYPE_INT_RGB);
        var g = image.createGraphics();
        g.setColor(java.awt.Color.GRAY);
        g.fillRect(0, 0, 400, 400);
        g.dispose();

        var detected = reader.read(json("""
                {"layer": "bunker",
                 "polygon": [[0.40,0.40],[0.46,0.40],[0.46,0.46],[0.40,0.46]]}
                """), BOUNDS, image);

        // The seed survives: eight points, not sixty-one.
        assertThat(detected).hasSize(1);
        assertThat(detected.get(0).ring().size()).isLessThan(20);
    }

    /// The failure this bound was built from. Traced against Long Biên, the
    /// model's greens averaged 2000 m² where the twelve a human had already
    /// drawn at the same course measure 491 to 712; hole 9 of Đường A came
    /// back at 5501. What it outlines when it is unsure is the whole green
    /// complex — surrounds, collar, approach — and a front edge fifty metres
    /// from the real one is a number a golfer clubs off.
    @Test
    @DisplayName("a green the size of a green complex is not a green")
    void refusesAnOversizeGreen() {
        // A fifth of a 500 m frame each way: about 11,000 m².
        var detected = reader.read(json("""
                {"layer": "green",
                 "polygon": [[0.4,0.4],[0.6,0.4],[0.6,0.6],[0.4,0.6]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    /// And the other end of it: a model that returns a dot where it cannot
    /// see the green rather than admitting it cannot see the green.
    @Test
    @DisplayName("a green too small to putt on is not a green")
    void refusesATinyGreen() {
        var detected = reader.read(json("""
                {"layer": "green",
                 "polygon": [[0.5,0.5],[0.505,0.5],[0.505,0.505],[0.5,0.505]]}
                """), BOUNDS);

        assertThat(detected).isEmpty();
    }

    /// The bound has to admit what is real, or it costs more than it saves.
    @Test
    @DisplayName("a green of six hundred square metres is a green")
    void acceptsARealGreen() {
        var detected = reader.read(json("""
                {"layer": "green",
                 "polygon": [[0.5,0.5],[0.545,0.5],[0.545,0.55],[0.5,0.55]]}
                """), BOUNDS);

        assertThat(detected).hasSize(1);
    }

    @Test
    @DisplayName("a green keeps the model's outline — grass has no edge to find")
    void doesNotRefineGrass() {
        var image = new java.awt.image.BufferedImage(
                400, 400, java.awt.image.BufferedImage.TYPE_INT_RGB);

        var detected = reader.read(json("""
                {"layer": "green",
                 "polygon": [[0.48,0.48],[0.525,0.48],[0.525,0.53],[0.48,0.53]]}
                """), BOUNDS, image);

        assertThat(detected.get(0).ring()).hasSize(5);
    }
}
