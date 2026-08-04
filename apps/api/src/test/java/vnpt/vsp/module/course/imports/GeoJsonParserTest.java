package vnpt.vsp.module.course.imports;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import vnpt.vsp.api.error.VspApiException;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for GeoJsonParser.
 * Per Story 3.4 AC-1.
 */
class GeoJsonParserTest {

    private GeoJsonParser parser;

    @BeforeEach
    void setUp() {
        parser = new GeoJsonParser(new ObjectMapper());
    }

    @Test
    void parse_validFeatureCollection_returnsParsedFeatures() {
        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [106.6292, 10.8231]
                  },
                  "properties": {
                    "landmark_type": "clubhouse",
                    "name": "Club House"
                  }
                },
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[106.62, 10.82], [106.63, 10.82], [106.63, 10.83], [106.62, 10.82]]]
                  },
                  "properties": {
                    "hole_id": 1
                  }
                }
              ]
            }
            """;

        List<ParsedFeature> features = parser.parse(geoJson);

        assertEquals(2, features.size());
        assertEquals("Point", features.get(0).getGeometryType());
        assertEquals("Polygon", features.get(1).getGeometryType());
        assertNotNull(features.get(0).getProperties());
        assertEquals("clubhouse", features.get(0).getProperties().get("landmark_type"));
    }

    @Test
    void parse_singleFeature_returnsSingleParsedFeature() {
        String geoJson = """
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [106.6292, 10.8231]
              },
              "properties": {
                "landmark_type": "restroom",
                "name": "Restroom 1"
              }
            }
            """;

        List<ParsedFeature> features = parser.parse(geoJson);

        assertEquals(1, features.size());
        assertEquals("Point", features.get(0).getGeometryType());
        assertEquals(0, features.get(0).getIndex());
    }

    @Test
    void parse_emptyCollection_throwsException() {
        String geoJson = """
            {
              "type": "FeatureCollection",
              "features": []
            }
            """;

        VspApiException exception = assertThrows(VspApiException.class, () -> parser.parse(geoJson));
        assertEquals("VSP-ERR-COURSE-IMPORT-002", exception.getErrorCode().getCode());
    }

    @Test
    void parse_invalidJson_throwsException() {
        String geoJson = "not valid json at all";

        VspApiException exception = assertThrows(VspApiException.class, () -> parser.parse(geoJson));
        assertEquals("VSP-ERR-COURSE-IMPORT-001", exception.getErrorCode().getCode());
    }

    @Test
    void parse_emptyString_throwsException() {
        VspApiException exception = assertThrows(VspApiException.class, () -> parser.parse(""));
        assertEquals("VSP-ERR-COURSE-IMPORT-001", exception.getErrorCode().getCode());
    }

    @Test
    void parse_nullJson_throwsException() {
        VspApiException exception = assertThrows(VspApiException.class, () -> parser.parse(null));
        assertEquals("VSP-ERR-COURSE-IMPORT-001", exception.getErrorCode().getCode());
    }

    @Test
    void parse_unsupportedType_throwsException() {
        String geoJson = """
            {
              "type": "GeometryCollection",
              "geometries": []
            }
            """;

        VspApiException exception = assertThrows(VspApiException.class, () -> parser.parse(geoJson));
        assertEquals("VSP-ERR-COURSE-IMPORT-001", exception.getErrorCode().getCode());
    }

    @Test
    void parse_lineStringFeature_parsesCorrectly() {
        String geoJson = """
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [[106.62, 10.82], [106.63, 10.83], [106.64, 10.84]]
              },
              "properties": {
                "path_type": "cart_path",
                "hole_id": 5
              }
            }
            """;

        List<ParsedFeature> features = parser.parse(geoJson);

        assertEquals(1, features.size());
        assertEquals("LineString", features.get(0).getGeometryType());
        assertNotNull(features.get(0).getCoordinates());
    }
}
