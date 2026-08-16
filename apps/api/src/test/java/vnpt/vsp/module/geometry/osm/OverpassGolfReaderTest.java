package vnpt.vsp.module.geometry.osm;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import vnpt.vsp.module.geometry.LayerType;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Reading what a mapper drew.
 *
 * <p>The JSON here is the shape Overpass really answers with — {@code out
 * geom}, coordinates inline on each way — trimmed to the parts this reader
 * looks at.
 */
class OverpassGolfReaderTest {

    private final OverpassGolfReader reader = new OverpassGolfReader(new ObjectMapper());

    private static String way(long id, String tags, String geometry) {
        return """
                {"type": "way", "id": %d, "tags": {%s}, "geometry": [%s]}
                """.formatted(id, tags, geometry);
    }

    private static String elements(String... ways) {
        return "{\"elements\": [" + String.join(",", ways) + "]}";
    }

    /// A closed square, near enough to a green for a parser's purposes.
    private static final String SQUARE = """
            {"lat": 21.0350, "lon": 105.8910},
            {"lat": 21.0350, "lon": 105.8912},
            {"lat": 21.0352, "lon": 105.8912},
            {"lat": 21.0352, "lon": 105.8910},
            {"lat": 21.0350, "lon": 105.8910}
            """;

    @Test
    @DisplayName("the golf tags this app has layers for are read")
    void readsTheGolfSchema() {
        var features = reader.read(elements(
                way(1, "\"golf\": \"green\"", SQUARE),
                way(2, "\"golf\": \"bunker\"", SQUARE),
                way(3, "\"golf\": \"fairway\"", SQUARE),
                way(4, "\"golf\": \"tee\"", SQUARE),
                way(5, "\"golf\": \"water_hazard\"", SQUARE),
                way(6, "\"golf\": \"rough\"", SQUARE)));

        assertThat(features).extracting(OsmGolfFeature::layer)
                .containsExactly(LayerType.GREEN, LayerType.BUNKER,
                        LayerType.FAIRWAY, LayerType.TEE,
                        LayerType.WATER_HAZARD, LayerType.ROUGH);
    }

    /// Most mappers tag a pond on a course natural=water and never reach for
    /// the golf schema at all. Sixty-five of the sixty-eight bodies of water
    /// at Long Biên are tagged that way.
    @Test
    @DisplayName("a plain body of water counts as a hazard")
    void readsPlainWater() {
        var features = reader.read(elements(way(7, "\"natural\": \"water\"", SQUARE)));

        assertThat(features).singleElement()
                .extracting(OsmGolfFeature::layer).isEqualTo(LayerType.WATER_HAZARD);
    }

    @Test
    @DisplayName("what is on a course but not part of playing it is skipped")
    void skipsWhatIsNotAFeature() {
        var features = reader.read(elements(
                way(9, "\"golf\": \"clubhouse\"", SQUARE),
                way(10, "\"golf\": \"driving_range\"", SQUARE),
                way(11, "\"golf\": \"hole\"", SQUARE),
                way(12, "\"building\": \"yes\"", SQUARE)));

        assertThat(features).isEmpty();
    }

    /// A cart path is not something to aim at, and it is kept anyway: the loop
    /// they form is the outline of the golf course, which is the only thing
    /// that tells a segmentation model the houses next door are not part of
    /// it. Long Biên's model painted their roofs as water.
    @Test
    @DisplayName("a cart path is kept, as a line, because it draws the course")
    void keepsCartPathsAsLines() {
        var open = """
                {"lat": 21.0350, "lon": 105.8910},
                {"lat": 21.0352, "lon": 105.8914},
                {"lat": 21.0356, "lon": 105.8919}
                """;

        var features = reader.read(elements(way(21, "\"golf\": \"cartpath\"", open)));

        assertThat(features).singleElement().satisfies(feature -> {
            assertThat(feature.layer()).isEqualTo(LayerType.CART_PATH);
            // A line, not a ring — closing it would enclose ground nobody
            // drives on and inflate the course by whatever it wrapped.
            assertThat(feature.toWkt()).startsWith("LINESTRING(");
        });
    }

    @Test
    @DisplayName("an open way that is not a path is still refused")
    void refusesOtherOpenWays() {
        var open = """
                {"lat": 21.0350, "lon": 105.8910},
                {"lat": 21.0352, "lon": 105.8914},
                {"lat": 21.0356, "lon": 105.8919}
                """;

        assertThat(reader.read(elements(way(22, "\"golf\": \"green\"", open)))).isEmpty();
    }

    /// A way whose ends do not meet is a fence, a wall or a path, whatever
    /// its tags say. Treating one as an area would file a bunker shaped like
    /// a hairpin.
    @Test
    @DisplayName("an open way is not an area")
    void refusesAnOpenWay() {
        var open = """
                {"lat": 21.0350, "lon": 105.8910},
                {"lat": 21.0350, "lon": 105.8912},
                {"lat": 21.0352, "lon": 105.8912},
                {"lat": 21.0352, "lon": 105.8914}
                """;

        assertThat(reader.read(elements(way(13, "\"golf\": \"bunker\"", open)))).isEmpty();
    }

    @Test
    @DisplayName("the way id survives, so a re-import updates rather than duplicates")
    void keepsTheWayId() {
        var features = reader.read(elements(
                way(414243, "\"golf\": \"green\", \"name\": \"Hố 1\"", SQUARE)));

        assertThat(features).singleElement().satisfies(feature -> {
            assertThat(feature.osmId()).isEqualTo(414243);
            assertThat(feature.externalId()).isEqualTo("osm:way:414243");
            assertThat(feature.name()).isEqualTo("Hố 1");
        });
    }

    /// Longitude first. The other order puts Hanoi in the Indian Ocean, and
    /// PostGIS accepts it without complaint.
    @Test
    @DisplayName("WKT is written longitude first")
    void writesWktLongitudeFirst() {
        var feature = reader.read(elements(way(14, "\"golf\": \"green\"", SQUARE))).get(0);

        assertThat(feature.toWkt()).startsWith("POLYGON((105.891000000 21.035000000");
        assertThat(feature.toWkt()).endsWith("))");
    }

    @Test
    @DisplayName("an answer that is not JSON produces nothing, not an exception")
    void survivesRubbish() {
        assertThat(reader.read("<html>rate limited</html>")).isEmpty();
        assertThat(reader.read(null)).isEmpty();
        assertThat(reader.read("")).isEmpty();
        assertThat(reader.read("{}")).isEmpty();
    }
}
