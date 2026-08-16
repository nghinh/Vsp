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
                 "polygon": [[0.5,0.5],[0.6,0.5],[0.6,0.6],[0.5,0.6]]}
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
                 "polygon": [[0.1,0.1],[0.2,0.1],[0.2,0.2],[0.1,0.2]]}
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
                {"layer": "sand trap", "polygon": [[0.3,0.3],[0.4,0.3],[0.4,0.4],[0.3,0.4]]},
                {"layer": "teeing ground", "polygon": [[0.5,0.5],[0.6,0.5],[0.6,0.6],[0.5,0.6]]}
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
                  "polygon": [[0.5,0.5],[0.6,0.5],[0.6,0.6],[0.5,0.6]]}]}
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
}
